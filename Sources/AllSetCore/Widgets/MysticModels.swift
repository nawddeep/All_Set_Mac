import CoreGraphics
import Foundation

/// A little metal charm hanging on the desktop.
public enum CharmShape: String, Codable, CaseIterable, Identifiable, Sendable {
    case heart, star, cross, wings, butterfly, moon, bow

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .heart: "Heart"
        case .star: "Star"
        case .cross: "Gothic Cross"
        case .wings: "Angel Wings"
        case .butterfly: "Butterfly"
        case .moon: "Crescent"
        case .bow: "Bow"
        }
    }
}

/// The twelve signs, each with its stars drawn as a simple figure.
public enum ZodiacSign: String, Codable, CaseIterable, Identifiable, Sendable {
    case aries, taurus, gemini, cancer, leo, virgo, libra, scorpio, sagittarius, capricorn, aquarius, pisces

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    /// The sign's glyph, drawn as text rather than as an emoji.
    public var glyph: String {
        ["♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓"][index] + "\u{FE0E}"
    }

    public var dates: String {
        ["Mar 21 – Apr 19", "Apr 20 – May 20", "May 21 – Jun 20", "Jun 21 – Jul 22", "Jul 23 – Aug 22", "Aug 23 – Sep 22",
         "Sep 23 – Oct 22", "Oct 23 – Nov 21", "Nov 22 – Dec 21", "Dec 22 – Jan 19", "Jan 20 – Feb 18", "Feb 19 – Mar 20"][index]
    }

    public var element: String {
        ["Fire", "Earth", "Air", "Water"][index % 4]
    }

    /// Three words people use for the sign.
    public var traits: String {
        ["bold · driven · spark", "steady · sensual · loyal", "curious · quick · social", "tender · intuitive · home",
         "radiant · proud · warm", "precise · kind · grounded", "graceful · fair · charming", "intense · magnetic · deep",
         "free · honest · wander", "ambitious · patient · wise", "original · visionary · cool", "dreamy · soft · psychic"][index]
    }

    private var index: Int { Self.allCases.firstIndex(of: self)! }

    /// The sign the sun is in on `date`.
    public static func sign(on date: Date, calendar: Calendar = .current) -> ZodiacSign {
        let parts = calendar.dateComponents([.month, .day], from: date)
        let day = (parts.month ?? 1) * 100 + (parts.day ?? 1)
        // Each sign's first day, from Capricorn's in late December around the year.
        let starts: [(Int, ZodiacSign)] = [(120, .aquarius), (219, .pisces), (321, .aries), (420, .taurus), (521, .gemini),
                                           (621, .cancer), (723, .leo), (823, .virgo), (923, .libra), (1023, .scorpio),
                                           (1122, .sagittarius), (1222, .capricorn)]
        return starts.last { day >= $0.0 }?.1 ?? .capricorn
    }

    /// Its main stars, in a unit square with y pointing down, and the lines between them.
    public var constellation: (stars: [CGPoint], lines: [(Int, Int)]) {
        func p(_ points: [(Double, Double)]) -> [CGPoint] { points.map { CGPoint(x: $0.0, y: $0.1) } }
        func chain(_ count: Int) -> [(Int, Int)] { (0..<(count - 1)).map { ($0, $0 + 1) } }
        switch self {
        case .aries:
            return (p([(0.12, 0.58), (0.48, 0.38), (0.68, 0.42), (0.86, 0.6)]), chain(4))
        case .taurus:
            return (p([(0.1, 0.2), (0.38, 0.46), (0.5, 0.58), (0.62, 0.47), (0.9, 0.28), (0.72, 0.7), (0.28, 0.74)]),
                    [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5), (1, 6)])
        case .gemini:
            return (p([(0.25, 0.1), (0.3, 0.42), (0.26, 0.86), (0.62, 0.12), (0.64, 0.46), (0.72, 0.88)]),
                    [(0, 1), (1, 2), (3, 4), (4, 5), (0, 3), (1, 4)])
        case .cancer:
            return (p([(0.5, 0.45), (0.46, 0.12), (0.2, 0.82), (0.8, 0.76), (0.52, 0.3)]), [(0, 4), (4, 1), (0, 2), (0, 3)])
        case .leo:
            return (p([(0.2, 0.3), (0.3, 0.14), (0.46, 0.2), (0.43, 0.38), (0.36, 0.56), (0.66, 0.5), (0.86, 0.66), (0.6, 0.76)]),
                    [(0, 1), (1, 2), (2, 3), (3, 4), (4, 7), (7, 6), (6, 5), (5, 3)])
        case .virgo:
            return (p([(0.08, 0.3), (0.3, 0.36), (0.46, 0.5), (0.62, 0.4), (0.84, 0.28), (0.5, 0.76), (0.76, 0.82)]),
                    [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5), (5, 6)])
        case .libra:
            return (p([(0.5, 0.14), (0.25, 0.42), (0.75, 0.4), (0.2, 0.76), (0.8, 0.72)]), [(0, 1), (0, 2), (1, 2), (1, 3), (2, 4)])
        case .scorpio:
            return (p([(0.1, 0.18), (0.2, 0.26), (0.3, 0.32), (0.4, 0.46), (0.45, 0.62), (0.56, 0.76), (0.7, 0.84),
                       (0.85, 0.76), (0.9, 0.6), (0.12, 0.42)]),
                    chain(9) + [(1, 9)])
        case .sagittarius:
            return (p([(0.2, 0.52), (0.35, 0.35), (0.5, 0.4), (0.66, 0.28), (0.82, 0.46), (0.66, 0.62), (0.46, 0.72), (0.3, 0.66)]),
                    chain(8) + [(7, 0), (2, 5)])
        case .capricorn:
            return (p([(0.1, 0.3), (0.3, 0.46), (0.55, 0.72), (0.76, 0.6), (0.9, 0.28), (0.5, 0.36)]), chain(6) + [(5, 0)])
        case .aquarius:
            return (p([(0.08, 0.3), (0.24, 0.46), (0.4, 0.3), (0.56, 0.46), (0.72, 0.34), (0.6, 0.7), (0.82, 0.86)]),
                    chain(5) + [(3, 5), (5, 6)])
        case .pisces:
            return (p([(0.1, 0.18), (0.24, 0.34), (0.4, 0.56), (0.55, 0.82), (0.7, 0.62), (0.84, 0.56), (0.92, 0.44), (0.8, 0.38)]),
                    chain(8) + [(7, 5)])
        }
    }
}

/// The twenty-two cards of the major arcana: one is drawn each day.
public struct TarotCard: Equatable, Sendable {
    public let number: Int
    public let name: String
    public let keyword: String
    public let message: String
    /// An SF Symbol for the card's picture.
    public let symbol: String

    public var numeral: String {
        let numerals = ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV",
                        "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI"]
        return numerals[number]
    }

    public static let deck: [TarotCard] = [
        TarotCard(number: 0, name: "The Fool", keyword: "new beginnings", message: "Leap before the plan is perfect.", symbol: "figure.walk"),
        TarotCard(number: 1, name: "The Magician", keyword: "manifestation", message: "You already hold every tool you need.", symbol: "wand.and.stars"),
        TarotCard(number: 2, name: "The High Priestess", keyword: "intuition", message: "The quiet answer is the true one.", symbol: "moon.stars"),
        TarotCard(number: 3, name: "The Empress", keyword: "abundance", message: "Tend what you love and watch it grow.", symbol: "leaf"),
        TarotCard(number: 4, name: "The Emperor", keyword: "structure", message: "Build the walls that let you be free.", symbol: "crown"),
        TarotCard(number: 5, name: "The Hierophant", keyword: "tradition", message: "Learn the rules, then choose your own.", symbol: "building.columns"),
        TarotCard(number: 6, name: "The Lovers", keyword: "harmony", message: "Choose with your whole heart.", symbol: "heart"),
        TarotCard(number: 7, name: "The Chariot", keyword: "willpower", message: "Hold the reins. Keep moving.", symbol: "arrow.up.forward"),
        TarotCard(number: 8, name: "Strength", keyword: "courage", message: "Soft is not the same as weak.", symbol: "flame"),
        TarotCard(number: 9, name: "The Hermit", keyword: "reflection", message: "A little solitude lights the way.", symbol: "lamp.desk"),
        TarotCard(number: 10, name: "Wheel of Fortune", keyword: "cycles", message: "What turns away turns back again.", symbol: "arrow.clockwise.circle"),
        TarotCard(number: 11, name: "Justice", keyword: "balance", message: "Be honest, especially with yourself.", symbol: "scalemass"),
        TarotCard(number: 12, name: "The Hanged Man", keyword: "surrender", message: "Pause. Look again from upside down.", symbol: "hourglass"),
        TarotCard(number: 13, name: "Death", keyword: "transformation", message: "Let the old skin fall away.", symbol: "leaf.arrow.triangle.circlepath"),
        TarotCard(number: 14, name: "Temperance", keyword: "patience", message: "Mix slowly. The blend is the magic.", symbol: "drop"),
        TarotCard(number: 15, name: "The Devil", keyword: "temptation", message: "Notice the chains you could just take off.", symbol: "link"),
        TarotCard(number: 16, name: "The Tower", keyword: "sudden change", message: "What falls down makes room.", symbol: "bolt.fill"),
        TarotCard(number: 17, name: "The Star", keyword: "hope", message: "You are healing more than you know.", symbol: "star"),
        TarotCard(number: 18, name: "The Moon", keyword: "dreams", message: "Trust the path even in the fog.", symbol: "moon"),
        TarotCard(number: 19, name: "The Sun", keyword: "joy", message: "Let yourself be seen today.", symbol: "sun.max"),
        TarotCard(number: 20, name: "Judgement", keyword: "awakening", message: "Answer the call you keep hearing.", symbol: "bell"),
        TarotCard(number: 21, name: "The World", keyword: "completion", message: "A circle closes. Celebrate it.", symbol: "globe"),
    ]

    /// The card for a day: the same all day, a different one tomorrow.
    public static func card(for date: Date, calendar: Calendar = .current) -> TarotCard {
        deck[dayHash(date, calendar: calendar, salt: 17) % deck.count]
    }
}

/// The colors and name of today's aura.
public struct AuraReading: Equatable, Sendable {
    public let name: String
    public let meaning: String
    public let colors: [Int]

    public static let all: [AuraReading] = [
        AuraReading(name: "Lavender", meaning: "calm, dreamy, protected", colors: [0xB9A7FF, 0xF3C6FF, 0x7F9CFF]),
        AuraReading(name: "Rose Gold", meaning: "confident and adored", colors: [0xFFB5A7, 0xFFD6A5, 0xF08BB2]),
        AuraReading(name: "Peach", meaning: "warm, open, social", colors: [0xFFB38A, 0xFFE0B5, 0xFF8FA3]),
        AuraReading(name: "Ocean", meaning: "clear-headed and honest", colors: [0x4FC3F7, 0x9BE7FF, 0x5A6CFF]),
        AuraReading(name: "Emerald", meaning: "growing, healing, lucky", colors: [0x3DDC97, 0xB8F2A0, 0x1FA2A8]),
        AuraReading(name: "Midnight", meaning: "mysterious, deep, intuitive", colors: [0x3B2A8F, 0x8E44FF, 0x0F1B4D]),
        AuraReading(name: "Golden Hour", meaning: "radiant and magnetic", colors: [0xFFC857, 0xFF9F43, 0xFFE8A3]),
        AuraReading(name: "Cherry", meaning: "passionate, bold, alive", colors: [0xFF3B5C, 0xFF8FA3, 0xB0123B]),
        AuraReading(name: "Lilac Haze", meaning: "creative and soft-hearted", colors: [0xD6A4FF, 0xA0C4FF, 0xFFC6FF]),
        AuraReading(name: "Mint", meaning: "fresh start energy", colors: [0x98F5E1, 0xCFFFE5, 0x72DDF7]),
        AuraReading(name: "Sunset", meaning: "nostalgic and romantic", colors: [0xFF6B6B, 0xFFB86B, 0xC06CFF]),
        AuraReading(name: "Pearl", meaning: "pure, gentle, glowing", colors: [0xF5EFFF, 0xDDE7FF, 0xFFE4F1]),
    ]

    public static func reading(for date: Date, calendar: Calendar = .current) -> AuraReading {
        all[dayHash(date, calendar: calendar, salt: 5) % all.count]
    }
}

/// What the magic ball says. Its own answers, a little cheeky.
public enum MagicAnswers {
    public static let all = [
        "Yes, obviously", "The stars say yes", "It's giving yes", "Manifest it", "Trust your gut", "Yes, bestie",
        "The vibes are right", "Go for it", "Absolutely", "Ask after coffee", "Unclear, shake again", "Sleep on it",
        "Not today", "Hard no", "The universe says wait", "Absolutely not", "Maybe later", "Only if it feels right",
    ]
}

/// A number from the day, the same for every call that day.
func dayHash(_ date: Date, calendar: Calendar, salt: Int) -> Int {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    var hash = UInt64(truncatingIfNeeded: salt) &+ 0x9E37_79B9_7F4A_7C15
    for value in [parts.year ?? 0, parts.month ?? 0, parts.day ?? 0] {
        hash ^= UInt64(truncatingIfNeeded: value)
        hash = hash &* 0x100_0000_01b3
        hash ^= hash >> 29
    }
    return Int(hash % 1_000_003)
}
