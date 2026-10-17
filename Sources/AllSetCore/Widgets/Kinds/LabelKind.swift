import Foundation

// `WidgetKind.label`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let label = WidgetKindDefinition(
        kind: .label, category: .aesthetic, title: "Label", symbol: "drop.fill",
        summary: "Your name on a perfume label",
        keywords: "label perfume fragrance bottle luxury number no parfum name brand",
        sizes: [.small, .medium], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            instance.material = .dark
            instance.tint = WidgetColor(hex: 0xF3EDE2)
            instance.options.ink = WidgetColor(hex: 0x1A1714)
            instance.options.customText = "MIDNIGHT"
            instance.options.caption = "Nº 07 · EAU DE NUIT"
        })
}
