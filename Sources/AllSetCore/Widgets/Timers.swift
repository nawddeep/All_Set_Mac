import Foundation

/// A Pomodoro timer: a focus session, then a break, then focus again. Saved
/// with the widget, so a running session survives quitting the app.
public struct FocusSession: Codable, Equatable, Sendable {
    /// When the running phase ends; nil while stopped or paused.
    public var endsAt: Date?
    /// Seconds left in a paused phase.
    public var pausedRemaining: Double?
    public var isBreak = false
    /// Focus sessions finished since the last reset.
    public var completed = 0

    public init() {}

    public var isRunning: Bool { endsAt != nil }
    /// Started and not reset: running, or paused partway.
    public var isUnderway: Bool { endsAt != nil || pausedRemaining != nil }

    /// Seconds in the current phase.
    public func length(focusMinutes: Double, breakMinutes: Double) -> Double {
        (isBreak ? breakMinutes : focusMinutes) * 60
    }

    public func remaining(at now: Date, focusMinutes: Double, breakMinutes: Double) -> Double {
        if let endsAt { return max(endsAt.timeIntervalSince(now), 0) }
        return pausedRemaining ?? length(focusMinutes: focusMinutes, breakMinutes: breakMinutes)
    }

    /// 0 at the start of the phase, 1 when it's over.
    public func progress(at now: Date, focusMinutes: Double, breakMinutes: Double) -> Double {
        let length = length(focusMinutes: focusMinutes, breakMinutes: breakMinutes)
        guard length > 0 else { return 0 }
        return min(max(1 - remaining(at: now, focusMinutes: focusMinutes, breakMinutes: breakMinutes) / length, 0), 1)
    }

    public mutating func start(at now: Date, focusMinutes: Double, breakMinutes: Double) {
        guard endsAt == nil else { return }
        endsAt = now.addingTimeInterval(remaining(at: now, focusMinutes: focusMinutes, breakMinutes: breakMinutes))
        pausedRemaining = nil
    }

    public mutating func pause(at now: Date) {
        guard let endsAt else { return }
        pausedRemaining = max(endsAt.timeIntervalSince(now), 0)
        self.endsAt = nil
    }

    /// Back to the start of a focus session.
    public mutating func reset() {
        endsAt = nil
        pausedRemaining = nil
        isBreak = false
        completed = 0
    }

    /// Time's up (or skipped): on to the next phase, waiting for a tap.
    public mutating func finishPhase(counting: Bool = true) {
        if !isBreak && counting { completed += 1 }
        isBreak.toggle()
        endsAt = nil
        pausedRemaining = nil
    }

    /// "25:00", or "1:05:00" past an hour.
    public static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.up))
        let hours = total / 3600, minutes = total / 60 % 60, secs = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%02d:%02d", minutes, secs)
    }
}

/// A stopwatch that keeps counting while the app is closed.
public struct StopwatchState: Codable, Equatable, Sendable {
    /// When the current run started; nil while stopped.
    public var startedAt: Date?
    /// Seconds from earlier runs.
    public var accumulated: Double = 0
    /// Lap times, as elapsed seconds, newest last.
    public var laps: [Double] = []

    public init() {}

    public var isRunning: Bool { startedAt != nil }

    public func elapsed(at now: Date) -> Double {
        accumulated + (startedAt.map { max(now.timeIntervalSince($0), 0) } ?? 0)
    }

    public mutating func start(at now: Date) {
        guard startedAt == nil else { return }
        startedAt = now
    }

    public mutating func stop(at now: Date) {
        guard startedAt != nil else { return }
        accumulated = elapsed(at: now)
        startedAt = nil
    }

    public mutating func lap(at now: Date) {
        guard isRunning else { return }
        laps.append(elapsed(at: now))
        if laps.count > 20 { laps.removeFirst(laps.count - 20) }
    }

    public mutating func reset() {
        self = StopwatchState()
    }

    /// "00:00.00", or "1:02:03.45" past an hour.
    public static func clock(_ seconds: Double) -> String {
        let hundredths = Int((seconds * 100).rounded(.down))
        let hours = hundredths / 360_000, minutes = hundredths / 6000 % 60, secs = hundredths / 100 % 60, fraction = hundredths % 100
        return hours > 0
            ? String(format: "%d:%02d:%02d.%02d", hours, minutes, secs, fraction)
            : String(format: "%02d:%02d.%02d", minutes, secs, fraction)
    }
}
