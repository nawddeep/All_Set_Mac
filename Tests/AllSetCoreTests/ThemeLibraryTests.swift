import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite struct ThemeLibraryTests {
    let canvas = CGSize(width: 1136, height: 768)

    @Test func everySetIsCompleteAndLaidOutCleanly() {
        #expect(Set(ThemeLibrary.all.map(\.id)).count == ThemeLibrary.all.count)
        for set in ThemeLibrary.all {
            let widgets = set.widgets(screenName: nil, bounds: canvas)
            #expect(widgets.count >= 5, "\(set.id) is too small to be a set")
            if set.setup == nil {
                #expect(widgets.count == set.layout.count, "\(set.id) has an entry that doesn't exist")
            }
            for item in set.layout {
                let entry = WidgetCatalog.entry(item.entry)
                #expect(entry != nil, "\(set.id): no entry \(item.entry)")
                #expect(entry?.sizes.contains(item.size) == true, "\(set.id): \(item.entry) can't be \(item.size)")
            }
            let rects = widgets.map { CGRect(origin: $0.offset, size: $0.size.dimensions) }
            for (index, a) in rects.enumerated() {
                #expect(CGRect(origin: .zero, size: canvas).contains(a), "\(set.id) spills off the screen")
                for b in rects[(index + 1)...] {
                    #expect(!a.insetBy(dx: 1, dy: 1).intersects(b), "\(set.id) overlaps itself")
                }
            }
            #expect(set.designTheme != nil || set.setup != nil, "\(set.id) has no look")
        }
    }

    @Test func moodboardsArePhotoLedAndFull() {
        #expect(WidgetTheme.moodboards.count >= 12)
        var photoLed = 0
        for theme in WidgetTheme.moodboards {
            let widgets = ThemeLibrary.set("setup.\(theme.id)")!.widgets(screenName: nil, bounds: canvas)
            #expect(widgets.count >= 7, "\(theme.id) is too sparse")
            let photos = widgets.filter { $0.kind == .photo || $0.kind == .polaroids }
            #expect(photos.allSatisfy { !$0.options.images.isEmpty }, "\(theme.id) has an empty photo")
            if photos.count >= 3 { photoLed += 1 }
        }
        #expect(photoLed >= 10)
        // Moodboards lead the library.
        #expect(ThemeLibrary.all.first?.id == "setup.\(WidgetTheme.moodboards[0].id)")
    }

    @Test func searchFindsByMood() {
        #expect(ThemeLibrary.search("night").contains { $0.id == "setup.cityNoir" })
        #expect(ThemeLibrary.search("leopard").first?.id == "setup.leopardNoir")
        #expect(ThemeLibrary.search("swag").contains { $0.id == "setup.afterDark" })
        #expect(ThemeLibrary.search("zzqx").isEmpty)
    }

    @Test @MainActor func featuredAuroraHasOfflineArtAndACompleteKit() async throws {
        let set = try #require(ThemeLibrary.set("setup.midnightAurora"))
        #expect(ThemeLibrary.search("aurora").first?.id == set.id)
        #expect(set.collections.contains(.featured))
        #expect(set.includedWidgets.count == 12)
        let source = ImageSource.bundled("midnight-aurora.jpg")
        let data = try JSONEncoder().encode(source)
        #expect(try JSONDecoder().decode(ImageSource.self, from: data) == source)
        let library = ImageLibrary()
        let file = try #require(library.fileURL(for: source))
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(await library.image(for: source, maxPixels: 768) != nil)
        #expect(await library.image(for: .bundled("missing.jpg")) == nil)
    }

    @Test func trendingFollowsUseAndSeason() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        var fresh = ThemeStats.Record()
        fresh.installs = 2
        fresh.lastUsed = now.addingTimeInterval(-3600)
        var stale = fresh
        stale.lastUsed = now.addingTimeInterval(-30 * 86_400)
        #expect(ThemeStats.trendingScore(baseline: 50, record: fresh, seasons: [], now: now)
                > ThemeStats.trendingScore(baseline: 50, record: stale, seasons: [], now: now))
        let month = Calendar(identifier: .gregorian).component(.month, from: now)
        #expect(ThemeStats.trendingScore(baseline: 50, record: .init(), seasons: [month], now: now)
                > ThemeStats.trendingScore(baseline: 50, record: .init(), seasons: [], now: now))
        var favorite = ThemeStats.Record()
        favorite.favorite = true
        #expect(ThemeStats.popularityScore(baseline: 40, record: favorite) > ThemeStats.popularityScore(baseline: 40, record: .init()))
    }

    @Test @MainActor func statsPersist() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("stats-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let stats = ThemeStats(fileURL: file)
        stats.toggleFavorite("midnight")
        stats.record(.install, for: "midnight")
        let reloaded = ThemeStats(fileURL: file)
        #expect(reloaded.isFavorite("midnight"))
        #expect(reloaded.records["midnight"]?.installs == 1)
    }
}

@Suite struct ColourThemeTests {
    @Test func colourThemesHaveTheirShelfAndAreColourful() {
        #expect(WidgetTheme.colour.count >= 8)
        let shelf = Set(ThemeLibrary.sets(in: .colourAndLight).map(\.id))
        for theme in WidgetTheme.colour {
            #expect(shelf.contains("setup.\(theme.id)"), "\(theme.id) isn't on the Colour & Light shelf")
            #expect(theme.palette != .mono, "\(theme.id) should bring colour")
            #expect(ThemeLibrary.search(theme.title).first?.id == "setup.\(theme.id)")
        }
        // Some light ones, not only dark.
        #expect(WidgetTheme.colour.filter { !$0.isDark }.count >= 4)
    }
}
