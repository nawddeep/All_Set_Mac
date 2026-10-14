import Foundation
import Testing
@testable import AllSetCore

// Ported from Lid Plane (c) 2026 Jhey, GPL-3.0-or-later.
@Suite struct LidPlaneAutoAnchorTests {
    @Test func waitsForPauseThenEasesToNewAngle() {
        var state = AutoAnchor(angle: 110, now: 0)
        #expect(state.delay == 0.15 && state.duration == 0.2)
        state.update(angle: 80, now: 0.1, enabled: true)
        state.update(angle: 80, now: 0.24, enabled: true)
        #expect(state.reference == 110)
        state.update(angle: 80, now: 0.251, enabled: true)
        state.update(angle: 80, now: 0.351, enabled: true)
        #expect(abs(state.reference - 95) < 0.01)
        state.update(angle: 80, now: 0.46, enabled: true)
        #expect(state.reference == 80)
    }

    @Test func movementInterruptsSettling() {
        var state = AutoAnchor(angle: 110, now: 0)
        state.update(angle: 80, now: 0.1, enabled: true)
        state.update(angle: 80, now: 0.251, enabled: true)
        state.update(angle: 80, now: 0.301, enabled: true)
        let reference = state.reference
        state.update(angle: 70, now: 0.32, enabled: true)
        state.update(angle: 70, now: 0.46, enabled: true)
        #expect(state.reference == reference)
    }

    @Test func slowCumulativeMovementRestartsDebounce() {
        var state = AutoAnchor(angle: 110, now: 0)
        for i in 1...10 { state.update(angle: 110 - Double(i), now: Double(i) * 0.3, enabled: true) }
        #expect(state.reference == 110)
    }

    @Test func smallSensorJitterDoesNotPreventSettling() {
        var state = AutoAnchor(angle: 110, now: 0)
        state.update(angle: 80, now: 0.1, enabled: true)
        for i in 2...20 { state.update(angle: 80 + (i.isMultiple(of: 2) ? 0.3 : -0.3), now: Double(i) * 0.1, enabled: true) }
        #expect(abs(state.reference - 80) < 0.4)
    }

    @Test func disabledModeHoldsReferenceAndManualAnchorResets() {
        var state = AutoAnchor(angle: 110, now: 0)
        state.update(angle: 70, now: 1, enabled: false)
        state.update(angle: 70, now: 10, enabled: false)
        #expect(state.reference == 110)
        state.anchor(at: 70, now: 11)
        state.update(angle: 60, now: 11.1, enabled: true)
        #expect(state.reference == 70)
    }
}

@Suite struct LidPlaneMotionPolicyTests {
    @Test func captureOnlyWhileAVisibleEffectIsNeeded() {
        #expect(!CaptureDemand.needsCapture(delta: 0, blur: true, warp: true))
        #expect(!CaptureDemand.needsCapture(delta: 0.002, blur: true, warp: true))
        #expect(CaptureDemand.needsCapture(delta: 0.01, blur: true, warp: false))
        #expect(CaptureDemand.needsCapture(delta: -0.01, blur: false, warp: true))
        #expect(!CaptureDemand.needsCapture(delta: 0.1, blur: false, warp: false))
        #expect(!CaptureDemand.needsCapture(delta: .nan, blur: true, warp: true))
    }

    @Test func absoluteActivationAndJitter() {
        #expect(LidPlaneDefaults.activationAngle == 110 && LidPlaneDefaults.jitterTolerance == 0)
        #expect(AngleActivation.allows(angle: 110, limit: 110, enabled: true))
        #expect(!AngleActivation.allows(angle: 110.01, limit: 110, enabled: true))
        #expect(AngleActivation.allows(angle: 120, limit: 90, enabled: false))
        #expect(!AngleActivation.allows(angle: .nan, limit: 90, enabled: false))
        var filter = LidMotionFilter()
        filter.reset(to: 110)
        let r1 = filter.update(109.9, tolerance: 0)
        #expect(r1 == 109.9)
        filter.reset(to: 110)
        for value in [109.0, 111, 108, 112, 109, 111] {
            let held = filter.update(value, tolerance: 2)
            #expect(held == 110)
        }
        // Slow movement accumulates instead of being swallowed.
        let r2 = filter.update(107, tolerance: 2)
        #expect(r2 == 107)
        let r3 = filter.update(106, tolerance: 1)
        #expect(r3 == 107)
        let r4 = filter.update(105, tolerance: 1)
        #expect(r4 == 105)
        // A stale filtered value can never bypass the raw cut-off.
        #expect(!AngleActivation.allows(angle: 91, limit: 90, enabled: true))
    }

    @Test func displaySafetyNeverFallsBackToAnExternalScreen() {
        var safety = DisplaySafetyGate()
        let r5 = safety.update(lidClosed: false, builtInAvailable: true, sensorAvailable: true, now: 0)
        #expect(!r5)
        let r6 = safety.update(lidClosed: false, builtInAvailable: true, sensorAvailable: true, now: 0.51)
        #expect(r6)
        let r7 = safety.update(lidClosed: true, builtInAvailable: true, sensorAvailable: true, now: 1)
        #expect(!r7)
        #expect(safety.state == .closed)
        let r8 = safety.update(lidClosed: false, builtInAvailable: false, sensorAvailable: true, now: 2)
        #expect(!r8)
        #expect(safety.state == .noDisplay)
        let r9 = safety.update(lidClosed: false, builtInAvailable: true, sensorAvailable: false, now: 3)
        #expect(!r9)
        #expect(safety.state == .noSensor)
        let r10 = safety.update(lidClosed: false, builtInAvailable: true, sensorAvailable: true, now: 4)
        #expect(!r10)
        let r11 = safety.update(lidClosed: false, builtInAvailable: false, sensorAvailable: true, now: 4.3)
        #expect(!r11)
        let r12 = safety.update(lidClosed: false, builtInAvailable: true, sensorAvailable: true, now: 4.4)
        #expect(!r12)
        let r13 = safety.update(lidClosed: false, builtInAvailable: true, sensorAvailable: true, now: 4.8)
        #expect(!r13)
        let r14 = safety.update(lidClosed: false, builtInAvailable: true, sensorAvailable: true, now: 4.91)
        #expect(r14)
        safety.reset()
        let r15 = safety.update(lidClosed: false, builtInAvailable: true, sensorAvailable: true, now: 5)
        #expect(!r15)
    }
}

@Suite @MainActor struct LidPlaneSettingsTests {
    private func freshDefaults() -> UserDefaults {
        let name = "AllSetTests-lidplane-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func startsOffWithTheRecommendedBehaviour() {
        let settings = LidPlaneSettings(defaults: freshDefaults())
        #expect(!settings.isEnabled && settings.angleMode)
        #expect(settings.activationAngle == 110 && settings.jitterTolerance == 0)
        #expect(settings.blur && settings.holdAngle && settings.perspective && settings.shortcutEnabled)
    }

    @Test func choicesSurviveARelaunchAndStayInRange() {
        let defaults = freshDefaults()
        let first = LidPlaneSettings(defaults: defaults)
        first.isEnabled = true
        first.angleMode = false
        first.activationAngle = 95
        first.perspective = false
        defaults.set(999.0, forKey: "lidplane.jitterTolerance")
        let second = LidPlaneSettings(defaults: defaults)
        #expect(second.isEnabled && !second.angleMode && second.activationAngle == 95 && !second.perspective)
        #expect(second.jitterTolerance == LidPlaneSettings.jitterRange.upperBound)
        second.resetBehaviour()
        #expect(second.isEnabled && second.angleMode && second.activationAngle == 110 && second.perspective)
    }
}

@Suite struct LidPlaneTrackingTests {
    private static func ease(_ x: Double) -> Double { let t = min(1, max(0, x)); return t * t * (3 - 2 * t) }

    /// Feeds whole-degree readings at 60 Hz, draws at `hz`. Returns the RMS and
    /// worst distance from the true lid after the first 0.3 s, and roughness:
    /// RMS change of per-frame movement (steps show up here).
    private func track(_ lid: (Double) -> Double, for duration: Double, hz: Double = 120)
        -> (rms: Double, worst: Double, roughness: Double) {
        var tracker = LidTracker()
        var lastPoll = -1.0, t = 0.0, errors: [Double] = [], drawn: [Double] = []
        while t < duration {
            if t - lastPoll >= 1.0 / 60 - 1e-9 { lastPoll = t; tracker.reading(lid(t).rounded(), at: t) }
            let angle = tracker.advance(to: t)!
            if t > 0.3 { errors.append(angle - lid(t)); drawn.append(angle) }
            t += 1 / hz
        }
        func rootMeanSquare(_ values: [Double]) -> Double {
            var sum = 0.0
            for value in values { sum += value * value }
            return (sum / Double(values.count)).squareRoot()
        }
        var bends: [Double] = []
        for index in 2..<drawn.count {
            let bend: Double = drawn[index] - 2 * drawn[index - 1] + drawn[index - 2]
            bends.append(bend)
        }
        return (rootMeanSquare(errors), errors.map(abs).max()!, rootMeanSquare(bends))
    }

    @Test func tracksANormalCloseClosely() {
        // 90° in 1.5 s. The spring this replaced was 4.3° RMS / 7.3° behind.
        let result = track({ 130 - 90 * Self.ease($0 / 1.5) }, for: 2.5)
        #expect(result.rms < 1.2)
        #expect(result.worst < 2.5)
    }

    @Test func smoothsOutTheWholeDegreeSteps() {
        // Raw readings are ~0.94 rough on this close; tracked ~0.03.
        let result = track({ 130 - 90 * Self.ease($0 / 1.5) }, for: 2.5)
        #expect(result.roughness < 0.06)
        // A slow 8 °/s drift: one reading step every 125 ms, drawn as a glide.
        let slow = track({ 120 - 8 * $0 }, for: 4)
        #expect(slow.roughness < 0.05)
        #expect(slow.worst < 0.5)
    }

    @Test func sameCurveAtSixtyAndOneTwentyHertz() {
        let lid: (Double) -> Double = { 130 - 90 * Self.ease($0 / 1.5) }
        let slow = track(lid, for: 2.5, hz: 60), fast = track(lid, for: 2.5, hz: 120)
        #expect(abs(slow.rms - fast.rms) < 0.3)
    }

    @Test func openingLidIsFlatByTheTimeItPassesTheAngle() {
        // The old spring still showed 10–30° of fold here, which then snapped
        // away as a resize.
        for duration in [2.0, 1.0, 0.5] {
            var tracker = LidTracker()
            var lastPoll = -1.0, t = 0.0, left = 0.0
            while t < duration + 0.5 {
                let reading = (70 + 60 * Self.ease(t / duration)).rounded()
                if t - lastPoll >= 1.0 / 60 - 1e-9 { lastPoll = t; tracker.reading(reading, at: t) }
                let angle = tracker.advance(to: t)!
                if reading > 110 { left = max(0, 110 - angle); break }
                t += 1.0 / 120
            }
            // Under a degree, and the overlay already more than half dissolved,
            // so hiding it can't be seen.
            #expect(left < 1)
            #expect(OverlayVisibility.alpha(delta: left * .pi / 180) < 0.5)
        }
    }

    @Test func holdsStillAndSurvivesTheIdleTimer() {
        var tracker = LidTracker()
        for frame in 0..<30 { tracker.reading(100, at: Double(frame) / 10); tracker.advance(to: Double(frame) / 10) }
        #expect(tracker.angle == 100 && tracker.velocity == 0)
        // Readings stop: the prediction doesn't run away.
        var moving = LidTracker()
        for frame in 0..<30 { moving.reading(100 - Double(frame), at: Double(frame) / 60) }
        let last = moving.predicted(at: 29.0 / 60)
        #expect(abs(moving.predicted(at: 10) - last) < 10)
    }

    @Test func aStartLevelWithTheLidJustTracksIt() {
        var intro = FoldIntro()
        let target = 0.5 * Double.pi / 180
        #expect(intro.step(toward: target, dt: 1.0 / 120) == target)
    }

    @Test func aLateStartEasesInLikeAKeyframe() {
        var intro = FoldIntro()
        let target = 30 * Double.pi / 180
        var previous = 0.0, steps: [Double] = [], peak = 0.0
        for _ in 0..<120 {
            let fold = intro.step(toward: target, dt: 1.0 / 120)
            steps.append(fold - previous)
            peak = max(peak, (fold - previous) * 120 * 180 / .pi)
            previous = fold
        }
        // Starts from rest, speeds up, lands on the lid, never sprints.
        #expect(steps[0] < steps[1] && steps[1] < steps[2])
        #expect(abs(previous - target) < 1e-9)
        #expect(peak < 100)
    }

    @Test func overlayDissolvesOverTheFirstDegreeAndAHalf() {
        #expect(OverlayVisibility.alpha(delta: 0) == 0)
        #expect(OverlayVisibility.alpha(delta: OverlayVisibility.fullAt / 2) == 0.5)
        #expect(OverlayVisibility.alpha(delta: -OverlayVisibility.fullAt) == 1)
        #expect(OverlayVisibility.alpha(delta: 0.5) == 1)
    }

    @Test func captureWarmsUpOnlyWhileTheLidHeadsForTheAngle() {
        var warmup = CaptureWarmup()
        warmup.update(angle: 130, now: 0)
        #expect(!warmup.isWarm(angle: 130, limit: 110, angleMode: true, now: 0.1))
        warmup.update(angle: 124, now: 0.5)
        #expect(warmup.isWarm(angle: 124, limit: 110, angleMode: true, now: 0.5))
        #expect(!warmup.isWarm(angle: 140, limit: 110, angleMode: true, now: 0.5))
        #expect(!warmup.isWarm(angle: 124, limit: 110, angleMode: false, now: 0.5))
        #expect(!warmup.isWarm(angle: 124, limit: 110, angleMode: true, now: 0.5 + CaptureWarmup.restAfter))
        warmup.update(angle: 124.6, now: 4)
        #expect(!warmup.isWarm(angle: 124.6, limit: 110, angleMode: true, now: 4))
    }

    @Test func aQuickCloseWarmsUpFurtherAhead() {
        var warmup = CaptureWarmup()
        warmup.update(angle: 160, now: 0)
        warmup.update(angle: 150, now: 0.05)
        #expect(warmup.isWarm(angle: 150, limit: 110, angleMode: true, closingSpeed: 180, now: 0.05))
        #expect(!warmup.isWarm(angle: 150, limit: 110, angleMode: true, closingSpeed: 20, now: 0.05))
        #expect(!warmup.isWarm(angle: 150, limit: 110, angleMode: true, closingSpeed: -180, now: 0.05))
        #expect(!warmup.isWarm(angle: 175, limit: 110, angleMode: true, closingSpeed: 1000, now: 0.05))
    }
}
