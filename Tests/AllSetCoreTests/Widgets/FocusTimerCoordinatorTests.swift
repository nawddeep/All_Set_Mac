import Foundation
import Testing
@testable import AllSetCore

/// Review P1: focus phases must finish on time with no widget on screen.
@Suite @MainActor struct FocusTimerCoordinatorTests {
    private func store(endsAt: [Date?]) -> (WidgetStore, URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetFocus-\(UUID().uuidString)")
        let store = WidgetStore(fileURL: folder.appendingPathComponent("widgets.json"))
        for end in endsAt {
            var widget = WidgetInstance(kind: .focus)
            widget.options.focus.endsAt = end
            store.add(widget)
        }
        return (store, folder)
    }

    @Test func duePhasesFinishAndChimeOnlyWhileStillAudible() {
        let now = Date()
        let (store, folder) = store(endsAt: [now.addingTimeInterval(-5), now.addingTimeInterval(-600), now.addingTimeInterval(300), nil])
        defer { try? FileManager.default.removeItem(at: folder) }
        let before = store.widgets.map(\.options.focus)
        var chimes = 0
        let timers = FocusTimerCoordinator(widgets: store) { _ in chimes += 1 }

        timers.finishDuePhases(at: now)

        let after = store.widgets.map(\.options.focus)
        #expect(after[0] != before[0])   // ended 5 s ago: finished
        #expect(after[1] != before[1])   // ended 10 min ago (app was closed): finished
        #expect(after[2] == before[2])   // not due yet
        #expect(after[3] == before[3])   // not running
        #expect(chimes == 1)             // only the one that just ended is heard
    }

    @Test func theScheduledWakeUpFinishesAPhaseWithNoViewInvolved() async throws {
        let (store, folder) = store(endsAt: [Date().addingTimeInterval(0.2)])
        defer { try? FileManager.default.removeItem(at: folder) }
        let before = store.widgets[0].options.focus
        var chimed = false
        let timers = FocusTimerCoordinator(widgets: store) { _ in chimed = true }
        timers.reschedule()
        for _ in 0..<50 where store.widgets[0].options.focus == before { try await Task.sleep(for: .milliseconds(20)) }
        #expect(store.widgets[0].options.focus != before)
        #expect(chimed)
        timers.stop()
    }

    @Test func nothingRunningMeansNoDeadline() {
        let (store, folder) = store(endsAt: [nil])
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(FocusTimerCoordinator(widgets: store) { _ in }.nextDeadline == nil)
    }
}
