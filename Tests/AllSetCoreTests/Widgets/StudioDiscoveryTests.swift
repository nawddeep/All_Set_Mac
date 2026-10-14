import Foundation
import CoreGraphics
import ImageIO
import Testing
@testable import AllSetCore

struct StudioDiscoveryTests {
    @Test func completeThemeLibraryIsIncludedWithoutLosingItsSkins() {
        let restored = StudioWidgetFilter.all.themeWidgets()
        #expect(restored.map(\.id) == ThemeWidgetCatalog.all.map(\.id))
        #expect(Set(restored.map(\.id)).count == restored.count)
        #expect(restored.map(\.instance) == ThemeWidgetCatalog.all.map(\.instance))
    }
    @Test func purposeFiltersIncludeMatchingThemeWidgets() {
        let clocks = StudioWidgetFilter.clocks.themeWidgets()
        #expect(!clocks.isEmpty)
        #expect(clocks.allSatisfy { $0.instance.kind == .clock || $0.instance.kind == .date })
        #expect(StudioWidgetFilter.weather.themeWidgets().allSatisfy { [.weather, .airQuality, .daylight].contains($0.instance.kind) })
        #expect(StudioWidgetFilter.clocks.themeWidgets(query: "zzzznomatch9876").isEmpty)
        let theme = ThemeWidgetCatalog.all[0].setName
        #expect(!StudioWidgetFilter.all.themeWidgets(query: theme).isEmpty)
    }
    @Test func wallpaperRowsHaveUniformWidthsAndExactAspectRatios() {
        for width: CGFloat in [900, 1120, 1280, 1586, 1728, 2560] {
            let grid = StudioWallpaperGrid(width: width)
            let total = CGFloat(grid.columns) * grid.cardWidth + CGFloat(grid.columns - 1) * grid.gap
            #expect(abs(total - grid.contentWidth) < 0.001)
            #expect(abs(grid.imageHeight / grid.cardWidth - 0.5625) < 0.001)
            #expect(grid.rowHeight > grid.imageHeight)
            #expect((1...5).contains(grid.columns))
            #expect(grid.cardWidth >= 230)
        }
    }
    @Test func everyArtVariantHasAnUnambiguousWallpaperID() {
        let ids = ArtPiece.all.map(StudioSavedIDs.wallpaperID)
        #expect(Set(ids).count == ids.count)
        #expect(ids.count == ArtStyle.allCases.count * ArtPalette.allCases.count)
        #expect(!ids.contains("aurora"))
        #expect(StudioSavedIDs.wallpaperID(ArtPiece(style: .aurora, palette: .midnight)) == "art:aurora")
        #expect(StudioSavedIDs.wallpaperID(ArtPiece(style: .aurora, palette: .ocean)) == "art:aurora.ocean")
    }
    @Test func completeCatalogRemainsAccessible() {
        #expect(StudioWidgetFilter.all.entries().map(\.id) == WidgetCatalog.entries.map(\.id))
        #expect(WidgetCatalog.entries.allSatisfy { StudioWidgetFilter.all.includes($0) })
    }
    @Test func purposeFiltersDoNotLeakUnrelatedKinds() {
        #expect(StudioWidgetFilter.weather.entries().allSatisfy { [.weather, .airQuality, .daylight].contains($0.kind) })
        #expect(StudioWidgetFilter.clocks.entries().allSatisfy { $0.kind == .clock || $0.kind == .date })
        #expect(StudioWidgetFilter.photos.entries().allSatisfy { [.photo, .polaroids, .magazine].contains($0.kind) })
        #expect(!StudioWidgetFilter.system.entries().isEmpty)
    }
    @Test func rankedSearchIsUniqueAndRespectsFilter() {
        let clocks = StudioWidgetFilter.clocks.entries(query: "digital clock")
        #expect(clocks.first?.id == "digitalClock")
        #expect(Set(clocks.map(\.id)).count == clocks.count)
        #expect(StudioWidgetFilter.weather.entries(query: "digital clock").isEmpty)
    }
    @Test func emptyAndNormalizedSearch() {
        #expect(StudioWidgetFilter.all.entries(query: "zzzznomatch9876").isEmpty)
        #expect(StudioWidgetFilter.all.entries(query: " \n ").count == WidgetCatalog.entries.count)
        #expect(StudioWidgetFilter.all.entries(query: "SYSTEM monitor").first?.id == "systemMonitor")
    }
    @Test func referenceClockProportions() {
        let layout = StudioLayout(width: 1586, height: 992)
        #expect(abs(layout.spotlightWidth - 642) < 2)
        #expect(abs(layout.spotlightHeight - 260) < 2)
        #expect(abs(layout.sideWidth - 287) < 3)
        #expect(abs(layout.filmstripHeight - 254) < 2)
    }
    @Test func spotlightLightingFollowsSquareAndWideWidgets() {
        let bounds = CGSize(width: 642, height: 260)
        let square = StudioLayout.fitting(WidgetCatalog.entry("focusTimer")!.make(size: .small).footprint, in: bounds)
        #expect(abs(square.width - square.height) < 0.001)
        #expect(square.width < bounds.width / 2)

        var clock = WidgetCatalog.entry("digitalClock")!.make(size: .medium)
        clock.stretch = 0.85
        let wide = StudioLayout.fitting(clock.footprint, in: bounds)
        #expect(wide.width > square.width * 2)
        #expect(abs(wide.width / wide.height - clock.footprint.width / clock.footprint.height) < 0.001)
    }
    @Test func everySupportedWidgetSizeFitsTheSpotlightAtEveryWindowWidth() {
        for width: CGFloat in [900, 1280, 1586, 2560] {
            let layout = StudioLayout(width: width, height: width * 0.625)
            let bounds = CGSize(width: layout.spotlightWidth, height: layout.spotlightHeight)
            for entry in WidgetCatalog.entries {
                for size in entry.sizes {
                    let footprint = entry.make(size: size).footprint
                    let fit = StudioLayout.fitting(footprint, in: bounds)
                    #expect(fit.width > 0 && fit.height > 0)
                    #expect(fit.width <= bounds.width + 0.001 && fit.height <= bounds.height + 0.001)
                    #expect(abs(fit.width / fit.height - footprint.width / footprint.height) < 0.001)
                }
            }
        }
    }
    @Test func invalidPreviewGeometryCannotCreateInfiniteLayout() {
        for footprint in [CGSize.zero, CGSize(width: -1, height: 100), CGSize(width: CGFloat.infinity, height: 100)] {
            #expect(StudioLayout.fitting(footprint, in: CGSize(width: 642, height: 260)) == .zero)
        }
    }
    @Test func responsiveStageAndShelfDoNotOverflow() {
        for width: CGFloat in [900, 1120, 1280, 1586, 1728, 2560] {
            let layout = StudioLayout(width: width, height: width * 0.625)
            #expect(layout.spotlightWidth + 2 * layout.sideWidth + 2 * 48 + 2 * 24 + 2 * 10 + 2 * 28 <= width)
            #expect(layout.tileWidth > 0)
            let widths = (0..<layout.columns).map { layout.tileWidth(at: $0) }
            let cards = widths.reduce(CGFloat.zero, +)
            let spacing = CGFloat(layout.columns - 1) * layout.tileGap
            let rowWidth = cards + spacing + 2 * layout.margin
            #expect(abs(rowWidth - width) < 0.001)
            #expect(layout.spotlightHeight > 0)
        }
    }
    @Test func referenceShelfKeepsWiderWeatherAndMusicCards() {
        let layout = StudioLayout(width: 1586, height: 992)
        #expect(abs(layout.tileWidth(at: 0) - 298) < 2)
        #expect(abs(layout.tileWidth(at: 4) - 300) < 3)
        #expect(abs(layout.tileWidth(at: 1) - 268) < 3)
        #expect(StudioLayout(width: 900, height: 600).columns == 3)
    }
    @Test func filmstripHasBoundedHeight() {
        #expect(StudioLayout(width: 900, height: 600).filmstripHeight >= 150)
        #expect(StudioLayout(width: 1728, height: 1080).filmstripHeight <= 254)
        #expect(StudioLayout(width: 900, height: 600).wallpaperCaptionBottom < 600)
    }
    @Test func cyclicSelectionHandlesEmptyAndNegativeIndices() {
        #expect(StudioLayout.wrapped(2, count: 0) == nil)
        #expect(StudioLayout.wrapped(-1, count: 5) == 4)
        #expect(StudioLayout.wrapped(5, count: 5) == 0)
        #expect(StudioLayout.wrapped(-51, count: 5) == 4)
    }
    @Test func oldOptionsKeepTheirAppearance() throws {
        let options = try JSONDecoder().decode(WidgetOptions.self, from: Data("{}".utf8))
        #expect(!options.cinematicClock)
        #expect(!options.showSeconds)
        let damaged = try JSONDecoder().decode(WidgetOptions.self, from: Data("{\"cinematicClock\":\"wrong\"}".utf8))
        #expect(!damaged.cinematicClock)
    }
    @Test func scenicClockOptionsAndGeometrySurviveSave() throws {
        var clock = WidgetCatalog.entry("digitalClock")!.make(size: .medium)
        clock.options.cinematicClock = true
        clock.options.background = .bundled(StudioScenery.wallpaper)
        clock.options.use24Hour = true
        clock.stretch = 0.85
        let copy = try JSONDecoder().decode(WidgetInstance.self, from: JSONEncoder().encode(clock))
        #expect(copy.options.cinematicClock)
        #expect(copy.options.use24Hour)
        #expect(copy.options.background == clock.options.background)
        #expect(copy.footprint == clock.footprint)
    }
    @Test func cinematicCardsKeepTheirStateAcrossAStoreReload() throws {
        for id in ["weather", "calendar", "systemMonitor", "focusTimer", "music"] {
            var widget = WidgetCatalog.entry(id)!.make(size: .medium)
            widget.options.cinematicStyle = true
            widget.options.background = .bundled(StudioScenery.widgets)
            widget.options.focusMinutes = 25
            let decoded = try JSONDecoder().decode(WidgetInstance.self, from: JSONEncoder().encode(widget))
            #expect(decoded == widget)
            #expect(decoded.options.cinematicStyle)
        }
    }
    @Test func malformedStyleDoesNotChangeOldCards() throws {
        let options = try JSONDecoder().decode(WidgetOptions.self, from: Data("{\"cinematicStyle\":[]}".utf8))
        #expect(!options.cinematicStyle)
        #expect(!options.cinematicClock)
    }
    @Test func extraLargeCinematicClockRemainsSupportedAfterSave() throws {
        var clock = WidgetCatalog.entry("digitalClock")!.make(size: .extraLarge)
        clock.options.cinematicClock = true
        let decoded = try JSONDecoder().decode(WidgetInstance.self, from: JSONEncoder().encode(clock))
        #expect(decoded.size == .extraLarge)
        #expect(decoded.kind.supportedSizes.contains(decoded.size))
        #expect(decoded.options.cinematicClock)
    }
    @Test func applyingAnExistingThemeReplacesTheCinematicAppearance() {
        var widget = WidgetCatalog.entry("digitalClock")!.make()
        widget.options.cinematicClock = true
        widget.options.cinematicStyle = true
        for theme in WidgetTheme.all {
            let styled = theme.styled(widget)
            #expect(!styled.options.cinematicClock)
            #expect(!styled.options.cinematicStyle)
            #expect(styled.kind == widget.kind)
            #expect(styled.id == widget.id)
        }
    }
    @Test func favoriteIDsPreserveFilenamesAndMigrateLegacySets() {
        let ids: Set<String> = ["A|B.mp4", "art:aurora", "aurora", "星空.mp4"]
        #expect(StudioSavedIDs.decode(StudioSavedIDs.encode(ids)) == ids)
        #expect(StudioSavedIDs.decode("digitalClock|weather") == ["digitalClock", "weather"])
        #expect(StudioSavedIDs.decode("").isEmpty)
        #expect(StudioSavedIDs.decode("[damaged").isEmpty)
        #expect(StudioSavedIDs.encode(ids) == StudioSavedIDs.encode(Set(ids.reversed())))
    }
    @Test func originalOfflineArtIsDecodable() throws {
        for name in [StudioScenery.wallpaper, StudioScenery.widgets, StudioScenery.coast, StudioScenery.dunes, StudioScenery.orbit, "cinema-weather-day.png"] {
            let url = try #require(StudioScenery.url(name))
            let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            #expect(image.width >= 1400)
            #expect(image.height >= 900)
            #expect(image.width * image.height * 4 < 8 * 1024 * 1024)
        }
    }
    @Test func widgetsBackdropIsDarkAndBlue() throws {
        let url = try #require(StudioScenery.url(StudioScenery.widgets))
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var pixels = [UInt8](repeating: 0, count: 40 * 25 * 4)
        let means = try pixels.withUnsafeMutableBytes { buffer -> (Double, Double, Double) in
            let context = try #require(CGContext(data: buffer.baseAddress, width: 40, height: 25, bitsPerComponent: 8, bytesPerRow: 160, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: 40, height: 25))
            let data = buffer.bindMemory(to: UInt8.self)
            var red = 0.0, green = 0.0, blue = 0.0
            for i in stride(from: 0, to: data.count, by: 4) { red += Double(data[i]); green += Double(data[i + 1]); blue += Double(data[i + 2]) }
            return (red / 1000, green / 1000, blue / 1000)
        }
        #expect(means.2 > means.0 * 1.4)
        #expect(means.2 > means.1)
        #expect(means.0 * 0.2126 + means.1 * 0.7152 + means.2 * 0.0722 < 45)
    }
}
