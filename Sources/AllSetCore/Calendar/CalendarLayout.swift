import Foundation

public enum MonthLayout {
    /// The month containing `date` as rows of seven days, weeks starting on
    /// the calendar's first weekday, padded with nil before the 1st and after
    /// the last day.
    public static func days(for date: Date, calendar: Calendar) -> [Int?] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let length = calendar.range(of: .day, in: .month, for: date)?.count else { return [] }
        let firstWeekday = calendar.component(.weekday, from: month.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [Int?] = Array(repeating: nil, count: leading) + (1...length).map { $0 }
        days += Array(repeating: nil, count: (7 - days.count % 7) % 7)
        return days
    }

    /// One-letter weekday headers in the same order as `days(for:calendar:)`.
    public static func weekdaySymbols(_ calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
}

public enum EventTiming {
    /// A short "when" for an event list: "Now · until 11:00", "10:30 – 11:00",
    /// "Tomorrow 9:00", "Fri 14:00", "All day".
    public static func label(start: Date, end: Date, isAllDay: Bool, now: Date,
                             calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = DateFormatter()
        time.calendar = calendar
        time.timeZone = calendar.timeZone
        time.locale = locale
        time.setLocalizedDateFormatFromTemplate("jmm")
        let weekday = DateFormatter()
        weekday.calendar = calendar
        weekday.timeZone = calendar.timeZone
        weekday.locale = locale
        weekday.setLocalizedDateFormatFromTemplate("EEE")

        let isTomorrow = calendar.date(byAdding: .day, value: 1, to: now).map { calendar.isDate(start, inSameDayAs: $0) } ?? false
        if isAllDay {
            if calendar.isDate(start, inSameDayAs: now) || (start <= now && end > now) { return "All day" }
            if isTomorrow { return "Tomorrow · All day" }
            return "\(weekday.string(from: start)) · All day"
        }
        if start <= now, end > now {
            return "Now · until \(time.string(from: end))"
        }
        if calendar.isDate(start, inSameDayAs: now) {
            return "\(time.string(from: start)) – \(time.string(from: end))"
        }
        if isTomorrow {
            return "Tomorrow \(time.string(from: start))"
        }
        return "\(weekday.string(from: start)) \(time.string(from: start))"
    }
}

extension BatteryInfo {
    /// "Charging · 45m to full", "8h 14m remaining", "Plugged in · Not charging"...
    public var statusDescription: String {
        if isCharging {
            return minutesRemaining.map { "Charging · \(Format.duration(minutes: $0)) to full" } ?? "Charging"
        }
        if isPluggedIn {
            return isFullyCharged ? "Fully charged" : "Plugged in · Not charging"
        }
        return minutesRemaining.map { "\(Format.duration(minutes: $0)) remaining" } ?? "On battery"
    }
}
