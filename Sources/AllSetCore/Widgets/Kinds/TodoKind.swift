import Foundation

// `WidgetKind.todo`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let todo = WidgetKindDefinition(
        kind: .todo, category: .productivity, title: "To-Do", symbol: "checklist",
        summary: "Tick things off. Syncs with the notch's Notes",
        keywords: "tasks checklist reminders list notes",
        sizes: [.small, .medium, .large], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            // Cream paper with soft brown ink.
            instance.material = .paper
            instance.tint = WidgetColor(hex: 0xF4EEE4)
            instance.options.ink = WidgetColor(hex: 0x4A4039)
            instance.options.accent = WidgetColor(hex: 0xB08D6E)
        })
}
