import AllSetCore
import SwiftUI

struct CalendarWidget: View {
    let instance: WidgetInstance
    let calendar: CalendarService
    @Environment(\.widgetAccent) private var accent

    private var events: [CalendarService.Event] {
        instance.options.showEvents && calendar.access == .granted ? calendar.events : []
    }

    var body: some View {
        WidgetTimeline(.everyMinute) { context in
            switch instance.size {
            case .small: small(context.date)
            case .medium: medium(context.date)
            case .large, .extraLarge: large(context.date)
            }
        }
    }

    private func small(_ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            weekday(date)
            dayNumber(date, size: 52)
            Spacer(minLength: 0)
            if let next = events.first {
                EventRow(event: next, now: date)
            } else {
                Text(WidgetDateFormat.string(date, template: "MMMMy"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    private func medium(_ date: Date) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                weekday(date)
                dayNumber(date, size: 48)
                Spacer(minLength: 0)
                Text(WidgetDateFormat.string(date, template: "MMMM"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 88, alignment: .leading)

            if events.isEmpty {
                MonthGrid(date: date, accent: accent)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(events.prefix(3)) { EventRow(event: $0, now: date) }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
    }

    private func large(_ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(WidgetDateFormat.string(date, template: "MMMMy"))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                weekday(date)
            }
            MonthGrid(date: date, accent: accent)
            Divider().opacity(0.5)
            if events.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(events.prefix(3)) { EventRow(event: $0, now: date) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private func weekday(_ date: Date) -> some View {
        Text(WidgetDateFormat.string(date, template: "EEEE").uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(accent)
    }

    private func dayNumber(_ date: Date, size: CGFloat) -> some View {
        Text(WidgetDateFormat.string(date, template: "d"))
            .font(.system(size: size, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
    }

    private var emptyMessage: String {
        guard instance.options.showEvents else { return "" }
        switch calendar.access {
        case .granted: return "Nothing else this week."
        case .notDetermined, .denied: return "Allow calendar access in this widget's options to see events."
        case .unavailable: return "Events appear when running the packaged app."
        }
    }
}

private struct EventRow: View {
    let event: CalendarService.Event
    let now: Date

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.color.map { Color($0) } ?? .accentColor)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 11, weight: .semibold))
                Text(EventTiming.label(start: event.start, end: event.end, isAllDay: event.isAllDay, now: now))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct MonthGrid: View {
    let date: Date
    let accent: Color

    var body: some View {
        let calendar = Calendar.current
        let days = MonthLayout.days(for: date, calendar: calendar)
        let symbols = MonthLayout.weekdaySymbols(calendar)
        let today = calendar.component(.day, from: date)

        Grid(horizontalSpacing: 0, verticalSpacing: 3) {
            GridRow {
                ForEach(symbols.indices, id: \.self) { index in
                    Text(symbols[index])
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<(days.count / 7), id: \.self) { week in
                GridRow {
                    ForEach(0..<7, id: \.self) { weekday in
                        let day = days[week * 7 + weekday]
                        Text(day.map(String.init) ?? "")
                            .font(.system(size: 10, weight: day == today ? .bold : .medium))
                            .monospacedDigit()
                            // On a "Color" widget the accent is white, so today's number goes dark.
                            .foregroundStyle(day == today ? (accent == .white ? Color.black.opacity(0.8) : .white) : .primary)
                            .frame(width: 19, height: 17)
                            .background {
                                if day == today {
                                    Circle().fill(accent)
                                }
                            }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}
