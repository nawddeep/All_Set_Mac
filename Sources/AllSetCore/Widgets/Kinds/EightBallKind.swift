import Foundation

// `WidgetKind.eightBall`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let eightBall = WidgetKindDefinition(
        kind: .eightBall, category: .mystic, title: "Magic Ball", symbol: "8.circle.fill",
        summary: "Ask a question, shake for an answer",
        keywords: "magic 8 ball eight fortune question answer yes no shake decide",
        sizes: [.small, .medium], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            instance.material = .dark
            instance.tint = WidgetColor(hex: 0x0B0B12)
            instance.options.accent = WidgetColor(hex: 0x3D5AFE)
        })
}
