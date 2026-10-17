import Foundation
import os

/// Every private or undocumented macOS interface All Set relies on, in one
/// place: what each one is, whether it works on this Mac, and a switch to turn
/// it off without a new build if a macOS update breaks it.
///
/// A feature built on one asks `isEnabled` before using it and reports what
/// happened with `report`; a capability that isn't available shows as
/// "Unavailable on this macOS" in Settings › General › Compatibility, and the
/// feature says so instead of hanging or crashing.
///
/// Turning one off (the "kill switch", read once at launch):
///
///     defaults write com.pratik.allset capability.nowPlaying.disabled -bool YES
public enum Capability: String, CaseIterable, Identifiable, Sendable {
    /// MediaRemote, through a helper `/usr/bin/perl` loads (MediaHelper.m).
    case nowPlaying
    /// IOHIDEventSystemClient temperature services (TemperatureReader).
    case temperatures
    /// The `AppleSPUHIDDevice` accelerometer (MotionSensor), for TapTap.
    case motionSensor
    /// Writing `com.apple.symbolichotkeys` to take ⌘⇧5 (ScreenshotShortcutController).
    case systemShortcuts
    /// Carbon `RegisterEventHotKey` global shortcuts (HotKeyCenter).
    case globalHotKeys
    /// Core Audio process taps for per-app volume (AppAudioRouter).
    case audioTaps
    /// TCC's private preflight for the audio-capture permission (AudioCapturePermission).
    case audioPermissionCheck

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .nowPlaying: "Now Playing"
        case .temperatures: "Temperature sensors"
        case .motionSensor: "Motion sensor (TapTap)"
        case .systemShortcuts: "Taking macOS's ⌘⇧5"
        case .globalHotKeys: "Global keyboard shortcuts"
        case .audioTaps: "Per-app audio (Sound Mixer)"
        case .audioPermissionCheck: "Audio permission check"
        }
    }

    /// What stops working without it.
    public var feature: String {
        switch self {
        case .nowPlaying: "The island and widgets show no track and can't control playback."
        case .temperatures: "System widgets and the monitor show no temperatures."
        case .motionSensor: "Knocks aren't heard."
        case .systemShortcuts: "AI Screenshot can't use ⌘⇧5; ⌃⌥⌘5 still works."
        case .globalHotKeys: "Window, workspace, clipboard and screenshot shortcuts don't respond."
        case .audioTaps: "Per-app volume sliders do nothing."
        case .audioPermissionCheck: "The mixer can't tell whether it's allowed; macOS asks on first use."
        }
    }

    public var killSwitchKey: String { "capability.\(rawValue).disabled" }
}

public enum CapabilityStatus: Equatable, Sendable {
    /// Not used yet this run.
    case unknown
    case available
    /// This Mac or macOS doesn't offer it.
    case unavailable(String)
    /// It was there but didn't work: timed out, crashed or returned an error.
    case failed(String)
    /// Switched off with its kill switch.
    case disabled

    public var label: String {
        switch self {
        case .unknown: "Not used yet"
        case .available: "Working"
        case .unavailable(let reason): "Unavailable on this macOS: \(reason)"
        case .failed(let reason): "Not working: \(reason)"
        case .disabled: "Switched off"
        }
    }

    public var isUsable: Bool {
        switch self {
        case .unknown, .available: true
        case .unavailable, .failed, .disabled: false
        }
    }
}

/// Thread-safe: sensors report from their own queues.
public final class Capabilities: Sendable {
    public static let shared = Capabilities()

    private let disabled: Set<Capability>
    private let statuses = OSAllocatedUnfairLock<[Capability: CapabilityStatus]>(initialState: [:])

    /// The kill switches are read once, here: flipping one takes effect at the next launch.
    public init(defaults: UserDefaults = .standard) {
        disabled = Set(Capability.allCases.filter { defaults.bool(forKey: $0.killSwitchKey) })
    }

    /// False when its kill switch is on: the feature must not touch the interface at all.
    public func isEnabled(_ capability: Capability) -> Bool {
        !disabled.contains(capability)
    }

    public func status(_ capability: Capability) -> CapabilityStatus {
        if disabled.contains(capability) { return .disabled }
        return statuses.withLock { $0[capability] ?? .unknown }
    }

    /// What using it just showed. A later success replaces an earlier failure.
    public func report(_ capability: Capability, _ status: CapabilityStatus) {
        guard !disabled.contains(capability) else { return }
        statuses.withLock { $0[capability] = status }
    }
}
