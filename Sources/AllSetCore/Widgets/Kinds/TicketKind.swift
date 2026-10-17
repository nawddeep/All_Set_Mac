import Foundation

// `WidgetKind.ticket`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let ticket = WidgetKindDefinition(
        kind: .ticket, category: .music, title: "Ticket", symbol: "ticket.fill",
        summary: "A ticket stub counting down to the show",
        keywords: "ticket concert tour gig show event match stub",
        sizes: [.small, .medium], defaultSize: .medium,
        isFreeform: true, paintsOwnBackground: true,
        defaults: { instance in
            // They paint their own backgrounds.
            instance.material = .dark
        })
}
