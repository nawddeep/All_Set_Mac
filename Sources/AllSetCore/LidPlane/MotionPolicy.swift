// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A dead band measured from the last accepted angle, not the last raw sample.
/// Small shakes are ignored; gradual movement still accumulates past tolerance.
public struct LidMotionFilter {
    public private(set) var angle: Double?
    public init() {}
    public mutating func reset(to angle: Double) { self.angle = angle }
    public mutating func update(_ sample: Double, tolerance: Double) -> Double {
        guard sample.isFinite else { return angle ?? 0 }
        if angle == nil || abs(sample - angle!) > max(0, tolerance) { angle = sample }
        return angle!
    }
}

/// An absolute lid-angle ceiling. Raw angle is checked first so filtering can
/// never leave the effect visible above the user's selected limit.
public enum AngleActivation {
    public static func allows(angle: Double, limit: Double, enabled: Bool) -> Bool {
        angle.isFinite && (!enabled || angle <= limit)
    }
}

/// Match the renderer's visibility threshold; aligned content needs no stream.
public enum CaptureDemand {
    public static func needsCapture(delta: Float, blur: Bool, warp: Bool) -> Bool {
        delta.isFinite && abs(delta) > 0.002 && (blur || warp)
    }
}

/// The lid angle as the screen should show it: tracked 1:1 with the hinge,
/// the way a touch tracks a finger, not chased by a spring.
///
/// The hinge reports whole degrees, so raw readings move in steps. An
/// alpha-beta filter estimates angle and speed from them and predicts between
/// readings; a smoother then takes out the leftover corrections while being
/// driven by that speed, so smoothing adds almost no lag. Simulated against
/// whole-degree readings at 60 Hz (a 90° close in 1.5 s): about 0.8° from the
/// true lid, where the spring this replaced trailed by 4–7°, and an opening
/// lid reaches the activation angle with the fold already flat (the spring
/// left 10–30° showing, which snapped away as a visible resize).
public struct LidTracker {
    public var alpha = 0.5
    public var beta = 0.1
    /// Seconds the leftover corrections take to fade.
    public var smoothing: TimeInterval = 0.08

    /// The angle to draw, after `advance(to:)`.
    public private(set) var angle: Double?
    /// Degrees a second; positive while opening.
    public private(set) var velocity = 0.0

    private var estimate = 0.0
    private var lastReading: TimeInterval = -.infinity
    private var lastAdvance: TimeInterval = -.infinity

    public init() {}

    /// Forget everything until the next reading.
    public mutating func reset() {
        angle = nil
        velocity = 0
        lastReading = -.infinity
        lastAdvance = -.infinity
    }

    /// Hold still at `angle` from `now` (an explicit anchor).
    public mutating func reset(to angle: Double, at now: TimeInterval) {
        self.angle = angle
        estimate = angle
        velocity = 0
        lastReading = now
        lastAdvance = now
    }

    public mutating func reading(_ value: Double, at now: TimeInterval) {
        guard value.isFinite else { return }
        let dt = now - lastReading
        // First reading, or one after a gap that says nothing about motion now.
        guard angle != nil, dt.isFinite, dt < 0.5 else {
            estimate = value
            velocity = 0
            lastReading = now
            angle = value
            lastAdvance = now
            return
        }
        guard dt > 0 else { return }
        let predicted = estimate + velocity * dt
        let residual = value - predicted
        estimate = predicted + alpha * residual
        velocity += beta / dt * residual
        lastReading = now
    }

    /// Where the filter puts the lid at `now`.
    public func predicted(at now: TimeInterval) -> Double {
        // Never run on far past the last reading if the sensor goes quiet.
        // Earlier times are fine: `advance` compares against the previous
        // frame, which can fall just before the latest reading.
        estimate + velocity * min(0.15, now - lastReading)
    }

    /// Moves the drawn angle on to `now`. Exact for any frame time: the gap to
    /// the prediction decays by e^(-dt/smoothing), so 60 Hz, 120 Hz and the
    /// 10 Hz idle timer all trace the same curve.
    @discardableResult
    public mutating func advance(to now: TimeInterval) -> Double? {
        guard let current = angle else { return nil }
        let dt = now - lastAdvance
        guard dt > 0, dt.isFinite else { return current }
        let gap = current - predicted(at: lastAdvance)
        let next = predicted(at: now) + gap * exp(-dt / max(0.001, smoothing))
        angle = next
        lastAdvance = now
        return next
    }
}

/// Only for a fold that can't start level with the lid: capture was late and
/// the lid is already past the angle. The fold is eased in from flat on a
/// smoothstep, over longer the further behind it starts (a 30° gap takes
/// 0.5 s, peaking near 90 °/s). A fold that starts level just tracks the lid.
public struct FoldIntro {
    /// Starts closer than this (radians, 1.5°) need no intro.
    public static let levelGap = 1.5 * Double.pi / 180
    /// One second per 60° behind, between `shortest` and `longest`.
    public static let shortest: TimeInterval = 0.3
    public static let longest: TimeInterval = 0.8

    private var duration: TimeInterval?
    private var elapsed: TimeInterval = 0

    public init() {}

    public mutating func reset() {
        duration = nil
        elapsed = 0
    }

    /// The fold to draw for `target` (radians).
    public mutating func step(toward target: Double, dt: TimeInterval) -> Double {
        guard target.isFinite else { return 0 }
        if duration == nil {
            let gap = abs(target)
            duration = gap < Self.levelGap ? 0
                : min(Self.longest, max(Self.shortest, gap * 180 / .pi / 60))
        }
        elapsed += max(0, dt)
        guard let duration, duration > 0 else { return target }
        let t = min(1, elapsed / duration)
        return target * t * t * (3 - 2 * t)
    }
}

/// How visible the overlay is for a fold of `delta` radians: none at flat, all
/// of it by 1.5°. Below that the folded picture is all but the desktop itself,
/// so dissolving there makes the start and the end of the effect seamless,
/// whatever small difference is left.
public enum OverlayVisibility {
    public static let fullAt = 1.5 * Double.pi / 180

    public static func alpha(delta: Double) -> Double {
        let t = min(1, max(0, abs(delta) / fullAt))
        return t * t * (3 - 2 * t)
    }
}

/// When to have the desktop stream running before the fold needs it. Capture
/// takes a few hundred milliseconds to deliver a first frame; starting it as
/// the lid heads toward the activation angle means the fold can begin from
/// flat the moment it crosses, instead of popping in late.
///
/// A fixed margin is too little for a quick close (15° at 180 °/s is 80 ms),
/// so a closing lid also warms up when it would reach the angle within
/// `leadTime`.
public struct CaptureWarmup {
    /// Degrees above the activation angle where the stream starts.
    public static let margin = 15.0
    /// Seconds ahead of the angle a closing lid starts the stream.
    public static let leadTime = 0.6
    /// Never further above the angle than this, however fast.
    public static let maximumMargin = 60.0
    /// A lid that stops moving near the angle lets the stream go after this.
    public static let restAfter: TimeInterval = 3

    private var lastAngle: Double?
    private var lastMoved: TimeInterval = -.infinity

    public init() {}

    public mutating func update(angle: Double, now: TimeInterval) {
        guard angle.isFinite else { return }
        guard let lastAngle else { self.lastAngle = angle; return }
        if abs(angle - lastAngle) >= 1 {
            self.lastAngle = angle
            lastMoved = now
        }
    }

    /// `closingSpeed` in degrees a second (`LidTracker.velocity`, negated).
    public func isWarm(angle: Double, limit: Double, angleMode: Bool, closingSpeed: Double = 0, now: TimeInterval) -> Bool {
        guard angleMode, now - lastMoved < Self.restAfter else { return false }
        let lead = closingSpeed > 0 ? min(Self.maximumMargin, closingSpeed * Self.leadTime) : 0
        return angle <= limit + max(Self.margin, lead)
    }
}

/// Fail closed, then wait for a stable display before restarting capture.
/// No display IDs or UI objects here: topology transitions are deterministic tests.
public struct DisplaySafetyGate {
    public enum State: String {
        case closed = "Paused · lid closed"
        case noDisplay = "Paused · built-in display unavailable"
        case noSensor = "Paused · sensor unavailable"
        case recovering = "Waiting for built-in display…"
        case ready = "Ready"
    }
    public private(set) var state: State = .recovering
    public var recoveryDelay: TimeInterval = 0.5
    private var readySince: TimeInterval?
    public init() {}
    public mutating func reset() { readySince = nil; state = .recovering }
    @discardableResult
    public mutating func update(lidClosed: Bool, builtInAvailable: Bool, sensorAvailable: Bool, now: TimeInterval) -> Bool {
        if lidClosed { state = .closed }
        else if !builtInAvailable { state = .noDisplay }
        else if !sensorAvailable { state = .noSensor }
        else {
            if readySince == nil { readySince = now }
            state = now - readySince! >= recoveryDelay ? .ready : .recovering
            return state == .ready
        }
        readySince = nil
        return false
    }
}
