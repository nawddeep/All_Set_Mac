import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite @MainActor struct ClipboardStoreTests {
    /// A store whose owner has turned history on (a new install starts with it off).
    private func temporaryStore() -> (ClipboardStore, URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetClipboard-\(UUID().uuidString)")
        let store = ClipboardStore(directory: folder)
        store.choose(collect: true)
        return (store, folder)
    }

    // MARK: Review D1: collection is a choice, and history doesn't live for ever

    @Test func aNewInstallCollectsNothingUntilItsOwnerSaysSo() {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetClipboard-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ClipboardStore(directory: folder)
        #expect(!store.settings.hasChosen && !store.settings.isEnabled)
        #expect(!store.add(.text("a secret", sourceBundleID: nil), ifCurrent: store.captureGeneration))
        #expect(store.items.isEmpty)

        store.choose(collect: true)
        #expect(store.add(.text("kept", sourceBundleID: nil), ifCurrent: store.captureGeneration))
        store.save()
        let reloaded = ClipboardStore(directory: folder)
        #expect(reloaded.settings.hasChosen && reloaded.settings.isEnabled)
        #expect(reloaded.settings.expiryDays == 30)

        // Saying no is an answer too: it isn't asked again.
        reloaded.choose(collect: false)
        reloaded.save()
        let declined = ClipboardStore(directory: folder)
        #expect(declined.settings.hasChosen && !declined.settings.isEnabled)
    }

    @Test func anInstallFromBeforeTheQuestionKeepsWhatItHad() throws {
        func decode(_ json: String) throws -> ClipboardSettings {
            try JSONDecoder().decode(ClipboardSettings.self, from: Data(json.utf8))
        }
        // History was on, with no expiry: still on, nothing starts expiring.
        let wasOn = try decode(#"{"isEnabled": true, "historyLimit": 200}"#)
        #expect(wasOn.hasChosen && wasOn.isEnabled && wasOn.expiryDays == nil)
        // Its owner had turned it off: still off, and not asked again.
        let wasOff = try decode(#"{"isEnabled": false}"#)
        #expect(wasOff.hasChosen && !wasOff.isEnabled)
        // "Never" survives a save, and so does a chosen number of days.
        var settings = wasOn
        #expect(try JSONDecoder().decode(ClipboardSettings.self, from: JSONEncoder().encode(settings)).expiryDays == nil)
        settings.expiryDays = 7
        #expect(try JSONDecoder().decode(ClipboardSettings.self, from: JSONEncoder().encode(settings)).expiryDays == 7)
    }

    @Test func oldCopiesAreForgottenButPinnedOnesStay() throws {
        let (store, folder) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: store.imageDirectory, withIntermediateDirectories: true)
        let picture = store.imageDirectory.appendingPathComponent("old.png")
        try Data("png".utf8).write(to: picture)
        let now = Date()
        func copied(_ text: String, daysAgo: Double, image: String? = nil) -> ClipboardItem {
            var item = image.map { ClipboardItem(kind: .image, imageFile: $0, imageSize: CGSize(width: 1, height: 1)) }
                ?? ClipboardItem.text(text, sourceBundleID: nil)
            item.date = now.addingTimeInterval(-daysAgo * 86_400)
            return item
        }
        store.settings.expiryDays = nil
        store.add(copied("yesterday", daysAgo: 1))
        store.add(copied("last month", daysAgo: 40))
        store.add(copied("", daysAgo: 45, image: "old.png"))
        store.add(copied("an address I pinned", daysAgo: 400))
        store.togglePin(try #require(store.items.first { $0.text == "an address I pinned" }).id)
        #expect(store.items.count == 4)   // no expiry: everything is still here

        store.settings.expiryDays = 30
        #expect(Set(store.items.compactMap(\.text)) == ["yesterday", "an address I pinned"])
        #expect(!FileManager.default.fileExists(atPath: picture.path))
        // And as time passes.
        #expect(store.expire(now: now.addingTimeInterval(31 * 86_400)) == 1)
        #expect(store.items.compactMap(\.text) == ["an address I pinned"])
    }

    @Test func erasingEverythingTakesPinnedItemsPicturesAndCapturesInFlight() throws {
        let (store, folder) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: store.imageDirectory, withIntermediateDirectories: true)
        for name in ["kept.png", "orphan.png"] {
            try Data("png".utf8).write(to: store.imageDirectory.appendingPathComponent(name))
        }
        store.add(.text("pinned", sourceBundleID: nil))
        store.togglePin(store.items[0].id)
        store.add(ClipboardItem(kind: .image, imageFile: "kept.png", imageSize: CGSize(width: 1, height: 1)))
        let inFlight = store.captureGeneration

        #expect(store.eraseEverything())
        #expect(store.items.isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.imageDirectory.path).isEmpty)
        #expect(!store.add(.text("late", sourceBundleID: nil), ifCurrent: inFlight))
        #expect(ClipboardStore(directory: folder).items.isEmpty)
        // The choice to collect isn't undone by erasing.
        #expect(store.settings.isEnabled && store.settings.hasChosen)
    }

    /// Review D2: an image still being encoded when history is cleared or turned
    /// off must not land in the history afterwards, nor leave its file behind.
    @Test func aCaptureFromBeforeClearingOrTurningOffIsDropped() throws {
        let (store, folder) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: store.imageDirectory, withIntermediateDirectories: true)
        func lateImage() throws -> ClipboardItem {
            try Data("png".utf8).write(to: store.imageDirectory.appendingPathComponent("late.png"))
            return ClipboardItem(kind: .image, imageFile: "late.png", imageSize: CGSize(width: 1, height: 1))
        }
        let late = store.imageDirectory.appendingPathComponent("late.png")

        var started = store.captureGeneration
        store.clear()
        #expect(!store.add(try lateImage(), ifCurrent: started))
        #expect(store.items.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: late.path))

        started = store.captureGeneration
        store.settings.isEnabled = false
        #expect(!store.add(try lateImage(), ifCurrent: started))
        #expect(store.items.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: late.path))

        // A capture from the current generation, with history on, is kept.
        store.settings.isEnabled = true
        #expect(store.add(try lateImage(), ifCurrent: store.captureGeneration))
        #expect(store.items.count == 1)
    }

    @Test func recognizesLinks() {
        #expect(ClipboardItem.text("https://apple.com/mac", sourceBundleID: nil).kind == .link)
        #expect(ClipboardItem.text("  https://apple.com  \n", sourceBundleID: nil).text == "https://apple.com")
        #expect(ClipboardItem.text("see https://apple.com", sourceBundleID: nil).kind == .text)
        #expect(ClipboardItem.text("ftp://files", sourceBundleID: nil).kind == .text)
        #expect(ClipboardItem.text("Hello\nworld", sourceBundleID: nil).preview == "Hello")
    }

    @Test func copyingAgainMovesToTheTop() {
        let (store, folder) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: folder) }
        store.add(.text("first", sourceBundleID: nil))
        store.add(.text("second", sourceBundleID: nil))
        store.add(.text("first", sourceBundleID: "com.apple.Notes"))
        #expect(store.items.map(\.text) == ["first", "second"])
        #expect(store.items.first?.sourceBundleID == "com.apple.Notes")
    }

    @Test func pinnedItemsSurviveTheLimitAndClearing() {
        let (store, folder) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: folder) }
        store.settings.historyLimit = 3
        store.add(.text("keep me", sourceBundleID: nil))
        let pinned = store.items[0].id
        store.togglePin(pinned)
        for index in 1...5 { store.add(.text("item \(index)", sourceBundleID: nil)) }
        #expect(store.items.count == 4)
        #expect(store.items.contains { $0.id == pinned })
        #expect(store.search("").first?.id == pinned)

        store.clear()
        #expect(store.items.map(\.id) == [pinned])
    }

    @Test func searchesTextAndFileNamesAndFiltersByKind() {
        let (store, folder) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: folder) }
        store.add(.text("Meeting notes for Friday", sourceBundleID: nil))
        store.add(.text("https://example.com/report", sourceBundleID: nil))
        store.add(ClipboardItem(kind: .files, fileURLs: [URL(fileURLWithPath: "/Users/me/Budget 2026.xlsx")]))
        #expect(store.search("friday").count == 1)
        #expect(store.search("budget").first?.kind == .files)
        #expect(store.search("", kind: .link).count == 1)
        #expect(store.search("nothing like this").isEmpty)
    }

    @Test func historyAndSettingsPersist() {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetClipboard-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ClipboardStore(directory: folder)
        store.add(.text("saved", sourceBundleID: nil))
        store.settings.pickerShortcut = nil
        store.settings.historyLimit = 50
        store.save()

        let reloaded = ClipboardStore(directory: folder)
        #expect(reloaded.items.map(\.text) == ["saved"])
        #expect(reloaded.settings.pickerShortcut == nil)
        #expect(reloaded.settings.historyLimit == 50)
    }

    @Test func settingsFromOlderVersionsGetDefaults() throws {
        let settings = try JSONDecoder().decode(ClipboardSettings.self, from: Data(#"{"historyLimit":100}"#.utf8))
        #expect(settings.historyLimit == 100)
        #expect(settings.pickerShortcut?.display == "⌃⌥V")
        #expect(settings.ignoredApps.contains("com.1password.1password"))
    }
}

@Suite @MainActor struct ShelfStoreTests {
    @Test func remembersFilesAndForgetsDeletedOnes() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetShelf-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let kept = folder.appendingPathComponent("kept.txt")
        let deleted = folder.appendingPathComponent("deleted.txt")
        try Data("a".utf8).write(to: kept)
        try Data("b".utf8).write(to: deleted)

        let shelf = ShelfStore(directory: folder.appendingPathComponent("Shelf"))
        shelf.add([kept, deleted])
        shelf.add([kept])
        #expect(shelf.items.count == 2)

        try FileManager.default.removeItem(at: deleted)
        let reloaded = ShelfStore(directory: folder.appendingPathComponent("Shelf"))
        #expect(reloaded.items.map(\.url) == [kept])

        reloaded.remove(reloaded.items[0].id)
        #expect(reloaded.items.isEmpty)
        #expect(FileManager.default.fileExists(atPath: kept.path))
    }
}

@Suite struct ClipboardPrivacyTests {
    /// A copy made in a password manager just before switching away is still
    /// left out: any app in front since the last look counts.
    @Test func anyAppInFrontSinceTheLastLookCounts() {
        let settings = ClipboardSettings()
        #expect(settings.ignores(anyOf: ["com.apple.Safari", "com.1password.1password"]))
        #expect(!settings.ignores(anyOf: ["com.apple.Safari", "com.apple.dt.Xcode"]))
        #expect(!settings.ignores(anyOf: []))
    }

    @Test func clearOnQuitIsOffUnlessChosen() throws {
        let old = try JSONDecoder().decode(ClipboardSettings.self, from: Data(#"{"isEnabled": true}"#.utf8))
        #expect(!old.clearOnQuit)
        var settings = ClipboardSettings()
        settings.clearOnQuit = true
        #expect(try JSONDecoder().decode(ClipboardSettings.self, from: JSONEncoder().encode(settings)).clearOnQuit)
    }
}
