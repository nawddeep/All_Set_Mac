import Foundation

// `WidgetKind.reading`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let reading = WidgetKindDefinition(
        kind: .reading, category: .lifestyle, title: "Reading Progress", symbol: "book.fill",
        summary: "How far through your book you are",
        keywords: "book reading pages progress",
        sizes: [.small, .medium], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            // The everyday widgets start in the native look.
            instance.material = .glass
            instance.options.designTheme = DesignTheme.native.id
        })
}
