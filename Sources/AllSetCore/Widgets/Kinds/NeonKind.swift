import Foundation

// `WidgetKind.neon`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let neon = WidgetKindDefinition(
        kind: .neon, category: .aesthetic, title: "Neon Sign", symbol: "lightbulb.fill",
        summary: "Your words in glowing tubes, flickering now and then",
        keywords: "neon sign glow light words text dark cyberpunk",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            // Tubes glowing right on the wallpaper.
            instance.material = .clear
            instance.tint = WidgetColor(hex: 0xFF3CAC)
            instance.options.customText = "good vibes only"
            instance.options.textStyle = .script
        })
}
