import Foundation

// `WidgetKind.focus`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let focus = WidgetKindDefinition(
        kind: .focus, category: .productivity, title: "Focus Timer", symbol: "timer",
        summary: "Pomodoro sessions, with breaks in between",
        keywords: "pomodoro timer study productivity break",
        sizes: [.small, .medium], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .frosted
            instance.tint = WidgetColor(hex: 0x1E1B22)
            instance.options.accent = WidgetColor(hex: 0xF7C6D9)
        })
}
