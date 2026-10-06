import Foundation
import Testing
@testable import AllSetCore

@Suite @MainActor struct DesktopJournalTests {
    private func scratch() throws -> URL {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    /// A desktop with one widget and a known look, in throwaway stores.
    private func desktop(in home: URL, suite: String, kinds: [WidgetKind]) throws -> (AppSettings, WidgetStore, WallpaperStore) {
        let defaults = try #require(UserDefaults(suiteName: suite))
        let settings = AppSettings(defaults: defaults)
        let widgets = WidgetStore(fileURL: home.appendingPathComponent("widgets.json"))
        widgets.replaceAll(with: kinds.map { WidgetInstance(kind: $0, size: .small) })
        let wallpaper = WallpaperStore(directory: home.appendingPathComponent("Wallpaper"))
        return (settings, widgets, wallpaper)
    }

    @Test func aPreviewIsWrittenBeforeAndForgottenAfter() throws {
        let home = try scratch()
        defer { try? FileManager.default.removeItem(at: home) }
        let suite = "AllSetTests.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let (settings, widgets, wallpaper) = try desktop(in: home, suite: suite, kinds: [.clock, .calendar])
        let journal = DesktopJournal(directory: home)
        #expect(journal.pendingPreview == nil)

        let before = DesktopSnapshot(settings: settings, widgets: widgets, wallpaper: wallpaper)
        #expect(journal.beginPreview(PendingPreview(setID: "setup.seven", before: before)))
        // Another launch (after a crash) sees it.
        let reopened = DesktopJournal(directory: home)
        #expect(reopened.pendingPreview?.setID == "setup.seven")
        #expect(reopened.pendingPreview?.before == before)

        journal.endPreview()
        #expect(DesktopJournal(directory: home).pendingPreview == nil)
    }

    @Test func recoveringAnInterruptedPreviewPutsTheRealDesktopBack() throws {
        let home = try scratch()
        defer { try? FileManager.default.removeItem(at: home) }
        let suite = "AllSetTests.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let (settings, widgets, wallpaper) = try desktop(in: home, suite: suite, kinds: [.clock, .calendar])
        settings.widgetCornerRadius = 9
        let journal = DesktopJournal(directory: home)
        let real = DesktopSnapshot(settings: settings, widgets: widgets, wallpaper: wallpaper)
        #expect(journal.beginPreview(PendingPreview(setID: "setup.seven", before: real)))

        // The trial goes on and is saved, then the app dies.
        widgets.replaceAll(with: [WidgetInstance(kind: .weather, size: .medium)])
        settings.widgetCornerRadius = 30
        widgets.saveNow()

        // Next launch.
        let relaunched = WidgetStore(fileURL: home.appendingPathComponent("widgets.json"))
        #expect(relaunched.widgets.map(\.kind) == [.weather])
        let pending = try #require(DesktopJournal(directory: home).pendingPreview)
        pending.before.restore(settings: settings, widgets: relaunched, wallpaper: wallpaper)
        relaunched.saveNow()
        #expect(WidgetStore(fileURL: home.appendingPathComponent("widgets.json")).widgets.map(\.kind) == [.clock, .calendar])
        #expect(settings.widgetCornerRadius == 9)
    }

    @Test func thePreviousDesktopSurvivesARelaunch() throws {
        let home = try scratch()
        defer { try? FileManager.default.removeItem(at: home) }
        let suite = "AllSetTests.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let (settings, widgets, wallpaper) = try desktop(in: home, suite: suite, kinds: [.clock])
        let before = DesktopSnapshot(settings: settings, widgets: widgets, wallpaper: wallpaper)
        #expect(DesktopJournal(directory: home).remember(PreviousDesktop(change: "New wallpaper", before: before)))
        let previous = try #require(DesktopJournal(directory: home).previous)
        #expect(previous.change == "New wallpaper")
        #expect(previous.before.widgets.map(\.kind) == [.clock])
    }

    @Test func aRecordThatCantBeWrittenIsReportedSoNothingStarts() throws {
        let home = try scratch()
        defer { try? FileManager.default.removeItem(at: home) }
        // A file where the folder should be: nothing can be written inside it.
        let blocked = home.appendingPathComponent("blocked")
        try Data().write(to: blocked)
        let suite = "AllSetTests.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let (settings, widgets, wallpaper) = try desktop(in: home, suite: suite, kinds: [.clock])
        let journal = DesktopJournal(directory: blocked)
        let before = DesktopSnapshot(settings: settings, widgets: widgets, wallpaper: wallpaper)
        #expect(!journal.beginPreview(PendingPreview(setID: "x", before: before)))
        #expect(journal.pendingPreview == nil)
    }

    // MARK: Restoring and keeping (review R8)

    @Test func goingBackRetiresTheRecordOnlyOnceTheDesktopIsSaved() throws {
        let home = try scratch()
        defer { try? FileManager.default.removeItem(at: home) }
        let suite = "AllSetTests.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let defaults = try #require(UserDefaults(suiteName: suite))
        let settings = AppSettings(defaults: defaults)
        let wallpaper = WallpaperStore(directory: home.appendingPathComponent("Wallpaper"))
        // The layout file can't be written: a folder stands where it goes.
        let layoutURL = home.appendingPathComponent("widgets.json")
        try FileManager.default.createDirectory(at: layoutURL, withIntermediateDirectories: true)
        let widgets = WidgetStore(fileURL: layoutURL)
        widgets.replaceAll(with: [WidgetInstance(kind: .clock, size: .small)])
        let journal = DesktopJournal(directory: home)
        let before = DesktopSnapshot(settings: settings, widgets: widgets, wallpaper: wallpaper)
        #expect(journal.beginPreview(PendingPreview(setID: "setup.seven", before: before)))
        widgets.replaceAll(with: [WidgetInstance(kind: .weather, size: .medium)])

        // Restored on screen, but not saved: the record stays for the next launch.
        #expect(journal.restorePreview(settings: settings, widgets: widgets, wallpaper: wallpaper) == .notSaved(setID: "setup.seven"))
        #expect(widgets.widgets.map(\.kind) == [.clock])
        #expect(journal.pendingPreview != nil)

        // Saving works again: the retry finishes and retires it.
        try FileManager.default.removeItem(at: layoutURL)
        #expect(journal.restorePreview(settings: settings, widgets: widgets, wallpaper: wallpaper) == .restored(setID: "setup.seven"))
        #expect(journal.pendingPreview == nil)
        #expect(WidgetStore(fileURL: layoutURL).widgets.map(\.kind) == [.clock])
    }

    @Test func aKeptPreviewsLeftoverRecordNeverRollsTheDesktopBack() throws {
        let home = try scratch()
        defer { try? FileManager.default.removeItem(at: home) }
        let suite = "AllSetTests.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let (settings, widgets, wallpaper) = try desktop(in: home, suite: suite, kinds: [.clock])
        let journal = DesktopJournal(directory: home)
        let before = DesktopSnapshot(settings: settings, widgets: widgets, wallpaper: wallpaper)
        // A record marked kept whose removal didn't happen (the app died in between).
        #expect(journal.beginPreview(PendingPreview(setID: "setup.seven", before: before, isKept: true)))
        widgets.replaceAll(with: [WidgetInstance(kind: .weather, size: .medium)])
        #expect(journal.restorePreview(settings: settings, widgets: widgets, wallpaper: wallpaper) == .wasKept)
        #expect(widgets.widgets.map(\.kind) == [.weather])
        #expect(journal.pendingPreview == nil)
    }

    @Test func keepingRetiresTheRecord() throws {
        let home = try scratch()
        defer { try? FileManager.default.removeItem(at: home) }
        let suite = "AllSetTests.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let (settings, widgets, wallpaper) = try desktop(in: home, suite: suite, kinds: [.clock])
        let journal = DesktopJournal(directory: home)
        #expect(journal.beginPreview(PendingPreview(setID: "x", before: DesktopSnapshot(settings: settings, widgets: widgets, wallpaper: wallpaper))))
        #expect(journal.keepPreview())
        #expect(journal.pendingPreview == nil)
        #expect(journal.restorePreview(settings: settings, widgets: widgets, wallpaper: wallpaper) == .nothingPending)
    }

    @Test func aRecordFromBeforeKeptExistedStillReads() throws {
        let home = try scratch()
        defer { try? FileManager.default.removeItem(at: home) }
        let suite = "AllSetTests.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let (settings, widgets, wallpaper) = try desktop(in: home, suite: suite, kinds: [.clock])
        let before = DesktopSnapshot(settings: settings, widgets: widgets, wallpaper: wallpaper)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(PendingPreview(setID: "x", before: before))) as? [String: Any])
        object["isKept"] = nil
        try JSONSerialization.data(withJSONObject: object).write(to: home.appendingPathComponent("desktop-preview.json"))
        let pending = try #require(DesktopJournal(directory: home).pendingPreview)
        #expect(!pending.isKept)
    }
}
