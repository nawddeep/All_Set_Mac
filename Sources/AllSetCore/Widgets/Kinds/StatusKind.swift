import Foundation

// `WidgetKind.status`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let status = WidgetKindDefinition(
        kind: .status, category: .developer, title: "Status", symbol: "waveform.path.ecg",
        summary: "Whether your sites and APIs are up",
        keywords: "status uptime api server health monitor ping",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            // The everyday widgets start in the native look.
            instance.material = .glass
            instance.options.designTheme = DesignTheme.native.id
        })
}
