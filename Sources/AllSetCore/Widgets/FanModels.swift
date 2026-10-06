import Foundation

// Settings for the football and music widgets: shirts, player cards, match
// boards, tickets, visualizers and word art. Every field decodes on its own,
// so saved widgets survive new fields.

/// How a football shirt is patterned.
public enum KitPattern: String, Codable, CaseIterable, Identifiable, Sendable {
    case plain, stripes, hoops, sash, halves, pinstripes, chevron

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .plain: "Plain"
        case .stripes: "Stripes"
        case .hoops: "Hoops"
        case .sash: "Sash"
        case .halves: "Halves"
        case .pinstripes: "Pinstripes"
        case .chevron: "Chevron"
        }
    }
}

/// The finish of a player card.
public enum CardFinish: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Gold foil, the classic.
    case gold
    /// Pearl white and pale gold, for the all-time greats.
    case legend
    /// Black with a gold edge.
    case night
    /// Dark glass lit by neon.
    case neon
    /// Shifting rainbow foil.
    case holo

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .gold: "Gold"
        case .legend: "Legend"
        case .night: "Night"
        case .neon: "Neon"
        case .holo: "Holo"
        }
    }
}

public enum Formation: String, Codable, CaseIterable, Identifiable, Sendable {
    case f433 = "4-3-3"
    case f442 = "4-4-2"
    case f4231 = "4-2-3-1"
    case f352 = "3-5-2"

    public var id: String { rawValue }
    public var title: String { rawValue }

    /// Rows of outfield players from defence to attack.
    public var lines: [Int] {
        switch self {
        case .f433: [4, 3, 3]
        case .f442: [4, 4, 2]
        case .f4231: [4, 2, 3, 1]
        case .f352: [3, 5, 2]
        }
    }
}

/// A player: for the shirt and the player card.
public struct PlayerDetails: Codable, Equatable, Sendable {
    public var name = "LEGEND"
    public var number = 7
    public var position = "ST"
    public var rating = 91
    /// A short line under the name on the card: "PORTUGAL", "SINCE 2003".
    public var tagline = ""
    /// Pace, shooting, passing, dribbling, defending, physical.
    public var stats = [89, 93, 81, 87, 35, 77]
    public var pattern: KitPattern = .plain
    public var primary = WidgetColor(hex: 0xC8102E)
    public var secondary = WidgetColor(hex: 0x0B5D3B)
    /// Number, collar and cuffs.
    public var trim = WidgetColor(hex: 0xE8C15A)
    public var finish: CardFinish = .gold

    public static let statNames = ["PAC", "SHO", "PAS", "DRI", "DEF", "PHY"]

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PlayerDetails()
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? d.name
        number = (try? c.decodeIfPresent(Int.self, forKey: .number)) ?? d.number
        position = (try? c.decodeIfPresent(String.self, forKey: .position)) ?? d.position
        rating = (try? c.decodeIfPresent(Int.self, forKey: .rating)) ?? d.rating
        tagline = (try? c.decodeIfPresent(String.self, forKey: .tagline)) ?? d.tagline
        stats = (try? c.decodeIfPresent([Int].self, forKey: .stats)).flatMap { $0.count == 6 ? $0 : nil } ?? d.stats
        pattern = (try? c.decodeIfPresent(KitPattern.self, forKey: .pattern)) ?? d.pattern
        primary = (try? c.decodeIfPresent(WidgetColor.self, forKey: .primary)) ?? d.primary
        secondary = (try? c.decodeIfPresent(WidgetColor.self, forKey: .secondary)) ?? d.secondary
        trim = (try? c.decodeIfPresent(WidgetColor.self, forKey: .trim)) ?? d.trim
        finish = (try? c.decodeIfPresent(CardFinish.self, forKey: .finish)) ?? d.finish
    }
}

/// A match: for the scoreboard and the pitch.
public struct MatchDetails: Codable, Equatable, Sendable {
    /// Three-letter codes read best: "POR", "ARG".
    public var home = "HOME"
    public var away = "AWAY"
    public var homeColor = WidgetColor(hex: 0xC8102E)
    public var awayColor = WidgetColor(hex: 0x75AADB)
    /// Nil until the match has a score; before then the board counts down.
    public var homeScore: Int?
    public var awayScore: Int?
    public var competition = "MATCHDAY"
    public var kickoff: Date?
    public var formation: Formation = .f433

    public init() {}

    public var hasScore: Bool { homeScore != nil || awayScore != nil }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = MatchDetails()
        home = (try? c.decodeIfPresent(String.self, forKey: .home)) ?? d.home
        away = (try? c.decodeIfPresent(String.self, forKey: .away)) ?? d.away
        homeColor = (try? c.decodeIfPresent(WidgetColor.self, forKey: .homeColor)) ?? d.homeColor
        awayColor = (try? c.decodeIfPresent(WidgetColor.self, forKey: .awayColor)) ?? d.awayColor
        homeScore = try? c.decodeIfPresent(Int.self, forKey: .homeScore)
        awayScore = try? c.decodeIfPresent(Int.self, forKey: .awayScore)
        competition = (try? c.decodeIfPresent(String.self, forKey: .competition)) ?? d.competition
        kickoff = try? c.decodeIfPresent(Date.self, forKey: .kickoff)
        formation = (try? c.decodeIfPresent(Formation.self, forKey: .formation)) ?? d.formation
    }
}

/// A ticket stub: a concert, a match, a trip.
public struct TicketDetails: Codable, Equatable, Sendable {
    public var headline = "WORLD TOUR"
    public var subtitle = "Live on stage"
    public var venue = "The Arena"
    public var seat = "GA"
    public var date: Date?

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = TicketDetails()
        headline = (try? c.decodeIfPresent(String.self, forKey: .headline)) ?? d.headline
        subtitle = (try? c.decodeIfPresent(String.self, forKey: .subtitle)) ?? d.subtitle
        venue = (try? c.decodeIfPresent(String.self, forKey: .venue)) ?? d.venue
        seat = (try? c.decodeIfPresent(String.self, forKey: .seat)) ?? d.seat
        date = try? c.decodeIfPresent(Date.self, forKey: .date)
    }
}

/// A big number worth celebrating: goals, streams, days sober, pages read.
public struct MilestoneDetails: Codable, Equatable, Sendable {
    public var value = 900
    public var suffix = "+"
    public var label = "CAREER GOALS"
    public var caption = "and counting"

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = MilestoneDetails()
        value = (try? c.decodeIfPresent(Int.self, forKey: .value)) ?? d.value
        suffix = (try? c.decodeIfPresent(String.self, forKey: .suffix)) ?? d.suffix
        label = (try? c.decodeIfPresent(String.self, forKey: .label)) ?? d.label
        caption = (try? c.decodeIfPresent(String.self, forKey: .caption)) ?? d.caption
    }
}

public enum VisualizerStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Bars rising from the floor.
    case bars
    /// Bars mirrored around a center line, like a waveform.
    case mirror
    /// Bars around a circle.
    case ring

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

/// The surface of a Word Art widget's letters.
public enum WordArtFinish: String, Codable, CaseIterable, Identifiable, Sendable {
    case chrome, gold, neon, glitter, fire, ice, holo

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .chrome: "Chrome"
        case .gold: "Gold Foil"
        case .neon: "Neon"
        case .glitter: "Glitter"
        case .fire: "Fire"
        case .ice: "Ice"
        case .holo: "Holographic"
        }
    }
}

/// Shirt colors to start from, named for their colors, not for any club.
public struct KitPreset: Identifiable, Sendable {
    public let title: String
    public let pattern: KitPattern
    public let primary: WidgetColor
    public let secondary: WidgetColor
    public let trim: WidgetColor

    public var id: String { title }

    init(_ title: String, _ pattern: KitPattern, _ primary: Int, _ secondary: Int, _ trim: Int) {
        self.title = title
        self.pattern = pattern
        self.primary = WidgetColor(hex: primary)
        self.secondary = WidgetColor(hex: secondary)
        self.trim = WidgetColor(hex: trim)
    }

    public static let all: [KitPreset] = [
        KitPreset("Red & Green", .plain, 0xC8102E, 0x0B5D3B, 0xE8C15A),
        KitPreset("Royal White", .plain, 0xF4F2EC, 0xE8C15A, 0xC9A13B),
        KitPreset("Sky Stripes", .stripes, 0x75AADB, 0xFFFFFF, 0x1C2A4A),
        KitPreset("Canary", .plain, 0xFFD400, 0x009C3B, 0x0B3D91),
        KitPreset("Pink & Black", .plain, 0xF4A6C6, 0x111111, 0x111111),
        KitPreset("Claret & Blue", .stripes, 0xA50044, 0x004D98, 0xEDBB00),
        KitPreset("Black & White", .stripes, 0x111111, 0xF2F2F2, 0xE8C15A),
        KitPreset("Midnight", .plain, 0x0B1026, 0x2F6BFF, 0xE8C15A),
        KitPreset("Orange Hoops", .hoops, 0xFF6A13, 0x111111, 0xFFFFFF),
        KitPreset("Forest Sash", .sash, 0x0E3B2E, 0xF2E6C9, 0xF2E6C9),
        KitPreset("Classic Red", .plain, 0xD0021B, 0xFFFFFF, 0xFFFFFF),
        KitPreset("Red & Black Stripes", .stripes, 0xC8102E, 0x111111, 0xFFFFFF),
        KitPreset("Navy Bleu", .plain, 0x1C2A5A, 0xFFFFFF, 0xE8C15A),
    ]
}

extension PlayerDetails {
    public mutating func apply(_ kit: KitPreset) {
        pattern = kit.pattern
        primary = kit.primary
        secondary = kit.secondary
        trim = kit.trim
    }
}
