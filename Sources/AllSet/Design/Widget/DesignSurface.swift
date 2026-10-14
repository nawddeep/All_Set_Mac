import AllSetCore
import SwiftUI

/// The card behind a themed widget. Each surface is drawn once and holds
/// still: nothing here animates or redraws on its own.
struct DesignSurface<Content: View>: View {
    let theme: DesignTheme
    let palette: ThemePalette
    let isDark: Bool
    let accent: Color
    /// 0 as designed, up to 1 for as see-through as the surface allows.
    let transparency: Double
    @ViewBuilder var content: Content

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous) }
    private var background: Color { Color(palette.background) }

    var body: some View {
        surfaced
            .overlay { edge.allowsHitTesting(false) }
            .clipShape(shape)
            .environment(\.colorScheme, isDark ? .dark : .light)
    }

    @ViewBuilder
    private var surfaced: some View {
        let filled = content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(Color(palette.ink))
        switch theme.surface {
        case .liquidGlass:
            WidgetGlassEffect(isDark: isDark, tint: accent, transparency: transparency, cornerRadius: theme.cornerRadius) {
                filled
            }
        default:
            filled.background { fill.allowsHitTesting(false) }
        }
    }

    @ViewBuilder
    private var fill: some View {
        let opaque = 1 - transparency
        switch theme.surface {
        case .native:
            ZStack {
                VisualEffectBlur(material: isDark ? .hudWindow : .popover, appearance: isDark ? .darkAqua : .aqua,
                                 cornerRadius: theme.cornerRadius)
                background.opacity(0.6 * opaque + 0.1)
                if theme.accentSource == .wallpaper {
                    // Dynamic Wallpaper: the desktop's color, barely there.
                    LinearGradient(colors: [accent.opacity(isDark ? 0.16 : 0.10), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
        case .darkGlass:
            ZStack {
                VisualEffectBlur(material: .hudWindow, appearance: .darkAqua, cornerRadius: theme.cornerRadius)
                background.opacity(0.55 * opaque)
            }
        case .aurora:
            ZStack {
                background.opacity(1 - 0.4 * transparency)
                RadialGradient(colors: [accent.opacity(0.22), .clear], center: UnitPoint(x: 0.12, y: -0.05), startRadius: 0, endRadius: 280)
                RadialGradient(colors: [Color(red: 0.48, green: 0.38, blue: 1).opacity(0.20), .clear],
                               center: UnitPoint(x: 1, y: 1.05), startRadius: 0, endRadius: 260)
            }
        case .solid, .editorial, .retro, .brutalist:
            background.opacity(1 - 0.6 * transparency)
        case .cyber:
            ZStack {
                background.opacity(1 - 0.5 * transparency)
                GridLines(spacing: 14, color: Color(palette.ink).opacity(0.045))
            }
        case .terminal:
            ZStack {
                background.opacity(1 - 0.5 * transparency)
                ScanLines()
                RadialGradient(colors: [Color(palette.ink).opacity(0.07), .clear], center: .center, startRadius: 0, endRadius: 260)
            }
        case .zen:
            background.opacity(1 - 0.5 * transparency).overlay(Grain(opacity: 0.035))
        case .paper:
            ZStack {
                background.opacity(1 - 0.5 * transparency)
                LinearGradient(colors: [.white.opacity(isDark ? 0.03 : 0.25), .clear], startPoint: .top, endPoint: .center)
            }
            .overlay(Grain(opacity: 0.07))
        case .neumorphic:
            LinearGradient(colors: [Color(palette.background.lighter(isDark ? 0.05 : 0.04)), Color(palette.background.darker(isDark ? 0.08 : 0.04))],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(1 - 0.5 * transparency)
        case .glow:
            ZStack {
                background.opacity(1 - 0.4 * transparency)
                RadialGradient(colors: [accent.opacity(isDark ? 0.30 : 0.18), .clear], center: UnitPoint(x: 0.1, y: -0.1),
                               startRadius: 0, endRadius: 260)
                RadialGradient(colors: [Color(palette.background2 ?? palette.accent).opacity(0.55), .clear],
                               center: UnitPoint(x: 1.05, y: 1.1), startRadius: 0, endRadius: 280)
            }
        case .gradient:
            // The second color, or (Eras) a wash of each widget's own accent.
            LinearGradient(colors: [background, palette.background2.map { Color($0) } ?? background.mix(accent, isDark ? 0.22 : 0.16)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(1 - 0.5 * transparency)
                .overlay(Grain(opacity: 0.03))
        case .chrome:
            let base = Color(palette.background), deep = Color(palette.background2 ?? palette.background.darker(0.3))
            LinearGradient(stops: [
                .init(color: base.mix(.white, isDark ? 0.10 : 0.35), location: 0),
                .init(color: base, location: 0.35),
                .init(color: deep, location: 0.62),
                .init(color: base.mix(.white, isDark ? 0.06 : 0.2), location: 1),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                // A band of reflected light, tinted by the accent (gold foil for gold themes).
                LinearGradient(stops: [.init(color: .clear, location: 0.18), .init(color: accent.opacity(0.16), location: 0.3),
                                       .init(color: .white.opacity(isDark ? 0.08 : 0.3), location: 0.34), .init(color: .clear, location: 0.46)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .opacity(1 - 0.4 * transparency)
        case .liquidGlass:
            EmptyView()
        }
    }

    @ViewBuilder
    private var edge: some View {
        switch theme.surface {
        case .native, .aurora:
            shape.strokeBorder(Color(palette.ink).opacity(isDark ? 0.10 : 0.06), lineWidth: 0.5)
        case .darkGlass:
            shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                               lineWidth: 0.75)
        case .solid:
            if theme.id == DesignTheme.monochrome.id {
                shape.strokeBorder(Color(palette.ink).opacity(0.08), lineWidth: 0.5)
            }
        case .cyber:
            ZStack {
                shape.strokeBorder(Color(palette.border ?? palette.accent).opacity(0.5), lineWidth: 1)
                CornerMarks(color: accent)
            }
        case .terminal:
            shape.strokeBorder(Color(palette.ink).opacity(0.22), lineWidth: 1)
        case .retro:
            shape.strokeBorder(Color(palette.border ?? palette.ink), lineWidth: 1.5)
        case .brutalist:
            shape.strokeBorder(Color(palette.border ?? palette.ink), lineWidth: 2.5)
        case .neumorphic:
            shape.strokeBorder(LinearGradient(colors: [.white.opacity(isDark ? 0.10 : 0.8), .clear, .black.opacity(isDark ? 0.35 : 0.08)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        case .glow:
            shape.strokeBorder(LinearGradient(colors: [accent.opacity(0.35), .clear, Color(palette.background2 ?? palette.accent).opacity(0.3)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        case .gradient:
            shape.strokeBorder(Color(palette.ink).opacity(isDark ? 0.10 : 0.06), lineWidth: 0.5)
        case .chrome:
            shape.strokeBorder(LinearGradient(colors: [.white.opacity(isDark ? 0.35 : 0.8), .white.opacity(0.05), .black.opacity(0.25)],
                                              startPoint: .top, endPoint: .bottom), lineWidth: 1)
        case .zen, .editorial, .paper, .liquidGlass:
            EmptyView()
        }
    }
}

/// Liquid Glass: the system's glass on macOS 26 (a blur before), with a faint
/// tint from the wallpaper, a soft light in the top corner, a specular rim
/// that's brightest along the top edge, and a crisp hairline outside it.
struct WidgetGlassEffect<Content: View>: View {
    let isDark: Bool
    let tint: Color
    let transparency: Double
    let cornerRadius: Double
    @ViewBuilder var content: Content
    @Environment(\.widgetSnapshot) private var snapshot

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        glass(shape)
            .overlay {
                ZStack {
                    // Light caught in the top corner of the glass.
                    shape.fill(RadialGradient(colors: [.white.opacity(isDark ? 0.09 : 0.20), .clear],
                                              center: UnitPoint(x: 0.18, y: 0), startRadius: 0, endRadius: 240))
                    // The specular rim.
                    shape.inset(by: 0.5).strokeBorder(LinearGradient(stops: [
                        .init(color: .white.opacity(isDark ? 0.50 : 0.75), location: 0),
                        .init(color: .white.opacity(isDark ? 0.10 : 0.25), location: 0.3),
                        .init(color: .white.opacity(0.03), location: 0.7),
                        .init(color: .white.opacity(isDark ? 0.14 : 0.35), location: 1),
                    ], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    shape.strokeBorder(Color.black.opacity(isDark ? 0.45 : 0.08), lineWidth: 0.5)
                }
                .allowsHitTesting(false)
            }
    }

    @ViewBuilder
    private func glass(_ shape: RoundedRectangle) -> some View {
        let tinted = content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(shape.fill(tint.opacity((isDark ? 0.12 : 0.08) * (1 - 0.5 * transparency))))
        if #available(macOS 26, *), !snapshot {
            tinted.glassEffect(transparency > 0.5 ? .clear : .regular, in: shape)
        } else {
            tinted.background {
                ZStack {
                    VisualEffectBlur(material: isDark ? .hudWindow : .popover, appearance: isDark ? .darkAqua : .aqua,
                                     cornerRadius: cornerRadius)
                    (isDark ? Color.black : .white).opacity(0.22 * (1 - transparency))
                }
            }
        }
    }
}

/// A faint square grid, drawn once.
private struct GridLines: View {
    let spacing: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x = spacing
            while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
            var y = spacing
            while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
            context.stroke(path, with: .color(color), lineWidth: 0.5)
        }
    }
}

/// Horizontal scan lines, like a CRT, drawn once.
private struct ScanLines: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            var y: CGFloat = 0
            while y < size.height { path.addRect(CGRect(x: 0, y: y, width: size.width, height: 1)); y += 3 }
            context.fill(path, with: .color(.black.opacity(0.22)))
        }
    }
}

/// Short neon brackets in each corner.
private struct CornerMarks: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let length: CGFloat = 12, inset: CGFloat = 5
            var path = Path()
            for (x, y, dx, dy) in [(inset, inset, 1.0, 1.0), (size.width - inset, inset, -1.0, 1.0),
                                   (inset, size.height - inset, 1.0, -1.0), (size.width - inset, size.height - inset, -1.0, -1.0)] {
                path.move(to: CGPoint(x: x + dx * length, y: y))
                path.addLine(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: y + dy * length))
            }
            context.stroke(path, with: .color(color), lineWidth: 1.5)
        }
    }
}

extension WidgetColor {
    func lighter(_ amount: Double) -> WidgetColor {
        WidgetColor(red: red + (1 - red) * amount, green: green + (1 - green) * amount, blue: blue + (1 - blue) * amount)
    }

    func darker(_ amount: Double) -> WidgetColor {
        WidgetColor(red: red * (1 - amount), green: green * (1 - amount), blue: blue * (1 - amount))
    }
}
