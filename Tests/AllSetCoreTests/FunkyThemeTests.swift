import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import AllSetCore

@Suite struct FunkyThemeTests {
    @Test func everySuppliedDesignIsARealInstallableSet() throws {
        let count = FunkyThemes.all.count
        #expect(count >= 20)
        #expect(FunkyThemes.layouts.count == count)
        #expect(ThemeLibrary.sets(in: .funkyThemes).count == count)
        #expect(Set(FunkyThemes.all.map { $0.theme.id }).count == count)
        for design in FunkyThemes.all {
            let set = try #require(ThemeLibrary.set("setup.\(design.theme.id)"))
            #expect(set.added == "2026-10-18")
            #expect(set.collections.contains(.funkyThemes))
            #expect(set.isDark == design.dark)
            #expect(ThemeLibrary.search(set.name).contains { $0.id == set.id })
            let placements = try #require(FunkyThemes.layouts[design.theme.id])
            let widgets = set.widgets(screenName: nil, bounds: CGSize(width: 1136, height: 768))
            #expect(widgets.count == placements.count)
            #expect(widgets.count >= 3, "\(design.theme.id) is too small to be a set")
            #expect(widgets.contains { [.clock, .date, .calendar].contains($0.kind) })
            #expect(widgets.allSatisfy { $0.kind.supportedSizes.contains($0.size) })
            #expect(widgets.allSatisfy { !$0.options.animateArt && !$0.options.neonFlicker })
            // Stretch squeezes the drawing on the desktop, so it stays too small to see.
            #expect(widgets.allSatisfy { (0.92...1.08).contains($0.stretch) })
            #expect(widgets.allSatisfy { WidgetInstance.scaleRange.contains($0.scale) })
            // Laid out where traced, not snapped to the grid or squeezed into the bounds.
            #expect(zip(widgets, placements).allSatisfy { $0.offset == $1.origin })
            let picks = try #require(ThemeCardArt.curated[set.id])
            #expect(widgets.indices.contains(picks.hero))
        }
    }

    @Test func widgetsLandOnTheCardsDrawnForThemOnAnyScreen() throws {
        let screens: [(screen: CGSize, visible: CGRect)] = [
            (CGSize(width: 1440, height: 900), CGRect(x: 0, y: 37, width: 1440, height: 863)),
            (CGSize(width: 1512, height: 982), CGRect(x: 0, y: 38, width: 1512, height: 870)),
            (CGSize(width: 1920, height: 1080), CGRect(x: 0, y: 25, width: 1920, height: 1055)),
            (CGSize(width: 2560, height: 1600), CGRect(x: 0, y: 25, width: 2560, height: 1575)),
        ]
        for design in FunkyThemes.all {
            let id = design.theme.id
            let placements = try #require(FunkyThemes.layouts[id])
            let layout = design.theme.kitWidgets(screenName: nil, bounds: CGSize(width: 10_000, height: 10_000))
            for (screen, visible) in screens {
                let fit = FunkyThemes.fitted(layout, id: id, screen: screen, visible: visible)
                let cover = max(screen.width / FunkyThemes.picture.width, screen.height / FunkyThemes.picture.height)
                let crop = CGPoint(x: (screen.width - FunkyThemes.picture.width * cover) / 2,
                                   y: (screen.height - FunkyThemes.picture.height * cover) / 2)
                let frames = fit.widgets.map {
                    CGRect(x: visible.minX + $0.offset.x * fit.scale, y: visible.minY + $0.offset.y * fit.scale,
                           width: $0.footprint.width * fit.scale, height: $0.footprint.height * fit.scale)
                }
                for (frame, placement) in zip(frames, placements) {
                    // The widget's centre is where the wallpaper's card is, as the picture is cropped to fill.
                    let traced = CGPoint(x: placement.origin.x + placement.size.dimensions.width * placement.scale / 2,
                                         y: placement.origin.y + placement.size.dimensions.height * placement.scale * placement.stretch / 2)
                    // Unless it came in from an edge the screen's shape cut off.
                    let nudgedAcross = frame.minX < 0.5 || abs(frame.maxX - screen.width) < 0.5
                    let nudgedDown = abs(frame.minY - visible.minY) < 0.5 || abs(frame.maxY - screen.height) < 0.5
                    #expect(nudgedAcross || abs(frame.midX - (crop.x + traced.x * cover)) < 1, "\(id) drifts across")
                    #expect(nudgedDown || abs(frame.midY - (crop.y + traced.y * cover)) < 1, "\(id) drifts down")
                    #expect(abs(frame.midX - (crop.x + traced.x * cover)) < 60, "\(id) is far from its card")
                    #expect(abs(frame.midY - (crop.y + traced.y * cover)) < 60, "\(id) is far from its card")
                    #expect(frame.minX >= 0 && frame.maxX <= screen.width && frame.minY >= visible.minY && frame.maxY <= screen.height,
                            "\(id) leaves the screen at \(screen)")
                }
                // A widget the screen's shape pushed in from an edge can touch its neighbour.
                let moved = frames.map { frame in
                    frame.minX < 0.5 || abs(frame.maxX - screen.width) < 0.5
                        || abs(frame.minY - visible.minY) < 0.5 || abs(frame.maxY - screen.height) < 0.5
                }
                for (index, rect) in frames.enumerated() where !moved[index] {
                    for (other, otherMoved) in zip(frames, moved).dropFirst(index + 1) where !otherMoved {
                        // Cards a few points apart touch once each widget reaches to its card's edge.
                        #expect(!rect.insetBy(dx: 12 * fit.scale, dy: 12 * fit.scale).intersects(other), "\(id) overlaps at \(screen)")
                    }
                }
            }
        }
    }

    @Test func galleryEntriesAreTheThemesOwnWidgets() throws {
        for design in FunkyThemes.all {
            let set = try #require(ThemeLibrary.set("setup.\(design.theme.id)"))
            let widgets = set.widgets(screenName: nil, bounds: CGSize(width: 1136, height: 768))
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

    @Test @MainActor func wallpapersAreBundledAtFullDesktopResolution() async throws {
        let library = ImageLibrary()
        for design in FunkyThemes.all {
            guard case .photo(let wallpaper) = design.theme.wallpaper else { Issue.record("Missing wallpaper"); continue }
            guard case .bundled = wallpaper else { Issue.record("Remote wallpaper in supplied theme"); continue }
            let file = try #require(library.fileURL(for: wallpaper))
            let source = try #require(CGImageSourceCreateWithURL(file as CFURL, nil))
            let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
            #expect(properties[kCGImagePropertyPixelWidth] as? Int == 2880)
            #expect(properties[kCGImagePropertyPixelHeight] as? Int == 1800)
            #expect(await library.image(for: wallpaper, maxPixels: 768) != nil)
            for widget in design.theme.kitWidgets(screenName: nil, bounds: CGSize(width: 1136, height: 768)) {
                #expect(widget.options.images.isEmpty)
                #expect(widget.options.background == nil)
            }
        }
    }
}
