// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Motion/debounce state independent of AppKit and the sensor, for deterministic tests.
public struct AutoAnchor {
    public private(set) var reference: Double
    public static let defaultDelay: TimeInterval = 0.15
    public var delay: TimeInterval = AutoAnchor.defaultDelay
    public var duration: TimeInterval = 0.2
    public var movementThreshold: Double = 1.5
    private var motionAngle: Double
    private var lastMovement: TimeInterval
    private var settlingSince: TimeInterval?
    private var settlingFrom: Double = 0

    public init(angle: Double, now: TimeInterval) {
        reference = angle
        motionAngle = angle
        lastMovement = now
    }

    public mutating func anchor(at angle: Double, now: TimeInterval) {
        reference = angle
        motionAngle = angle
        lastMovement = now
        settlingSince = nil
    }

    public mutating func update(angle: Double, now: TimeInterval, enabled: Bool) {
        // Compare against the last meaningful movement, not the previous sample:
        // slow accumulated movement must also restart the debounce.
        if abs(angle - motionAngle) >= movementThreshold {
            motionAngle = angle
            lastMovement = now
            settlingSince = nil
        }
        guard enabled, now - lastMovement >= delay else {
            settlingSince = nil
            return
        }
        if abs(reference - angle) < 0.05 {
            reference = angle
            settlingSince = nil
            return
        }
        if settlingSince == nil { settlingSince = now; settlingFrom = reference }
        let progress = min(1, max(0, (now - settlingSince!) / max(0.01, duration)))
        let eased = progress * progress * (3 - 2 * progress)
        reference = settlingFrom + (angle - settlingFrom) * eased
        if progress == 1 { settlingSince = nil }
    }
}
