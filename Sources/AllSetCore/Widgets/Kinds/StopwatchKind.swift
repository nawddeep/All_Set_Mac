import Foundation

// `WidgetKind.stopwatch`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let stopwatch = WidgetKindDefinition(
        kind: .stopwatch, category: .time, title: "Stopwatch", symbol: "stopwatch.fill",
        summary: "Time anything, to the hundredth",
        keywords: "timer lap time",
        sizes: [.small, .medium], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .paper
            instance.tint = WidgetColor(hex: 0xEFECE8)
            instance.options.ink = WidgetColor(hex: 0x3A3633)
            instance.options.accent = WidgetColor(hex: 0x3A3633)
        })
}
