import AllSetCore
import AppKit
import SwiftUI

// MARK: To-Do

/// The notch's Notes as a checklist: tick things off here or there.
struct TodoWidget: View {
    let instance: WidgetInstance
    let notes: NotesStore

    @Environment(\.widgetAccent) private var accent
    @Environment(\.widgetIsPreview) private var isPreview
    @Environment(\.widgetSnapshot) private var snapshot
    @State private var draft = ""
    @FocusState private var isTyping: Bool

    private var options: WidgetOptions { instance.options }

    /// Open items first, then done ones, as many as fit.
    private var shown: [QuickNote] {
        let open = notes.notes.filter { !$0.isDone }
        let done = options.showDone ? notes.notes.filter(\.isDone) : []
        let fits = switch instance.size {
        case .small: 4
        case .medium: 4
        case .large, .extraLarge: 10
        }
        let items = Array((open + done).prefix(fits))
        // Previews for the gallery show a list even before there are notes.
        return items.isEmpty && isPreview ? Self.samples : items
    }

    private static let samples = [
        QuickNote(text: "Pilates at 5"), QuickNote(text: "Reply to Maya"),
        QuickNote(text: "Laundry", isDone: true), QuickNote(text: "Read 20 pages", isDone: true),
    ]

    var body: some View {
        let small = instance.size == .small
        VStack(alignment: .leading, spacing: small ? 6 : 8) {
            HStack {
                Text(options.listTitle.isEmpty ? "to-do" : options.listTitle)
                    .font(.system(size: small ? 11 : 12, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(accent)
                Spacer()
                let left = notes.notes.filter { !$0.isDone }.count
                if left > 0 {
                    Text("\(left) left")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            if shown.isEmpty {
                Spacer(minLength: 0)
                Text("All clear ✨")
                    .font(.system(size: small ? 15 : 17, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: small ? 5 : 7) {
                    ForEach(shown) { note in
                        row(note, small: small)
                    }
                }
                Spacer(minLength: 0)
            }
            if !small, !snapshot {
                addField
            }
        }
        .padding(small ? 14 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ note: QuickNote, small: Bool) -> some View {
        Button {
            withMotion(Motion.press) { notes.toggle(note.id) }
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(.secondary, lineWidth: 1.2)
                    if note.isDone {
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(accent)
                        Image(systemName: "checkmark")
                            .font(.system(size: small ? 7 : 8, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: small ? 12 : 14, height: small ? 12 : 14)
                Text(note.text)
                    .font(.system(size: small ? 12 : 13, weight: .medium))
                    .strikethrough(note.isDone, color: .secondary)
                    .foregroundStyle(note.isDone ? .secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var addField: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            TextField("Add a to-do", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .focused($isTyping)
                .onSubmit {
                    notes.add(draft)
                    draft = ""
                    isTyping = true
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.primary.opacity(0.07)))
    }
}

// MARK: Focus Timer

/// A Pomodoro timer: focus, break, repeat. Its state is saved with the
/// widget, so a session keeps running (and finishing) across relaunches.
struct FocusWidget: View {
    let instance: WidgetInstance
    let store: WidgetStore

    @Environment(\.widgetAccent) private var accent
    @Environment(\.widgetIsPreview) private var isPreview

    private var options: WidgetOptions { instance.options }
    private var session: FocusSession { options.focus }

    var body: some View {
        // Ticks once a second, only while running.
        WidgetTimeline(.periodic(from: .now, by: session.isRunning ? 1 : 3600)) { context in
            let remaining = session.remaining(at: context.date, focusMinutes: options.focusMinutes, breakMinutes: options.breakMinutes)
            let progress = session.progress(at: context.date, focusMinutes: options.focusMinutes, breakMinutes: options.breakMinutes)
            switch instance.size {
            case .small: small(remaining: remaining, progress: progress)
            default: medium(remaining: remaining, progress: progress)
            }
        }
        // Phases finish in AppServices.focusTimers, not here: a hidden widget's
        // view is gone, and its task with it.
    }

    private var phaseTitle: String { session.isBreak ? "break" : "focus" }

    private func small(remaining: Double, progress: Double) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(phaseTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(accent)
                Spacer()
                sessionDots
            }
            Spacer(minLength: 0)
            Text(FocusSession.clock(remaining))
                .font(.system(size: 44, weight: .light))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            LevelBar(fraction: progress, color: accent, track: .primary.opacity(0.12))
                .frame(height: 4)
            Spacer(minLength: 0)
            controls(size: 30)
        }
        .padding(14)
    }

    private func medium(remaining: Double, progress: Double) -> some View {
        HStack(spacing: 18) {
            ZStack {
                RingGauge(fraction: progress, color: accent, track: .primary.opacity(0.12), lineWidth: 7)
                playButton(size: 50)
            }
            .frame(width: 120, height: 120)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(phaseTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(2.5)
                        .foregroundStyle(accent)
                    Spacer()
                    sessionDots
                }
                Text(FocusSession.clock(remaining))
                    .font(.system(size: 50, weight: .light))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(session.isBreak ? "Stretch, sip some water." : "\(Int(options.focusMinutes)) min focus · \(Int(options.breakMinutes)) min break")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    smallButton("arrow.counterclockwise", help: "Start over") { change { $0.reset() } }
                    smallButton("forward.end.fill", help: session.isBreak ? "Skip the break" : "Skip to the break") {
                        change { $0.finishPhase(counting: false) }
                    }
                }
            }
        }
        .padding(18)
    }

    /// Four dots, filling as focus sessions finish.
    private var sessionDots: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index < session.completed % 4 || (session.completed > 0 && session.completed % 4 == 0 && session.isBreak)
                          ? AnyShapeStyle(accent) : AnyShapeStyle(.primary.opacity(0.18)))
                    .frame(width: 5, height: 5)
            }
        }
    }

    private func controls(size: CGFloat) -> some View {
        HStack(spacing: 10) {
            smallButton("arrow.counterclockwise", help: "Start over") { change { $0.reset() } }
            Spacer()
            playButton(size: size)
        }
    }

    private func playButton(size: CGFloat) -> some View {
        Button {
            let now = Date.now
            update { widget in
                if widget.options.focus.isRunning {
                    widget.options.focus.pause(at: now)
                } else {
                    widget.options.focus.start(at: now, focusMinutes: widget.options.focusMinutes, breakMinutes: widget.options.breakMinutes)
                }
            }
        } label: {
            Image(systemName: session.isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(accent.isLightColor ? .black : .white)
                .frame(width: size, height: size)
                .background(Circle().fill(accent))
                .contentShape(Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressableStyle())
        .help(session.isRunning ? "Pause" : "Start")
    }

    private func smallButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(.primary.opacity(0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .help(help)
    }

    private func change(_ change: @escaping (inout FocusSession) -> Void) {
        store.update(instance.id) { change(&$0.options.focus) }
    }

    private func update(_ change: (inout WidgetInstance) -> Void) {
        store.update(instance.id, change)
    }
}

// MARK: Stopwatch

struct StopwatchWidget: View {
    let instance: WidgetInstance
    let store: WidgetStore

    @Environment(\.widgetAccent) private var accent
    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.colorScheme) private var colorScheme

    private var watch: StopwatchState { instance.options.stopwatch }

    var body: some View {
        // Hundredths only move while it runs and can be seen; a covered
        // stopwatch catches up when it's shown again.
        switch instance.size {
        case .small: small
        default: medium
        }
    }

    private var small: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            readout(size: 34)
            Spacer(minLength: 0)
            buttons(size: 44)
        }
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                WidgetWord("stopwatch")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                readout(size: 44)
                Spacer(minLength: 0)
                buttons(size: 44)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                WidgetWord("laps")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(.secondary)
                if watch.laps.isEmpty {
                    Text("—").foregroundStyle(.tertiary)
                }
                ForEach(Array(watch.laps.enumerated().reversed().prefix(5)), id: \.offset) { index, lap in
                    HStack {
                        Text("\(index + 1)").foregroundStyle(.secondary)
                        Spacer()
                        Text(StopwatchState.clock(lap - (index > 0 ? watch.laps[index - 1] : 0)))
                            .monospacedDigit()
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                Spacer(minLength: 0)
            }
            .frame(width: 110)
        }
        .padding(18)
    }

    /// The running time, drawn by a Core Animation text layer that updates
    /// ten times a second: a SwiftUI text would redraw the whole card each time.
    private func readout(size: CGFloat) -> some View {
        TickingText(fontSize: size, color: instance.options.ink.map { Color($0) } ?? (colorScheme == .dark ? .white : .black),
                    isTicking: watch.isRunning && isVisible, interval: 0.1) { [watch] now in
            StopwatchState.clock(watch.elapsed(at: now))
        }
        .frame(height: size * 1.25)
        .frame(maxWidth: .infinity)
    }

    /// iPhone-style: lap or reset on the left, start or stop on the right.
    private func buttons(size: CGFloat) -> some View {
        HStack {
            circleButton(watch.isRunning ? "Lap" : "Reset", filled: false, size: size) {
                let now = Date.now
                update { watch in
                    if watch.isRunning { watch.lap(at: now) } else { watch.reset() }
                }
            }
            .disabled(!watch.isRunning && watch.accumulated == 0)
            Spacer()
            circleButton(watch.isRunning ? "Stop" : "Start", filled: true, size: size) {
                let now = Date.now
                update { watch in
                    if watch.isRunning { watch.stop(at: now) } else { watch.start(at: now) }
                }
            }
        }
    }

    private func circleButton(_ title: String, filled: Bool, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: size * 0.24, weight: .semibold))
                .foregroundStyle(filled ? (accent.isLightColor ? Color.black : .white) : .primary)
                .frame(width: size, height: size)
                .background(Circle().fill(filled ? AnyShapeStyle(accent) : AnyShapeStyle(.primary.opacity(0.1))))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
    }

    private func update(_ change: @escaping (inout StopwatchState) -> Void) {
        store.update(instance.id) { change(&$0.options.stopwatch) }
    }
}

extension Color {
    /// Whether dark text reads better than white on this color.
    var isLightColor: Bool {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return false }
        return 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent > 0.6
    }
}

/// Text that changes many times a second, drawn with a `CATextLayer` so each
/// change redraws only itself. It shrinks to fit its width, like
/// `minimumScaleFactor`, and stops its timer while not ticking or off screen.
struct TickingTextLayer: NSViewRepresentable {
    let fontSize: CGFloat
    let color: Color
    let isTicking: Bool
    let interval: TimeInterval
    let text: @MainActor (Date) -> String

    func makeNSView(context: Context) -> TickingTextView {
        TickingTextView()
    }

    func updateNSView(_ view: TickingTextView, context: Context) {
        view.fontSize = fontSize
        view.color = NSColor(color)
        view.text = text
        view.interval = interval
        view.isTicking = isTicking
        view.refresh()
    }

    final class TickingTextView: NSView {
        private let textLayer = CATextLayer()
        private var timer: Timer?
        var fontSize: CGFloat = 34
        var color = NSColor.labelColor
        var interval: TimeInterval = 0.1
        var text: @MainActor (Date) -> String = { _ in "" }
        var isTicking = false { didSet { if isTicking != oldValue { schedule() } } }

        init() {
            super.init(frame: .zero)
            wantsLayer = true
            textLayer.alignmentMode = .left
            textLayer.truncationMode = .none
            textLayer.actions = ["contents": NSNull(), "string": NSNull(), "bounds": NSNull(), "position": NSNull()]
            layer?.addSublayer(textLayer)
        }

        required init?(coder: NSCoder) { nil }

        override var isFlipped: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            textLayer.contentsScale = window?.backingScaleFactor ?? 2
            schedule()
            refresh()
        }

        override func viewDidChangeBackingProperties() {
            super.viewDidChangeBackingProperties()
            textLayer.contentsScale = window?.backingScaleFactor ?? 2
        }

        override func layout() {
            super.layout()
            refresh()
        }

        private func schedule() {
            timer?.invalidate()
            timer = nil
            guard isTicking, window != nil else { return }
            let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            timer.tolerance = interval * 0.2
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }

        func refresh() {
            let string = text(.now)
            var size = fontSize
            var attributed = Self.attributed(string, size: size, color: color)
            let width = attributed.size().width
            if width > bounds.width, bounds.width > 0 {
                size = max(fontSize * bounds.width / width, fontSize * 0.5)
                attributed = Self.attributed(string, size: size, color: color)
            }
            let measured = attributed.size()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            textLayer.string = attributed
            textLayer.frame = CGRect(x: (bounds.width - measured.width) / 2, y: (bounds.height - measured.height) / 2,
                                     width: measured.width + 1, height: measured.height)
            CATransaction.commit()
        }

        private static func attributed(_ string: String, size: CGFloat, color: NSColor) -> NSAttributedString {
            NSAttributedString(string: string, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .light),
                .foregroundColor: color,
            ])
        }
    }
}

/// Fast-changing text (Core Animation); plain text in snapshots.
struct TickingText: View {
    let fontSize: CGFloat
    let color: Color
    let isTicking: Bool
    let interval: TimeInterval
    let text: @MainActor (Date) -> String
    @Environment(\.widgetSnapshot) private var snapshot

    var body: some View {
        if snapshot {
            Text(text(.now))
                .font(.system(size: fontSize, weight: .light).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } else {
            TickingTextLayer(fontSize: fontSize, color: color, isTicking: isTicking, interval: interval, text: text)
        }
    }
}
