import AllSetCore
import AppKit
import SwiftUI

/// Circular gauge with the value in the middle and a label underneath.
struct StatRing: View {
    let title: String
    let fraction: Double?
    let color: Color
    var symbol: String?
    var diameter: CGFloat = 50

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RingGauge(fraction: fraction ?? 0, color: color)
                Text(fraction.map(Format.percent) ?? "–")
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
            }
            .frame(width: diameter, height: diameter)

            HStack(spacing: 2) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 8, weight: .bold))
                }
                WidgetWord(title)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
        }
    }
}

/// A rounded card for the System tab.
struct StatCard<Content: View>: View {
    let title: String
    let symbol: String
    let color: Color
    var value: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                WidgetWord(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if let value {
                    Text(value)
                        .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                }
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.06)))
    }
}

/// Line chart of recent values, newest at the right edge.
struct Sparkline: View {
    let values: [Double]
    let capacity: Int
    let color: Color
    var maxValue: Double?
    var filled = true

    var body: some View {
        let top = max(maxValue ?? values.max() ?? 1, .ulpOfOne)
        ZStack {
            if filled {
                SparklineShape(values: values, capacity: capacity, maxValue: top, closed: true)
                    .fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
            }
            SparklineShape(values: values, capacity: capacity, maxValue: top, closed: false)
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

struct SparklineShape: Shape {
    let values: [Double]
    let capacity: Int
    let maxValue: Double
    let closed: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        let step = rect.width / CGFloat(max(capacity - 1, 1))
        let points = values.enumerated().map { index, value in
            CGPoint(x: rect.maxX - CGFloat(values.count - 1 - index) * step,
                    y: rect.maxY - CGFloat(min(max(value / maxValue, 0), 1)) * rect.height)
        }
        path.addLines(points)
        if closed, let first = points.first, let last = points.last {
            path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
            path.addLine(to: CGPoint(x: first.x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// A horizontal fill bar.
struct LevelBar: View {
    let fraction: Double
    var color: Color = .white
    var track: Color = .white.opacity(0.18)

    var body: some View {
        BarGauge(values: [fraction], colors: [color], track: track, direction: .right, duration: 0.25)
    }
}

/// A bar split into colored segments, e.g. the parts of used memory.
struct UsageBar: View {
    struct Segment {
        let fraction: Double
        let color: Color
    }

    let segments: [Segment]

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                ForEach(segments.indices, id: \.self) { index in
                    Rectangle()
                        .fill(segments[index].color)
                        .frame(width: geometry.size.width * min(max(segments[index].fraction, 0), 1))
                }
                Spacer(minLength: 0)
            }
            .background(Color.white.opacity(0.18))
            .clipShape(Capsule())
        }
    }
}

struct Chip: View {
    let symbol: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
        }
        .lineLimit(1)
    }
}

struct Legend: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
        }
    }
}

/// Animated bars beside the notch while media plays. MediaRemote exposes no
/// audio levels, so the motion is synthesized. Core Animation runs it, since
/// it can play for hours.
struct AudioBars: View {
    let isPlaying: Bool
    let color: Color

    var body: some View {
        AudioBarsLayer(isPlaying: isPlaying, color: color)
            .frame(width: 18, height: 16)
    }
}

private struct AudioBarsLayer: NSViewRepresentable {
    let isPlaying: Bool
    let color: Color

    func makeNSView(context: Context) -> BarsView {
        let view = BarsView()
        view.update(isPlaying: isPlaying, color: color)
        return view
    }

    func updateNSView(_ view: BarsView, context: Context) {
        view.update(isPlaying: isPlaying, color: color)
    }

    final class BarsView: NSView {
        private let bars = (0..<4).map { _ in CALayer() }
        private var isPlaying = false
        /// Seconds per loop and the heights each bar moves through.
        private static let loops: [(Double, [CGFloat])] = [
            (1.9, [5, 13, 8, 16, 6, 11, 4, 14, 5]),
            (1.4, [9, 4, 15, 7, 12, 5, 16, 8, 9]),
            (2.3, [4, 10, 6, 14, 9, 16, 5, 12, 4]),
            (1.7, [12, 6, 16, 4, 10, 14, 7, 5, 12]),
        ]

        init() {
            super.init(frame: .zero)
            wantsLayer = true
            for bar in bars {
                bar.cornerRadius = 1.5
                layer?.addSublayer(bar)
            }
        }

        required init?(coder: NSCoder) { nil }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for (index, bar) in bars.enumerated() {
                bar.bounds = CGRect(x: 0, y: 0, width: 3, height: bar.bounds.height > 0 ? bar.bounds.height : 3)
                bar.position = CGPoint(x: 1.5 + CGFloat(index) * 5, y: bounds.midY)
            }
            CATransaction.commit()
        }

        func update(isPlaying playing: Bool, color: Color) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for bar in bars { bar.backgroundColor = NSColor(color).cgColor }
            CATransaction.commit()
            guard playing != isPlaying || bars.first?.animation(forKey: "level") == nil && playing else { return }
            isPlaying = playing
            for (index, bar) in bars.enumerated() {
                if playing {
                    let (duration, heights) = Self.loops[index]
                    let animation = CAKeyframeAnimation(keyPath: "bounds.size.height")
                    animation.values = heights
                    animation.duration = duration
                    animation.calculationMode = .cubic
                    animation.repeatCount = .infinity
                    animation.beginTime = CACurrentMediaTime() - duration * Double(index) / 4
                    animation.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
                    bar.add(animation, forKey: "level")
                } else {
                    // Settle down to a row of dots.
                    let current = bar.presentation()?.bounds.height ?? bar.bounds.height
                    bar.removeAnimation(forKey: "level")
                    let settle = CABasicAnimation(keyPath: "bounds.size.height")
                    settle.fromValue = current
                    settle.toValue = 3
                    settle.duration = 0.25
                    bar.bounds.size.height = 3
                    bar.add(settle, forKey: "settle")
                }
            }
        }
    }
}

struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(colors: [Color.primary.opacity(0.16), Color.primary.opacity(0.06)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.4, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.5))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct AppIcon: View {
    let bundleIdentifier: String?
    let size: CGFloat

    var body: some View {
        if let bundleIdentifier, let icon = AppIconCache.icon(for: bundleIdentifier) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
        }
    }
}

@MainActor
enum AppIconCache {
    private static var icons: [String: NSImage] = [:]
    /// Launch Services lookups by bundle id (nil: not installed), and display
    /// names: both asked for on every redraw of a list row otherwise.
    private static var paths: [String: String?] = [:]
    private static var names: [String: String?] = [:]

    private static func path(for bundleIdentifier: String) -> String? {
        if let known = paths[bundleIdentifier] { return known }
        let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)?.path
        paths[bundleIdentifier] = .some(path)
        return path
    }

    static func icon(for bundleIdentifier: String) -> NSImage? {
        path(for: bundleIdentifier).map(icon(forPath:))
    }

    /// The Finder icon for an app bundle or executable.
    static func icon(forPath path: String) -> NSImage {
        if let icon = icons[path] { return icon }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icons[path] = icon
        return icon
    }

    static func name(for bundleIdentifier: String?) -> String? {
        guard let bundleIdentifier else { return nil }
        if let known = names[bundleIdentifier] { return known }
        let name = path(for: bundleIdentifier).map { FileManager.default.displayName(atPath: $0).replacingOccurrences(of: ".app", with: "") }
        names[bundleIdentifier] = .some(name)
        return name
    }
}

/// One app in a "most energy" list: icon, name, power and a bar scaled to the
/// heaviest app in the list.
struct AppUsageRow: View {
    let usage: AppUsage
    /// Share of the top entry, 0...1.
    let fraction: Double
    /// False on Macs that don't report energy; CPU is shown instead.
    let showsPower: Bool
    var track: Color = .white.opacity(0.14)

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: AppIconCache.icon(forPath: usage.id))
                .resizable()
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(usage.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(showsPower ? Format.power(usage.watts) : "\(Int(usage.cpuPercent.rounded()))%")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                LevelBar(fraction: fraction, color: Theme.energy(fraction), track: track)
                    .frame(height: 4)
            }
        }
        .help("\(usage.name): \(Format.power(usage.watts)), \(Int(usage.cpuPercent.rounded()))% CPU")
    }
}

/// The top apps as rows, or a placeholder until there are two samples to compare.
struct TopAppsList: View {
    let apps: [AppUsage]
    var spacing: CGFloat = 9
    var track: Color = .white.opacity(0.14)

    var body: some View {
        let showsPower = apps.contains { $0.watts > 0 }
        let top = max(apps.map { showsPower ? $0.watts : $0.cpuPercent }.max() ?? 0, .ulpOfOne)
        if apps.isEmpty {
            Text("Measuring…")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } else {
            // No row animation: the list changes every second or two, and
            // animating it would redraw the whole panel continuously. The
            // bars still glide, on Core Animation.
            VStack(spacing: spacing) {
                ForEach(apps) { usage in
                    AppUsageRow(usage: usage,
                                fraction: (showsPower ? usage.watts : usage.cpuPercent) / top,
                                showsPower: showsPower, track: track)
                }
            }
        }
    }
}

struct NotchIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary.opacity(configuration.isPressed ? 0.6 : 0.92))
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .motion(Motion.bouncy, value: configuration.isPressed)
    }
}

/// Buttons that give a little under the finger.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .motion(Motion.bouncy, value: configuration.isPressed)
    }
}

/// A picture file shown small: decoded off the main thread at the size it's
/// drawn and cached, instead of loaded whole for every cell it scrolls past.
struct FileThumbnail: View {
    let url: URL
    let images: ImageLibrary
    var maxPixels = 256

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Color.primary.opacity(0.08)
            if let image { Image(nsImage: image).resizable().aspectRatio(contentMode: .fill) }
        }
        .task(id: url) {
            image = images.cachedThumbnail(at: url, maxPixels: maxPixels)
            if image == nil { image = await images.thumbnail(at: url, maxPixels: maxPixels) }
        }
    }
}
