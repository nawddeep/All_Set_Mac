import Foundation

/// A repeating main-thread timer that exists only while something needs it.
/// A timer that checks a condition and returns early still wakes the Mac on
/// every tick; one that isn't scheduled doesn't.
@MainActor
public final class NeededTimer {
    public let interval: TimeInterval
    public let tolerance: TimeInterval
    private let tick: @MainActor () -> Void
    private var timer: Timer?

    public init(interval: TimeInterval, tolerance: TimeInterval, tick: @escaping @MainActor () -> Void) {
        self.interval = interval
        self.tolerance = tolerance
        self.tick = tick
    }

    public var isRunning: Bool { timer != nil }

    /// Schedules the timer, or removes it, to match `needed`. Returns whether that changed anything.
    @discardableResult
    public func setNeeded(_ needed: Bool) -> Bool {
        guard needed != isRunning else { return false }
        if needed {
            let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            timer.tolerance = tolerance
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } else {
            timer?.invalidate()
            timer = nil
        }
        return true
    }
}
