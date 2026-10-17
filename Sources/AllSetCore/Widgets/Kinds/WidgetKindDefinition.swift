import Foundation

/// What every widget kind is: its name, look in the gallery, sizes and
/// defaults. Each kind's definition is in its own file in this folder;
/// adding a kind is a `WidgetKind` case, that file, and a line in `all`.
public struct WidgetKindDefinition: Sendable {
    public let kind: WidgetKind
    public let category: WidgetCategory
    public let title: String
    public let symbol: String
    public let summary: String
    /// Extra words search matches it by.
    public let keywords: String
    /// The sizes it has layouts for.
    public let sizes: [WidgetSize]
    public let defaultSize: WidgetSize
    /// Drawn straight onto the desktop, with no card behind it.
    public let isFreeform: Bool
    /// Paints its own background, so card styles don't apply.
    public let paintsOwnBackground: Bool
    /// How a new widget of this kind starts: its card material, tint and options.
    public let defaults: @Sendable (inout WidgetInstance) -> Void

    /// Every kind, in gallery order. One line per kind.
    public static let all: [WidgetKindDefinition] = [
        .clock,
        .calendar,
        .weather,
        .system,
        .battery,
        .nowPlaying,
        .note,
        .photo,
        .ambient,
        .quote,
        .countdown,
        .lockScreen,
        .vinyl,
        .moon,
        .daylight,
        .polaroids,
        .todo,
        .focus,
        .stopwatch,
        .shortcuts,
        .sticker,
        .neon,
        .terminal,
        .dots,
        .metric,
        .date,
        .nextEvent,
        .goals,
        .habits,
        .reading,
        .github,
        .status,
        .airQuality,
        .retroWindow,
        .enso,
        .magazine,
        .jersey,
        .playerCard,
        .pitch,
        .scoreboard,
        .milestone,
        .cassette,
        .vhs,
        .visualizer,
        .ticket,
        .wordArt,
        .spiral,
        .charm,
        .label,
        .aura,
        .tarot,
        .zodiac,
        .eightBall,
        .candle,
    ]

    private static let byKind = Dictionary(uniqueKeysWithValues: all.map { ($0.kind, $0) })

    /// A kind's definition. Every case has one (`WidgetKindDefinitionTests`).
    public static func of(_ kind: WidgetKind) -> WidgetKindDefinition {
        guard let definition = byKind[kind] else {
            preconditionFailure("WidgetKind.\(kind.rawValue) has no WidgetKindDefinition: add its file and a line in `all`")
        }
        return definition
    }
}
