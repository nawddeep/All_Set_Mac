import Foundation

/// The macOS permissions All Set can use, what each is for, and what stops
/// working without it. Each is asked for only when the feature that needs it
/// is first used or switched on, never at launch.
public enum Permission: String, CaseIterable, Identifiable, Sendable {
    case accessibility, calendars, audioCapture

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .accessibility: "Accessibility"
        case .calendars: "Calendars"
        case .audioCapture: "Audio Recording"
        }
    }

    /// Why All Set would ask.
    public var purpose: String {
        switch self {
        case .accessibility: "Moves and resizes other apps' windows (Window Snapping, Workspaces) and sends keystrokes for TapTap actions like Copy and Paste."
        case .calendars: "Shows your upcoming events in the Calendar and Next Event widgets. Events are read on this Mac and never sent anywhere."
        case .audioCapture: "Lets the Sound Mixer turn one app up or down. Sound goes straight to your speakers; nothing is recorded or saved."
        }
    }

    /// What doesn't work while it's denied.
    public var withoutIt: String {
        switch self {
        case .accessibility: "Window shortcuts beep, drag-to-edge snapping does nothing, workspaces can't place windows, and TapTap's editing actions fail."
        case .calendars: "Calendar widgets show the date but no events."
        case .audioCapture: "Per-app volume sliders are disabled; every app plays at its own volume."
        }
    }

    /// The Privacy & Security pane that holds it.
    public var settingsURL: URL {
        let anchor = switch self {
        case .accessibility: "Privacy_Accessibility"
        case .calendars: "Privacy_Calendars"
        case .audioCapture: "Privacy_AudioCapture"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
    }

    /// The extras that can't work without it.
    public var extras: Set<Extra> {
        switch self {
        case .accessibility: [.snapping, .workspaces, .knocks]
        case .calendars: []
        case .audioCapture: [.mixer]
        }
    }

    /// The permissions worth showing for what's switched on and on the desktop:
    /// one nobody needs isn't listed, so nobody is nudged to grant it.
    public static func relevant(extras: Set<Extra>, widgetKinds: Set<WidgetKind>) -> [Permission] {
        allCases.filter { permission in
            if !permission.extras.isDisjoint(with: extras) { return true }
            return permission == .calendars && !widgetKinds.isDisjoint(with: [.calendar, .nextEvent])
        }
    }

    /// The permission switching an extra on would need first, if any.
    public static func needed(toTurnOn extra: Extra) -> Permission? {
        // TapTap works without Accessibility; only some of its actions need it, and those ask when chosen.
        guard extra != .knocks else { return nil }
        return allCases.first { $0.extras.contains(extra) }
    }
}

/// How a permission stands right now, as the app can tell.
public enum PermissionStatus: Equatable, Sendable {
    case granted, denied, notAsked
    /// macOS gives no way to check (or the bare `.build` binary can't ask).
    case unknown

    public var label: String {
        switch self {
        case .granted: "Allowed"
        case .denied: "Not allowed"
        case .notAsked: "Not asked yet"
        case .unknown: "Can't tell"
        }
    }
}

/// The first-run welcome: shown once to a new install, never to one from
/// before it existed.
public enum Onboarding {
    static let completedKey = "onboarding.completedVersion"
    /// Bump when the welcome changes enough to show again.
    public static let version = 1

    public static func shouldShow(isLegacyInstall: Bool, defaults: UserDefaults = .standard) -> Bool {
        !isLegacyInstall && defaults.integer(forKey: completedKey) < version
    }

    public static func markCompleted(defaults: UserDefaults = .standard) {
        defaults.set(version, forKey: completedKey)
    }
}
