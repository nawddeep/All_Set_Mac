import Foundation
import Observation

/// The parts of All Set beyond its four pillars (the Dynamic Island, desktop
/// widgets, themes and wallpaper). Each can be switched off as a whole: off,
/// it starts nothing, keeps no timer, holds no shortcut and asks for no
/// permission, and its page leaves the navigation.
public enum Extra: String, CaseIterable, Codable, Identifiable, Sendable {
    case snapping, workspaces, clipboard, shelf, mixer, knocks, screenshot, monitor

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .snapping: "Window Snapping"
        case .workspaces: "Workspaces"
        case .clipboard: "Clipboard History"
        case .shelf: "Shelf"
        case .mixer: "Sound Mixer"
        case .knocks: "TapTap"
        case .screenshot: "AI Screenshot"
        case .monitor: "System Monitor"
        }
    }

    public var summary: String {
        switch self {
        case .snapping: "Keyboard shortcuts and drag-to-edge layouts for windows. Needs Accessibility."
        case .workspaces: "Save the windows of a task and bring them all back with one shortcut. Needs Accessibility."
        case .clipboard: "A searchable history of what you copy, kept on this Mac."
        case .shelf: "A place in the island to park files while you work."
        case .mixer: "A volume slider for each app. Needs Audio Recording permission."
        case .knocks: "Knock on your Mac to run an action. Reads the motion sensor while on."
        case .screenshot: "Capture part of the screen and ask an AI about it with your own API key."
        case .monitor: "A page of live CPU, memory, disk, network and battery readings."
        }
    }

    public var symbol: String {
        switch self {
        case .snapping: "rectangle.split.2x1.fill"
        case .workspaces: "square.stack.3d.down.right.fill"
        case .clipboard: "doc.on.clipboard.fill"
        case .shelf: "tray.full.fill"
        case .mixer: "slider.vertical.3"
        case .knocks: "hand.tap.fill"
        case .screenshot: "camera.viewfinder"
        case .monitor: "gauge.with.dots.needle.50percent"
        }
    }
}

/// Which extras are on, saved in UserDefaults. A new install starts with
/// every extra off; an install from before extras existed (2026-10-17) keeps
/// everything on, as it was.
@Observable @MainActor
public final class ExtrasSettings {
    public private(set) var enabled: Set<Extra>
    /// The install predates extras: anything that used to default to on keeps doing so.
    public let isLegacyInstall: Bool

    @ObservationIgnored private let defaults: UserDefaults
    static let enabledKey = "extras.enabled"
    static let legacyKey = "extras.legacyInstall"

    /// `existingData`: whether the app's data folder already held anything
    /// when this ran, i.e. All Set had been used before. Only read the first time.
    public init(defaults: UserDefaults = .standard, existingData: @autoclosure () -> Bool = ExtrasSettings.hasExistingData()) {
        self.defaults = defaults
        if let saved = defaults.stringArray(forKey: Self.enabledKey) {
            enabled = Set(saved.compactMap(Extra.init(rawValue:)))
            isLegacyInstall = defaults.bool(forKey: Self.legacyKey)
        } else {
            let legacy = existingData()
            isLegacyInstall = legacy
            enabled = legacy ? Set(Extra.allCases) : []
            defaults.set(legacy, forKey: Self.legacyKey)
            defaults.set(enabled.map(\.rawValue).sorted(), forKey: Self.enabledKey)
        }
    }

    public func isOn(_ extra: Extra) -> Bool { enabled.contains(extra) }

    public func set(_ extra: Extra, on: Bool) {
        guard on != isOn(extra) else { return }
        if on { enabled.insert(extra) } else { enabled.remove(extra) }
        defaults.set(enabled.map(\.rawValue).sorted(), forKey: Self.enabledKey)
    }

    /// Anything in All Set's data folder (`~/Library/Application Support/AllSet`):
    /// widgets, notes, settings files written by an earlier version.
    public nonisolated static func hasExistingData(in folder: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AllSet", isDirectory: true)) -> Bool {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return contents.contains { !$0.hasPrefix(".") }
    }
}
