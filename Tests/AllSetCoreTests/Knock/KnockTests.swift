import Foundation
import Testing
@testable import AllSetCore

// Detector tests from the TapTap project, run against All Set's copy.

/// Deterministic noise, so a failing test fails every time.
private struct DeterministicNoise {
    private var state: UInt64 = 0x7A97_7A97

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(1 << 53) * 2 - 1
    }

    mutating func vector(scale: Double) -> SIMD3<Double> {
        SIMD3(next() * scale, next() * scale, next() * scale)
    }
}

/// Accelerometer streams shaped like the real sensor's: 794.4 reports a
/// second, about 1 g at rest, and its measured noise.
private struct SyntheticStream {
    static let interval: TimeInterval = 1 / 794.4
    static let restingNoise = 0.0009

    private(set) var samples: [AccelerometerSample] = []
    private var time: TimeInterval = 0
    private var gravity = SIMD3<Double>(0, 0, -0.9973)
    private var noise = DeterministicNoise()

    mutating func still(for duration: TimeInterval) {
        for _ in 0..<count(duration) { append(.zero) }
    }

    /// Reorienting the Mac: gravity swings smoothly to a new direction.
    mutating func tilt(to target: SIMD3<Double>, over duration: TimeInterval) {
        let steps = count(duration)
        let start = gravity
        for step in 1...max(steps, 1) {
            gravity = start + (target - start) * (Double(step) / Double(max(steps, 1)))
            append(.zero)
        }
    }

    /// A sharp impulse that rings down.
    mutating func knock(peak: Double, ring: TimeInterval = 0.025, frequency: Double = 180) {
        let direction = SIMD3<Double>(0.25, 0.15, 1.0) / (SIMD3<Double>(0.25, 0.15, 1.0) * SIMD3<Double>(0.25, 0.15, 1.0)).sum().squareRoot()
        for step in 0..<count(ring) {
            let elapsed = Double(step) * Self.interval
            append(direction * (peak * exp(-elapsed / (ring / 3)) * sin(2 * .pi * frequency * elapsed)))
        }
    }

    mutating func knocks(_ number: Int, gap: TimeInterval, peak: Double) {
        for index in 0..<number {
            knock(peak: peak)
            if index < number - 1 { still(for: gap - 0.025) }
        }
    }

    private mutating func append(_ offset: SIMD3<Double>) {
        let vector = gravity + offset + noise.vector(scale: Self.restingNoise)
        samples.append(AccelerometerSample(timestamp: time, x: vector.x, y: vector.y, z: vector.z))
        time += Self.interval
    }

    private func count(_ duration: TimeInterval) -> Int {
        max(Int((duration / Self.interval).rounded()), 0)
    }

    struct Result {
        var events: [KnockEvent] = []
        var taps: [TapObservation] = []
        var blocked: [SuppressionReason] = []
        var counts: [KnockCount] { events.map(\.count) }
    }

    /// Replays the stream, with key presses, clicks and wakes at the given times.
    func run(_ configuration: DetectorConfiguration = DetectorConfiguration(), keyDowns: [TimeInterval] = [],
             clicks: [TimeInterval] = [], wakes: [TimeInterval] = []) -> Result {
        var detector = KnockDetector(configuration: configuration)
        var external: [(time: TimeInterval, apply: (inout KnockDetector) -> Void)] = []
        external += keyDowns.map { time in (time, { $0.noteKeyDown(at: time) }) }
        external += clicks.map { time in (time, { $0.notePointerEvent(at: time) }) }
        external += wakes.map { time in (time, { $0.noteWake(at: time) }) }
        external.sort { $0.time < $1.time }

        var result = Result()
        var pending = external[...]
        for sample in samples {
            while let first = pending.first, first.time <= sample.timestamp {
                first.apply(&detector)
                pending = pending.dropFirst()
            }
            let outcome = detector.process(sample)
            if let tap = outcome.tap { result.taps.append(tap) }
            if let blocked = outcome.blocked { result.blocked.append(blocked) }
            result.events += outcome.events
        }
        if let last = samples.last, let event = detector.flush(at: last.timestamp) {
            result.events.append(event)
        }
        return result
    }
}

@Suite struct KnockDetectorTests {
    private let firm = 0.5

    private func stream(_ build: (inout SyntheticStream) -> Void) -> SyntheticStream {
        var stream = SyntheticStream()
        stream.still(for: 1)
        build(&stream)
        stream.still(for: 0.8)
        return stream
    }

    @Test func stillnessIsNotAKnock() {
        var stream = SyntheticStream()
        stream.still(for: 5)
        let result = stream.run()
        #expect(result.events.isEmpty && result.taps.isEmpty)
    }

    @Test func tiltingIsNotAKnockByDefault() {
        let gentle = stream { $0.tilt(to: SIMD3(-0.7, 0, -0.7), over: 6) }
        #expect(gentle.run().taps.isEmpty)
        // A brisk tilt fools the high-pass signal alone, which is why All Set
        // defaults to requiring a sharp change as well.
        let brisk = stream { $0.tilt(to: SIMD3(-0.7, 0, -0.7), over: 1.5) }
        #expect(!brisk.run(.init(sensitivity: .normal, signal: .highPass)).taps.isEmpty)
        #expect(brisk.run().taps.isEmpty)
        #expect(brisk.run(.init(sensitivity: .normal, signal: .jerk)).taps.isEmpty)
    }

    @Test func everySignalCatchesAFirmKnock() {
        let knock = stream { $0.knock(peak: firm) }
        for signal in DetectionSignal.allCases {
            #expect(knock.run(.init(sensitivity: .normal, signal: signal)).counts == [.single], "\(signal)")
        }
    }

    @Test func countsKnocks() {
        #expect(stream { $0.knocks(2, gap: 0.2, peak: firm) }.run().counts == [.double])
        #expect(stream { $0.knocks(3, gap: 0.2, peak: firm) }.run().counts == [.triple])
        // A fourth knock lands after the triple was reported and starts anew.
        #expect(stream { $0.knocks(4, gap: 0.2, peak: firm) }.run().counts == [.triple, .single])
        let apart = stream {
            $0.knock(peak: firm)
            $0.still(for: 0.8)
            $0.knock(peak: firm)
        }
        #expect(apart.run().counts == [.single, .single])
    }

    @Test func aRingingKnockCountsOnce() {
        var stream = SyntheticStream()
        stream.still(for: 1)
        stream.knock(peak: firm, ring: 0.06)
        stream.still(for: 0.8)
        let result = stream.run()
        #expect(result.counts == [.single])
        #expect(result.taps.count == 1)
    }

    @Test func typingClickingAndWakingHoldKnocksOff() {
        let knock = stream { $0.knock(peak: firm) }
        // Keys 100 ms before the knock: held off. 300 ms before: counted.
        #expect(knock.run(keyDowns: [0.9]).blocked == [.typing])
        #expect(knock.run(keyDowns: [0.7]).counts == [.single])
        #expect(knock.run(clicks: [0.95]).blocked == [.pointer])

        var woken = SyntheticStream()
        woken.still(for: 0.5)
        woken.knock(peak: firm)
        woken.still(for: 1.0)
        woken.knock(peak: firm)
        woken.still(for: 0.8)
        #expect(woken.run(wakes: [0.4]).counts == [.single], "only the knock after the grace second counts")

        var noTyping = DetectorConfiguration()
        noTyping.typingSuppression = 0
        #expect(knock.run(noTyping, keyDowns: [0.9]).counts == [.single])
    }

    @Test func reportsAsSoonAsNothingLongerHasAnAction() throws {
        var stream = SyntheticStream()
        stream.still(for: 1)
        stream.knock(peak: firm)
        stream.still(for: 0.05)
        var singleOnly = DetectorConfiguration()
        singleOnly.assignedCounts = [1]
        let result = stream.run(singleOnly)
        #expect(result.counts == [.single])
        #expect(result.events.first?.timestamp == (try #require(result.taps.first)).time)

        var doubleOnly = DetectorConfiguration()
        doubleOnly.assignedCounts = [2]
        var twice = SyntheticStream()
        twice.still(for: 1)
        twice.knocks(2, gap: 0.2, peak: firm)
        twice.still(for: 0.05)
        #expect(twice.run(doubleOnly).counts == [.double])
    }

    @Test func sensitivityDecidesWhatCounts() {
        let soft = stream { $0.knock(peak: 0.08) }
        #expect(soft.run(.init(sensitivity: .gentle)).counts == [.single])
        #expect(soft.run(.init(sensitivity: .firm)).events.isEmpty)
        #expect(Sensitivity.custom(0.005).threshold == 0.02)
        #expect(Sensitivity.custom(5).threshold == 1)

        var configuration = DetectorConfiguration()
        configuration.tapWindow = 0.05
        #expect(configuration.tapWindow == 0.25)
        configuration.refractory = 1
        #expect(configuration.refractory == 0.12)
    }

    @Test func peaksAreReportedPerKnock() {
        let event = stream { $0.knocks(2, gap: 0.2, peak: firm) }.run().events.first
        #expect(event?.peaks.count == 2)
        #expect(event?.peaks.allSatisfy { $0 > DetectorConfiguration().threshold } == true)
    }
}

@Suite struct KnockSettingsTests {
    @Test func decodesSensorReports() throws {
        var report = [UInt8](repeating: 0, count: 22)
        func put(_ value: Int32, at offset: Int) {
            withUnsafeBytes(of: value.littleEndian) { report.replaceSubrange(offset..<offset + 4, with: $0) }
        }
        put(65536, at: 6)          // 1 g
        put(-32768, at: 10)        // -0.5 g
        put(-65_359, at: 14)       // about -0.997 g
        let sample = try #require(report.withUnsafeBytes { MotionSensor.decode($0, timestamp: 3) })
        #expect(sample.x == 1 && sample.y == -0.5)
        #expect(abs(sample.z + 0.9973) < 0.001)
        #expect(sample.timestamp == 3)
        #expect([UInt8](repeating: 0, count: 10).withUnsafeBytes { MotionSensor.decode($0, timestamp: 0) } == nil)
    }

    @Test func actionsSurviveSaving() throws {
        let actions: [KnockAction] = KnockAction.simple + [
            .openIsland(.sound), .applyWorkspace(id: UUID(), name: "Coding"), .moveWindow(.leftHalf),
            .openApp(bundleID: "com.apple.Music", name: "Music"), .runShortcut(name: "Morning"),
            .shellCommand("open ~/Downloads"), .playSound(name: "Glass"),
        ]
        let decoded = try JSONDecoder().decode([KnockAction].self, from: JSONEncoder().encode(actions))
        #expect(decoded == actions)
        #expect(Set(actions.map(\.id)).count == actions.count)
    }

    @Test func settingsSurviveSavingAndOddFiles() throws {
        var settings = KnockSettings()
        settings.single = .screenshot
        settings.double = nil
        settings.sensitivity = .custom(0.3)
        settings.rules = [KnockRule(bundleID: "com.apple.Safari", appName: "Safari", double: .nextTab)]
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(KnockSettings.self, from: data) == settings)

        // Missing values fall back to defaults; an action from a newer
        // version empties just its slot; a cleared slot stays cleared.
        let odd = #"{"triple": {"kind": "teleport"}, "double": null, "sensitivity": "firm", "tapWindow": 9}"#
        let read = try JSONDecoder().decode(KnockSettings.self, from: Data(odd.utf8))
        #expect(read.triple == nil && read.double == nil)
        #expect(read.sensitivity == .firm)
        #expect(read.tapWindow == 0.7)
        #expect(read.isEnabled && read.showInIsland)
        #expect(try JSONDecoder().decode(KnockSettings.self, from: Data("{}".utf8)) == KnockSettings())
    }

    @Test func appRulesOverrideTheUsualActions() {
        var settings = KnockSettings()
        settings.single = nil
        settings.double = .toggleIsland
        settings.triple = nil
        settings.rules = [KnockRule(bundleID: "com.apple.Safari", appName: "Safari", double: .nextTab, triple: .closeWindow)]
        #expect(settings.action(for: .double, frontmost: "com.apple.Safari") == .nextTab)
        #expect(settings.action(for: .double, frontmost: "com.apple.Notes") == .toggleIsland)
        #expect(settings.action(for: .triple, frontmost: nil) == nil)
        // Triple has an action only in Safari, but the detector must still wait for it.
        #expect(settings.assignedCounts == [2, 3])
        settings.ignoreWhileTyping = false
        #expect(settings.detectorConfiguration.typingSuppression == 0)
        #expect(settings.detectorConfiguration.assignedCounts == [2, 3])
    }

    @Test @MainActor func storeRemembersSettings() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetKnocks-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let store = KnockStore(fileURL: file)
        #expect(store.settings == KnockSettings())
        store.settings.single = .ripple
        store.save()
        #expect(KnockStore(fileURL: file).settings.single == .ripple)
    }

    @Test func meterShowsThePeakBetweenReadings() {
        let readings = Readings()
        let engine = KnockEngine { output in
            if let meter = output.meter { readings.append(meter) }
        }
        engine.isMetering = true
        var stream = SyntheticStream()
        stream.still(for: 0.5)
        stream.knock(peak: 0.5)
        stream.still(for: 0.1)
        for sample in stream.samples { engine.process(sample) }
        // About 30 readings a second, and the knock's peak among them.
        #expect((15...22).contains(readings.values.count))
        #expect((readings.values.max() ?? 0) > 0.3)
    }
}

private final class Readings: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Double] = []
    func append(_ value: Double) { lock.withLock { stored.append(value) } }
    var values: [Double] { lock.withLock { stored } }
}
