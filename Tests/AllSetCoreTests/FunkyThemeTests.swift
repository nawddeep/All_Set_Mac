import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import AllSetCore

@Suite struct FunkyThemeTests {
    @Test func allTwentySuppliedDesignsAreRealInstallableSets() throws {
        #expect(FunkyThemes.all.count == 20)
        #expect(ThemeLibrary.sets(in: .funkyThemes).count == 20)
        #expect(Set(FunkyThemes.all.map { $0.theme.id }).count == 20)
        for design in FunkyThemes.all {
            let set = try #require(ThemeLibrary.set("setup.\(design.theme.id)"))
            #expect(set.added == "2026-10-18")
            #expect(set.isDark == design.dark)
            #expect(ThemeLibrary.search(set.name).contains { $0.id == set.id })
            let widgets = set.widgets(screenName: nil, bounds: CGSize(width: 1136, height: 768))
            #expect((8...10).contains(widgets.count))
            #expect(widgets.contains { $0.kind == .clock })
            #expect(widgets.contains { $0.kind == .nowPlaying })
            #expect(widgets.contains { $0.kind == .todo })
            #expect(widgets.allSatisfy { $0.kind.supportedSizes.contains($0.size) })
            #expect(widgets.allSatisfy { !$0.options.animateArt && !$0.options.neonFlicker })
            let picks = try #require(ThemeCardArt.curated[set.id])
            #expect(widgets.indices.contains(picks.hero))
        }
    }

    @Test func installationFitsBothDisplayRatiosWithoutOverlapsOrOversizedCards() throws {
        for design in FunkyThemes.all {
            let layout = design.theme.kitWidgets(screenName: nil, bounds: CGSize(width: 10_000, height: 10_000))
            for bounds in [CGSize(width: 800, height: 600), CGSize(width: 1440, height: 900), CGSize(width: 1920, height: 1080)] {
                let fit = FunkyThemes.fitted(layout, in: bounds)
                #expect(fit.scale <= 1.1)
                let frames = fit.widgets.map {
                    CGRect(x: $0.offset.x * fit.scale, y: $0.offset.y * fit.scale,
                           width: $0.footprint.width * fit.scale, height: $0.footprint.height * fit.scale)
                }
                for (index, rect) in frames.enumerated() {
                    #expect(CGRect(origin: .zero, size: bounds).contains(rect), "\(design.theme.id) clips")
                    for other in frames.dropFirst(index + 1) {
                        #expect(!rect.insetBy(dx: 1, dy: 1).intersects(other), "\(design.theme.id) overlaps")
                    }
                }
                let occupied = frames.reduce(0) { $0 + $1.width * $1.height }
                #expect(occupied / (bounds.width * bounds.height) < 0.78)
            }
        }
    }

    @Test func galleryPreservesEveryLookAndPhotoSlotsAcceptPersonalImages() throws {
        let personal: ImageSource = .bundled("edit-botanical-paper.jpg")
        for design in FunkyThemes.all {
            let set = try #require(ThemeLibrary.set("setup.\(design.theme.id)"))
            let widgets = set.widgets(screenName: nil, bounds: CGSize(width: 1136, height: 768))
            let personalized = ThemeSet.personalized(widgets, with: [personal])
            for widget in personalized where [.photo, .polaroids].contains(widget.kind) {
                #expect(!widget.options.images.isEmpty)
                #expect(widget.options.images.allSatisfy { $0 == personal })
            }
            for entry in ThemeWidgetCatalog.widgets(in: set.id) {
                let index = try #require(Int(entry.id.split(separator: "/").last ?? ""))
                #expect(entry.instance.options == widgets[index].options)
                let added = entry.make()
                #expect(added.id != entry.instance.id)
                #expect(added.offset == .zero)
                #expect(try JSONDecoder().decode(WidgetInstance.self, from: JSONEncoder().encode(added)) == added)
            }
        }
    }

    @Test @MainActor func sourceDerivedArtIsBundledAndWallpapersHaveFullDesktopResolution() async throws {
        let library = ImageLibrary()
        for design in FunkyThemes.all {
            guard case .photo(let wallpaper) = design.theme.wallpaper else { Issue.record("Missing wallpaper"); continue }
            let file = try #require(library.fileURL(for: wallpaper))
            let source = try #require(CGImageSourceCreateWithURL(file as CFURL, nil))
            let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
            #expect(properties[kCGImagePropertyPixelWidth] as? Int == 2880)
            #expect(properties[kCGImagePropertyPixelHeight] as? Int == 1800)
            var sources = Set<ImageSource>([wallpaper])
            for widget in design.theme.kitWidgets(screenName: nil, bounds: CGSize(width: 1136, height: 768)) {
                sources.formUnion(widget.options.images)
                #expect(widget.options.background == nil)
            }
            for image in sources {
                guard case .bundled = image else { Issue.record("Remote image in supplied theme"); continue }
                #expect(await library.image(for: image, maxPixels: 768) != nil)
            }
        }
    }
}
