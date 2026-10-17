import Foundation

// `WidgetKind.wordArt`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let wordArt = WidgetKindDefinition(
        kind: .wordArt, category: .aesthetic, title: "Word Art", symbol: "textformat",
        summary: "Words in chrome, gold, neon or glitter",
        keywords: "word art chrome gold neon glitter fire ice holographic text script name",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: true, paintsOwnBackground: true,
        defaults: { instance in
            // Letters straight on the wallpaper.
            instance.material = .clear
            instance.tint = WidgetColor(hex: 0xFF3CAC)
            instance.options.customText = "Legend"
            instance.options.textStyle = .script
        })
}
