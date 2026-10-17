import Foundation

// `WidgetKind.retroWindow`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let retroWindow = WidgetKindDefinition(
        kind: .retroWindow, category: .aesthetic, title: "Classic Mac", symbol: "macwindow",
        summary: "The time in a 1984 Mac window",
        keywords: "retro mac macintosh classic 1984 vintage window",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .glass
            instance.options.designTheme = DesignTheme.retroMac.id
        })
}
