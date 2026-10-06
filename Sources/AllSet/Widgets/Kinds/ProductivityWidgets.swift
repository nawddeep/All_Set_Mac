import AllSetCore
import AppKit
import SwiftUI

/// Opens the Calendar app, for widgets about dates and events.
@MainActor
func openCalendarApp() {
    if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
        NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
    }
}

// MARK: Date

/// Today, big: the weekday in the accent, the day's number as the hero, and
/// (medium) the week around it.
struct DateWidget: View {
    let instance: WidgetInstance

    @Environment(\.widgetStyle) private var style
    @Environment(\.widgetDate) private var previewDate

    var body: some View {
        WidgetTimeline(.periodic(from: Calendar.current.startOfDay(for: .now), by: 3600)) { context in
            let now = previewDate ?? context.date
            HStack(spacing: 18) {
                day(now)
                if instance.size != .small {
                    week(now)
                }
            }
            .padding(WidgetMetrics.padding(instance.size))
            .contentShape(Rectangle())
            .onTapGesture { openCalendarApp() }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(now.formatted(date: .complete, time: .omitted))
            .accessibilityHint("Opens Calendar")
        }
    }

    private func day(_ now: Date) -> some View {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let week = calendar.component(.weekOfYear, from: now)
        return VStack(alignment: .leading, spacing: 0) {
            Text(WidgetDateFormat.string(now, template: "EEEE"))
                .font(style.title(13))
                .textCase(style.uppercaseLabels ? .uppercase : nil)
                .tracking(style.labelTracking)
                .foregroundStyle(style.accent)
            Text(WidgetDateFormat.string(now, template: "d"))
                .font(style.number(instance.size == .small ? 68 : 76))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            Text(WidgetDateFormat.string(now, template: "MMMMy"))
                .font(style.body(12, weight: .semibold))
            Text("Day \(dayOfYear) · Week \(week)")
                .font(style.body(10))
                .foregroundStyle(style.secondary)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .frame(width: instance.size == .small ? nil : 130, alignment: .leading)
        .frame(maxWidth: instance.size == .small ? .infinity : nil, alignment: .leading)
    }

    private func week(_ now: Date) -> some View {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let monthDays = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let today = calendar.component(.day, from: now)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { date in
                    let isToday = calendar.isDate(date, inSameDayAs: now)
                    VStack(spacing: 5) {
                        Text(WidgetDateFormat.string(date, template: "EEEEE"))
                            .font(style.label(10))
                            .foregroundStyle(style.secondary)
                        Text(WidgetDateFormat.string(date, template: "d"))
                            .font(style.body(13, weight: isToday ? .bold : .medium))
                            .foregroundStyle(isToday ? (style.accent.isLightColor ? Color.black : .white) : style.ink)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(isToday ? style.accent : .clear))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Spacer(minLength: 0)
            HStack {
                Text("\(WidgetDateFormat.string(now, template: "MMMM"))").font(style.label()).foregroundStyle(style.secondary)
                Spacer()
                Text("\(monthDays - today) days left").font(style.body(11)).foregroundStyle(style.secondary)
            }
            WidgetBar(fraction: Double(today) / Double(monthDays))
        }
    }
}

// MARK: Next Event

/// What's next, and how soon. Click to open Calendar.
struct NextEventWidget: View {
    let instance: WidgetInstance
    let calendar: CalendarService

    @Environment(\.widgetStyle) private var style

    var body: some View {
        Group {
            switch calendar.access {
            case .granted:
                WidgetTimeline(.periodic(from: .now, by: 60)) { context in
                    content(now: context.date)
                }
            case .notDetermined:
                WidgetStateView(kind: .empty, symbol: "calendar.badge.clock", title: "See what's next",
                                message: "All Set needs to read your calendars.", actionTitle: "Allow Access") {
                    Task { await calendar.requestAccess() }
                }
            default:
                WidgetStateView(kind: .error, symbol: "calendar.badge.exclamationmark", title: "No calendar access",
                                message: "Turn it on in System Settings › Privacy & Security › Calendars.")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openCalendarApp() }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let upcoming = calendar.events.filter { $0.end > now }
        let timed = upcoming.filter { !$0.isAllDay }
        if let next = timed.first ?? upcoming.first {
            let rest = Array(upcoming.filter { $0.id != next.id }.prefix(instance.size == .large ? 6 : 3))
            switch instance.size {
            case .small:
                VStack(alignment: .leading, spacing: 5) {
                    WidgetHeader(title: "Next", symbol: "calendar.badge.clock")
                    Spacer(minLength: 0)
                    eventTitle(next, size: 16, lines: 3)
                    Text(timeRange(next)).font(style.body(11)).foregroundStyle(style.secondary)
                    countdown(next, now: now)
                }
                .padding(WidgetMetrics.padding(.small))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .medium:
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        WidgetHeader(title: "Next", symbol: "calendar.badge.clock")
                        Spacer(minLength: 0)
                        eventTitle(next, size: 18, lines: 2)
                        Text(timeRange(next)).font(style.body(11)).foregroundStyle(style.secondary)
                        countdown(next, now: now)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 8) {
                        WidgetWord("Later").font(style.label()).foregroundStyle(style.secondary)
                        if rest.isEmpty {
                            WidgetWord("Nothing else this week").font(style.body(12)).foregroundStyle(style.secondary)
                        }
                        ForEach(rest) { eventRow($0, now: now) }
                        Spacer(minLength: 0)
                    }
                    .frame(width: 150, alignment: .leading)
                }
                .padding(WidgetMetrics.padding(.medium))
            case .large, .extraLarge:
                VStack(alignment: .leading, spacing: 10) {
                    WidgetHeader(title: "Up Next", symbol: "calendar.badge.clock", detail: WidgetDateFormat.string(now, template: "EEEdMMM"))
                    eventTitle(next, size: 22, lines: 2)
                    HStack {
                        Text(timeRange(next)).font(style.body(12)).foregroundStyle(style.secondary)
                        Spacer()
                        countdown(next, now: now)
                    }
                    WidgetDivider()
                    ForEach(rest) { eventRow($0, now: now) }
                    Spacer(minLength: 0)
                }
                .padding(WidgetMetrics.padding(.large))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            WidgetStateView(kind: .empty, symbol: "checkmark.circle", title: "Nothing coming up",
                            message: "Your week is clear.")
        }
    }

    private func eventTitle(_ event: CalendarService.Event, size: CGFloat, lines: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Capsule()
                .fill(event.color.map { Color($0) } ?? style.accent)
                .frame(width: 3, height: size)
            Text(event.title)
                .font(style.title(size))
                .lineLimit(lines)
        }
        .accessibilityElement(children: .combine)
    }

    private func countdown(_ event: CalendarService.Event, now: Date) -> some View {
        let text: String = {
            if event.start <= now { return "Now" }
            let minutes = Int(event.start.timeIntervalSince(now) / 60)
            if minutes < 60 { return "in \(max(minutes, 1)) min" }
            if Calendar.current.isDate(event.start, inSameDayAs: now) { return "in \(minutes / 60) h \(minutes % 60) min" }
            return WidgetDateFormat.string(event.start, template: "EEE")
        }()
        return Text(text)
            .font(style.body(11, weight: .semibold))
            .foregroundStyle(style.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(style.accent.opacity(0.14)))
    }

    private func eventRow(_ event: CalendarService.Event, now: Date) -> some View {
        HStack(spacing: 7) {
            Circle().fill(event.color.map { Color($0) } ?? style.accent).frame(width: 6, height: 6)
            Text(event.isAllDay ? "All day" : WidgetDateFormat.string(event.start, template: "jmm"))
                .font(style.body(11))
                .foregroundStyle(style.secondary)
                .frame(width: 52, alignment: .leading)
            Text(event.title).font(style.body(12)).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private func timeRange(_ event: CalendarService.Event) -> String {
        if event.isAllDay { return "All day" }
        return "\(WidgetDateFormat.string(event.start, template: "jmm")) – \(WidgetDateFormat.string(event.end, template: "jmm"))"
    }
}

// MARK: Daily Goals

/// A few counts to reach today. Click a goal to add to it; right-click to take
/// one back. Progress starts again each day.
struct GoalsWidget: View {
    let instance: WidgetInstance
    let store: WidgetStore

    @Environment(\.widgetStyle) private var style

    var body: some View {
        WidgetTimeline(.periodic(from: Calendar.current.startOfDay(for: .now), by: 3600)) { context in
            let today = Habit.key(context.date)
            let goals = instance.options.goals.map { goal in
                var goal = goal
                if instance.options.goalsDay != today { goal.progress = 0 }
                return goal
            }
            let done = goals.filter { $0.fraction >= 1 }.count
            content(goals, done: done)
                .padding(WidgetMetrics.padding(instance.size))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func content(_ goals: [DailyGoal], done: Int) -> some View {
        let shown = Array(goals.prefix(instance.size == .large ? 5 : 3))
        let header = WidgetHeader(title: "Today", symbol: "target", detail: "\(done) of \(goals.count) done")
        switch instance.size {
        case .small:
            VStack(alignment: .leading, spacing: 8) {
                header
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    ForEach(shown) { goal in
                        ring(goal, diameter: 38).frame(maxWidth: .infinity)
                    }
                }
                Spacer(minLength: 0)
            }
        case .medium:
            VStack(alignment: .leading, spacing: 10) {
                header
                HStack(spacing: 12) {
                    ForEach(shown) { goal in
                        VStack(spacing: 6) {
                            ring(goal, diameter: 56)
                            Text(goal.title).font(style.body(12, weight: .semibold)).lineLimit(1)
                            Text("\(goal.progress)/\(goal.target) \(goal.unit)").font(style.body(10)).foregroundStyle(style.secondary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        case .large, .extraLarge:
            VStack(alignment: .leading, spacing: 12) {
                header
                ForEach(shown) { goal in
                    Button { add(goal, by: step(goal)) } label: {
                        HStack(spacing: 10) {
                            WidgetIcon(symbol: goal.symbol, size: 15)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(goal.title).font(style.body(13, weight: .semibold))
                                    Spacer()
                                    Text("\(goal.progress) / \(goal.target) \(goal.unit)").font(style.body(11)).foregroundStyle(style.secondary)
                                }
                                WidgetBar(fraction: goal.fraction, height: 6)
                            }
                            Image(systemName: goal.fraction >= 1 ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(style.accent)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .contextMenu { menu(goal) }
                    .accessibilityLabel("\(goal.title), \(goal.progress) of \(goal.target) \(goal.unit)")
                    .accessibilityHint("Adds \(step(goal))")
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func ring(_ goal: DailyGoal, diameter: CGFloat) -> some View {
        Button { add(goal, by: step(goal)) } label: {
            ZStack {
                WidgetRing(fraction: goal.fraction, lineWidth: diameter * 0.12)
                Image(systemName: goal.fraction >= 1 ? "checkmark" : goal.symbol)
                    .font(.system(size: diameter * 0.32, weight: .semibold))
                    .foregroundStyle(style.accent)
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .contextMenu { menu(goal) }
        .help("\(goal.title): \(goal.progress) of \(goal.target) \(goal.unit). Click to add \(step(goal)).")
        .accessibilityLabel("\(goal.title), \(goal.progress) of \(goal.target) \(goal.unit)")
    }

    @ViewBuilder
    private func menu(_ goal: DailyGoal) -> some View {
        Button("Take One Back") { add(goal, by: -step(goal)) }
        Button("Mark Done") { add(goal, by: goal.target) }
        Button("Reset Today") { add(goal, by: -goal.target) }
        Divider()
        WidgetMenuItems()
    }

    /// Small targets count one at a time; big ones in sixths.
    private func step(_ goal: DailyGoal) -> Int {
        goal.target <= 12 ? 1 : max(goal.target / 6, 1)
    }

    private func add(_ goal: DailyGoal, by amount: Int) {
        let today = Habit.key(.now)
        store.update(instance.id) { widget in
            if widget.options.goalsDay != today {
                for index in widget.options.goals.indices { widget.options.goals[index].progress = 0 }
                widget.options.goalsDay = today
            }
            guard let index = widget.options.goals.firstIndex(where: { $0.id == goal.id }) else { return }
            let target = widget.options.goals[index].target
            widget.options.goals[index].progress = min(max(widget.options.goals[index].progress + amount, 0), target)
        }
    }
}

// MARK: Habit Tracker

/// Habits with their streaks and recent days. Click today's mark to tick it.
struct HabitsWidget: View {
    let instance: WidgetInstance
    let store: WidgetStore

    @Environment(\.widgetStyle) private var style

    var body: some View {
        WidgetTimeline(.periodic(from: Calendar.current.startOfDay(for: .now), by: 3600)) { context in
            let now = context.date
            let habits = Array(instance.options.habits.prefix(instance.size == .large ? 7 : 4))
            let doneToday = instance.options.habits.filter { $0.isDone(on: now) }.count
            VStack(alignment: .leading, spacing: instance.size == .small ? 7 : 9) {
                WidgetHeader(title: "Habits", symbol: "checkmark.seal.fill", detail: "\(doneToday)/\(instance.options.habits.count) today")
                if instance.size == .small {
                    ForEach(habits) { habit in todayRow(habit, now: now) }
                } else {
                    grid(habits, now: now, days: instance.size == .medium ? 7 : 14)
                }
                Spacer(minLength: 0)
            }
            .padding(WidgetMetrics.padding(instance.size))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func todayRow(_ habit: Habit, now: Date) -> some View {
        let done = habit.isDone(on: now)
        return Button { toggle(habit) } label: {
            HStack(spacing: 7) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(done ? style.accent : style.ink.opacity(0.35))
                Text(habit.title).font(style.body(12)).lineLimit(1)
                Spacer(minLength: 0)
                let streak = habit.streak(until: now)
                if streak > 1 {
                    Text("\(streak)").font(style.body(10, weight: .semibold)).foregroundStyle(style.secondary)
                    Image(systemName: "flame.fill").font(.system(size: 9)).foregroundStyle(.orange)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(habit.title), \(done ? "done" : "not done") today")
    }

    private func grid(_ habits: [Habit], now: Date, days: Int) -> some View {
        let calendar = Calendar.current
        let dates = (0..<days).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }
        return VStack(spacing: 7) {
            HStack(spacing: 0) {
                Spacer().frame(width: 96)
                ForEach(dates, id: \.self) { date in
                    Text(WidgetDateFormat.string(date, template: "EEEEE"))
                        .font(style.label(9))
                        .foregroundStyle(calendar.isDate(date, inSameDayAs: now) ? AnyShapeStyle(style.accent) : style.secondary)
                        .frame(maxWidth: .infinity)
                }
                Spacer().frame(width: 30)
            }
            ForEach(habits) { habit in
                HStack(spacing: 0) {
                    HStack(spacing: 5) {
                        WidgetIcon(symbol: habit.symbol, size: 11)
                        Text(habit.title).font(style.body(11)).lineLimit(1)
                    }
                    .frame(width: 96, alignment: .leading)
                    ForEach(dates, id: \.self) { date in
                        let done = habit.isDone(on: date)
                        let isToday = calendar.isDate(date, inSameDayAs: now)
                        Group {
                            if isToday {
                                Button { toggle(habit) } label: { mark(done: done, today: true) }
                                    .buttonStyle(PressableStyle())
                                    .accessibilityLabel("\(habit.title) today, \(done ? "done" : "not done")")
                            } else {
                                mark(done: done, today: false)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    Text("\(habit.streak(until: now))")
                        .font(style.body(11, weight: .semibold))
                        .foregroundStyle(style.secondary)
                        .frame(width: 30, alignment: .trailing)
                        .accessibilityLabel("\(habit.streak(until: now)) day streak")
                }
            }
        }
    }

    private func mark(done: Bool, today: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(done ? style.accent : style.ink.opacity(0.08))
            .overlay {
                if today {
                    RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(style.accent, lineWidth: 1.5)
                }
            }
            .frame(width: 14, height: 14)
            .contentShape(Rectangle())
    }

    private func toggle(_ habit: Habit) {
        store.update(instance.id) { widget in
            guard let index = widget.options.habits.firstIndex(where: { $0.id == habit.id }) else { return }
            widget.options.habits[index].toggle(on: .now)
        }
    }
}

// MARK: Reading Progress

/// The book on the go: a cover, how far in, and buttons to move the bookmark.
struct ReadingWidget: View {
    let instance: WidgetInstance
    let store: WidgetStore

    @Environment(\.widgetStyle) private var style

    private var book: ReadingBook { instance.options.book }

    var body: some View {
        Group {
            if instance.size == .small {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        BookCover(book: book).frame(width: 40, height: 58)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title).font(style.title(13)).lineLimit(3)
                            Text(book.author).font(style.body(10)).foregroundStyle(style.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    progress
                }
            } else {
                HStack(spacing: 16) {
                    BookCover(book: book).frame(width: 86, height: 126)
                    VStack(alignment: .leading, spacing: 6) {
                        WidgetHeader(title: "Reading", symbol: "book.fill")
                        Text(book.title).font(style.title(17)).lineLimit(2)
                        Text(book.author).font(style.body(12)).foregroundStyle(style.secondary)
                        Spacer(minLength: 0)
                        progress
                        HStack(spacing: 6) {
                            pageButton("+1", 1)
                            pageButton("+10", 10)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(WidgetMetrics.padding(instance.size))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contextMenu {
            Button("Back a Page") { turn(-1) }
            Button("Finished!") { turn(book.pages) }
            Divider()
            WidgetMenuItems()
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 4) {
            WidgetBar(fraction: book.fraction, height: 6)
            HStack {
                Text("\(Int((book.fraction * 100).rounded()))%").font(style.body(11, weight: .semibold))
                Spacer()
                Text(book.page >= book.pages ? "Finished" : "\(book.pages - book.page) pages left")
                    .font(style.body(11))
                    .foregroundStyle(style.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Page \(book.page) of \(book.pages)")
    }

    private func pageButton(_ title: String, _ pages: Int) -> some View {
        Button(title) { turn(pages) }
            .font(style.body(11, weight: .semibold))
            .buttonStyle(.plain)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(style.accent.opacity(0.16)))
            .foregroundStyle(style.accent)
            .accessibilityLabel("Add \(pages) page\(pages == 1 ? "" : "s")")
    }

    private func turn(_ pages: Int) {
        store.update(instance.id) { widget in
            widget.options.book.page = min(max(widget.options.book.page + pages, 0), widget.options.book.pages)
        }
    }
}

/// A book cover made from its color and title.
struct BookCover: View {
    let book: ReadingBook

    var body: some View {
        let color = Color(book.color)
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(LinearGradient(colors: [color.mix(.white, 0.12), color.mix(.black, 0.18)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .leading) {
                Rectangle().fill(.black.opacity(0.18)).frame(width: 4)
            }
            .overlay {
                Text(book.title)
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .padding(7)
            }
            .shadow(color: .black.opacity(0.25), radius: 3, x: 1, y: 2)
            .accessibilityHidden(true)
    }
}
