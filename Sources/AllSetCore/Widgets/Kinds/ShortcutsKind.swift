import Foundation

// `WidgetKind.shortcuts`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let shortcuts = WidgetKindDefinition(
        kind: .shortcuts, category: .productivity, title: "Shortcuts", symbol: "square.grid.3x2.fill",
        summary: "Cute icons that open your apps and sites",
        keywords: "apps launcher links icons favorites",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            // Icons right on the wallpaper.
            instance.material = .clear
            instance.tint = WidgetColor(hex: 0xFAFAFA)
        })
}
