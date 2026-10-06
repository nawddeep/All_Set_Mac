import CoreGraphics
import Foundation
import Observation
import OSLog

/// Modifier keys for a shortcut, independent of AppKit and Carbon.
public struct KeyModifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let control = KeyModifiers(rawValue: 1 << 0)
    public static let option = KeyModifiers(rawValue: 1 << 1)
    public static let shift = KeyModifiers(rawValue: 1 << 2)
    public static let command = KeyModifiers(rawValue: 1 << 3)

    /// ⌃⌥⇧⌘, in the order macOS shows them.
    public var symbols: String {
        (contains(.control) ? "⌃" : "") + (contains(.option) ? "⌥" : "")
            + (contains(.shift) ? "⇧" : "") + (contains(.command) ? "⌘" : "")
    }
}

/// A global keyboard shortcut.
public struct Shortcut: Codable, Hashable, Sendable {
    /// A hardware key code (kVK_… in Carbon).
    public var keyCode: UInt32
    public var modifiers: KeyModifiers
    /// The key as shown to people, e.g. "←" or "U".
    public var key: String

    public init(keyCode: UInt32, modifiers: KeyModifiers, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    public var display: String { modifiers.symbols + key }

    /// Rectangle's widely known defaults, so muscle memory carries over.
    public static let defaults: [WindowAction: Shortcut] = {
        let hyper: KeyModifiers = [.control, .option]
        let displays: KeyModifiers = [.control, .option, .command]
        return [
            .leftHalf: Shortcut(keyCode: 0x7B, modifiers: hyper, key: "←"),
            .rightHalf: Shortcut(keyCode: 0x7C, modifiers: hyper, key: "→"),
            .bottomHalf: Shortcut(keyCode: 0x7D, modifiers: hyper, key: "↓"),
            .topHalf: Shortcut(keyCode: 0x7E, modifiers: hyper, key: "↑"),
            .topLeft: Shortcut(keyCode: 0x20, modifiers: hyper, key: "U"),
            .topRight: Shortcut(keyCode: 0x22, modifiers: hyper, key: "I"),
            .bottomLeft: Shortcut(keyCode: 0x26, modifiers: hyper, key: "J"),
            .bottomRight: Shortcut(keyCode: 0x28, modifiers: hyper, key: "K"),
            .firstThird: Shortcut(keyCode: 0x02, modifiers: hyper, key: "D"),
            .centerThird: Shortcut(keyCode: 0x03, modifiers: hyper, key: "F"),
            .lastThird: Shortcut(keyCode: 0x05, modifiers: hyper, key: "G"),
            .firstTwoThirds: Shortcut(keyCode: 0x0E, modifiers: hyper, key: "E"),
            .lastTwoThirds: Shortcut(keyCode: 0x11, modifiers: hyper, key: "T"),
            .maximize: Shortcut(keyCode: 0x24, modifiers: hyper, key: "↩"),
            .almostMaximize: Shortcut(keyCode: 0x24, modifiers: [.control, .option, .shift], key: "↩"),
            .center: Shortcut(keyCode: 0x08, modifiers: hyper, key: "C"),
            .restore: Shortcut(keyCode: 0x33, modifiers: hyper, key: "⌫"),
            .nextDisplay: Shortcut(keyCode: 0x7C, modifiers: displays, key: "→"),
            .previousDisplay: Shortcut(keyCode: 0x7B, modifiers: displays, key: "←"),
        ]
    }()
}

/// Where one window of a workspace goes, relative to its screen's usable area
/// (0...1 on each axis), so the layout survives a change of resolution.
public struct WindowPlacement: Codable, Hashable, Sendable {
    /// Used to match the right window when an app has several.
    public var title: String?
    /// The display's stable id (see `DisplayIdentity`); the name is the fallback.
    public var screenID: String?
    public var screenName: String?
    public var frame: CGRect

    public init(title: String?, screenID: String? = nil, screenName: String?, frame: CGRect) {
        self.title = title
        self.screenID = screenID
        self.screenName = screenName
        self.frame = frame
    }
}

public struct WorkspaceApp: Codable, Hashable, Identifiable, Sendable {
    public var bundleID: String
    public var name: String
    public var windows: [WindowPlacement]

    public var id: String { bundleID }

    public init(bundleID: String, name: String, windows: [WindowPlacement]) {
        self.bundleID = bundleID
        self.name = name
        self.windows = windows
    }
}

/// A saved arrangement of apps and windows, brought back with one click or shortcut.
public struct Workspace: Codable, Hashable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var symbol: String
    public var apps: [WorkspaceApp]
    /// Hide every other app when switching to this workspace.
    public var hideOthers = true
    public var shortcut: Shortcut?

    public init(name: String, symbol: String = "square.grid.2x2", apps: [WorkspaceApp]) {
        self.name = name
        self.symbol = symbol
        self.apps = apps
    }

    public static let symbols = [
        "briefcase.fill", "hammer.fill", "paintbrush.pointed.fill", "book.fill", "gamecontroller.fill",
        "music.note", "film.fill", "graduationcap.fill", "bubble.left.and.bubble.right.fill", "chart.bar.fill",
        "cup.and.saucer.fill", "moon.stars.fill",
    ]
}

public struct WorkspaceSettings: Codable, Equatable, Sendable {
    /// Keyboard shortcuts for window actions.
    public var shortcutsEnabled = true
    /// Snap windows dropped at a screen edge or corner.
    public var dragToSnap = true
    /// Space between snapped windows and around the screen edge, in points.
    public var gap: Double = 0
    /// Overrides of the default shortcuts; a nil value turns one off.
    public var shortcuts: [WindowAction: Shortcut?] = [:]

    public init() {}

    public func shortcut(for action: WindowAction) -> Shortcut? {
        if let custom = shortcuts[action] { return custom }
        return Shortcut.defaults[action]
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shortcutsEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .shortcutsEnabled)) ?? true
        dragToSnap = (try? container.decodeIfPresent(Bool.self, forKey: .dragToSnap)) ?? true
        gap = (try? container.decodeIfPresent(Double.self, forKey: .gap)) ?? 0
        shortcuts = (try? container.decodeIfPresent([WindowAction: Shortcut?].self, forKey: .shortcuts)) ?? [:]
    }
}

/// Window management settings and saved workspaces, as JSON in Application Support.
@Observable @MainActor
public final class WorkspaceStore {
    public var settings: WorkspaceSettings { didSet { if settings != oldValue { save() } } }
    public var workspaces: [Workspace] { didSet { if workspaces != oldValue { save() } } }

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "workspaces")

    private struct Saved: Codable {
        var settings: WorkspaceSettings
        var workspaces: [Workspace]
    }

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AllSet/workspaces.json")
        let saved = StoreFile.load(Saved.self, from: self.fileURL)
        settings = saved?.settings ?? WorkspaceSettings()
        workspaces = saved?.workspaces ?? []
    }

    public func update(_ id: UUID, _ change: (inout Workspace) -> Void) {
        guard let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        change(&workspaces[index])
    }

    /// Why the last save failed; nil once one works. Shown in the main window.
    public private(set) var saveError: String?

    /// Writes now. True when the workspaces are on disk; on failure `saveError` says why.
    @discardableResult
    public func saveNow() -> Bool { save() }

    @discardableResult
    private func save() -> Bool {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(Saved(settings: settings, workspaces: workspaces)).write(to: fileURL, options: .atomic)
            if saveError != nil { saveError = nil }
            return true
        } catch {
            log.error("Couldn't save workspaces: \(error.localizedDescription, privacy: .public)")
            saveError = error.localizedDescription
            return false
        }
    }
}
