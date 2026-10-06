import Foundation

/// How hard All Set may work right now, decided in one place from the
/// power and heat signals macOS gives, so every subsystem slows together
/// rather than each guessing on its own.
///
/// | Tier | When | Decorative motion | Art | Stats (idle) | Clipboard | Network |
/// |---|---|---|---|---|---|---|
/// | full | plugged in, cool | on | 24 fps | 3 s | 0.5 s | as set |
/// | balanced | on battery, or warm ("fair") | on | 15 fps | 10 s | 1 s | as set |
/// | saver | Low Power Mode, or hot ("serious") | paused | still | 20 s | 1.5 s | 2× slower |
/// | minimal | very hot ("critical") | paused | still | 60 s | 2 s | 4× slower |
///
/// Art here covers the live wallpaper's too: off the charger it's drawn at
/// the tier's rate, whatever the wallpaper's own frame-rate setting.
///
/// Reduce Motion pauses decorative motion in every tier. Nothing a person
/// asked to see is turned off: live stats, clocks and data keep updating,
/// just less often, and decorative motion resumes as soon as the Mac cools
/// or leaves Low Power Mode.
public struct PerformancePolicy: Equatable, Sendable {
    public enum Tier: Int, Comparable, Sendable {
        case full, balanced, saver, minimal

        public static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public var isLowPower = false
    public var reducesMotion = false
    public var isOnBattery = false
    public var thermal: ProcessInfo.ThermalState = .nominal

    public init(isLowPower: Bool = false, reducesMotion: Bool = false, isOnBattery: Bool = false,
                thermal: ProcessInfo.ThermalState = .nominal) {
        self.isLowPower = isLowPower
        self.reducesMotion = reducesMotion
        self.isOnBattery = isOnBattery
        self.thermal = thermal
    }

    public var tier: Tier {
        if thermal == .critical { return .minimal }
        if isLowPower || thermal == .serious { return .saver }
        if isOnBattery || thermal == .fair { return .balanced }
        return .full
    }

    /// Animation that's only there to look good: widget and wallpaper
    /// motion, moving art, glows. Stops rather than stutters.
    public var pausesDecorativeMotion: Bool { reducesMotion || tier >= .saver }

    /// Frames a second for moving art.
    public var artFrameRate: Int { tier == .full ? 24 : 15 }

    /// Seconds between system samples while nothing shows them (they only
    /// keep the sparklines and the optional menu-bar CPU figure going).
    public var monitorIdleInterval: Double { [3, 10, 20, 60][tier.rawValue] }

    /// The fastest live stats may update, whatever the setting.
    public var monitorMinimumInterval: Double { [0, 1, 2, 3][tier.rawValue] }

    /// Seconds between clipboard checks (macOS doesn't announce changes).
    public var clipboardInterval: Double { [0.5, 1, 1.5, 2][tier.rawValue] }

    /// How much longer network-backed widgets wait between refreshes.
    public var networkRefreshScale: Double { [1, 1, 2, 4][tier.rawValue] }
}
