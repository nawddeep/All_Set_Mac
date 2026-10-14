import Foundation
import Testing
@testable import AllSetCore

@Suite struct ThemeWidgetCatalogTests {
    @Test func everyThemeContributesItsWidgets() {
        let all = ThemeWidgetCatalog.all
        #expect(Set(all.map(\.setID)) == Set(ThemeLibrary.all.map(\.id)))
        #expect(Set(all.map(\.id)).count == all.count)
        for set in ThemeLibrary.all {
            let own = ThemeWidgetCatalog.widgets(in: set.id)
            #expect(!own.isEmpty, "\(set.id) has no widgets")
            #expect(own.count <= set.includedWidgets.count)
        }
        print("THEME WIDGETS", all.count)
    }

    @Test func aThemeWidgetKeepsItsLookAndGetsAFreshIdentity() throws {
        let setup = try #require(ThemeLibrary.all.first { $0.setup != nil })
        let widget = try #require(ThemeWidgetCatalog.widgets(in: setup.id).first)
        #expect(widget.instance.options.font == setup.setup?.font)
        let first = widget.make(), second = widget.make()
        #expect(first.id != second.id)
        #expect(first.kind == widget.instance.kind && first.size == widget.instance.size)
    }

    @Test func newTextOptionsRoundTripAndOldLayoutsStillRead() throws {
        var widget = WidgetInstance(kind: .system, size: .small)
        widget.options.font = .serif
        widget.options.cornerRadius = 12
        widget.options.textCase = .uppercase
        widget.options.renamedText = ["CPU": "Brain"]
        widget.options.footnote = "my mac"
        widget.options.footnoteStyle.alignment = .trailing
        let data = try JSONEncoder().encode(widget)
        let back = try JSONDecoder().decode(WidgetInstance.self, from: data)
        #expect(back == widget)
        #expect(back.options.text("CPU") == "Brain" && back.options.text("GPU") == "GPU")
        // A layout saved before these options existed.
        let old = #"{"id":"11111111-0000-0000-0000-000000000001","kind":"clock","size":"medium","offset":[0,0],"options":{"use24Hour":true}}"#
        let decoded = try JSONDecoder().decode(WidgetInstance.self, from: Data(old.utf8))
        #expect(decoded.options.use24Hour && decoded.options.font == nil && decoded.options.footnote.isEmpty)
    }
}
