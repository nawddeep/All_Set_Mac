import AllSetCore
import SwiftUI

struct ClockWidget: View {
    let instance: WidgetInstance
    @Environment(\.widgetAccent) private var accent
    @Environment(\.widgetStyle) private var style

    private var options: WidgetOptions { instance.options }
    private var timeZone: TimeZone { options.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current }
    /// The city of a world clock; nil for local time.
    private var city: String? { options.timeZoneID.map(TimeZoneName.city) }

    var body: some View {
        // Ticks on the second or on the minute, aligned so the display changes
        // exactly when the time does.
        let step: TimeInterval = options.showSeconds || options.cinematicClock ? 1 : 60
        WidgetTimeline(.periodic(from: Self.aligned(.now, to: step), by: step)) { context in
            if options.cinematicClock {
                CinematicClockFace(instance: instance, date: context.date)
            } else {
            switch options.clockFace {
            case .digital: digital(context.date)
            case .analog: analog(context.date)
            case .stacked: stacked(context.date)
            case .words: words(context.date)
            case .flip: flip(context.date)
            case .minimal: minimal(context.date)
            case .world: world(context.date)
            }
            }
        }
    }

    @ViewBuilder
    private func digital(_ date: Date) -> some View {
        let weekday = WidgetDateFormat.string(date, template: "EEEE", timeZone: timeZone)
        let day = WidgetDateFormat.string(date, template: "dMMMM", timeZone: timeZone)
        switch instance.size {
        case .small:
            VStack(alignment: .leading, spacing: 0) {
                heading(city ?? weekday)
                Spacer(minLength: 0)
                TimeLabel(parts: timeParts(date), size: options.showSeconds ? 34 : 46)
                Text(city == nil ? day : "\(weekday), \(day)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(16)
        case .medium:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    heading(city ?? weekday)
                    Spacer(minLength: 0)
                    TimeLabel(parts: timeParts(date), size: options.showSeconds ? 44 : 58)
                    Text(city == nil ? day : "\(weekday), \(day)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                AnalogFace(date: date, timeZone: timeZone, showSeconds: options.showSeconds, accent: accent)
                    .frame(width: 122, height: 122)
            }
            .padding(18)
        case .large, .extraLarge:
            VStack(alignment: .leading, spacing: 4) {
                heading(city ?? weekday)
                TimeLabel(parts: timeParts(date), size: options.showSeconds ? 64 : 84)
                    .padding(.top, 6)
                Text("\(weekday), \(day)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                DayProgress(date: date, timeZone: timeZone, accent: accent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(22)
        }
    }

    @ViewBuilder
    private func analog(_ date: Date) -> some View {
        let face = AnalogFace(date: date, timeZone: timeZone, showSeconds: options.showSeconds, accent: accent)
        switch instance.size {
        case .small:
            face.padding(14)
        case .medium:
            HStack(spacing: 18) {
                face.frame(width: 134, height: 134)
                VStack(alignment: .leading, spacing: 4) {
                    heading(city ?? WidgetDateFormat.string(date, template: "EEEE", timeZone: timeZone))
                    TimeLabel(parts: timeParts(date), size: 32)
                    Text(WidgetDateFormat.string(date, template: "dMMMM", timeZone: timeZone))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
        case .large, .extraLarge:
            VStack(spacing: 14) {
                face
                Text(city ?? WidgetDateFormat.string(date, template: "EEEEdMMMM", timeZone: timeZone))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(22)
        }
    }

    /// Hours above minutes, big and round, as on the iPhone lock screen.
    @ViewBuilder
    private func stacked(_ date: Date) -> some View {
        let hour = WidgetDateFormat.string(date, format: options.use24Hour ? "HH" : "h", timeZone: timeZone)
        let minute = WidgetDateFormat.string(date, format: "mm", timeZone: timeZone)
        let dayLine = city ?? WidgetDateFormat.string(date, template: "EEEEdMMMM", timeZone: timeZone)
        switch instance.size {
        case .small:
            VStack(spacing: 2) {
                heading(city ?? WidgetDateFormat.string(date, template: "EEEdMMM", timeZone: timeZone))
                StackedTime(hour: hour, minute: minute, size: 60)
            }
            .padding(12)
        case .medium:
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    heading(city ?? WidgetDateFormat.string(date, template: "EEEE", timeZone: timeZone))
                    Text(WidgetDateFormat.string(date, template: "dMMMM", timeZone: timeZone))
                        .font(.system(size: 20, weight: .semibold))
                    Spacer(minLength: 0)
                    DayProgress(date: date, timeZone: timeZone, accent: accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                StackedTime(hour: hour, minute: minute, size: 64)
            }
            .padding(18)
        case .large, .extraLarge:
            VStack(spacing: 8) {
                heading(dayLine)
                Spacer(minLength: 0)
                StackedTime(hour: hour, minute: minute, size: 128)
                Spacer(minLength: 0)
            }
            .padding(22)
        }
    }

    /// "It's quarter to eleven."
    @ViewBuilder
    private func words(_ date: Date) -> some View {
        let phrase = WordClock.phrase(hour: component(.hour, of: date), minute: component(.minute, of: date))
        let size: CGFloat = switch instance.size {
        case .small: 24
        case .medium: 32
        case .large, .extraLarge: 44
        }
        VStack(alignment: .leading, spacing: size * 0.12) {
            heading(city ?? WidgetDateFormat.string(date, template: "EEEEdMMMM", timeZone: timeZone))
            Spacer(minLength: 0)
            Text("It's")
                .font(.system(size: size * 0.6, weight: .regular, design: .serif).italic())
                .foregroundStyle(.secondary)
            Text(phrase)
                .font(.system(size: size, weight: .semibold, design: .serif))
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .contentTransition(.opacity)
                .motion(Motion.gentle, value: phrase)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(instance.size == .small ? 14 : 20)
    }

    /// Split-flap tiles, with the day spelled out underneath.
    @ViewBuilder
    private func flip(_ date: Date) -> some View {
        let hour = WidgetDateFormat.string(date, format: options.use24Hour ? "HH" : "hh", timeZone: timeZone)
        let minute = WidgetDateFormat.string(date, format: "mm", timeZone: timeZone)
        let period = options.use24Hour ? nil : WidgetDateFormat.string(date, format: "a", timeZone: timeZone)
        let day = city ?? WidgetDateFormat.string(date, template: instance.size == .small ? "EEEdMMM" : "EEEEdMMM", timeZone: timeZone)
        let tile: CGFloat = switch instance.size {
        case .small: 60
        case .medium: 74
        case .large, .extraLarge: 120
        }
        VStack(spacing: tile * 0.16) {
            HStack(spacing: tile * 0.08) {
                FlipTile(text: hour, height: tile, period: period)
                FlipTile(text: minute, height: tile)
            }
            Text(day.uppercased())
                .font(.system(size: max(tile * 0.17, 11), weight: .heavy))
                .tracking(1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(instance.size == .small ? 12 : 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// One thin, large time and nothing that doesn't need to be there.
    @ViewBuilder
    private func minimal(_ date: Date) -> some View {
        let time = WidgetDateFormat.string(date, format: options.use24Hour ? "HH:mm" : "h:mm", timeZone: timeZone)
        let day = WidgetDateFormat.string(date, template: "EEEEdMMMM", timeZone: timeZone)
        let label = Text(city ?? day).font(style.body(instance.size == .small ? 11 : 13)).foregroundStyle(style.secondary)
        switch instance.size {
        case .small:
            VStack(spacing: 2) {
                Text(time).font(style.number(56)).lineLimit(1).minimumScaleFactor(0.5)
                label.lineLimit(1)
            }
            .padding(12)
        case .medium:
            HStack(alignment: .lastTextBaseline) {
                Text(time).font(style.number(84)).lineLimit(1).minimumScaleFactor(0.5)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(WidgetDateFormat.string(date, template: "EEEE", timeZone: timeZone))
                        .font(style.title(13)).foregroundStyle(style.accent)
                    Text(city ?? WidgetDateFormat.string(date, template: "dMMMM", timeZone: timeZone))
                        .font(style.body(12)).foregroundStyle(style.secondary)
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 22)
        case .large, .extraLarge:
            VStack(spacing: 6) {
                Spacer(minLength: 0)
                Text(time).font(style.number(118)).lineLimit(1).minimumScaleFactor(0.5)
                label
                Spacer(minLength: 0)
                DayProgress(date: date, timeZone: timeZone, accent: accent)
            }
            .padding(22)
        }
    }

    /// Several cities: the Mac's own first, then the chosen ones.
    @ViewBuilder
    private func world(_ date: Date) -> some View {
        let zones = [TimeZone.current] + options.worldZones.compactMap(TimeZone.init(identifier:))
        switch instance.size {
        case .small:
            VStack(alignment: .leading, spacing: 7) {
                ForEach(zones.prefix(3), id: \.identifier) { zone in worldRow(zone, date: date, compact: true) }
                Spacer(minLength: 0)
            }
            .padding(14)
        case .medium:
            HStack(spacing: 8) {
                ForEach(zones.prefix(4), id: \.identifier) { zone in
                    VStack(spacing: 6) {
                        AnalogFace(date: date, timeZone: zone, showSeconds: false, accent: accent)
                            .frame(width: 66, height: 66)
                            .environment(\.colorScheme, isNight(zone, date) ? .dark : .light)
                            .background(Circle().fill(isNight(zone, date) ? Color.black.opacity(0.85) : .white.opacity(0.9)))
                        Text(zone == .current ? "Here" : TimeZoneName.city(zone.identifier))
                            .font(style.body(11, weight: .semibold)).lineLimit(1)
                        Text(offset(zone, date: date)).font(style.body(10)).foregroundStyle(style.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(14)
        case .large, .extraLarge:
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(title: "World Clock", symbol: "globe")
                ForEach(zones.prefix(6), id: \.identifier) { zone in
                    worldRow(zone, date: date, compact: false)
                    if zone != zones.prefix(6).last { WidgetDivider() }
                }
                Spacer(minLength: 0)
            }
            .padding(18)
        }
    }

    private func worldRow(_ zone: TimeZone, date: Date, compact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(zone == .current ? "Here" : TimeZoneName.city(zone.identifier))
                    .font(style.body(compact ? 12 : 14, weight: .semibold)).lineLimit(1)
                Text(offset(zone, date: date)).font(style.body(compact ? 9 : 11)).foregroundStyle(style.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: isNight(zone, date) ? "moon.fill" : "sun.max.fill")
                .font(.system(size: compact ? 9 : 11))
                .foregroundStyle(style.secondary)
                .accessibilityLabel(isNight(zone, date) ? "Night" : "Day")
            Text(WidgetDateFormat.string(date, format: options.use24Hour ? "HH:mm" : "h:mm", timeZone: zone))
                .font(style.number(compact ? 22 : 30))
        }
        .accessibilityElement(children: .combine)
    }

    /// "+5:30 · Tomorrow", relative to this Mac.
    private func offset(_ zone: TimeZone, date: Date) -> String {
        guard zone != .current else { return WidgetDateFormat.string(date, template: "EEE") }
        let seconds = zone.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)
        let hours = abs(seconds) / 3600, minutes = abs(seconds) / 60 % 60
        let shift = seconds == 0 ? "Same time" : "\(seconds < 0 ? "−" : "+")\(hours)\(minutes > 0 ? String(format: ":%02d", minutes) : "") h"
        var here = Calendar(identifier: .gregorian)
        here.timeZone = .current
        var there = here
        there.timeZone = zone
        let dayHere = here.ordinality(of: .day, in: .era, for: date) ?? 0
        let dayThere = there.ordinality(of: .day, in: .era, for: date) ?? 0
        let day = dayThere > dayHere ? " · Tomorrow" : dayThere < dayHere ? " · Yesterday" : ""
        return shift + day
    }

    private func isNight(_ zone: TimeZone, _ date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let hour = calendar.component(.hour, from: date)
        return hour < 6 || hour >= 19
    }

    private func component(_ unit: Calendar.Component, of date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.component(unit, from: date)
    }

    private func heading(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(accent)
            .lineLimit(1)
    }

    private func timeParts(_ date: Date) -> TimeLabel.Parts {
        let format = options.use24Hour
            ? (options.showSeconds ? "HH:mm:ss" : "HH:mm")
            : (options.showSeconds ? "h:mm:ss" : "h:mm")
        return TimeLabel.Parts(
            time: WidgetDateFormat.string(date, format: format, timeZone: timeZone),
            period: options.use24Hour ? nil : WidgetDateFormat.string(date, format: "a", timeZone: timeZone)
        )
    }

    private static func aligned(_ date: Date, to step: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / step).rounded(.down) * step)
    }
}

private struct TimeLabel: View {
    struct Parts {
        let time: String
        let period: String?
    }

    let parts: Parts
    let size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.06) {
            Text(parts.time)
                .font(.system(size: size, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            if let period = parts.period {
                Text(period)
                    .font(.system(size: size * 0.3, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        // Rolls when the minute changes; seconds just change. Rolling every
        // second measured 9-12% CPU for a visible seconds clock.
        .motion(Motion.standard, value: Self.minute(of: parts.time))
    }

    /// "10:42:17" → "10:42"; a time without seconds stays as it is.
    static func minute(of time: String) -> Substring {
        let colons = time.indices.filter { time[$0] == ":" }
        return colons.count > 1 ? time[..<colons[1]] : time[...]
    }
}

/// One split-flap card: two digits on dark tiles with a hinge across the middle.
struct FlipTile: View {
    let text: String
    let height: CGFloat
    var period: String?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: height * 0.12, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [Color(white: 0.2), Color(white: 0.11)], startPoint: .top, endPoint: .bottom))
            // The bottom flap sits a shade darker.
            shape.fill(Color.black.opacity(0.18))
                .mask(VStack(spacing: 0) { Color.clear; Color.black })
            Text(text)
                .font(.system(size: height * 0.72, weight: .bold, design: .rounded))
                // The tile's width is fixed: a wide theme font mustn't truncate the digits.
                .fontWidth(.standard)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(Color(white: 0.95))
                .contentTransition(.numericText(countsDown: false))
                .motion(Motion.responsive, value: text)
            Rectangle()
                .fill(Color.black.opacity(0.7))
                .frame(height: max(height * 0.018, 1))
            if let period {
                Text(period)
                    .font(.system(size: height * 0.13, weight: .bold))
                    .foregroundStyle(Color(white: 0.8))
                    .padding(height * 0.06)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: height * 0.95, height: height)
        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
        .environment(\.colorScheme, .dark)
    }
}

/// Two big numerals, one above the other.
struct StackedTime: View {
    let hour: String
    let minute: String
    let size: CGFloat

    var body: some View {
        VStack(spacing: -size * 0.24) {
            Text(hour)
            Text(minute)
        }
        .font(.system(size: size, weight: .bold, design: .rounded))
        .monospacedDigit()
        .contentTransition(.numericText())
        .motion(Motion.standard, value: minute)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
    }
}

/// A watch face with tick marks. Hand angles keep growing through the day, so
/// the tick animation never spins a hand backward past 12.
struct AnalogFace: View {
    let date: Date
    let timeZone: TimeZone
    let showSeconds: Bool
    let accent: Color

    var body: some View {
        let seconds = secondsSinceMidnight
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let radius = side / 2
            ZStack {
                Circle().fill(.primary.opacity(0.07))
                Circle().strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    for tick in 0..<60 {
                        let major = tick % 5 == 0
                        let angle = Double(tick) / 60 * 2 * .pi
                        let outer = radius * 0.9
                        let inner = outer - radius * (major ? 0.13 : 0.05)
                        var path = Path()
                        path.move(to: CGPoint(x: center.x + sin(angle) * inner, y: center.y - cos(angle) * inner))
                        path.addLine(to: CGPoint(x: center.x + sin(angle) * outer, y: center.y - cos(angle) * outer))
                        context.stroke(path, with: .color(.primary.opacity(major ? 0.75 : 0.3)),
                                       style: StrokeStyle(lineWidth: major ? max(radius * 0.03, 1.5) : 1, lineCap: .round))
                    }
                }
                hand(length: radius * 0.5, width: max(radius * 0.07, 3), degrees: seconds / 120, style: .primary)
                hand(length: radius * 0.76, width: max(radius * 0.045, 2), degrees: seconds / 10, style: .primary)
                if showSeconds {
                    hand(length: radius * 0.84, width: max(radius * 0.018, 1), degrees: seconds * 6, style: accent)
                }
                Circle()
                    .fill(showSeconds ? accent : .primary)
                    .frame(width: radius * 0.1, height: radius * 0.1)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The hands ease into each new minute; the seconds hand steps
            // like a quartz watch instead of springing (a spring every second
            // redraws the whole face at animation rate, all day).
            .motion(Motion.bouncy, value: Int(seconds) / 60)
        }
    }

    private var secondsSinceMidnight: Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return date.timeIntervalSince(calendar.startOfDay(for: date)).rounded(.down)
    }

    private func hand(length: CGFloat, width: CGFloat, degrees: Double, style: some ShapeStyle) -> some View {
        Capsule()
            .fill(style)
            .frame(width: width, height: length)
            .offset(y: -length / 2 + width / 2)
            .rotationEffect(.degrees(degrees))
    }
}

private struct DayProgress: View {
    let date: Date
    let timeZone: TimeZone
    let accent: Color

    var body: some View {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let fraction = date.timeIntervalSince(calendar.startOfDay(for: date)) / 86_400
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Day")
                Spacer()
                Text("\(Int(fraction * 100))% done")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            LevelBar(fraction: fraction, color: accent, track: .primary.opacity(0.12))
                .frame(height: 6)
        }
    }
}

enum TimeZoneName {
    /// "America/New_York" → "New York"
    static func city(_ identifier: String) -> String {
        (identifier.split(separator: "/").last.map(String.init) ?? identifier).replacingOccurrences(of: "_", with: " ")
    }
}

/// Date formatters are costly to create and widgets redraw every second.
@MainActor
enum WidgetDateFormat {
    private static var formatters: [String: DateFormatter] = [:]

    /// A fixed pattern such as "h:mm".
    static func string(_ date: Date, format: String, timeZone: TimeZone = .current) -> String {
        formatter(key: "f" + format, timeZone: timeZone) { $0.dateFormat = format }.string(from: date)
    }

    /// A localized template such as "EEEE" or "dMMMM".
    static func string(_ date: Date, template: String, timeZone: TimeZone = .current) -> String {
        formatter(key: "t" + template, timeZone: timeZone) { $0.setLocalizedDateFormatFromTemplate(template) }.string(from: date)
    }

    private static func formatter(key: String, timeZone: TimeZone, configure: (DateFormatter) -> Void) -> DateFormatter {
        let cacheKey = key + "|" + timeZone.identifier
        if let formatter = formatters[cacheKey] { return formatter }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone
        configure(formatter)
        formatters[cacheKey] = formatter
        return formatter
    }
}
