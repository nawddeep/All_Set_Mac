import Foundation
import Testing
@testable import AllSetCore

/// Review P7: the timeout must be an upper bound, output bounded, cancellation real.
@Suite struct CommandRunnerTests {
    private func timed(_ work: () async -> String?) async -> (String?, TimeInterval) {
        let start = Date()
        let result = await work()
        return (result, Date().timeIntervalSince(start))
    }

    @Test func aCommandThatIgnoresTerminateIsKilled() async {
        // The review's probe: a 0.1 s timeout took about 3 s and relied on the command obeying.
        let (result, elapsed) = await timed {
            await CommandRunner.run("/bin/sh", ["-c", "trap '' TERM; exec sleep 30"], timeout: 0.1)
        }
        #expect(result?.contains("was stopped") == true)
        #expect(elapsed < 2.5)
    }

    @Test func aBackgroundChildHoldingThePipeDoesNotHoldTheResult() async {
        let (result, elapsed) = await timed {
            await CommandRunner.run("/bin/sh", ["-c", "sleep 5 >&2 & exit 0"], timeout: nil)
        }
        #expect(result == nil)
        #expect(elapsed < 2)
    }

    @Test func errorOutputIsCapped() async {
        let result = await CommandRunner.run("/bin/sh", ["-c", "head -c 1000000 /dev/zero | tr '\\\\0' x >&2; exit 3"], timeout: 10)
        #expect(result != nil)
        #expect((result?.utf8.count ?? .max) <= CommandRunner.outputLimit)
    }

    @Test func cancellingTheTaskStopsTheCommand() async {
        let start = Date()
        let task = Task { await CommandRunner.run("/bin/sh", ["-c", "exec sleep 30"], timeout: nil) }
        try? await Task.sleep(for: .milliseconds(200))
        task.cancel()
        let result = await task.value
        #expect(result?.contains("cancelled") == true)
        #expect(Date().timeIntervalSince(start) < 3)
    }

    /// Recheck S2: cancellation only sent TERM and then waited for ever, so a
    /// command that ignores TERM kept the caller waiting.
    @Test func cancellingACommandThatIgnoresTerminateStillStopsIt() async {
        let start = Date()
        let task = Task { await CommandRunner.run("/bin/sh", ["-c", "trap '' TERM; sleep 30"], timeout: nil) }
        try? await Task.sleep(for: .milliseconds(300))
        task.cancel()
        let result = await task.value
        #expect(result?.contains("cancelled") == true)
        #expect(Date().timeIntervalSince(start) < 4)
    }

    /// Recheck S2: a timeout killed the command it started but not what that
    /// command started, which ran on (and could hold the error pipe open).
    @Test func aTimeoutStopsWhatTheCommandStartedToo() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetChild-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: file) }
        // A shell that waits on a child ignoring TERM, having written the child's pid.
        let script = "trap '' TERM; sleep 30 & echo $! > '\(file.path)'; wait"
        let result = await CommandRunner.run("/bin/sh", ["-c", script], timeout: 0.4)
        #expect(result?.contains("was stopped") == true)
        let child = try #require(pid_t(String(contentsOf: file, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
        defer { kill(child, SIGKILL) }
        // Gone (or a zombie being reaped) within a moment of the runner answering.
        var alive = true
        for _ in 0..<40 where alive {
            alive = kill(child, 0) == 0
            if alive { try await Task.sleep(for: .milliseconds(25)) }
        }
        #expect(!alive)
    }
}
