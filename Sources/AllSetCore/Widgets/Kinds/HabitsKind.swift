import Foundation

// `WidgetKind.habits`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let habits = WidgetKindDefinition(
        kind: .habits, category: .productivity, title: "Habit Tracker", symbol: "checkmark.seal.fill",
        summary: "Streaks for the things you do every day",
        keywords: "habits streak tracker routine daily",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            // The everyday widgets start in the native look.
            instance.material = .glass
            instance.options.designTheme = DesignTheme.native.id
        })
}
