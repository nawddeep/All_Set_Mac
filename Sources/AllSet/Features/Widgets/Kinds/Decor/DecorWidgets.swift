import AllSetCore
import AppKit
import SwiftUI

// MARK: Shortcuts

/// A grid of little icons, each opening an app or a site, like the rows of
/// stars people put on their desktops.
struct ShortcutsWidget: View {
    let instance: WidgetInstance

    @Environment(\.widgetAccent) private var accent

    private var options: WidgetOptions { instance.options }

    var body: some View {
        let (columns, rows) = switch instance.size {
        case .small: (2, 2)
        case .medium: (4, 2)
        case .large, .extraLarge: (3, 3)
        }
        let items = Array(options.shortcuts.prefix(columns * rows))
        let iconSize: CGFloat = instance.size == .large ? 46 : instance.size == .small ? 34 : 38
        Grid(horizontalSpacing: 8, verticalSpacing: options.showLabels ? 8 : 12) {
            ForEach(0..<rows, id: \.self) { row in
                GridRow {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        if index < items.count {
                            ShortcutButton(item: items[index], iconSize: iconSize, showLabel: options.showLabels, color: accent)
                        } else {
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        }
                    }
                }
            }
        }
        .padding(instance.size == .small ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ShortcutButton: View {
    let item: ShortcutItem
    let iconSize: CGFloat
    let showLabel: Bool
    let color: Color

    @State private var isHovered = false

    var body: some View {
        Button {
            ShortcutLauncher.open(item.target)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil) == nil ? "star.fill" : item.symbol)
                    .font(.system(size: iconSize * 0.72))
                    .foregroundStyle(color)
                    .frame(height: iconSize)
                    .scaleEffect(isHovered ? 1.14 : 1)
                    .rotationEffect(.degrees(isHovered ? -6 : 0))
                if showLabel {
                    Text(item.title)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .opacity(0.9)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .onHover { hovering in
            withMotion(Motion.bouncy) { isHovered = hovering }
        }
        .help(item.title)
    }
}

/// Opens what a shortcut points at: a URL, an app by bundle identifier, or an app's path.
@MainActor
enum ShortcutLauncher {
    static func open(_ target: String) {
        let target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        if target.hasPrefix("/") || target.hasPrefix("~") {
            NSWorkspace.shared.open(URL(fileURLWithPath: (target as NSString).expandingTildeInPath))
        } else if target.contains(":"), let url = URL(string: target) {
            NSWorkspace.shared.open(url)
        } else if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target) {
            NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
        } else if target.contains("."), !target.contains(" "), let url = URL(string: "https://" + target) {
            // "pinterest.com"
            NSWorkspace.shared.open(url)
        }
    }

    /// A display name for a target: the app's name, or the site's.
    static func title(for target: String) -> String {
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target) ?? (target.hasPrefix("/") ? URL(fileURLWithPath: target) : nil) {
            return app.deletingPathExtension().lastPathComponent.lowercased()
        }
        if let host = URL(string: target)?.host() {
            return host.replacingOccurrences(of: "www.", with: "").split(separator: ".").first.map(String.init) ?? host
        }
        return target
    }
}

// MARK: Sticker

/// A big shape (or emoji) sitting on the desktop, finished soft, glossy,
/// chrome, flat or outlined. Click it for a little bounce.
struct StickerWidget: View {
    let instance: WidgetInstance

    @State private var bounce = false

    private var options: WidgetOptions { instance.options }

    var body: some View {
        let side = min(instance.size.dimensions.width, instance.size.dimensions.height) * 0.86
        StickerArt(shape: options.sticker, text: options.stickerText, finish: options.stickerFinish,
                   color: Color(instance.tint), side: side)
            .rotationEffect(.degrees(options.stickerTilt))
            .scaleEffect(bounce ? 1.12 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                withMotion(Motion.bouncy) { bounce = true }
                Task {
                    try? await Task.sleep(for: .milliseconds(180))
                    withMotion(Motion.bouncy) { bounce = false }
                }
            }
    }
}

/// The sticker's drawing, also used for thumbnails in the editor.
struct StickerArt: View {
    let shape: StickerShape
    var text = ""
    let finish: StickerFinish
    let color: Color
    let side: CGFloat

    var body: some View {
        switch finish {
        case .soft:
            glyph
                .foregroundStyle(color)
                .blur(radius: side * 0.045)
                .shadow(color: color.opacity(0.9), radius: side * 0.12)
                .overlay(glyph.foregroundStyle(.white.opacity(0.35)).blur(radius: side * 0.1).scaleEffect(0.6))
        case .glossy:
            glyph
                .foregroundStyle(LinearGradient(colors: [color.mix(.white, 0.45), color, color.mix(.black, 0.25)],
                                                startPoint: .top, endPoint: .bottom))
                // A shine across the top, kept inside the shape.
                .overlay(shine(0.85))
                .shadow(color: color.mix(.black, 0.4).opacity(0.45), radius: side * 0.05, y: side * 0.04)
        case .chrome:
            glyph
                .foregroundStyle(LinearGradient(stops: [
                    .init(color: .white, location: 0), .init(color: Color(white: 0.62), location: 0.38),
                    .init(color: Color(white: 0.96), location: 0.5), .init(color: Color(white: 0.32), location: 0.64),
                    .init(color: color.mix(.white, 0.6), location: 1),
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(shine(0.9))
                .shadow(color: .black.opacity(0.35), radius: side * 0.04, y: side * 0.03)
        case .solid:
            // A die-cut sticker: the shape on a white border.
            ZStack {
                ForEach(0..<12, id: \.self) { step in
                    let angle = Double(step) / 12 * 2 * .pi
                    glyph.foregroundStyle(.white)
                        .offset(x: cos(angle) * side * 0.035, y: sin(angle) * side * 0.035)
                }
                glyph.foregroundStyle(color)
            }
            .shadow(color: .black.opacity(0.28), radius: side * 0.03, y: side * 0.025)
        case .outline:
            outlineGlyph
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.6), radius: side * 0.04)
        }
    }

    /// White fading down to nothing over the top half, clipped to the shape.
    private func shine(_ opacity: Double) -> some View {
        LinearGradient(colors: [.white.opacity(opacity), .white.opacity(0)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.5))
            .mask { glyph.foregroundStyle(.black) }
            .blendMode(.screen)
    }

    @ViewBuilder
    private var glyph: some View {
        if text.isEmpty {
            Image(systemName: shape.symbol)
                .font(.system(size: side * 0.78))
                .frame(width: side, height: side)
        } else {
            Text(text)
                .font(.system(size: side * (text.count <= 2 ? 0.72 : 0.36), weight: .black).width(.compressed))
                .lineLimit(2)
                .minimumScaleFactor(0.3)
                .multilineTextAlignment(.center)
                .frame(width: side, height: side)
        }
    }

    @ViewBuilder
    private var outlineGlyph: some View {
        if text.isEmpty {
            let outline = shape.symbol.replacingOccurrences(of: ".fill", with: "")
            Image(systemName: NSImage(systemSymbolName: outline, accessibilityDescription: nil) == nil ? shape.symbol : outline)
                .font(.system(size: side * 0.78, weight: .light))
                .frame(width: side, height: side)
        } else {
            glyph
        }
    }
}

extension Color {
    /// Moves toward `other` by `amount`, in sRGB. `Color.mix` needs macOS 15.
    func mix(_ other: Color, _ amount: Double) -> Color {
        guard let a = NSColor(self).usingColorSpace(.sRGB), let b = NSColor(other).usingColorSpace(.sRGB) else { return self }
        return Color(.sRGB,
                     red: a.redComponent + (b.redComponent - a.redComponent) * amount,
                     green: a.greenComponent + (b.greenComponent - a.greenComponent) * amount,
                     blue: a.blueComponent + (b.blueComponent - a.blueComponent) * amount,
                     opacity: a.alphaComponent)
    }
}
