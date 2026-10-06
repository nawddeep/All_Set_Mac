import Foundation
import CryptoKit
import Testing
@testable import AllSetCore

/// A person's All Set data can be exported, checked, and restored, and the
/// restore is exercised here end to end before anyone is told it's a backup.
@Suite struct DataArchiveTests {
    /// A data folder shaped like the real one.
    private func dataFolder() throws -> (root: URL, scratch: URL) {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetArchive-\(UUID().uuidString)")
        let root = scratch.appendingPathComponent("AllSet")
        let files = [
            "widgets.json": "widgets", "notes.json": "notes", "Images/one.jpg": "picture",
            "Wallpaper/wallpaper.json": "wallpaper settings", "Wallpaper/Videos/mine.mp4": "my video",
            "Wallpaper/Library/catalog.json": "library", "Wallpaper/Library/live/a.mp4": "rendered",
            "Clipboard/history.json": "something copied", "Clipboard/Images/c.png": "copied picture",
        ]
        for (path, content) in files { try write(content, to: root.appendingPathComponent(path)) }
        return (root, scratch)
    }

    private func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
    }

    private func read(_ url: URL) -> String? {
        (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) }
    }

    private let settings: [String: Any] = ["widgetScale": 1.25, "showWidgets": true, "screenshot.systemShortcutOffByAllSet": true]

    @Test func anExportHoldsTheDataItsChecksumsAndTheSettings() throws {
        let (root, scratch) = try dataFolder()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let archive = scratch.appendingPathComponent("backup")
        let manifest = try DataArchive.export(from: root, settings: settings, to: archive, appVersion: "1.2")

        // Clipboard history and the rendered library stay out unless asked for.
        #expect(manifest.files.map(\.path) == ["Images/one.jpg", "Wallpaper/Videos/mine.mp4", "Wallpaper/wallpaper.json",
                                               "notes.json", "widgets.json"])
        #expect(manifest.format == DataArchive.format && manifest.appVersion == "1.2")
        #expect(read(archive.appendingPathComponent("data/notes.json")) == "notes")
        #expect(try DataArchive.verify(archive) == manifest)

        let saved = try #require(try PropertyListSerialization.propertyList(
            from: Data(contentsOf: archive.appendingPathComponent("settings.plist")), format: nil) as? [String: Any])
        #expect(saved["widgetScale"] as? Double == 1.25)
        // This Mac's state right now isn't a setting to carry elsewhere.
        #expect(saved["screenshot.systemShortcutOffByAllSet"] == nil)

        // The data folder itself is untouched, and a second export can't land on the first.
        #expect(read(root.appendingPathComponent("Clipboard/history.json")) == "something copied")
        #expect(throws: DataArchive.Failure.destinationExists) {
            try DataArchive.export(from: root, settings: [:], to: archive, appVersion: "1.2")
        }
    }

    @Test func clipboardAndTheLibraryAreIncludedOnlyWhenAsked() throws {
        let (root, scratch) = try dataFolder()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let manifest = try DataArchive.export(from: root, settings: [:], to: scratch.appendingPathComponent("full"),
                                              options: .init(includesClipboard: true, includesWallpaperLibrary: true), appVersion: "1")
        #expect(manifest.files.count == 9)
        #expect(manifest.includesClipboard && manifest.includesWallpaperLibrary)
    }

    @Test func aDamagedOrForeignArchiveIsRefused() throws {
        let (root, scratch) = try dataFolder()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let archive = scratch.appendingPathComponent("backup")
        try DataArchive.export(from: root, settings: [:], to: archive, appVersion: "1")

        try write("tampered", to: archive.appendingPathComponent("data/notes.json"))
        try FileManager.default.removeItem(at: archive.appendingPathComponent("data/widgets.json"))
        #expect(throws: DataArchive.Failure.damaged(["notes.json has changed", "widgets.json is missing"])) {
            try DataArchive.verify(archive)
        }
        // Refused before anything is staged.
        #expect(throws: DataArchive.Failure.self) { try DataArchive.stage(archive, in: root) }
        #expect(!DataArchive.hasStagedRestore(in: root))

        #expect(throws: DataArchive.Failure.notAnArchive("it has no manifest")) { try DataArchive.verify(scratch) }

        // A manifest naming a path outside the archive is never followed.
        let hostile = scratch.appendingPathComponent("hostile")
        try write(#"{"format":1,"created":"2026-10-06T00:00:00Z","appVersion":"1","includesClipboard":false,"#
                  + #""includesWallpaperLibrary":false,"files":[{"path":"../../outside.txt","size":1,"sha256":"00"}]}"#,
                  to: hostile.appendingPathComponent("manifest.json"))
        #expect(throws: DataArchive.Failure.self) { try DataArchive.verify(hostile) }

        let newer = scratch.appendingPathComponent("newer")
        try write(#"{"format":99,"created":"2026-10-06T00:00:00Z","appVersion":"9","includesClipboard":false,"#
                  + #""includesWallpaperLibrary":false,"files":[]}"#, to: newer.appendingPathComponent("manifest.json"))
        #expect(throws: DataArchive.Failure.newerFormat(99)) { try DataArchive.verify(newer) }
    }

    @Test func aRestoreReplacesWhatTheArchiveCarriesAndKeepsWhatWasThere() throws {
        let (root, scratch) = try dataFolder()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let archive = scratch.appendingPathComponent("backup")
        try DataArchive.export(from: root, settings: settings, to: archive, appVersion: "1")

        // Time passes: things change, and something new appears.
        try write("newer notes", to: root.appendingPathComponent("notes.json"))
        try write("another picture", to: root.appendingPathComponent("Images/two.jpg"))
        try write("copied later", to: root.appendingPathComponent("Clipboard/history.json"))
        try write("library, grown", to: root.appendingPathComponent("Wallpaper/Library/catalog.json"))

        #expect(try DataArchive.applyStaged(in: root) == nil)   // nothing staged: nothing happens
        try DataArchive.stage(archive, in: root)
        #expect(DataArchive.hasStagedRestore(in: root))
        #expect(read(root.appendingPathComponent("notes.json")) == "newer notes")   // staging changes nothing yet

        let applied = try #require(try DataArchive.applyStaged(in: root))
        #expect(read(root.appendingPathComponent("notes.json")) == "notes")
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Images/two.jpg").path))
        #expect(applied.settings?["widgetScale"] as? Double == 1.25)
        // What the archive didn't carry is as it was.
        #expect(read(root.appendingPathComponent("Clipboard/history.json")) == "copied later")
        #expect(read(root.appendingPathComponent("Wallpaper/Library/catalog.json")) == "library, grown")
        #expect(read(root.appendingPathComponent("Wallpaper/Videos/mine.mp4")) == "my video")
        // What was replaced is kept, not deleted.
        #expect(read(applied.previous.appendingPathComponent("notes.json")) == "newer notes")
        #expect(read(applied.previous.appendingPathComponent("Images/two.jpg")) == "another picture")
        #expect(DataArchive.previousData(in: root).map(\.lastPathComponent) == [applied.previous.lastPathComponent])
        // Done once: it isn't waiting any more, and a later export doesn't sweep the kept copy in.
        #expect(!DataArchive.hasStagedRestore(in: root))
        #expect(try DataArchive.applyStaged(in: root) == nil)
        #expect(DataArchive.exportedPaths(in: root, options: .init()).allSatisfy { !$0.hasPrefix(".") })
    }

    @Test func aStagedRestoreThatWentBadChangesNothing() throws {
        let (root, scratch) = try dataFolder()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let archive = scratch.appendingPathComponent("backup")
        try DataArchive.export(from: root, settings: [:], to: archive, appVersion: "1")
        try DataArchive.stage(archive, in: root)
        try write("newer notes", to: root.appendingPathComponent("notes.json"))
        // The staged copy is damaged before the next launch.
        try write("bit rot", to: root.appendingPathComponent(".pending-restore/data/widgets.json"))

        #expect(throws: DataArchive.Failure.damaged(["widgets.json has changed"])) { try DataArchive.applyStaged(in: root) }
        #expect(read(root.appendingPathComponent("notes.json")) == "newer notes")
        #expect(read(root.appendingPathComponent("widgets.json")) == "widgets")
        #expect(!DataArchive.hasStagedRestore(in: root))
        #expect(DataArchive.previousData(in: root).isEmpty)
    }

    /// The real stores, not stand-in files: what they saved is what they read
    /// back after a restore.
    @Test @MainActor func notesAndWidgetsComeBackThroughTheirOwnStores() throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetArchive-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let root = scratch.appendingPathComponent("AllSet")
        let notes = NotesStore(fileURL: root.appendingPathComponent("notes.json"))
        notes.add("call the dentist\nbuy milk")
        notes.save()
        let widgets = WidgetStore(fileURL: root.appendingPathComponent("widgets.json"))
        widgets.add(WidgetInstance(kind: .clock))
        widgets.add(WidgetInstance(kind: .weather))
        widgets.saveNow()
        let archive = scratch.appendingPathComponent("backup")
        try DataArchive.export(from: root, settings: [:], to: archive, appVersion: "1")

        notes.remove(notes.notes[0].id)
        notes.remove(notes.notes[0].id)
        notes.save()
        widgets.remove(widgets.widgets[0].id)
        widgets.saveNow()
        #expect(NotesStore(fileURL: root.appendingPathComponent("notes.json")).notes.isEmpty)

        try DataArchive.stage(archive, in: root)
        _ = try DataArchive.applyStaged(in: root)
        #expect(NotesStore(fileURL: root.appendingPathComponent("notes.json")).notes.map(\.text) == ["call the dentist", "buy milk"])
        #expect(WidgetStore(fileURL: root.appendingPathComponent("widgets.json")).widgets.map(\.kind) == [.clock, .weather])
    }
    @Test func changedSettingsAndUnlistedFilesAreRefusedBeforeRestore() throws {
        let (root, scratch) = try dataFolder()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let archive = scratch.appendingPathComponent("backup")
        try DataArchive.export(from: root, settings: settings, to: archive, appVersion: "1")
        let settingsURL = archive.appendingPathComponent("settings.plist")
        let original = try Data(contentsOf: settingsURL)
        try PropertyListSerialization.data(fromPropertyList: ["widgetScale": 9.0], format: .binary, options: 0)
            .write(to: settingsURL)
        #expect(throws: DataArchive.Failure.self) { try DataArchive.stage(archive, in: root) }
        try Data("broken plist".utf8).write(to: settingsURL)
        #expect(throws: DataArchive.Failure.self) { try DataArchive.verify(archive) }
        try original.write(to: settingsURL)
        try write("unverified", to: archive.appendingPathComponent("data/Images/unlisted.jpg"))
        #expect(throws: DataArchive.Failure.self) { try DataArchive.stage(archive, in: root) }
        #expect(!DataArchive.hasStagedRestore(in: root))
        #expect(read(root.appendingPathComponent("Images/one.jpg")) == "picture")
    }

    @Test func aSymlinkedDataFolderIsRefused() throws {
        let (root, scratch) = try dataFolder()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let archive = scratch.appendingPathComponent("backup")
        try DataArchive.export(from: root, settings: settings, to: archive, appVersion: "1")
        let data = archive.appendingPathComponent("data")
        let outside = scratch.appendingPathComponent("outside")
        try FileManager.default.moveItem(at: data, to: outside)
        try FileManager.default.createSymbolicLink(at: data, withDestinationURL: outside)
        #expect(throws: DataArchive.Failure.self) { try DataArchive.stage(archive, in: root) }
        #expect(read(outside.appendingPathComponent("Images/one.jpg")) == "picture")
    }

    @Test func invalidSettingsStructureAndNoncanonicalPathsAreRefused() throws {
        let (root, scratch) = try dataFolder()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let archive = scratch.appendingPathComponent("backup")
        try DataArchive.export(from: root, settings: settings, to: archive, appVersion: "1")
        let manifestURL = archive.appendingPathComponent("manifest.json")
        var manifest = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any])
        let broken = Data("not a property list".utf8)
        try broken.write(to: archive.appendingPathComponent("settings.plist"))
        manifest["settingsFile"] = ["path": "settings.plist", "size": broken.count,
                                    "sha256": SHA256.hash(data: broken).map { String(format: "%02x", $0) }.joined()]
        try JSONSerialization.data(withJSONObject: manifest).write(to: manifestURL)
        #expect(throws: DataArchive.Failure.self) { try DataArchive.verify(archive) }

        let clean = scratch.appendingPathComponent("clean")
        try DataArchive.export(from: root, settings: settings, to: clean, appVersion: "1")
        let cleanManifest = clean.appendingPathComponent("manifest.json")
        var changed = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: cleanManifest)) as? [String: Any])
        var files = try #require(changed["files"] as? [[String: Any]])
        files[0]["path"] = "./Images/one.jpg"
        changed["files"] = files
        try JSONSerialization.data(withJSONObject: changed).write(to: cleanManifest)
        #expect(throws: DataArchive.Failure.self) { try DataArchive.stage(clean, in: root) }
        #expect(!DataArchive.hasStagedRestore(in: root))
    }

    private final class FailingMoves: FileManager, @unchecked Sendable {
        let failRollback: Bool
        init(failRollback: Bool) { self.failRollback = failRollback; super.init() }
        override func moveItem(at source: URL, to destination: URL) throws {
            if source.path.contains(".pending-restore/data/Wallpaper")
                || (failRollback && source.path.contains(".before-restore-") && destination.lastPathComponent == "Images") {
                throw NSError(domain: "InjectedRestoreFailure", code: 1)
            }
            try super.moveItem(at: source, to: destination)
        }
    }

    @Test func aFailedRollbackKeepsOriginalsAndReportsPartialRestoration() throws {
        let (root, scratch) = try dataFolder()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let archive = scratch.appendingPathComponent("backup")
        try DataArchive.export(from: root, settings: settings, to: archive, appVersion: "1")
        try write("newer picture", to: root.appendingPathComponent("Images/one.jpg"))
        try DataArchive.stage(archive, in: root)
        do {
            _ = try DataArchive.applyStaged(in: root, now: .now, manager: FailingMoves(failRollback: true))
            Issue.record("Expected the swap and rollback to fail")
        } catch {
            #expect(String(describing: error).contains("partially restored"))
            #expect(!String(describing: error).contains("nothing was changed"))
        }
        let previous = try #require(DataArchive.previousData(in: root).first)
        #expect(read(previous.appendingPathComponent("Images/one.jpg")) == "newer picture")
        #expect(read(root.appendingPathComponent("notes.json")) == "notes")
        // Further successful restores must not prune the unresolved originals.
        for _ in 0..<3 {
            try DataArchive.stage(archive, in: root)
            _ = try DataArchive.applyStaged(in: root)
        }
        #expect(read(previous.appendingPathComponent("Images/one.jpg")) == "newer picture")
    }

    @Test func aFailedSwapWithSuccessfulRollbackRestoresTheOriginals() throws {
        let (root, scratch) = try dataFolder()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let archive = scratch.appendingPathComponent("backup")
        try DataArchive.export(from: root, settings: settings, to: archive, appVersion: "1")
        try write("newer picture", to: root.appendingPathComponent("Images/one.jpg"))
        try DataArchive.stage(archive, in: root)
        #expect(throws: DataArchive.Failure.self) {
            try DataArchive.applyStaged(in: root, now: .now, manager: FailingMoves(failRollback: false))
        }
        #expect(read(root.appendingPathComponent("Images/one.jpg")) == "newer picture")
        #expect(DataArchive.previousData(in: root).isEmpty)
    }

}
