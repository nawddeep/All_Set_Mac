import AllSetCore
import AppKit
import SwiftUI

/// Everything a widget's components need to draw in its theme: colors, type
/// and the card they sit on. Resolved once per widget and handed down the
/// environment, so no widget styles itself.
struct WidgetStyle {
    var theme: DesignTheme?
    var isDark: Bool
    var ink: Color
    /// Supporting text; the theme's own gray, or the system's.
    var secondary: AnyShapeStyle
    var accent: Color
    var design: Font.Design
    var width: Font.Width
    var numberWeight: Font.Weight
    var titleWeight: Font.Weight
    var uppercaseLabels: Bool
    var labelTracking: CGFloat
    var cornerRadius: CGFloat
    var motion: MotionLanguage = .calm

    var surface: SurfaceStyle? { theme?.surface }

    /// Big figures: times, temperatures, percentages.
    func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: numberWeight, design: design).width(width).monospacedDigit()
    }

    func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: titleWeight, design: design).width(width)
    }

    func body(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: design).width(width)
    }

    /// Small captions over values ("CPU", "Today").
    func label(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: design).width(width)
    }

    /// The look for widgets on the classic cards (no design theme).
    static func classic(font: WidgetFont, accent: Color, cornerRadius: CGFloat) -> WidgetStyle {
        WidgetStyle(theme: nil, isDark: false, ink: .primary, secondary: AnyShapeStyle(.secondary), accent: accent,
                    design: font.design, width: font.width, numberWeight: .light, titleWeight: .semibold,
                    uppercaseLabels: false, labelTracking: 0, cornerRadius: cornerRadius)
    }

    static func themed(_ theme: DesignTheme, palette: ThemePalette, isDark: Bool, accent: Color) -> WidgetStyle {
        let type = theme.typography
        return WidgetStyle(theme: theme, isDark: isDark, ink: Color(palette.ink), secondary: AnyShapeStyle(Color(palette.secondaryInk)),
                           accent: accent, design: type.font.design, width: type.font.width,
                           numberWeight: type.numberWeight.fontWeight, titleWeight: type.titleWeight.fontWeight,
                           uppercaseLabels: type.uppercaseLabels, labelTracking: type.labelTracking, cornerRadius: theme.cornerRadius,
                           motion: theme.motion)
    }
}

extension EnvironmentValues {
    @Entry var widgetStyle = WidgetStyle.classic(font: .rounded, accent: .accentColor, cornerRadius: 22)
}

extension ThemeWeight {
    var fontWeight: Font.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

/// Keeps what themes need from the outside world: the color of the desktop
/// picture. It looks again only when something could have changed it (a new
/// space, waking, the app coming forward, the live wallpaper changing), and
/// then only if the file did, decoding a 64-pixel thumbnail off the main thread.
@Observable @MainActor
final class ThemeManager {
    private(set) var wallpaperAccent: WidgetColor?

    @ObservationIgnored private var lastSource: String?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private weak var services: AppServices?

    func start(services: AppServices) {
        self.services = services
        refresh()
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.screensDidWakeNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil,
                                                                queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
        observe({ [services] in services.wallpaper.config.isEnabled ? services.wallpaper.config.source : nil }) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        guard let services else { return }
        let config = services.wallpaper.config
        // Our own live wallpaper: its art already knows its colors.
        if config.isEnabled, case .art(let piece) = config.source {
            let source = "art:\(piece.id)"
            guard source != lastSource else { return }
            lastSource = source
            wallpaperAccent = piece.palette.colors[2...4].max { $0.hsvSaturation < $1.hsvSaturation }
            return
        }
        let url: URL?
        if config.isEnabled, case .photo(let image) = config.source {
            url = services.images.fileURL(for: image)
        } else {
            url = NSScreen.main.flatMap { NSWorkspace.shared.desktopImageURL(for: $0) }
        }
        guard let url else { return }
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? 0
        let source = "\(url.path)|\(modified)"
        guard source != lastSource else { return }
        lastSource = source
        Task.detached(priority: .utility) {
            let color = WallpaperColor.accent(of: url)
            await MainActor.run { [weak self] in self?.wallpaperAccent = color }
        }
    }

    /// The highlight a themed widget uses: the widget's own color if it has
    /// one, then its wallpaper setting (Automatic nudges the theme's color
    /// toward the desktop's, never replacing it; Off draws highlights in gray),
    /// then the theme's source.
    func accent(for theme: DesignTheme, palette: ThemePalette, isDark: Bool, override: WidgetColor?,
                mode: WallpaperAdaptation? = nil) -> Color {
        if let override { return Color(override) }
        switch mode {
        case .disabled:
            return Color(palette.secondaryInk)
        case .fixed:
            return theme.accentSource == .system ? Color(nsColor: .controlAccentColor) : Color(palette.accent)
        case .automatic:
            guard theme.accentSource != .wallpaper else { break }
            guard let wallpaper = wallpaperAccent else { return Color(palette.accent) }
            return Color(palette.accent.blended(toward: wallpaper.adjusted(forDark: isDark), by: 0.35))
        case nil:
            break
        }
        switch theme.accentSource {
        case .theme:
            return Color(palette.accent)
        case .system:
            return Color(nsColor: .controlAccentColor)
        case .wallpaper:
            return Color((wallpaperAccent ?? palette.accent).adjusted(forDark: isDark))
        }
    }
}

extension WidgetColor {
    func blended(toward other: WidgetColor, by amount: Double) -> WidgetColor {
        WidgetColor(red: red + (other.red - red) * amount, green: green + (other.green - green) * amount,
                    blue: blue + (other.blue - blue) * amount)
    }

    var hsvSaturation: Double {
        let maxC = max(red, green, blue), minC = min(red, green, blue)
        return maxC == 0 ? 0 : (maxC - minC) / maxC
    }
}
