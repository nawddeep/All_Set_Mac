import Foundation
import OSLog

/// A theme being tried on the desktop, written down before the desktop changes so
/// that quitting or a crash mid-trial can put the real desktop back.
public struct PendingPreview: Codable, Equatable, Sendable {
    public var setID: String
    public var before: DesktopSnapshot
    public var startedAt: Date
    /// The person kept the preview: if this record is still found later (its
    /// removal failed), it must not roll the desktop back.
    public var isKept: Bool

    public init(setID: String, before: DesktopSnapshot, startedAt: Date = .now, isKept: Bool = false) {
        self.setID = setID
        self.before = before
        self.startedAt = startedAt
        self.isKept = isKept
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        setID = try container.decode(String.self, forKey: .setID)
        before = try container.decode(DesktopSnapshot.self, forKey: .before)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        isKept = try container.decodeIfPresent(Bool.self, forKey: .isKept) ?? false
    }
}

/// How restoring the desktop from a preview record went.
public enum PreviewRestore: Equatable, Sendable {
    /// No record: nothing to do.
    case nothingPending
    /// The record was a kept preview: retired, nothing restored.
    case wasKept
    /// The desktop before the preview is back and saved; the record is retired.
    case restored(setID: String)
    /// The desktop before the preview is back on screen but couldn't be saved,
    /// so the record stays and the next launch tries again.
    case notSaved(setID: String)
}

/// The desktop from before the last whole-desktop change (a theme, a wallpaper,
/// turning a theme off), kept on disk so it can be brought back after the Undo
/// offer has gone, or after a relaunch.
public struct PreviousDesktop: Codable, Equatable, Sendable {
    /// What happened, in words: "Seven went on", "New wallpaper".
    public var change: String
    public var before: DesktopSnapshot
    public var date: Date

    public init(change: String, before: DesktopSnapshot, date: Date = .now) {
        self.change = change
        self.before = before
        self.date = date
    }
}

/// Durable records of desktop changes. Writes are atomic and read back before
/// they count, so nothing destructive starts on a record that didn't stick.
@MainActor
public final class DesktopJournal {
    private let previewURL: URL
    private let previousURL: URL
    private let log = Logger(subsystem: "com.pratik.allset", category: "desktop")

    public nonisolated static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AllSet", isDirectory: true)
    }

    public init(directory: URL = DesktopJournal.defaultDirectory) {
        previewURL = directory.appendingPathComponent("desktop-preview.json")
        previousURL = directory.appendingPathComponent("previous-desktop.json")
    }

    // MARK: Preview

    /// Records a preview about to start. False if it couldn't be written and read
    /// back: the caller must not change the desktop then.
    @discardableResult
    public func beginPreview(_ preview: PendingPreview) -> Bool {
        write(preview, to: previewURL)
    }

    /// Removes the preview record. True once it's gone.
    @discardableResult
    public func endPreview() -> Bool {
        try? FileManager.default.removeItem(at: previewURL)
        return !FileManager.default.fileExists(atPath: previewURL.path)
    }

    /// Puts back the desktop from before the preview (Go Back, or a preview the
    /// app quit or crashed in), saves it, and only then retires the record. A
    /// kept preview's leftover record is retired without restoring anything.
    public func restorePreview(settings: AppSettings, widgets: WidgetStore, wallpaper: WallpaperStore) -> PreviewRestore {
        guard let pending = pendingPreview else { return .nothingPending }
        if pending.isKept {
            endPreview()
            return .wasKept
        }
        pending.before.restore(settings: settings, widgets: widgets, wallpaper: wallpaper)
        let saved = widgets.saveNow() && wallpaper.saveNow()
        guard saved, endPreview() else {
            return .notSaved(setID: pending.setID)
        }
        return .restored(setID: pending.setID)
    }

    /// The person kept the preview: the record is marked kept first, then removed,
    /// so a record that survives can't roll the desktop back. False if neither
    /// could be done (then a later launch would undo the preview).
    @discardableResult
    public func keepPreview() -> Bool {
        guard var pending = pendingPreview else { return true }
        pending.isKept = true
        let marked = write(pending, to: previewURL)
        return endPreview() || marked
    }

    /// A preview that never ended: the app quit or crashed during it.
    public var pendingPreview: PendingPreview? {
        StoreFile.load(PendingPreview.self, from: previewURL)
    }

    // MARK: Previous desktop

    @discardableResult
    public func remember(_ previous: PreviousDesktop) -> Bool {
        write(previous, to: previousURL)
    }

    public var previous: PreviousDesktop? {
        StoreFile.load(PreviousDesktop.self, from: previousURL)
    }

    // MARK: Writing

    private func write<Value: Codable & Equatable>(_ value: Value, to url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Default date coding, matching `StoreFile.load`, which reads these back.
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
            guard try JSONDecoder().decode(Value.self, from: Data(contentsOf: url)) == value else {
                log.error("\(url.lastPathComponent, privacy: .public) didn't read back the same")
                return false
            }
            return true
        } catch {
            log.error("Couldn't write \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
