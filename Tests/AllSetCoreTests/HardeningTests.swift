import Foundation
import Testing
@testable import AllSetCore

@Suite struct StoreFileTests {
    private func temporaryFile(_ contents: String?) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("storefile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("notes.json")
        if let contents { try Data(contents.utf8).write(to: file) }
        return file
    }

    @Test func missingFilesAreQuietlyEmpty() throws {
        let file = try temporaryFile(nil)
        #expect(StoreFile.load([QuickNote].self, from: file) == nil)
        let siblings = try FileManager.default.contentsOfDirectory(atPath: file.deletingLastPathComponent().path)
        #expect(siblings.isEmpty)
    }

    @Test func unreadableFilesAreKeptAside() throws {
        let file = try temporaryFile("{ this is not json")
        #expect(StoreFile.load([QuickNote].self, from: file) == nil)
        let siblings = try FileManager.default.contentsOfDirectory(atPath: file.deletingLastPathComponent().path)
        #expect(siblings.contains { $0.hasPrefix("notes.unreadable-") && $0.hasSuffix(".json") })
    }

    /// Review D6: a failed notes save was only logged; it's now reported.
    @Test @MainActor func notesSavesReportFailures() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("notes-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("notes.json")
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        let store = NotesStore(fileURL: file)
        store.add("buy milk")
        #expect(!store.save())
        #expect(store.saveError != nil)
        try FileManager.default.removeItem(at: file)
        #expect(store.save())
        #expect(store.saveError == nil)
    }

    /// Review U4: removing notes (one, Clear Done, or editing one to nothing)
    /// could not be taken back; the last removal can now be undone in place.
    @Test @MainActor func removedNotesComeBackWhereTheyWere() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("notes-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = NotesStore(fileURL: folder.appendingPathComponent("notes.json"))
        store.add("a\nb\nc\nd\ne")
        let original = store.notes
        store.toggle(original[1].id)
        store.toggle(original[3].id)
        let ticked = store.notes

        #expect(store.doneCount == 2)
        store.removeDone()
        #expect(store.notes.count == 3 && store.lastRemoval?.count == 2)
        store.undoRemoval()
        #expect(store.notes == ticked)
        #expect(store.lastRemoval == nil)

        store.remove(original[0].id)
        store.undoRemoval()
        #expect(store.notes == ticked)

        store.update(original[4].id, text: "   ")
        #expect(store.notes.count == 4)
        store.undoRemoval()
        #expect(store.notes == ticked)

        store.remove(original[2].id)
        store.forgetRemoval()
        store.undoRemoval()
        #expect(store.notes.count == 4)
    }

    @Test @MainActor func aCorruptNotesFileSurvivesTheNextSave() throws {
        let file = try temporaryFile(#"[{"text": 42}]"#)
        let store = NotesStore(fileURL: file)
        #expect(store.notes.isEmpty)
        store.add("new note")
        store.save()
        let siblings = try FileManager.default.contentsOfDirectory(atPath: file.deletingLastPathComponent().path)
        let kept = try #require(siblings.first { $0.contains("unreadable") })
        let original = try String(contentsOf: file.deletingLastPathComponent().appendingPathComponent(kept), encoding: .utf8)
        #expect(original == #"[{"text": 42}]"#)
    }

    /// Review D6: the clipboard, shelf, workspace and wallpaper stores only logged
    /// a failed save; each now reports it until a save works.
    @Test @MainActor func everyStoreReportsFailedSaves() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("stores-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        // A folder where each file should be: no write can succeed.
        func block(_ path: String) throws -> URL {
            let file = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
            return file
        }
        func unblock(_ file: URL) throws { try FileManager.default.removeItem(at: file) }

        let workspacesFile = try block("workspaces.json")
        let workspaces = WorkspaceStore(fileURL: workspacesFile)
        workspaces.workspaces = [Workspace(name: "Write", apps: [])]
        #expect(workspaces.saveError != nil)
        try unblock(workspacesFile)
        #expect(workspaces.saveNow())
        #expect(workspaces.saveError == nil)

        let shelfFile = try block("Shelf/shelf.json")
        let shelf = ShelfStore(directory: root.appendingPathComponent("Shelf"))
        shelf.add([root])
        #expect(shelf.saveError != nil)
        try unblock(shelfFile)
        #expect(shelf.saveNow())
        #expect(shelf.saveError == nil)

        let wallpaperFile = try block("Wallpaper/wallpaper.json")
        let wallpaper = WallpaperStore(directory: root.appendingPathComponent("Wallpaper"))
        wallpaper.config.isEnabled.toggle()
        #expect(wallpaper.saveError != nil)
        try unblock(wallpaperFile)
        #expect(wallpaper.saveNow())
        #expect(wallpaper.saveError == nil)

        let clipboardFile = try block("Clipboard/history.json")
        let clipboard = ClipboardStore(directory: root.appendingPathComponent("Clipboard"))
        #expect(!clipboard.save())
        #expect(clipboard.saveError != nil)
        try unblock(clipboardFile)
        #expect(clipboard.save())
        #expect(clipboard.saveError == nil)
    }

    @Test @MainActor func widgetSavesReportFailures() throws {
        // A folder where the file should be: the write can't succeed.
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("widgets-\(UUID().uuidString)", isDirectory: true)
        let file = folder.appendingPathComponent("widgets.json")
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        let store = WidgetStore(fileURL: file)
        store.add(WidgetInstance(kind: .clock))
        store.saveNow()
        #expect(store.saveError != nil)
    }

    /// Review D5: a widget this version can't read (a kind from a newer version)
    /// used to be skipped on load and then erased by the next save.
    @Test @MainActor func widgetsThisVersionCantReadSurviveSaves() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("widgets-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("widgets.json")
        let known = try JSONSerialization.jsonObject(with: JSONEncoder().encode(WidgetInstance(kind: .clock)))
        let future: [String: Any] = ["id": UUID().uuidString, "kind": "hologram", "futureField": [1, 2, 3]]
        try JSONSerialization.data(withJSONObject: [known, future]).write(to: file)

        let store = WidgetStore(fileURL: file)
        #expect(store.widgets.map(\.kind) == [.clock])
        #expect(store.unreadableCount == 1)
        // The file as it was is copied aside too.
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).contains { $0.contains("unreadable") })

        store.add(WidgetInstance(kind: .calendar))
        #expect(store.saveNow())
        let saved = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [[String: Any]])
        #expect(saved.count == 3)
        let kept = try #require(saved.first { $0["kind"] as? String == "hologram" })
        #expect(kept["futureField"] as? [Int] == [1, 2, 3])
        #expect(kept["id"] as? String == future["id"] as? String)
        // And a later launch still reads the two it knows.
        #expect(WidgetStore(fileURL: file).widgets.map(\.kind) == [.clock, .calendar])
    }
}

@Suite struct PhotoURLTests {
    @Test func oddIdsNeverCrash() {
        let photo = WebPhoto(id: "a b/c?d#e", author: "Someone", width: 4000, height: 3000)
        #expect(photo.displayURL.host() == "picsum.photos")
        #expect(photo.thumbnailURL(side: 200).absoluteString.contains("picsum.photos"))
    }
}
