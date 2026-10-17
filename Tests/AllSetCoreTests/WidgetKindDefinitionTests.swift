import Foundation
import Testing
@testable import AllSetCore

@Suite struct WidgetKindDefinitionTests {
    @Test func everyKindHasExactlyOneDefinition() {
        let defined = WidgetKindDefinition.all.map(\.kind)
        #expect(defined.count == Set(defined).count, "a kind is registered twice")
        #expect(Set(defined) == Set(WidgetKind.allCases), "a kind has no definition, or a definition has no kind")
        // Gallery order follows the enum.
        #expect(defined == WidgetKind.allCases)
    }

    @Test func definitionsAreSane() {
        for definition in WidgetKindDefinition.all {
            #expect(!definition.title.isEmpty && !definition.symbol.isEmpty && !definition.summary.isEmpty, "\(definition.kind)")
            #expect(definition.sizes.contains(definition.defaultSize), "\(definition.kind) starts at a size it has no layout for")
        }
    }

    /// widgets.json written before widget kinds moved into their own files
    /// (one widget of every kind, as each started) still reads, and writes back the same.
    @Test func savedWidgetsOfEveryKindRoundTrip() throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/widgets-every-kind.json")
        let data = try Data(contentsOf: fixture)
        let widgets = try JSONDecoder().decode([WidgetInstance].self, from: data)
        #expect(Set(widgets.map(\.kind)) == Set(WidgetKind.allCases))
        let again = try JSONDecoder().decode([WidgetInstance].self, from: JSONEncoder().encode(widgets))
        #expect(again == widgets)
        // And a new widget of each kind still starts the way the saved one did.
        for saved in widgets {
            var fresh = WidgetInstance(kind: saved.kind)
            fresh.id = saved.id
            fresh.options.countdownDate = saved.options.countdownDate
            #expect(fresh == saved, "\(saved.kind) starts differently from before")
        }
    }
}
