import Foundation

/// Requests shared by everyone asking for the same thing. Each caller awaits
/// the one request, and it belongs to them: it is cancelled once every caller
/// still waiting on it has been cancelled (its widgets left the screen), and
/// not before. A caller arriving after that starts a fresh request.
@MainActor
public final class SharedRequests {
    @MainActor private final class Request {
        var task: Task<Void, Never>?
        var waiting = Set<UUID>()
    }

    private var running: [String: Request] = [:]

    public init() {}

    public func isRunning(_ key: String) -> Bool { running[key] != nil }

    /// Starts `work` unless a request for `key` is already running, then waits for it.
    public func run(_ key: String, _ work: @escaping @MainActor () async -> Void) async {
        guard !Task.isCancelled else { return }
        let request: Request
        if let existing = running[key] {
            request = existing
        } else {
            request = Request()
            running[key] = request
            request.task = Task {
                await work()
                if running[key] === request { running[key] = nil }
            }
        }
        let caller = UUID()
        request.waiting.insert(caller)
        await withTaskCancellationHandler {
            await request.task?.value
        } onCancel: {
            Task { @MainActor in self.leave(key, request: request, caller: caller) }
        }
        request.waiting.remove(caller)
    }

    private func leave(_ key: String, request: Request, caller: UUID) {
        guard request.waiting.remove(caller) != nil, request.waiting.isEmpty else { return }
        request.task?.cancel()
        if running[key] === request { running[key] = nil }
    }
}
