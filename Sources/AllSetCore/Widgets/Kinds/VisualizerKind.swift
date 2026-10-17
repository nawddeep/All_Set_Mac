import Foundation

// `WidgetKind.visualizer`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let visualizer = WidgetKindDefinition(
        kind: .visualizer, category: .music, title: "Visualizer", symbol: "waveform",
        summary: "Glowing bars that dance to your music",
        keywords: "visualizer audio music bars equalizer glow spectrum",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            instance.material = .dark
            instance.tint = WidgetColor(hex: 0x7CFF6B)
        })
}
