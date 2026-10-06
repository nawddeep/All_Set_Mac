import Foundation

/// The chord that starts an AI screenshot from any app.
public enum ScreenshotShortcut: String, CaseIterable, Identifiable, Sendable {
    case off
    /// ⌘⇧5, replacing macOS's own screenshot toolbar while All Set runs.
    case commandShift5
    /// ⌃⌥⌘5, which leaves macOS's shortcut alone.
    case controlOptionCommand5

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .off: "Off"
        case .commandShift5: "⌘⇧5 (replaces macOS)"
        case .controlOptionCommand5: "⌃⌥⌘5"
        }
    }

    public var shortcut: Shortcut? {
        switch self {
        case .off: nil
        case .commandShift5: Shortcut(keyCode: 0x17, modifiers: [.command, .shift], key: "5")
        case .controlOptionCommand5: Shortcut(keyCode: 0x17, modifiers: [.control, .option, .command], key: "5")
        }
    }

    /// Whether macOS's own "Screenshot and recording options" shortcut has to
    /// be switched off first: the system gets a chord before any app does.
    public var needsSystemShortcutOff: Bool { self == .commandShift5 }
}

/// macOS keeps its keyboard shortcuts in `com.apple.symbolichotkeys`. This is
/// the pure part of switching one off and putting it back exactly as it was.
public enum SymbolicHotKeys {
    /// "Screenshot and recording options" (⌘⇧5).
    public static let screenshotOptions = "184"

    /// Whether the shortcut is on. An entry macOS never wrote means defaults: on.
    public static func isEnabled(_ id: String, in hotKeys: [String: Any]) -> Bool {
        guard let entry = hotKeys[id] as? [String: Any] else { return true }
        return (entry["enabled"] as? Bool) ?? (entry["enabled"] as? NSNumber)?.boolValue ?? true
    }

    /// The table with one shortcut switched on or off, everything else kept.
    public static func setting(_ id: String, enabled: Bool, in hotKeys: [String: Any],
                               defaultEntry: [String: Any]) -> [String: Any] {
        var result = hotKeys
        var entry = (hotKeys[id] as? [String: Any]) ?? defaultEntry
        entry["enabled"] = enabled
        result[id] = entry
        return result
    }

    /// What macOS writes for ⌘⇧5: key code 23 ("5"), ⇧⌘.
    public static var screenshotOptionsEntry: [String: Any] {
        [
        "enabled": true,
        "value": ["parameters": [53, 23, 1_179_648], "type": "standard"] as [String: Any],
        ]
    }
}
