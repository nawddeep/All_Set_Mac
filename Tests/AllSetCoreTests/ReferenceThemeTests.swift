import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite struct ReferenceThemeTests {
    @Test func collectionHasTwentyFiveDistinctCompleteDesigns() throws {
        let designs = ReferenceThemes.all
        #expect(designs.count == 25)
        #expect(Set(designs.map { $0.theme.id }).count == 25)
        #expect(ThemeLibrary.sets(in: .desktopEdit).count == 25)
        for design in designs {
            let theme = design.theme
            let set = try #require(ThemeLibrary.set("setup.\(theme.id)"))
            #expect(set.setup?.id == theme.id)
            #expect(set.added == "2026-10-08")
            #expect(set.philosophy == design.philosophy)
            #expect(set.isDark == design.dark)
            #expect(theme.kit.count >= 7)
            #expect(ThemeLibrary.search(theme.title).contains { $0.id == set.id })
            let widgets = set.widgets(screenName: nil, bounds: CGSize(width: 1136, height: 768))
            #expect(widgets.allSatisfy { $0.kind.supportedSizes.contains($0.size) })
            #expect(widgets.allSatisfy { !$0.options.animateArt && !$0.options.neonFlicker })
            let picks = try #require(ThemeCardArt.curated[set.id])
            let indices = [picks.hero] + picks.flankers + [picks.title].compactMap { $0 }
            #expect(indices.allSatisfy { widgets.indices.contains($0) })
            #expect(Set(indices).count == indices.count)
        }
    }

    @Test @MainActor func everyPhotographShipsOfflineAndDecodes() async throws {
        let library = ImageLibrary()
        var sources = Set<ImageSource>()
        for design in ReferenceThemes.all {
            if case .photo(let source) = design.theme.wallpaper { sources.insert(source) }
            for widget in design.theme.kitWidgets(screenName: nil, bounds: CGSize(width: 1136, height: 768)) {
                for source in widget.options.images { sources.insert(source) }
                if let source = widget.options.background { sources.insert(source) }
            }
        }
        #expect(sources.count >= 11)
        for source in sources {
            guard case .bundled = source else { Issue.record("Reference photo is not bundled: \(source)"); continue }
            let file = try #require(library.fileURL(for: source))
            #expect(FileManager.default.fileExists(atPath: file.path))
            #expect(await library.image(for: source, maxPixels: 768) != nil)
        }
    }

    @Test func individualWidgetsKeepTheExactThemeLookAndPersist() throws {
        for design in ReferenceThemes.all {
            let set = try #require(ThemeLibrary.set("setup.\(design.theme.id)"))
            let installed = set.widgets(screenName: nil, bounds: CGSize(width: 1136, height: 768))
            let gallery = ThemeWidgetCatalog.widgets(in: set.id)
            #expect(!gallery.isEmpty)
            for entry in gallery {
                let position = try #require(Int(entry.id.split(separator: "/").last ?? ""))
                let original = installed[position]
                #expect(entry.instance.kind == original.kind && entry.instance.size == original.size)
                #expect(entry.instance.options == original.options)
                #expect(entry.instance.tint == original.tint && entry.instance.material == original.material)
                let added = entry.make()
                #expect(added.id != entry.instance.id)
                #expect(added.offset == .zero && added.screenName == nil)
                let data = try JSONEncoder().encode(added)
                #expect(try JSONDecoder().decode(WidgetInstance.self, from: data) == added)
            }
        }
    }
}
