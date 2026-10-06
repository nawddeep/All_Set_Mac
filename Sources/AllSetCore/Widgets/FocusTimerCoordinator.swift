import Foundation

/// Finishes focus-timer phases on time whether or not any widget is on screen.
/// The views used to do it in a SwiftUI task, which hiding widgets (or closing
/// their windows) cancelled: the phase then finished only when the view came
/// back, and a late chime was skipped. Views now only show the state.
@MainActor
public final class FocusTimerCoordinator {
    private let widgets: WidgetStore
    /// Called for each phase that ends while it can still be heard (within a
    /// minute); true when a break ended.
    private let chime: @MainActor (_ breakEnded: Bool) -> Void
    private var timer: Task<Void, Never>?

    public init(widgets: WidgetStore, chime: @escaping @MainActor (_ breakEnded: Bool) -> Void) {
        self.widgets = widgets
        self.chime = chime
    }

    /// The next moment any running focus timer changes phase.
    public var nextDeadline: Date? {
        widgets.widgets.compactMap(\.options.focus.endsAt).min()
    }

    /// Finishes every phase that's due by `now`. One that ended over a minute ago
    /// (the app was closed meanwhile) finishes quietly.
    public func finishDuePhases(at now: Date = .now) {
        for widget in widgets.widgets {
            guard let endsAt = widget.options.focus.endsAt, endsAt <= now else { continue }
            if now.timeIntervalSince(endsAt) < 60 { chime(widget.options.focus.isBreak) }
            widgets.update(widget.id) { $0.options.focus.finishPhase() }
        }
    }

    /// Sleeps until the next deadline, then finishes what's due. Call whenever a
    /// timer starts, pauses or is reset (the app does, on any widget change).
    public func reschedule() {
        timer?.cancel()
        timer = nil
        guard let deadline = nextDeadline else { return }
        timer = Task { [weak self] in
            let wait = deadline.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled, let self else { return }
            finishDuePhases()
            reschedule()
        }
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }
}
