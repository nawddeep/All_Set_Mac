import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite @MainActor struct DesktopSnapshotTests {
    @Test func adoptingASetupTakesItsFontCornersAndTheme() throws {
        let suite = "AllSetTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        let set = try #require(ThemeLibrary.set("setup.seven"))
        let setup = try #require(set.setup)
        settings.widgetFont = setup.font == .monospaced ? .serif : .monospaced
        settings.widgetCornerRadius = setup.cornerRadius + 7
        settings.widgetDesignTheme = "terminal"
        settings.showWidgets = false

        settings.adopt(set)

        #expect(settings.widgetFont == setup.font)
        #expect(settings.widgetCornerRadius == setup.cornerRadius)
        #expect(settings.widgetTheme == setup.id)
        #expect(settings.widgetDesignTheme == nil)
        #expect(settings.showWidgets)
        #expect(settings.activeThemeSet == set.id)
    }

    /// The Themes banner follows the set on the desktop, and survives a restart.
    @Test func theActiveSetIsRememberedAndForgotten() throws {
        let suite = "AllSetTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let set = try #require(ThemeLibrary.set("setup.seven"))
        let settings = AppSettings(defaults: defaults)
        settings.adopt(set)
        #expect(AppSettings(defaults: defaults).activeThemeSet == set.id)
        settings.resetWidgetLook()
        #expect(AppSettings(defaults: defaults).activeThemeSet == nil)
    }

    /// Each display keeps its own widget size; the size slider sets them all.
    @Test func eachDisplayKeepsItsOwnWidgetSize() throws {
        let suite = "AllSetTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.screenFits["Built-in"] = ScreenFit(scale: 1.2, size: CGSize(width: 1470, height: 956))
        settings.screenFits["Monitor"] = ScreenFit(scale: 1.8, size: CGSize(width: 2560, height: 1440))
        #expect(settings.widgetScale(for: "Built-in") == 1.2 && settings.widgetScale(for: "Monitor") == 1.8)
        #expect(settings.widgetScale(for: "Unknown") == settings.widgetScale)
        #expect(AppSettings(defaults: defaults).screenFits["Monitor"]?.scale == 1.8)
        settings.widgetScale = 1.5
        #expect(settings.widgetScale(for: "Built-in") == 1.5 && settings.widgetScale(for: "Monitor") == 1.5)
    }

    /// Picking a wallpaper leaves no theme behind.
    @Test func resettingTheLookForgetsTheTheme() throws {
        let suite = "AllSetTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let freshSuite = suite + ".fresh"
        let freshDefaults = try #require(UserDefaults(suiteName: freshSuite))
        defer { freshDefaults.removePersistentDomain(forName: freshSuite) }
        let set = try #require(ThemeLibrary.set("setup.seven"))
        let settings = AppSettings(defaults: defaults)
        settings.adopt(set)
        settings.widgetScale = 1.3
        settings.widgetDesignTheme = "terminal"

        settings.resetWidgetLook()

        #expect(settings.widgetFont == AppSettings.defaultWidgetFont)
        #expect(settings.widgetCornerRadius == AppSettings.defaultWidgetCornerRadius)
        #expect(settings.widgetScale == 1)
        #expect(settings.widgetTheme == nil)
        #expect(settings.widgetDesignTheme == nil)
        // Matches a fresh install's look.
        let fresh = AppSettings(defaults: freshDefaults)
        #expect(fresh.widgetFont == settings.widgetFont && fresh.widgetCornerRadius == settings.widgetCornerRadius)
    }

    /// What Undo and a preview's Go Back rely on: everything a theme touches
    /// comes back, not just the widgets.
    @Test func restoringPutsBackEverythingAThemeChanged() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("snapshot-\(UUID())")
        let suite = "AllSetTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: home)
        }
        let settings = AppSettings(defaults: defaults)
        let widgets = WidgetStore(fileURL: home.appendingPathComponent("widgets.json"))
        let wallpaper = WallpaperStore(directory: home.appendingPathComponent("Wallpaper"))

        widgets.replaceAll(with: [WidgetInstance(kind: .clock), WidgetInstance(kind: .note, offset: CGPoint(x: 300, y: 40))])
        settings.widgetScale = 1.2
        settings.widgetFont = .monospaced
        settings.widgetCornerRadius = 4
        settings.widgetDesignTheme = "terminal"
        settings.widgetTheme = nil
        settings.showWidgets = false
        wallpaper.set(.art(ArtPiece(style: .waves, palette: .ocean)))
        let before = DesktopSnapshot(settings: settings, widgets: widgets, wallpaper: wallpaper)

        // A theme goes on, the way installing one does.
        let set = try #require(ThemeLibrary.set("setup.seven"))
        let themeWallpaper = try #require(set.wallpaper)
        widgets.replaceAll(with: set.widgets(screenName: nil, bounds: CGSize(width: 1136, height: 768)))
        settings.widgetScale = 0.9
        wallpaper.set(themeWallpaper)
        settings.adopt(set)
        #expect(DesktopSnapshot(settings: settings, widgets: widgets, wallpaper: wallpaper) != before)

        before.restore(settings: settings, widgets: widgets, wallpaper: wallpaper)

        #expect(DesktopSnapshot(settings: settings, widgets: widgets, wallpaper: wallpaper) == before)
        #expect(settings.widgetFont == .monospaced)
        #expect(settings.widgetCornerRadius == 4)
        #expect(settings.widgetDesignTheme == "terminal")
        #expect(settings.widgetTheme == nil)
        #expect(!settings.showWidgets)
        #expect(wallpaper.config.source == .art(ArtPiece(style: .waves, palette: .ocean)))
    }
}

@Suite @MainActor struct WidgetStoreInsertTests {
    /// Undoing a removal puts the widget back in its old place.
    @Test func insertPutsAWidgetBackWhereItWas() {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("insert-\(UUID())")
        defer { try? FileManager.default.removeItem(at: home) }
        let store = WidgetStore(fileURL: home.appendingPathComponent("widgets.json"))
        let a = WidgetInstance(kind: .clock), b = WidgetInstance(kind: .note), c = WidgetInstance(kind: .weather)
        store.replaceAll(with: [a, b, c])
        store.remove(b.id)
        store.insert(b, at: 1)
        #expect(store.widgets.map(\.id) == [a.id, b.id, c.id])
        // An index past the end (other widgets went since) lands last.
        store.remove(b.id)
        store.remove(c.id)
        store.insert(b, at: 5)
        #expect(store.widgets.map(\.id) == [a.id, b.id])
    }
}
