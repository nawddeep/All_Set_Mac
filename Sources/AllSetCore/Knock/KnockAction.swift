import Foundation

/// A tab of the Dynamic Island a knock can open.
public enum IslandTab: String, CaseIterable, Codable, Sendable {
    case home, tray, sound, notes, system

    public var title: String {
        switch self {
        case .home: "Home"
        case .tray: "Shelf & Clipboard"
        case .sound: "Sound"
        case .notes: "Notes"
        case .system: "System"
        }
    }
}

/// Something a knock can do. All Set's own features come first; the rest
/// come from TapTap.
public enum KnockAction: Hashable, Identifiable, Sendable {
    // All Set
    case toggleIsland
    case openIsland(IslandTab)
    case clipboardHistory
    case toggleWidgets
    case toggleWallpaper
    case applyWorkspace(id: UUID, name: String)
    case moveWindow(WindowAction)
    case openAllSet
    // Media
    case playPause, nextTrack, previousTrack
    // Sound
    case volumeUp, volumeDown, toggleMute
    // System
    case lockScreen, screenshot, aiScreenshot, missionControl, nextDesktop, previousDesktop, showDesktop
    // Editing
    case copy, paste, undo, closeWindow, nextTab, previousTab
    // Apps and automation
    case openApp(bundleID: String, name: String)
    case runShortcut(name: String)
    case shellCommand(String)
    // Fun
    case screenFlash, ripple
    case playSound(name: String)

    public enum Category: String, CaseIterable, Sendable {
        case allSet, media, sound, system, editing, apps, automation, fun

        public var title: String {
            switch self {
            case .allSet: "All Set"
            case .media: "Media"
            case .sound: "Sound"
            case .system: "System"
            case .editing: "Editing"
            case .apps: "Apps"
            case .automation: "Automation"
            case .fun: "Fun"
            }
        }

        public var symbol: String {
            switch self {
            case .allSet: "capsule.fill"
            case .media: "play.circle.fill"
            case .sound: "speaker.wave.2.fill"
            case .system: "macwindow"
            case .editing: "character.cursor.ibeam"
            case .apps: "app.fill"
            case .automation: "wand.and.stars"
            case .fun: "sparkles"
            }
        }
    }

    public var id: String { kind + (parameter.map { ":" + $0 } ?? "") }

    public var title: String {
        switch self {
        case .toggleIsland: "Open or Close the Island"
        case .openIsland(let tab): "Open the Island's \(tab.title)"
        case .clipboardHistory: "Clipboard History"
        case .toggleWidgets: "Show or Hide Widgets"
        case .toggleWallpaper: "Live Wallpaper On or Off"
        case .applyWorkspace(_, let name): "Switch to \(name)"
        case .moveWindow(let action): "Window: \(action.title)"
        case .openAllSet: "Open All Set"
        case .playPause: "Play/Pause"
        case .nextTrack: "Next Track"
        case .previousTrack: "Previous Track"
        case .volumeUp: "Volume Up"
        case .volumeDown: "Volume Down"
        case .toggleMute: "Mute or Unmute"
        case .lockScreen: "Lock Screen"
        case .screenshot: "Screenshot"
        case .aiScreenshot: "Screenshot with AI"
        case .missionControl: "Mission Control"
        case .nextDesktop: "Next Desktop"
        case .previousDesktop: "Previous Desktop"
        case .showDesktop: "Show Desktop"
        case .copy: "Copy"
        case .paste: "Paste"
        case .undo: "Undo"
        case .closeWindow: "Close Window or Tab"
        case .nextTab: "Next Tab"
        case .previousTab: "Previous Tab"
        case .openApp(_, let name): "Open \(name)"
        case .runShortcut(let name): "Run \u{201C}\(name)\u{201D}"
        case .shellCommand: "Shell Command"
        case .screenFlash: "Screen Flash"
        case .ripple: "Ripple"
        case .playSound(let name): "Play \u{201C}\(name)\u{201D}"
        }
    }

    public var symbol: String {
        switch self {
        case .toggleIsland: "capsule.fill"
        case .openIsland(let tab):
            switch tab {
            case .home: "house.fill"
            case .tray: "tray.full.fill"
            case .sound: "slider.vertical.3"
            case .notes: "note.text"
            case .system: "gauge.with.dots.needle.50percent"
            }
        case .clipboardHistory: "doc.on.clipboard.fill"
        case .toggleWidgets: "square.grid.2x2.fill"
        case .toggleWallpaper: "photo.artframe"
        case .applyWorkspace: "square.stack.3d.down.right.fill"
        case .moveWindow: "rectangle.split.2x1.fill"
        case .openAllSet: "gearshape.fill"
        case .playPause: "playpause.fill"
        case .nextTrack: "forward.end.fill"
        case .previousTrack: "backward.end.fill"
        case .volumeUp: "speaker.wave.3.fill"
        case .volumeDown: "speaker.wave.1.fill"
        case .toggleMute: "speaker.slash.fill"
        case .lockScreen: "lock.fill"
        case .screenshot: "camera.viewfinder"
        case .aiScreenshot: "sparkles.rectangle.stack"
        case .missionControl: "rectangle.3.group.fill"
        case .nextDesktop: "arrow.right.square.fill"
        case .previousDesktop: "arrow.left.square.fill"
        case .showDesktop: "menubar.dock.rectangle"
        case .copy: "doc.on.doc.fill"
        case .paste: "doc.on.clipboard"
        case .undo: "arrow.uturn.backward"
        case .closeWindow: "xmark.square.fill"
        case .nextTab: "arrow.right.to.line"
        case .previousTab: "arrow.left.to.line"
        case .openApp: "app.badge.fill"
        case .runShortcut: "square.2.layers.3d.fill"
        case .shellCommand: "terminal.fill"
        case .screenFlash: "bolt.fill"
        case .ripple: "circle.circle"
        case .playSound: "music.note"
        }
    }

    public var category: Category {
        switch self {
        case .toggleIsland, .openIsland, .clipboardHistory, .toggleWidgets, .toggleWallpaper,
             .applyWorkspace, .moveWindow, .openAllSet: .allSet
        case .playPause, .nextTrack, .previousTrack: .media
        case .volumeUp, .volumeDown, .toggleMute: .sound
        case .lockScreen, .screenshot, .aiScreenshot, .missionControl, .nextDesktop, .previousDesktop, .showDesktop: .system
        case .copy, .paste, .undo, .closeWindow, .nextTab, .previousTab: .editing
        case .openApp: .apps
        case .runShortcut, .shellCommand: .automation
        case .screenFlash, .ripple, .playSound: .fun
        }
    }

    /// Sends keystrokes or moves windows, which needs Accessibility permission.
    public var needsAccessibility: Bool {
        switch self {
        case .lockScreen, .nextDesktop, .previousDesktop, .showDesktop,
             .copy, .paste, .undo, .closeWindow, .nextTab, .previousTab, .moveWindow: true
        default: false
        }
    }

    /// Actions that need nothing chosen first, in menu order.
    public static let simple: [KnockAction] = [
        .toggleIsland, .clipboardHistory, .toggleWidgets, .toggleWallpaper, .openAllSet,
        .playPause, .nextTrack, .previousTrack,
        .volumeUp, .volumeDown, .toggleMute,
        .lockScreen, .screenshot, .aiScreenshot, .missionControl, .nextDesktop, .previousDesktop, .showDesktop,
        .copy, .paste, .undo, .closeWindow, .nextTab, .previousTab,
        .screenFlash, .ripple,
    ]

    /// Built-in sounds offered for Play Sound.
    public static let soundNames = ["Pop", "Tink", "Glass", "Ping", "Purr", "Submarine", "Funk", "Hero"]

    // MARK: Saving

    private var kind: String {
        switch self {
        case .toggleIsland: "toggleIsland"
        case .openIsland: "openIsland"
        case .clipboardHistory: "clipboardHistory"
        case .toggleWidgets: "toggleWidgets"
        case .toggleWallpaper: "toggleWallpaper"
        case .applyWorkspace: "applyWorkspace"
        case .moveWindow: "moveWindow"
        case .openAllSet: "openAllSet"
        case .playPause: "playPause"
        case .nextTrack: "nextTrack"
        case .previousTrack: "previousTrack"
        case .volumeUp: "volumeUp"
        case .volumeDown: "volumeDown"
        case .toggleMute: "toggleMute"
        case .lockScreen: "lockScreen"
        case .screenshot: "screenshot"
        case .aiScreenshot: "aiScreenshot"
        case .missionControl: "missionControl"
        case .nextDesktop: "nextDesktop"
        case .previousDesktop: "previousDesktop"
        case .showDesktop: "showDesktop"
        case .copy: "copy"
        case .paste: "paste"
        case .undo: "undo"
        case .closeWindow: "closeWindow"
        case .nextTab: "nextTab"
        case .previousTab: "previousTab"
        case .openApp: "openApp"
        case .runShortcut: "runShortcut"
        case .shellCommand: "shellCommand"
        case .screenFlash: "screenFlash"
        case .ripple: "ripple"
        case .playSound: "playSound"
        }
    }

    private var parameter: String? {
        switch self {
        case .openIsland(let tab): tab.rawValue
        case .applyWorkspace(let id, _): id.uuidString
        case .moveWindow(let action): action.rawValue
        case .openApp(let bundleID, _): bundleID
        case .runShortcut(let name), .playSound(let name): name
        case .shellCommand(let command): command
        default: nil
        }
    }

    /// For the parameters that also carry a name to show.
    private var label: String? {
        switch self {
        case .applyWorkspace(_, let name), .openApp(_, let name): name
        default: nil
        }
    }

    private init?(kind: String, parameter: String?, label: String?) {
        if let simple = Self.simple.first(where: { $0.kind == kind }) {
            self = simple
            return
        }
        guard let parameter else { return nil }
        switch kind {
        case "openIsland":
            guard let tab = IslandTab(rawValue: parameter) else { return nil }
            self = .openIsland(tab)
        case "applyWorkspace":
            guard let id = UUID(uuidString: parameter) else { return nil }
            self = .applyWorkspace(id: id, name: label ?? "Workspace")
        case "moveWindow":
            guard let action = WindowAction(rawValue: parameter) else { return nil }
            self = .moveWindow(action)
        case "openApp": self = .openApp(bundleID: parameter, name: label ?? parameter)
        case "runShortcut": self = .runShortcut(name: parameter)
        case "shellCommand": self = .shellCommand(parameter)
        case "playSound": self = .playSound(name: parameter)
        default: return nil
        }
    }
}

// Saved as {"kind": "openApp", "value": "com.apple.Music", "label": "Music"}.
extension KnockAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, value, label
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        guard let action = KnockAction(kind: kind,
                                       parameter: try container.decodeIfPresent(String.self, forKey: .value),
                                       label: try container.decodeIfPresent(String.self, forKey: .label)) else {
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown action \(kind)")
        }
        self = action
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(parameter, forKey: .value)
        try container.encodeIfPresent(label, forKey: .label)
    }
}
