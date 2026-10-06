import AllSetCore
import SwiftUI

// The building blocks every widget is made of. They read `WidgetStyle`, so a
// widget built from them looks right in every theme without knowing any.

/// Consistent spacing and sizes across the catalog.
enum WidgetMetrics {
    /// Padding inside the card, by size.
    static func padding(_ size: WidgetSize) -> CGFloat {
        switch size {
        case .small: 14
        case .medium: 16
        case .large, .extraLarge: 18
        }
    }

    static let iconSize: CGFloat = 12
    static let rowSpacing: CGFloat = 8
}

/// An SF Symbol at the catalog's icon size, in the accent.
struct WidgetIcon: View {
    let symbol: String
    var size: CGFloat = WidgetMetrics.iconSize
    var color: Color?
    @Environment(\.widgetStyle) private var style

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color ?? style.accent)
            .frame(width: size * 1.35, height: size * 1.35)
            .accessibilityHidden(true)
    }
}

/// The small label at the top of a widget: an icon, a title, maybe a detail
/// on the right. Retro themes draw it as a striped title bar, editorial ones
/// as a headline over a rule, the terminal as a prompt.
struct WidgetHeader: View {
    let title: String
    var symbol: String?
    var detail: String?
    @Environment(\.widgetStyle) private var style

    var body: some View {
        Group {
            switch style.surface {
            case .retro: retro
            case .editorial: editorial
            case .terminal: terminal
            default: standard
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var standard: some View {
        HStack(spacing: 5) {
            if let symbol { WidgetIcon(symbol: symbol) }
            WidgetWord(title)
                .font(style.label())
                .textCase(style.uppercaseLabels ? .uppercase : nil)
                .tracking(style.labelTracking)
                .foregroundStyle(symbol == nil ? AnyShapeStyle(style.accent) : AnyShapeStyle(style.ink))
                .lineLimit(1)
            Spacer(minLength: 4)
            if let detail {
                Text(detail)
                    .font(style.body(11))
                    .foregroundStyle(style.secondary)
                    .lineLimit(1)
            }
        }
    }

    /// A 1984 title bar: close box, pinstripes, the title in a white gap.
    private var retro: some View {
        ZStack {
            Canvas { context, size in
                var stripes = Path()
                var y: CGFloat = 2
                while y < size.height - 1 {
                    stripes.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
                    y += 2
                }
                context.fill(stripes, with: .color(style.ink))
            }
            HStack {
                Rectangle()
                    .fill(Color(white: 1))
                    .frame(width: 11, height: 11)
                    .overlay(Rectangle().strokeBorder(style.ink, lineWidth: 1))
                    .padding(.horizontal, 6)
                    .background(Color.white)
                Spacer()
            }
            Text(detail.map { "\(title) — \($0)" } ?? title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(style.ink)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .background(Color.white)
        }
        .frame(height: 13)
    }

    private var editorial: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                WidgetWord(title)
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .textCase(.uppercase)
                    .tracking(2)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.system(size: 10, weight: .regular, design: .serif).italic())
                        .foregroundStyle(style.secondary)
                }
            }
            Rectangle().fill(style.ink).frame(height: 1)
        }
    }

    private var terminal: some View {
        HStack(spacing: 0) {
            Text("❯ ").foregroundStyle(style.accent)
            Text(title.lowercased())
            Spacer(minLength: 4)
            if let detail { Text(detail).foregroundStyle(style.secondary) }
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .lineLimit(1)
    }
}

/// A figure with its unit and caption: "34 %  CPU". With `animated`, changes
/// roll over as numbers (unless Reduce Motion is on); leave it off for data
/// that changes every second, where the roll would redraw constantly.
struct WidgetMetric: View {
    let value: String
    var unit: String?
    var caption: String?
    var size: CGFloat = 34
    var alignment: HorizontalAlignment = .leading
    var animated = false
    @Environment(\.widgetStyle) private var style

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            if let caption {
                WidgetWord(caption)
                    .font(style.label(max(size * 0.28, 10)))
                    .textCase(style.uppercaseLabels ? .uppercase : nil)
                    .tracking(style.labelTracking)
                    .foregroundStyle(style.secondary)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: size * 0.06) {
                Text(value)
                    .font(style.number(size))
                    .contentTransition(animated ? .numericText() : .identity)
                    .motion(animated ? style.motion.change : nil, value: value)
                if let unit {
                    WidgetWord(unit)
                        .font(style.body(max(size * 0.36, 10), weight: .semibold))
                        .foregroundStyle(style.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A caption along the bottom: when it was updated, or where the data's from.
struct WidgetFooter: View {
    let text: String
    var symbol: String?
    @Environment(\.widgetStyle) private var style

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 9, weight: .semibold))
            }
            Text(text).lineLimit(1)
        }
        .font(style.body(10))
        .foregroundStyle(style.secondary)
    }
}

/// A thin level bar in the accent, run by Core Animation.
struct WidgetBar: View {
    let fraction: Double
    var color: Color?
    var height: CGFloat = 5
    @Environment(\.widgetStyle) private var style

    var body: some View {
        LevelBar(fraction: fraction, color: color ?? style.accent, track: style.ink.opacity(0.12))
            .frame(height: height)
            .clipShape(Capsule())
            .accessibilityHidden(true)
    }
}

/// A progress ring in the accent, run by Core Animation.
struct WidgetRing: View {
    let fraction: Double
    var color: Color?
    var lineWidth: CGFloat = 6
    @Environment(\.widgetStyle) private var style

    var body: some View {
        RingGauge(fraction: fraction, color: color ?? style.accent, track: style.ink.opacity(0.12), lineWidth: lineWidth)
            .accessibilityHidden(true)
    }
}

/// Recent values as a line, in the accent.
struct WidgetSparkline: View {
    let values: [Double]
    var capacity: Int = 60
    var maxValue: Double?
    var color: Color?
    @Environment(\.widgetStyle) private var style

    var body: some View {
        Sparkline(values: values, capacity: capacity, color: color ?? style.accent, maxValue: maxValue)
            .accessibilityHidden(true)
    }
}

/// A hairline between sections.
struct WidgetDivider: View {
    @Environment(\.widgetStyle) private var style

    var body: some View {
        Rectangle().fill(style.ink.opacity(style.surface == .editorial ? 0.8 : 0.1)).frame(height: style.surface == .editorial ? 1 : 0.5)
    }
}

/// What a widget shows when it has nothing yet, is loading, or failed.
struct WidgetStateView: View {
    enum Kind { case empty, loading, error }

    let kind: Kind
    let symbol: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?
    @Environment(\.widgetStyle) private var style

    var body: some View {
        VStack(spacing: 6) {
            if kind == .loading {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(kind == .error ? AnyShapeStyle(Color.orange) : AnyShapeStyle(style.accent))
            }
            WidgetWord(title)
                .font(style.title(13))
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(style.body(11))
                    .foregroundStyle(style.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .controlSize(.small)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// "just now", "5 min ago", "2 h ago".
enum RelativeTime {
    static func short(_ date: Date, now: Date = .now) -> String {
        let seconds = max(now.timeIntervalSince(date), 0)
        switch seconds {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(seconds / 60)) min ago"
        case ..<86_400: return "\(Int(seconds / 3600)) h ago"
        default: return "\(Int(seconds / 86_400)) d ago"
        }
    }
}

extension EnvironmentValues {
    /// False while the widget's window is covered. Unlike `widgetIsVisible`,
    /// Reduce Motion and Low Power Mode don't change it: data still updates.
    @Entry var widgetIsOnScreen = true
    /// How much longer network-backed widgets wait between refreshes: 1
    /// normally, more in Low Power Mode or when the Mac is hot.
    @Entry var widgetRefreshScale = 1.0
}

extension View {
    /// Runs `action` at once and then every `interval` seconds, only while the
    /// widget is on screen (and just once in a preview). The action decides
    /// whether anything is actually due, so a quick recheck is cheap.
    func widgetRefresh(every interval: TimeInterval?, id: some Hashable, perform action: @escaping @MainActor () async -> Void) -> some View {
        modifier(WidgetRefresh(interval: interval, id: AnyHashable(id), action: action))
    }
}

private struct WidgetRefresh: ViewModifier {
    let interval: TimeInterval?
    let id: AnyHashable
    /// Awaited, so a fetch it starts belongs to this widget being on screen:
    /// leaving the screen cancels the loop and, with it, the fetch.
    let action: @MainActor () async -> Void
    @Environment(\.widgetIsOnScreen) private var isOnScreen
    @Environment(\.widgetIsPreview) private var isPreview

    private struct Key: Hashable {
        var id: AnyHashable
        var active: Bool
        var interval: TimeInterval?
    }

    func body(content: Content) -> some View {
        content.task(id: Key(id: id, active: isOnScreen || isPreview, interval: interval)) {
            guard isOnScreen || isPreview else { return }
            await action()
            guard !isPreview, let interval else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(min(interval, 60)))
                guard !Task.isCancelled else { return }
                await action()
            }
        }
    }
}

/// A small mark on a widget showing data it couldn't update, or that has gone
/// stale: how old the data is, and why on hover and to VoiceOver. Nothing
/// while the data is fresh.
struct WidgetStaleBadge: View {
    let updated: Date
    let problem: String?
    /// The widget's refresh interval; nil (refreshed by hand) is never stale by age.
    let interval: TimeInterval?
    @Environment(\.widgetStyle) private var style

    static func isStale(updated: Date, interval: TimeInterval?, now: Date) -> Bool {
        guard let interval else { return false }
        return now.timeIntervalSince(updated) > max(interval * 2, 15 * 60)
    }

    var body: some View {
        if problem != nil || interval != nil {
            WidgetTimeline(.everyMinute) { context in
                if problem != nil || Self.isStale(updated: updated, interval: interval, now: context.date) {
                    let age = updated.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.icloud")
                        Text(age)
                    }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(style.secondary)
                    .padding(8)
                    .help(["Updated \(age)", problem].compactMap(\.self).joined(separator: ". "))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(["Not up to date, updated \(age)", problem].compactMap(\.self).joined(separator: ". "))
                }
            }
        }
    }
}

/// A `TimelineView` for desktop widgets that stops ticking while the widget's
/// window is covered. SwiftUI doesn't know a window can't be seen and keeps
/// redrawing it: measured, a clock showing seconds cost the same 12 % CPU
/// covered as visible. Uncovered, it picks up at once on the current time.
struct WidgetTimeline<Schedule: TimelineSchedule, Content: View>: View {
    let schedule: Schedule
    let content: (WidgetTimelineContext) -> Content
    @Environment(\.widgetIsOnScreen) private var isOnScreen

    init(_ schedule: Schedule, @ViewBuilder content: @escaping (WidgetTimelineContext) -> Content) {
        self.schedule = schedule
        self.content = content
    }

    var body: some View {
        TimelineView(PausableSchedule(base: schedule, isPaused: !isOnScreen)) { context in
            content(WidgetTimelineContext(date: context.date))
        }
    }
}

/// The moment a widget timeline draws for.
struct WidgetTimelineContext {
    let date: Date
}

/// Another schedule's dates, or just the first one while paused.
struct PausableSchedule<Base: TimelineSchedule>: TimelineSchedule {
    let base: Base
    let isPaused: Bool

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnySequence<Date> {
        isPaused ? AnySequence([startDate]) : AnySequence(base.entries(from: startDate, mode: mode))
    }
}
