import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite struct FandomTests {
    @Test func newWidgetsHaveGalleryEntries() {
        for kind in [WidgetKind.jersey, .playerCard, .pitch, .scoreboard, .milestone, .cassette, .vhs, .visualizer, .ticket, .wordArt] {
            #expect(WidgetCatalog.entries.contains { $0.kind == kind }, "\(kind) has no gallery entry")
        }
        #expect(WidgetCatalog.entries(in: .football).count >= 8)
        #expect(WidgetCatalog.entries(in: .music).count >= 5)
    }

    @Test func fanOptionsSurviveOldAndPartialData() throws {
        // Saved before these widgets existed: every field falls back.
        let old = try JSONDecoder().decode(WidgetOptions.self, from: Data("{}".utf8))
        #expect(old.player == PlayerDetails())
        #expect(old.match == MatchDetails())
        // A partial player, with a broken stats list.
        let json = #"{"player": {"name": "KAKA", "number": 22, "stats": [1, 2]}}"#
        let partial = try JSONDecoder().decode(WidgetOptions.self, from: Data(json.utf8))
        #expect(partial.player.name == "KAKA")
        #expect(partial.player.number == 22)
        #expect(partial.player.stats == PlayerDetails().stats)
        // And a round trip keeps everything.
        var options = WidgetOptions()
        options.match.homeScore = 3
        options.ticket.headline = "FINAL"
        options.wordArt = .glitter
        let again = try JSONDecoder().decode(WidgetOptions.self, from: JSONEncoder().encode(options))
        #expect(again == options)
    }

    @Test func myPhotosFillEveryPictureSlot() {
        let set = ThemeLibrary.set("setup.seven")!
        let widgets = set.widgets(screenName: nil, bounds: CGSize(width: 1136, height: 768))
        let mine: [ImageSource] = [.file("a.jpg"), .file("b.jpg")]
        let personal = ThemeSet.personalized(widgets, with: mine)
        let slots = personal.filter { [.photo, .vhs, .playerCard, .polaroids].contains($0.kind) }
        #expect(!slots.isEmpty)
        #expect(slots.allSatisfy { !$0.options.images.isEmpty && $0.options.images.allSatisfy(mine.contains) })
        // Everything else is untouched.
        for (before, after) in zip(widgets, personal) where ![.photo, .vhs, .playerCard, .polaroids, .lockScreen].contains(before.kind) {
            #expect(before == after)
        }
        #expect(ThemeSet.personalized(widgets, with: []) == widgets)
        // The first photo is the player card's portrait.
        #expect(personal.first { $0.kind == .playerCard }?.options.images == [mine[0]])
    }

    @Test func fanWorldsNameNoOne() {
        let names = ["ronaldo", "cristiano", "cr7", "messi", "pelé", "pele", "neymar", "lana", "del rey", "travis", "xxxtentacion",
                     "billie", "eilish", "weeknd", "carti", "frank ocean", "real madrid", "barcelona", "nike", "adidas",
                     "kaká", "kaka", "maldini", "yamal", "mbappé", "mbappe", "manchester united", "haaland", "maradona"]
        #expect(WidgetTheme.fandom.count >= 15)
        for theme in WidgetTheme.fandom {
            let set = ThemeLibrary.set("setup.\(theme.id)")!
            #expect(set.inspiration != nil, "\(theme.id) needs an inspiration line")
            let shown = "\(set.name) \(set.tagline) \(set.description) \(set.philosophy) \(set.inspiration ?? "")".lowercased()
            let words = set.widgets(screenName: nil, bounds: CGSize(width: 1136, height: 768)).map {
                "\($0.options.customText) \($0.options.player.name) \($0.options.player.tagline) \($0.options.ticket.headline) \($0.options.ticket.venue)"
            }.joined(separator: " ").lowercased()
            for name in names {
                #expect(!shown.contains(name), "\(theme.id) shows \(name)")
                #expect(!words.contains(name), "\(theme.id) widgets show \(name)")
            }
        }
        // They can still be found by the names people search for.
        #expect(ThemeLibrary.search("ronaldo").first?.id == "setup.seven")
        #expect(ThemeLibrary.search("lana").contains { $0.id == "setup.americana" })
        #expect(ThemeLibrary.search("billie").contains { $0.id == "setup.slimeGreen" })
    }

    @Test func fanWorldsAreFullAndDistinct() {
        var wallpapers = Set<String>()
        for theme in WidgetTheme.fandom {
            let widgets = theme.kitWidgets(screenName: nil, bounds: CGSize(width: 1136, height: 768))
            #expect(widgets.count >= 10, "\(theme.id) is too sparse")
            // Each brings at least two of the new live widgets.
            let live: Set<WidgetKind> = [.jersey, .playerCard, .pitch, .scoreboard, .milestone, .cassette, .vhs, .visualizer, .ticket, .wordArt]
            #expect(widgets.filter { live.contains($0.kind) }.count >= 2, "\(theme.id) needs more live widgets")
            wallpapers.insert("\(theme.wallpaper)")
        }
        #expect(wallpapers.count == WidgetTheme.fandom.count, "every world needs its own wallpaper")
    }

    @Test func licensedPhotosAreFreeToUse() {
        let licensed = CuratedBackgrounds.licensed.flatMap(\.photos)
        #expect(licensed.count >= 140)
        for photo in licensed {
            #expect(["CC0", "PDM"].contains(photo.license ?? "") || (photo.license ?? "").hasPrefix("CC BY"), "\(photo.id): \(photo.license ?? "none")")
            #expect(photo.imageURLString?.hasPrefix("https://") == true)
        }
    }
}

@Suite @MainActor struct ThemePhotosTests {
    @Test func photosPersistPerSet() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("theme-photos-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ThemePhotos(fileURL: url)
        #expect(!store.hasPhotos("setup.seven"))
        #expect(store.version(of: "setup.seven") == "0")
        store.set(["a.jpg", "b.jpg"], for: "setup.seven")
        let version = store.version(of: "setup.seven")
        #expect(version != "0")
        let reloaded = ThemePhotos(fileURL: url)
        #expect(reloaded.sources(for: "setup.seven") == [.file("a.jpg"), .file("b.jpg")])
        #expect(reloaded.version(of: "setup.seven") == version)
        reloaded.clear("setup.seven")
        #expect(!ThemePhotos(fileURL: url).hasPhotos("setup.seven"))
    }
}

@Suite struct ScreenCoverageTests {
    @Test func coverageTellsAStripFromHalfTheDesktop() {
        let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)
        #expect(ScreenCoverage.uncoveredFraction(of: screen, by: []) == 1)
        // A maximized window leaves only the menu bar and Dock strips.
        let maximized = CGRect(x: 0, y: 70, width: 1470, height: 856)
        #expect(ScreenCoverage.uncoveredFraction(of: screen, by: [maximized]) < 0.15)
        // Half the desktop showing plays.
        let half = CGRect(x: 0, y: 0, width: 735, height: 956)
        #expect(abs(ScreenCoverage.uncoveredFraction(of: screen, by: [half]) - 0.5) < 0.05)
        // A window on another screen doesn't count.
        let elsewhere = CGRect(x: 2000, y: 0, width: 1920, height: 1080)
        #expect(ScreenCoverage.uncoveredFraction(of: screen, by: [elsewhere]) == 1)
    }
}

@Suite @MainActor struct CalmReadingsTests {
    @Test func calmCopiesAtMostEveryFewSeconds() {
        let monitor = SystemMonitor()
        let calm = monitor.calm
        let start = Date(timeIntervalSince1970: 1_000_000)
        calm.copy(from: monitor, now: start)
        let first = calm.snapshot
        calm.copy(from: monitor, now: start.addingTimeInterval(1))
        #expect(calm.snapshot == first)
        calm.copy(from: monitor, now: start.addingTimeInterval(CalmReadings.interval + 0.1))
        #expect(calm.snapshot == monitor.snapshot)
    }
}

@Suite struct FitToScreenTests {
    @Test func themesFillWideScreensCenteredAndEvenly() {
        let set = ThemeLibrary.set("setup.seven")!
        let layout = set.widgets(screenName: nil, bounds: CGSize(width: 10_000, height: 10_000))
        // A 13-inch MacBook Air's desktop, below the menu bar and above the Dock.
        let screen = CGSize(width: 1470, height: 889)
        let fitted = WidgetLayout.fitted(layout, in: screen, range: AppSettings.widgetScaleRange)
        #expect(fitted.scale > 1.1 && fitted.scale < 1.25)
        let rects = fitted.widgets.map {
            CGRect(x: $0.offset.x * fitted.scale, y: $0.offset.y * fitted.scale,
                   width: $0.size.dimensions.width * fitted.scale, height: $0.size.dimensions.height * fitted.scale)
        }
        let box = rects.dropFirst().reduce(rects[0]) { $0.union($1) }
        // Fills the height inside the margins, and sits centered across.
        #expect(abs(box.height - (screen.height - 2 * WidgetLayout.margin)) < 1)
        #expect(abs(box.minX - (screen.width - box.maxX)) < 1)
        #expect(box.minX >= 0 && box.maxX <= screen.width && box.maxY <= screen.height)
        // Gaps stay in proportion: none overlap.
        for (index, a) in rects.enumerated() {
            for b in rects[(index + 1)...] { #expect(!a.insetBy(dx: 1, dy: 1).intersects(b)) }
        }
        // A screen the theme already fits exactly stays at natural size.
        let natural = WidgetLayout.fitted(layout, in: CGSize(width: 1088 + 2 * WidgetLayout.margin, height: 720 + 2 * WidgetLayout.margin), range: AppSettings.widgetScaleRange)
        #expect(abs(natural.scale - 1) < 0.01)
    }
}
