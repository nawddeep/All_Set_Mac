import Foundation

// `WidgetKind.terminal`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let terminal = WidgetKindDefinition(
        kind: .terminal, category: .system, title: "Terminal", symbol: "terminal.fill",
        summary: "Live stats in green on black, like a hacker",
        keywords: "terminal hacker code cpu memory stats dark matrix neofetch",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .paper
            instance.tint = WidgetColor(hex: 0x0A0C0A)
            instance.options.ink = WidgetColor(hex: 0x39FF88)
            instance.options.accent = WidgetColor(hex: 0x39FF88)
        })
}
