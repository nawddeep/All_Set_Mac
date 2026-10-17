import Foundation

// `WidgetKind.countdown`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let countdown = WidgetKindDefinition(
        kind: .countdown, category: .time, title: "Countdown", symbol: "hourglass",
        summary: "Days until something good",
        keywords: "days event birthday trip",
        sizes: [.small, .medium, .large], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .art
            instance.options.art = ArtPiece(style: .sunset, palette: .peach)
            instance.options.animateArt = false
            instance.options.countdownDate = Calendar.current.date(byAdding: .day, value: 30, to: Calendar.current.startOfDay(for: .now))
        })
}
