import Foundation

// Knock detection from the TapTap project, adapted for All Set. The detector
// is a plain value type driven entirely by the timestamps on the samples it
// is handed, so replaying a stream gives the same answer every time.

/// One accelerometer reading, in units of standard gravity.
public struct AccelerometerSample: Equatable, Sendable {
    /// Seconds since boot, not counting sleep (the same clock as `NSEvent.timestamp`).
    public let timestamp: TimeInterval
    public let x: Double
    public let y: Double
    public let z: Double

    public init(timestamp: TimeInterval, x: Double, y: Double, z: Double) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.z = z
    }

    /// At rest this is about 1 g.
    public var magnitude: Double {
        (x * x + y * y + z * z).squareRoot()
    }
}

/// Which measurement decides that a sample is part of a knock.
public enum DetectionSignal: String, CaseIterable, Codable, Sendable {
    /// Distance from the slow-moving resting vector. Picking the Mac up or
    /// tilting the screen briskly can read as a knock.
    case highPass
    /// Change from one sample to the next; blind to slow movement.
    case jerk
    /// Both must clear their thresholds: the least fooled by moving the Mac.
    case both
}

/// How hard a knock has to be.
public enum Sensitivity: Equatable, Hashable, Sendable {
    case gentle
    case normal
    case firm
    case slap
    case custom(Double)

    /// Threshold in g. Custom values are kept within the supported range.
    public var threshold: Double {
        switch self {
        case .gentle: 0.05
        case .normal: 0.10
        case .firm: 0.20
        case .slap: 0.40
        case .custom(let value): value.clamped(to: DetectorConfiguration.thresholdRange)
        }
    }

    public var title: String {
        switch self {
        case .gentle: "Gentle"
        case .normal: "Normal"
        case .firm: "Firm"
        case .slap: "Slap"
        case .custom: "Custom"
        }
    }

    public static let presets: [Sensitivity] = [.gentle, .normal, .firm, .slap]
}

// Written by hand so the file reads `"normal"` or `0.12` rather than the
// nested objects Swift makes for enums with values.
extension Sensitivity: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Double.self) {
            self = .custom(value)
        } else {
            switch try container.decode(String.self) {
            case "gentle": self = .gentle
            case "firm": self = .firm
            case "slap": self = .slap
            default: self = .normal
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .gentle: try container.encode("gentle")
        case .normal: try container.encode("normal")
        case .firm: try container.encode("firm")
        case .slap: try container.encode("slap")
        case .custom(let value): try container.encode(value)
        }
    }
}

/// Everything tunable about the detector. Ranges are enforced on assignment,
/// since these values come straight from settings.
public struct DetectorConfiguration: Equatable, Sendable {
    public static let thresholdRange = 0.02...1.0
    public static let tapWindowRange = 0.25...0.70
    public static let refractoryRange = 0.08...0.12

    public var sensitivity: Sensitivity = .normal
    public var signal: DetectionSignal = .both

    /// Time constant of the resting-vector estimate: long enough that a knock
    /// can't drag it, short enough to follow the Mac being tilted.
    public var baselineTimeConstant: TimeInterval = 0.5

    /// Jerk threshold in g for `.jerk` and `.both`. Nil follows the main
    /// threshold, so one slider moves both.
    public var jerkThreshold: Double?
    public var jerkThresholdFraction = 0.6

    /// Counts that have an action. A sequence is reported the moment it
    /// reaches the highest of these rather than waiting out the window, so
    /// someone who only uses double knocks never waits for a third.
    public var assignedCounts: Set<Int> = [1, 2, 3]

    /// How long typing, clicking and waking hold knocks off, in seconds.
    public var typingSuppression: TimeInterval = 0.25
    public var pointerSuppression: TimeInterval = 0.15
    public var wakeSuppression: TimeInterval = 1.0

    private var storedTapWindow: TimeInterval = 0.40
    private var storedRefractory: TimeInterval = 0.10

    /// How long to wait for another knock before counting what there is.
    public var tapWindow: TimeInterval {
        get { storedTapWindow }
        set { storedTapWindow = newValue.clamped(to: Self.tapWindowRange) }
    }

    /// How long one knock may ring before another can register.
    public var refractory: TimeInterval {
        get { storedRefractory }
        set { storedRefractory = newValue.clamped(to: Self.refractoryRange) }
    }

    public var threshold: Double { sensitivity.threshold }

    public var effectiveJerkThreshold: Double {
        jerkThreshold ?? threshold * jerkThresholdFraction
    }

    /// Three when nothing is assigned, so the detector still behaves.
    public var highestAssignedCount: Int {
        min(assignedCounts.filter { (1...3).contains($0) }.max() ?? 3, 3)
    }

    public init() {}

    public init(sensitivity: Sensitivity, signal: DetectionSignal = .both) {
        self.sensitivity = sensitivity
        self.signal = signal
    }
}

/// How many knocks were counted. Longer sequences count as three.
public enum KnockCount: Int, CaseIterable, Codable, Identifiable, Sendable {
    case single = 1
    case double = 2
    case triple = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .single: "Single"
        case .double: "Double"
        case .triple: "Triple"
        }
    }
}

/// A finished knock sequence.
public struct KnockEvent: Equatable, Sendable {
    public let count: KnockCount
    /// When the last knock landed.
    public let timestamp: TimeInterval
    /// Peak strength of each knock in g, in order.
    public let peaks: [Double]

    public init(count: KnockCount, timestamp: TimeInterval, peaks: [Double]) {
        self.count = count
        self.timestamp = timestamp
        self.peaks = peaks
    }
}

/// One knock, before it's known how many it belongs with.
public struct TapObservation: Equatable, Sendable {
    public let time: TimeInterval
    public let magnitude: Double
    public let jerk: Double
    /// 1 for the first knock of a sequence, 2 for the second...
    public let positionInSequence: Int
}

/// Why a knock that was strong enough didn't count.
public enum SuppressionReason: String, Sendable {
    case typing
    case pointer
    case wake
}

/// Everything one sample produced.
public struct DetectionOutcome: Sendable {
    public var tap: TapObservation?
    /// Usually empty or one.
    public var events: [KnockEvent] = []
    public var blocked: SuppressionReason?
    /// The current movement in g, for a live meter.
    public var magnitude: Double?

    public static let none = DetectionOutcome()

    public var isEmpty: Bool { tap == nil && events.isEmpty && blocked == nil }
}

/// Turns accelerometer samples into single, double and triple knocks:
///
/// 1. Subtract a slow average of each axis, which removes gravity and tilt.
/// 2. Reduce what's left to one number: its size, the change since the last
///    sample, or both.
/// 3. Call it a knock when that number crosses the threshold upwards.
/// 4. Ignore everything for a moment, because one knock rings for tens of
///    milliseconds and would otherwise cross again on the way down.
/// 5. Count knocks that arrive close together; report the total once they stop.
public struct KnockDetector: Sendable {
    /// For the first sample, before there's an interval to measure. The
    /// sensor reports about 794 times a second.
    static let nominalInterval: TimeInterval = 1.0 / 794.4

    /// Changing settings drops any sequence in progress, since it was
    /// judged against thresholds that no longer apply.
    public var configuration: DetectorConfiguration {
        didSet {
            guard configuration != oldValue else { return }
            clearSequence()
        }
    }

    private var baseline: SIMD3<Double>?
    private var previousVector: SIMD3<Double>?
    private var lastTimestamp: TimeInterval?
    private var wasAboveThreshold = false
    private var refractoryUntil: TimeInterval = -.infinity

    private var tapCount = 0
    private var lastTapTime: TimeInterval?
    private var peaks: [Double] = []

    private var suppressedUntil: TimeInterval = -.infinity
    private var suppressionReason: SuppressionReason?
    private var needsBaselineReset = false

    public init(configuration: DetectorConfiguration = DetectorConfiguration()) {
        self.configuration = configuration
        peaks.reserveCapacity(4)
    }

    public mutating func process(_ sample: AccelerometerSample) -> DetectionOutcome {
        let time = sample.timestamp
        let vector = SIMD3(sample.x, sample.y, sample.z)
        let interval = lastTimestamp.map { max(time - $0, 0) } ?? Self.nominalInterval
        let previous = previousVector
        lastTimestamp = time
        previousVector = vector

        // After waking, the Mac may sit at a completely different angle.
        if needsBaselineReset {
            needsBaselineReset = false
            baseline = vector
            wasAboveThreshold = false
            clearSequence()
            return .none
        }
        guard var base = baseline else {
            baseline = vector
            return .none
        }

        let inRefractory = time < refractoryUntil
        // Hold the resting vector still while a knock rings, or the knock
        // drags it along and leaves an offset behind.
        if !inRefractory {
            let alpha = (interval / configuration.baselineTimeConstant).clamped(to: 0...1)
            base += (vector - base) * alpha
            baseline = base
        }

        let magnitude = Self.length(vector - base)
        let jerk = previous.map { Self.length(vector - $0) } ?? 0

        // A ringing knock's true peak comes a few samples after it registered.
        if inRefractory, !peaks.isEmpty {
            peaks[peaks.count - 1] = max(peaks[peaks.count - 1], magnitude)
        }

        var outcome = DetectionOutcome()
        outcome.magnitude = magnitude

        // A sequence quiet for a whole window is finished.
        if tapCount > 0, let last = lastTapTime, time - last >= configuration.tapWindow {
            outcome.events.append(makeEvent(at: last))
            clearSequence()
        }

        let above = isAboveThreshold(magnitude: magnitude, jerk: jerk)
        defer { wasAboveThreshold = above }
        // Only the upward crossing counts: one knock, not one per loud sample.
        guard above, !wasAboveThreshold, !inRefractory else { return outcome }

        if let reason = activeSuppression(at: time) {
            // Held off for the same ring time, so an ignored knock is
            // reported once rather than on every crossing.
            refractoryUntil = time + configuration.refractory
            outcome.blocked = reason
            return outcome
        }

        tapCount += 1
        lastTapTime = time
        peaks.append(magnitude)
        refractoryUntil = time + configuration.refractory
        outcome.tap = TapObservation(time: time, magnitude: magnitude, jerk: jerk, positionInSequence: tapCount)

        // Nothing longer has an action, so there's nothing to wait for.
        if tapCount >= configuration.highestAssignedCount {
            outcome.events.append(makeEvent(at: time))
            clearSequence()
        }
        return outcome
    }

    /// Reports a sequence whose window ran out, for when samples stop mid-sequence.
    public mutating func flush(at time: TimeInterval) -> KnockEvent? {
        guard tapCount > 0, let last = lastTapTime, time - last >= configuration.tapWindow else { return nil }
        let event = makeEvent(at: last)
        clearSequence()
        return event
    }

    /// Typing shakes the case.
    public mutating func noteKeyDown(at time: TimeInterval) {
        suppress(from: time, for: configuration.typingSuppression, reason: .typing)
    }

    /// A trackpad click is a small knock of its own.
    public mutating func notePointerEvent(at time: TimeInterval) {
        suppress(from: time, for: configuration.pointerSuppression, reason: .pointer)
    }

    /// Waking or opening the lid moves the Mac, and may leave it at a new angle.
    public mutating func noteWake(at time: TimeInterval) {
        suppress(from: time, for: configuration.wakeSuppression, reason: .wake)
        needsBaselineReset = true
    }

    /// Forgets the resting vector, any sequence and any suppression.
    public mutating func reset() {
        baseline = nil
        previousVector = nil
        lastTimestamp = nil
        wasAboveThreshold = false
        refractoryUntil = -.infinity
        suppressedUntil = -.infinity
        suppressionReason = nil
        needsBaselineReset = false
        clearSequence()
    }

    private mutating func suppress(from start: TimeInterval, for duration: TimeInterval, reason: SuppressionReason) {
        let until = start + duration
        guard until > suppressedUntil else { return }
        suppressedUntil = until
        suppressionReason = reason
    }

    private func activeSuppression(at time: TimeInterval) -> SuppressionReason? {
        time < suppressedUntil ? suppressionReason : nil
    }

    private func isAboveThreshold(magnitude: Double, jerk: Double) -> Bool {
        let loud = magnitude >= configuration.threshold
        let sharp = jerk >= configuration.effectiveJerkThreshold
        switch configuration.signal {
        case .highPass: return loud
        case .jerk: return sharp
        case .both: return loud && sharp
        }
    }

    private func makeEvent(at time: TimeInterval) -> KnockEvent {
        let capped = min(tapCount, KnockCount.triple.rawValue)
        return KnockEvent(count: KnockCount(rawValue: capped) ?? .triple, timestamp: time, peaks: Array(peaks.prefix(capped)))
    }

    private mutating func clearSequence() {
        tapCount = 0
        lastTapTime = nil
        peaks.removeAll(keepingCapacity: true)
    }

    @inline(__always)
    private static func length(_ vector: SIMD3<Double>) -> Double {
        (vector * vector).sum().squareRoot()
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
