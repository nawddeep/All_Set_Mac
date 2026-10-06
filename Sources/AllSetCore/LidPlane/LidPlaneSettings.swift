import Foundation
import Observation

/// How the lid effect behaves, persisted to UserDefaults as it changes.
///
/// The effect itself comes from Lid Plane (c) 2026 Jhey, GPL-3.0-or-later.
@Observable @MainActor
public final class LidPlaneSettings {
    /// Whether the effect is switched on. Off until a person turns it on.
    public var isEnabled: Bool { didSet { save(isEnabled, Key.isEnabled) } }
    /// Only blur and tilt at or below `activationAngle`; otherwise follow the
    /// lid's movement from an anchor.
    public var angleMode: Bool { didSet { save(angleMode, Key.angleMode) } }
    public var activationAngle: Double { didSet { save(activationAngle, Key.activationAngle) } }
    /// Hinge movement smaller than this many degrees is ignored.
    public var jitterTolerance: Double { didSet { save(jitterTolerance, Key.jitterTolerance) } }
    /// Settle back to the current angle after the lid stops moving (movement mode).
    public var autoAnchor: Bool { didSet { save(autoAnchor, Key.autoAnchor) } }
    /// Seconds the lid must rest before auto-anchoring.
    public var anchorDelay: Double { didSet { save(anchorDelay, Key.anchorDelay) } }
    public var blur: Bool { didSet { save(blur, Key.blur) } }
    /// Hold the content at its original angle as the lid closes.
    public var holdAngle: Bool { didSet { save(holdAngle, Key.holdAngle) } }
    public var perspective: Bool { didSet { save(perspective, Key.perspective) } }
    /// ⌃⌘L turns the effect on and off from any app.
    public var shortcutEnabled: Bool { didSet { save(shortcutEnabled, Key.shortcutEnabled) } }

    public static let activationRange: ClosedRange<Double> = 10...180
    public static let jitterRange: ClosedRange<Double> = 0...5
    public static let anchorDelays: [Double] = [AutoAnchor.defaultDelay, 0.3, 0.5, 1, 2]

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let isEnabled = "lidplane.enabled"
        static let angleMode = "lidplane.angleMode"
        static let activationAngle = "lidplane.activationAngle"
        static let jitterTolerance = "lidplane.jitterTolerance"
        static let autoAnchor = "lidplane.autoAnchor"
        static let anchorDelay = "lidplane.anchorDelay"
        static let blur = "lidplane.blur"
        static let holdAngle = "lidplane.holdAngle"
        static let perspective = "lidplane.perspective"
        static let shortcutEnabled = "lidplane.shortcut"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func bool(_ key: String, _ fallback: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }
        func number(_ key: String, _ fallback: Double) -> Double { defaults.object(forKey: key) as? Double ?? fallback }
        isEnabled = bool(Key.isEnabled, false)
        angleMode = bool(Key.angleMode, true)
        activationAngle = min(Self.activationRange.upperBound, max(Self.activationRange.lowerBound,
                                                                   number(Key.activationAngle, LidPlaneDefaults.activationAngle)))
        jitterTolerance = min(Self.jitterRange.upperBound, max(Self.jitterRange.lowerBound,
                                                                number(Key.jitterTolerance, LidPlaneDefaults.jitterTolerance)))
        autoAnchor = bool(Key.autoAnchor, true)
        anchorDelay = number(Key.anchorDelay, AutoAnchor.defaultDelay)
        blur = bool(Key.blur, true)
        holdAngle = bool(Key.holdAngle, true)
        perspective = bool(Key.perspective, true)
        shortcutEnabled = bool(Key.shortcutEnabled, true)
    }

    /// Back to the effect's recommended behaviour. Whether it's on stays as it is.
    public func resetBehaviour() {
        angleMode = true
        activationAngle = LidPlaneDefaults.activationAngle
        jitterTolerance = LidPlaneDefaults.jitterTolerance
        autoAnchor = true
        anchorDelay = AutoAnchor.defaultDelay
        blur = true
        holdAngle = true
        perspective = true
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
