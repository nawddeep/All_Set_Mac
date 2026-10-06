import Darwin
import Foundation

/// Runs a command and says why it failed (nil when it succeeded).
///
/// The command runs in a process group of its own. Stopping it, because its
/// timeout ran out or the calling task was cancelled, is the same bounded
/// procedure either way: the whole group is asked to stop (SIGTERM), then
/// killed (SIGKILL) a second later, so what the command started stops with
/// it and a command that ignores SIGTERM can't keep the caller waiting. The
/// result says if even that didn't stop it.
///
/// A command that ends by itself leaves what it started alone: a script may
/// start something on purpose. Its error output is drained as it comes, capped,
/// and never waited on past a short grace (something left running can keep the
/// pipe open long after the command ended); the reader is then told to stop.
public enum CommandRunner {
    /// Error output kept for the message; the rest is read and dropped.
    public static let outputLimit = 64 * 1024
    static let killGrace: TimeInterval = 1
    static let drainGrace: TimeInterval = 0.5

    public static func run(_ path: String, _ arguments: [String], timeout: TimeInterval?) async -> String? {
        let state = RunState()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    continuation.resume(returning: runAndWait(path, arguments, timeout: timeout, state: state))
                }
            }
        } onCancel: {
            state.cancel()
        }
    }

    private static func runAndWait(_ path: String, _ arguments: [String], timeout: TimeInterval?, state: RunState) -> String? {
        let name = URL(fileURLWithPath: path).lastPathComponent
        var pipeEnds: [Int32] = [-1, -1]
        guard pipe(&pipeEnds) == 0 else { return "Couldn't start \(name): \(String(cString: strerror(errno)))" }
        let readEnd = pipeEnds[0], writeEnd = pipeEnds[1]

        var started: pid_t = 0
        let spawned = spawn(path, arguments, errorsTo: writeEnd, pid: &started)
        close(writeEnd)
        guard spawned == 0 else {
            close(readEnd)
            return "Couldn't start \(name): \(String(cString: strerror(spawned)))"
        }
        let pid = started

        // Reaped on its own thread, so waiting here can also end on a timeout or a cancel.
        DispatchQueue.global().async {
            var status: Int32 = 0
            while waitpid(pid, &status, 0) == -1, errno == EINTR {}
            state.exited(status)
        }
        // Drained as it runs: a command that fills the pipe would otherwise stall.
        let output = ErrorOutput()
        let drained = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            drain(readEnd, into: output)
            close(readEnd)
            drained.signal()
        }
        defer { output.stopReading() }

        switch state.wait(timeout: timeout) {
        case .exited(let status):
            // Something left running in the background may hold the pipe open: don't wait for it.
            _ = drained.wait(timeout: .now() + drainGrace)
            let code = exitCode(status)
            guard code != 0 else { return nil }
            let message = String(decoding: output.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return message.isEmpty ? "\(name) failed (\(code))" : message
        case .timedOut:
            return stop(pid, state: state) ? "\(name) took too long and was stopped" : "\(name) took too long and couldn't be stopped"
        case .cancelled:
            return stop(pid, state: state) ? "\(name) was cancelled" : "\(name) was cancelled but couldn't be stopped"
        }
    }

    /// Stops the command's whole process group: SIGTERM, then SIGKILL after
    /// `killGrace`. True once the command itself has ended. The group is killed
    /// even when the command obeyed SIGTERM, since what it started may not have.
    private static func stop(_ pid: pid_t, state: RunState) -> Bool {
        kill(-pid, SIGTERM)
        let obeyed = state.waitForExit(killGrace)
        kill(-pid, SIGKILL)
        return obeyed || state.waitForExit(killGrace)
    }

    /// Starts `path` in a new process group, with standard output discarded,
    /// standard error on `errors` and no other descriptors inherited. Returns
    /// 0, or the error number.
    private static func spawn(_ path: String, _ arguments: [String], errorsTo errors: Int32, pid: inout pid_t) -> Int32 {
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addinherit_np(&actions, STDIN_FILENO)
        posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, "/dev/null", O_WRONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, errors, STDERR_FILENO)

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        // Its own group (so the group can be signalled without touching this
        // app), default signal handling, and only the descriptors set up above.
        var noSignals = sigset_t(), allSignals = sigset_t()
        sigemptyset(&noSignals)
        sigfillset(&allSignals)
        posix_spawnattr_setpgroup(&attributes, 0)
        posix_spawnattr_setsigmask(&attributes, &noSignals)
        posix_spawnattr_setsigdefault(&attributes, &allSignals)
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF
                                                    | POSIX_SPAWN_CLOEXEC_DEFAULT))

        var argv: [UnsafeMutablePointer<CChar>?] = ([path] + arguments).map { strdup($0) }
        argv.append(nil)
        defer { for pointer in argv { free(pointer) } }
        return posix_spawn(&pid, path, &actions, &attributes, argv, environ)
    }

    /// Reads until the pipe closes or `output` is told to stop, looking up
    /// every 100 ms: a plain blocking read would sit for as long as anything
    /// held the pipe open.
    private static func drain(_ descriptor: Int32, into output: ErrorOutput) {
        var buffer = [UInt8](repeating: 0, count: 16 * 1024)
        while !output.shouldStop {
            var poller = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
            let ready = poll(&poller, 1, 100)
            if ready == 0 || (ready < 0 && errno == EINTR) { continue }
            if ready < 0 { return }
            let count = read(descriptor, &buffer, buffer.count)
            if count > 0 {
                output.append(buffer[0..<count])
            } else if count == 0 || errno != EINTR {
                return
            }
        }
    }

    private static func exitCode(_ status: Int32) -> Int32 {
        let signal = status & 0x7f
        return signal == 0 ? (status >> 8) & 0xff : 128 + signal
    }

    /// What the wait ended on, shared between the waiting thread, the thread
    /// that reaps the command and the task's cancellation handler.
    private final class RunState: @unchecked Sendable {
        enum Outcome { case exited(Int32), timedOut, cancelled }

        private let condition = NSCondition()
        private var status: Int32?
        private var isCancelled = false

        func exited(_ status: Int32) {
            condition.withLock {
                self.status = status
                condition.broadcast()
            }
        }

        func cancel() {
            condition.withLock {
                isCancelled = true
                condition.broadcast()
            }
        }

        /// Until the command ends, the task is cancelled, or `timeout` passes.
        func wait(timeout: TimeInterval?) -> Outcome {
            let deadline = timeout.map { Date().addingTimeInterval($0) }
            return condition.withLock {
                while true {
                    if let status { return .exited(status) }
                    if isCancelled { return .cancelled }
                    if let deadline {
                        if !condition.wait(until: deadline), status == nil, !isCancelled { return .timedOut }
                    } else {
                        condition.wait()
                    }
                }
            }
        }

        /// True if the command has ended within `seconds`.
        func waitForExit(_ seconds: TimeInterval) -> Bool {
            let deadline = Date().addingTimeInterval(seconds)
            return condition.withLock {
                while status == nil {
                    if !condition.wait(until: deadline) { break }
                }
                return status != nil
            }
        }
    }

    private final class ErrorOutput: @unchecked Sendable {
        private let lock = NSLock()
        private var stored = Data()
        private var stopped = false

        func append(_ chunk: ArraySlice<UInt8>) {
            lock.withLock {
                let room = CommandRunner.outputLimit - stored.count
                if room > 0 { stored.append(contentsOf: chunk.prefix(room)) }
            }
        }

        func stopReading() { lock.withLock { stopped = true } }

        var shouldStop: Bool { lock.withLock { stopped } }
        var data: Data { lock.withLock { stored } }
    }
}
