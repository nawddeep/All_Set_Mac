import AllSetCore
import AppKit
import SwiftUI

// MARK: Neon Sign

/// Words bent from glowing glass tubes. Every so often the tubes stutter,
/// a few quick flickers, then glow steady again.
struct NeonSignWidget: View {
    let instance: WidgetInstance

    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.widgetIsPreview) private var isPreview
    @State private var dimmed = false

    private var options: WidgetOptions { instance.options }

    var body: some View {
        let color = Color(instance.tint)
        let size: CGFloat = switch instance.size {
        case .small: 30
        case .medium: 44
        case .large, .extraLarge: 60
        }
        Text(options.customText.isEmpty ? "good vibes only" : options.customText)
            .textStyle(options.textStyle, size: size)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.3)
            // A white-hot core inside layers of colored glow.
            .foregroundStyle(color.mix(.white, 0.7))
            .shadow(color: color, radius: 1.5)
            .shadow(color: color, radius: 6)
            .shadow(color: color.opacity(0.85), radius: 16)
            .shadow(color: color.opacity(0.55), radius: 34)
            .opacity(dimmed ? 0.4 : 1)
            .padding(instance.size == .small ? 12 : 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: options.neonFlicker && isVisible && !isPreview) {
                guard options.neonFlicker, isVisible, !isPreview else { return }
                // Only a handful of redraws every several seconds: costs nothing.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Double.random(in: 5...13)))
                    for _ in 0..<Int.random(in: 2...4) {
                        dimmed = true
                        try? await Task.sleep(for: .milliseconds(Int.random(in: 40...110)))
                        dimmed = false
                        try? await Task.sleep(for: .milliseconds(Int.random(in: 50...160)))
                    }
                }
            }
    }
}

// MARK: Terminal

/// Live stats as a shell session, bars drawn in block characters. The numbers
/// arrive with the monitor's samples; the cursor blinks in Core Animation.
struct TerminalWidget: View {
    let instance: WidgetInstance
    let monitor: any SystemReadings
    let unit: TemperatureUnit

    @Environment(\.widgetAccent) private var accent
    @Environment(\.widgetIsVisible) private var isVisible

    var body: some View {
        let snapshot = monitor.snapshot
        let size: CGFloat = instance.size == .small ? 10.5 : 11.5
        VStack(alignment: .leading, spacing: instance.size == .small ? 3 : 2.5) {
            (Text("\(Self.user)@\(Self.host)").foregroundStyle(accent) + Text(" ~ % ").foregroundStyle(.secondary)
                + Text(instance.size == .large ? "neofetch" : "stats"))
                .lineLimit(1)
            ForEach(lines(snapshot), id: \.0) { label, value in
                HStack(spacing: 0) {
                    Text(label.padding(toLength: 6, withPad: " ", startingAt: 0)).foregroundStyle(accent)
                    value.lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Text("~ % ").foregroundStyle(.secondary)
                BlinkingCursor(color: accent, isBlinking: isVisible)
                    .frame(width: size * 0.6, height: size * 1.15)
            }
        }
        .font(.system(size: size, weight: .medium, design: .monospaced))
        .padding(instance.size == .small ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func lines(_ s: SystemSnapshot) -> [(String, Text)] {
        let barWidth = instance.size == .small ? 7 : 14
        /// Lit blocks for the level, then the rest of the track, dim.
        func meter(_ fraction: Double, _ suffix: String = "") -> Text {
            let clamped = min(max(fraction, 0), 1)
            let filled = Int((clamped * Double(barWidth)).rounded())
            return Text(String(repeating: "█", count: filled))
                + Text(String(repeating: "█", count: barWidth - filled)).foregroundStyle(.quaternary)
                + Text(String(format: " %3d%%", Int((clamped * 100).rounded())) + suffix)
        }
        var lines: [(String, Text)] = [("cpu", meter(s.cpu.total)), ("mem", meter(s.memory.usedFraction))]
        if instance.size != .small, let gpu = s.gpu {
            lines.insert(("gpu", meter(gpu.utilization)), at: 1)
        }
        if let battery = s.battery {
            lines.append(("bat", meter(Double(battery.percent) / 100, battery.isCharging ? " ⚡" : "")))
        }
        if instance.size == .small {
            lines.append(("up", Text(Self.uptime())))
            return lines
        }
        lines.append(("disk", meter(s.disk.usedFraction)))
        lines.append(("net", Text("↓ \(Format.rate(s.network.downloadBytesPerSecond))  ↑ \(Format.rate(s.network.uploadBytesPerSecond))")))
        if instance.size == .large {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            lines.insert(("os", Text("macOS \(version.majorVersion).\(version.minorVersion)")), at: 0)
            lines.insert(("up", Text(Self.uptime())), at: 1)
            if let soc = s.temperatures.soc { lines.append(("temp", Text(Format.temperature(soc, unit: unit)))) }
            for (index, app) in s.topApps.prefix(4).enumerated() {
                lines.append((index == 0 ? "top" : " \(index)", Text("\(app.name.prefix(18))  \(Int(app.cpuPercent.rounded()))%")))
            }
        }
        return lines
    }

    /// "3d 4h", "5h 12m".
    private static func uptime() -> String {
        let minutes = Int(ProcessInfo.processInfo.systemUptime / 60)
        let days = minutes / 1440, hours = minutes / 60 % 24
        return days > 0 ? "\(days)d \(hours)h" : "\(hours)h \(minutes % 60)m"
    }

    private static let user = NSUserName().lowercased()

    /// "pratiks-macbook-air", from the Mac's name.
    private static let host: String = {
        let name = Host.current().localizedName ?? "mac"
        let cleaned = name.lowercased()
            .replacingOccurrences(of: "\u{2019}s", with: "s").replacingOccurrences(of: "'s", with: "s")
            .map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return String(cleaned).split(separator: "-").joined(separator: "-")
    }()
}

/// A block cursor blinking in Core Animation: no redraws at all.
struct BlinkingCursorLayer: NSViewRepresentable {
    let color: Color
    let isBlinking: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let layer = view.layer else { return }
        layer.backgroundColor = NSColor(color).cgColor
        let key = "blink"
        if isBlinking, layer.animation(forKey: key) == nil {
            let blink = CAKeyframeAnimation(keyPath: "opacity")
            blink.values = [1, 0]
            blink.keyTimes = [0, 0.5]
            blink.calculationMode = .discrete
            blink.duration = 1.1
            blink.repeatCount = .infinity
            // It only changes twice a second.
            blink.preferredFrameRateRange = CAFrameRateRange(minimum: 4, maximum: 10, preferred: 10)
            layer.add(blink, forKey: key)
        } else if !isBlinking {
            layer.removeAnimation(forKey: key)
        }
    }
}

// MARK: Year in Dots

/// Every day as a dot: gone ones lit, today in the highlight, the rest faint.
/// Small shows this month, medium the year, large the year month by month.
struct DotsWidget: View {
    let instance: WidgetInstance

    @Environment(\.widgetAccent) private var accent
    @Environment(\.widgetDate) private var previewDate

    var body: some View {
        WidgetTimeline(.periodic(from: .now, by: 1800)) { context in
            let now = previewDate ?? context.date
            let calendar = Calendar.current
            switch instance.size {
            case .small: month(now, calendar)
            case .medium: year(now, calendar)
            case .large, .extraLarge: months(now, calendar)
            }
        }
    }

    private func header(_ title: String, _ detail: String, big: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: big ? 30 : 13, weight: big ? .bold : .semibold))
                .textCase(big ? nil : .uppercase)
                .tracking(big ? 0 : 2)
                .foregroundStyle(accent)
            Spacer()
            Text(detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func month(_ now: Date, _ calendar: Calendar) -> some View {
        let days = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let today = calendar.component(.day, from: now)
        return VStack(alignment: .leading, spacing: 10) {
            header(WidgetDateFormat.string(now, template: "MMMM"), "\(today)/\(days)", big: false)
            DotGrid(count: days, done: today - 1, columns: 7, accent: accent)
        }
        .padding(14)
    }

    private func year(_ now: Date, _ calendar: Calendar) -> some View {
        let days = calendar.range(of: .day, in: .year, for: now)?.count ?? 365
        let today = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let percent = Int(Double(today - 1) / Double(days) * 100)
        return VStack(alignment: .leading, spacing: 10) {
            header(String(calendar.component(.year, from: now)), "\(percent)% · \(days - today) days left", big: false)
            DotGrid(count: days, done: today - 1, columns: nil, accent: accent)
        }
        .padding(16)
    }

    private func months(_ now: Date, _ calendar: Calendar) -> some View {
        let days = calendar.range(of: .day, in: .year, for: now)?.count ?? 365
        let today = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        let year = calendar.component(.year, from: now)
        let lengths = (1...12).map { index -> Int in
            let start = calendar.date(from: DateComponents(year: year, month: index, day: 1)) ?? now
            return calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        }
        let symbols = calendar.shortMonthSymbols
        return VStack(alignment: .leading, spacing: 12) {
            header(String(year), "\(Int(Double(today - 1) / Double(days) * 100))% · \(days - today) left", big: true)
            Canvas { context, size in
                let label: CGFloat = 30
                let cell = min((size.width - label) / 31, size.height / 12)
                let radius = cell * 0.3
                for index in 0..<12 {
                    let y = CGFloat(index) * (size.height / 12) + size.height / 24
                    context.draw(Text(symbols[index]).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary),
                                 at: CGPoint(x: 0, y: y), anchor: .leading)
                    for dayIndex in 0..<lengths[index] {
                        let x = label + CGFloat(dayIndex) * cell + cell / 2
                        let dot = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                        let isPast = index + 1 < month || (index + 1 == month && dayIndex + 1 < day)
                        let isToday = index + 1 == month && dayIndex + 1 == day
                        var layer = context
                        layer.opacity = isToday ? 1 : isPast ? 0.85 : 0.16
                        layer.fill(dot, with: isToday ? .color(accent) : .foreground)
                    }
                }
            }
        }
        .padding(18)
    }
}

/// Dots in rows, laid out to fill the space (or in fixed columns).
private struct DotGrid: View {
    let count: Int
    let done: Int
    let columns: Int?
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let columns = columns ?? max(Int((Double(count) * size.width / max(size.height, 1)).squareRoot().rounded(.up)), 1)
            let rows = (count + columns - 1) / columns
            let cell = min(size.width / CGFloat(columns), size.height / CGFloat(rows))
            let radius = cell * 0.32
            for index in 0..<count {
                let x = CGFloat(index % columns) * cell + cell / 2
                let y = CGFloat(index / columns) * cell + cell / 2
                let dot = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                var layer = context
                layer.opacity = index == done ? 1 : index < done ? 0.85 : 0.16
                layer.fill(dot, with: index == done ? .color(accent) : .foreground)
            }
        }
    }
}

/// A block cursor; solid in snapshots.
struct BlinkingCursor: View {
    let color: Color
    let isBlinking: Bool
    @Environment(\.widgetSnapshot) private var snapshot

    var body: some View {
        if snapshot {
            Rectangle().fill(color)
        } else {
            BlinkingCursorLayer(color: color, isBlinking: isBlinking)
        }
    }
}
