import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite struct DatasetTwoThemeTests {
    @Test func sparseDesignsStayIndependentAndEditable() throws {
        let designs = DatasetTwoThemes.all
        #expect(designs.count == 3)
        #expect(Set(designs.map(\.theme.id)).count == designs.count)
        #expect(ThemeLibrary.sets(in: .datasetTwo).count == designs.count)

        for design in designs {
            let set = try #require(ThemeLibrary.set("setup.\(design.theme.id)"))
            #expect(set.isDark == design.dark)
            #expect((6...8).contains(design.theme.kit.count))
            #expect(ThemeLibrary.search(design.theme.title).contains { $0.id == set.id })
            let widgets = set.widgets(screenName: nil, bounds: CGSize(width: 1440, height: 900))
            #expect(widgets.allSatisfy { $0.kind.supportedSizes.contains($0.size) })
            #expect(widgets.allSatisfy { !$0.options.animateArt && !$0.options.neonFlicker })
            let gallery = ThemeWidgetCatalog.widgets(in: set.id)
            #expect(gallery.count == widgets.count)
            for entry in gallery {
                let added = entry.make()
                #expect(added.id != entry.instance.id)
                #expect(added.offset == .zero)
                #expect(try JSONDecoder().decode(WidgetInstance.self, from: JSONEncoder().encode(added)) == added)
            }
        }
    }

    @Test @MainActor func referencedArtworkShipsOffline() async throws {
        let library = ImageLibrary()
        for design in DatasetTwoThemes.all {
            var sources: [ImageSource] = []
            if case .photo(let source) = design.theme.wallpaper { sources.append(source) }
            for widget in design.theme.kitWidgets(screenName: nil, bounds: CGSize(width: 1440, height: 900)) {
                sources.append(contentsOf: widget.options.images)
            }
            for source in sources {
                guard case .bundled = source else { Issue.record("Artwork must be bundled"); continue }
                #expect(try library.fileURL(for: source) != nil)
                #expect(await library.image(for: source, maxPixels: 768) != nil)
            }
        }
    }

    @Test func compactDesktopKeepsCardsApart() throws {
        let bounds = CGSize(width: 640, height: 600)
        for design in DatasetTwoThemes.all {
            let widgets = design.theme.kitWidgets(screenName: nil, bounds: bounds)
            #expect(widgets.count == 3)
            let frames = widgets.map { CGRect(origin: $0.offset, size: $0.footprint) }
            #expect(frames.allSatisfy { $0.minX >= 0 && $0.minY >= 0 && $0.maxX <= bounds.width && $0.maxY <= bounds.height })
            for first in frames.indices {
                for second in frames.indices where first < second {
                    #expect(!frames[first].intersects(frames[second]))
                }
            }
        }
    }
}
