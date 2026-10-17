import Foundation

// `WidgetKind.github`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    // Designed for the extra-large size too.
    static let github = WidgetKindDefinition(
        kind: .github, category: .developer, title: "GitHub", symbol: "chevron.left.forwardslash.chevron.right",
        summary: "Contributions, pull requests, issues and CI",
        keywords: "github git code developer contributions pull requests issues ci actions repository",
        sizes: [.small, .medium, .large, .extraLarge], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            // The everyday widgets start in the native look.
            instance.material = .glass
            instance.options.designTheme = DesignTheme.native.id
        })
}
