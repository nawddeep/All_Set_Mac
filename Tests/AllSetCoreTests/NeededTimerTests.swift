import Foundation
import Testing
@testable import AllSetCore

/// Review P4: the pointer watch must not wake the Mac when nothing needs it.
@Suite @MainActor struct NeededTimerTests {
    @Test func ticksOnlyWhileNeeded() async throws {
        var ticks = 0
        let timer = NeededTimer(interval: 0.01, tolerance: 0) { ticks += 1 }
        #expect(!timer.isRunning)
        try await Task.sleep(for: .milliseconds(80))
        #expect(ticks == 0)

        #expect(timer.setNeeded(true))
        #expect(!timer.setNeeded(true))   // already running: not scheduled twice
        try await Task.sleep(for: .milliseconds(120))
        #expect(ticks > 0)

        #expect(timer.setNeeded(false))
        #expect(!timer.isRunning)
        let stoppedAt = ticks
        try await Task.sleep(for: .milliseconds(80))
        #expect(ticks == stoppedAt)
    }
}
