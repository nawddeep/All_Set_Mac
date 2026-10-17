import Foundation
import Testing

/// Waits while `condition` holds, checking every few milliseconds, for up to
/// `timeout`. Returns as soon as it stops holding, so a fast machine never
/// waits; the generous deadline is for a slow CI runner, where fixed short
/// budgets made tests flaky. Records an issue if the deadline passes.
@MainActor
func waitWhile(_ timeout: Duration = .seconds(10), sourceLocation: SourceLocation = #_sourceLocation,
               _ condition: @MainActor () -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Still waiting after \(timeout)", sourceLocation: sourceLocation)
            return
        }
        try await Task.sleep(for: .milliseconds(5))
    }
}
