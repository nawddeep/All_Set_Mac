import Foundation

/// A generative artwork: a drawing style in a color palette. Drawn in code, so
/// the library works offline, costs nothing to ship, and can animate.
public struct ArtPiece: Codable, Hashable, Identifiable, Sendable {
    public var style: ArtStyle
    public var palette: ArtPalette

    public init(style: ArtStyle, palette: ArtPalette) {
        self.style = style
        self.palette = palette
    }

    public var id: String { "\(style.rawValue).\(palette.rawValue)" }
    public var title: String { "\(style.title) · \(palette.title)" }

    /// Every combination: the whole art library.
    public static let all: [ArtPiece] = ArtStyle.allCases.flatMap { style in
        ArtPalette.allCases.map { ArtPiece(style: style, palette: $0) }
    }
}

public enum ArtStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case blobs
    case aurora
    case sunset
    case waves
    case synthwave
    case dunes
    case stars
    case bokeh
    case lava
    case rain
    case orbits
    case stripes
    case clouds
    case hearts
    case spiral
    case leopard
    case film
    case checker
    case skyline
    case embers
    case stadium
    case palms
    case smoke

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .blobs: "Glow"
        case .aurora: "Aurora"
        case .sunset: "Sunset"
        case .waves: "Waves"
        case .synthwave: "Synthwave"
        case .dunes: "Dunes"
        case .stars: "Starry Night"
        case .bokeh: "Bokeh"
        case .lava: "Lava Lamp"
        case .rain: "Rain"
        case .orbits: "Orbits"
        case .stripes: "Retro Stripes"
        case .clouds: "Cloud Nine"
        case .hearts: "Floating Hearts"
        case .spiral: "Hypnotic"
        case .leopard: "Leopard"
        case .film: "Film Grain"
        case .checker: "Checkerboard"
        case .skyline: "Night Skyline"
        case .embers: "Embers"
        case .stadium: "Stadium Lights"
        case .palms: "Palm Sunset"
        case .smoke: "Smoke"
        }
    }

    /// Words people search for that should find this style.
    public var tags: String {
        switch self {
        case .blobs: "glow gradient soft blur"
        case .aurora: "northern lights night"
        case .sunset: "sun evening retro"
        case .waves: "ocean sea water beach coastal"
        case .synthwave: "retro 80s vaporwave outrun grid neon"
        case .dunes: "desert sand hills"
        case .stars: "night sky space galaxy"
        case .bokeh: "lights blur bubbles"
        case .lava: "lava lamp groovy 70s"
        case .rain: "rain storm lofi cozy"
        case .orbits: "space planets circles"
        case .stripes: "retro 70s rainbow"
        case .clouds: "clouds sky dreamy heaven cloud nine sparkle stars angel"
        case .hearts: "hearts love coquette cute valentine romantic girly"
        case .spiral: "spiral hypnotic grunge trippy psychedelic swirl"
        case .leopard: "leopard cheetah animal print diva baddie y2k"
        case .film: "film grain vintage grunge noir analog sepia old"
        case .checker: "checkerboard checkered y2k indie skater retro"
        case .skyline: "city skyline night rain dark gotham batman vigilante searchlight noir cyberpunk buildings"
        case .embers: "embers fire sparks candle dark academia fireflies gothic warm cozy night"
        case .stadium: "stadium football soccer floodlights pitch match night camera flashes sport"
        case .palms: "palm trees sunset california beach americana summer coastal retro la"
        case .smoke: "smoke haze mist rap trap moody dark concert fog"
        }
    }
}

public enum ArtPalette: String, Codable, CaseIterable, Identifiable, Sendable {
    case sunset
    case ocean
    case aurora
    case neon
    case midnight
    case lavender
    case forest
    case desert
    case mono
    case pastel
    case peach
    case candy
    case sky
    case blush
    case coquette
    case diva
    case mocha
    case matcha
    case cherry
    case shadow
    case ember
    case emerald
    // Football
    case floodlit
    case redGreen
    case skyWhite
    case canary
    case royal
    case miami
    case classicRed
    case rossoneri
    case blaugrana
    case bleu
    case hallOfFame
    // Music
    case americana
    case coastline
    case slime
    case rage
    case sadBlue
    case crimson
    case opium
    case blond

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .floodlit: "Floodlit"
        case .redGreen: "Red & Green"
        case .skyWhite: "Sky & White"
        case .sadBlue: "Sad Blue"
        case .classicRed: "Classic Red"
        case .hallOfFame: "Hall of Fame"
        default: rawValue.capitalized
        }
    }

    /// Background top, background bottom, then three accents.
    public var colors: [WidgetColor] {
        let hex: [Int] = switch self {
        case .sunset: [0x2E1437, 0x8A2E5A, 0xFF6B6B, 0xFFA36C, 0xFFD56B]
        case .ocean: [0x021B33, 0x0B4F6C, 0x01BAEF, 0x20BF9F, 0x9EE6F9]
        case .aurora: [0x050A1F, 0x0B1E3F, 0x00F5A0, 0x00D9F5, 0x8E2DE2]
        case .neon: [0x0D0221, 0x261447, 0xFF3864, 0x2DE2E6, 0xF6019D]
        case .midnight: [0x020024, 0x1B1464, 0x3A0CA3, 0x4CC9F0, 0xF72585]
        case .lavender: [0x1E1A33, 0x4B3F72, 0xB8A1FF, 0xE4C1F9, 0xFFD6F6]
        case .forest: [0x0B1D14, 0x1E3D2F, 0x5C946E, 0xA9D18E, 0xE3F2C1]
        case .desert: [0x3D1E0F, 0xA0522D, 0xE9A15D, 0xF4D19B, 0xFFF1D6]
        case .mono: [0x0E0E10, 0x2A2A2E, 0x8E8E93, 0xC7C7CC, 0xF2F2F7]
        case .pastel: [0xFDEFF9, 0xE0E7FF, 0xFFB5C2, 0xA5CCFF, 0xC9B6FF]
        case .peach: [0xFFE8D6, 0xFFC4A8, 0xFF7E67, 0xFFB38A, 0xFFF5E4]
        case .candy: [0xFFE3EC, 0xFFD1E8, 0xFF5F8F, 0xFFC371, 0x9B8CFF]
        case .sky: [0xA9C8EE, 0xE4EEF9, 0xFFFFFF, 0xFFF4E6, 0x7FA6DA]
        case .blush: [0xF6BFD2, 0xFBE3EA, 0xF08CAE, 0xD9A7E0, 0xFFF1F5]
        case .coquette: [0xFFF4F6, 0xFFE0E8, 0xF4A6B8, 0xE0557A, 0xB3243F]
        case .diva: [0x6B4A2E, 0x3E2A19, 0x0F0906, 0x4E331D, 0xFF8CC6]
        case .mocha: [0x2B211A, 0x4A3A2E, 0xC8A97E, 0xE8DCC8, 0x8C6E54]
        case .matcha: [0xDCE3D0, 0xF3F1E7, 0x9CAF88, 0xC9D4B8, 0x6E7F5E]
        case .cherry: [0x14070A, 0x3B0A14, 0xE0314B, 0xFF8FA3, 0xFFD6DD]
        case .shadow: [0x05070A, 0x151B24, 0x2A3442, 0xFFD23F, 0x7D8B9C]
        case .ember: [0x0B0604, 0x241008, 0xFF6A2B, 0xFFB347, 0xFF3D00]
        case .emerald: [0x07120D, 0x14261D, 0x3E6B55, 0xC9A45C, 0xE8DCC0]
        case .floodlit: [0x05070D, 0x0B1424, 0x1E7A3A, 0xBFD8FF, 0xEAF2FF]
        case .redGreen: [0x12040A, 0x2A0A12, 0x0B5D3B, 0xC8102E, 0xE8C15A]
        case .skyWhite: [0x06101F, 0x10233F, 0x75AADB, 0xFFFFFF, 0xE8C15A]
        case .canary: [0x031B0E, 0x06301A, 0x009C3B, 0xFFDF00, 0x3E7BFF]
        case .royal: [0x0A0C14, 0x1A1E2E, 0x2C3350, 0xE8C15A, 0xFFFFFF]
        case .miami: [0x0B0B0F, 0x1E0E18, 0xF4A6C6, 0xFF5FA2, 0xFFD1E3]
        case .classicRed: [0x0C0204, 0x2A0508, 0xD0021B, 0xFF4D4D, 0xFFFFFF]
        case .rossoneri: [0x0A0303, 0x2A0A0A, 0xC8102E, 0xFF6B4A, 0x3A3A3A]
        case .blaugrana: [0x070A1F, 0x1A0B2E, 0x004D98, 0xA50044, 0xEDBB00]
        case .bleu: [0x040A1F, 0x0C1A3F, 0x1C2A5A, 0xE8C15A, 0xFFFFFF]
        case .hallOfFame: [0x050403, 0x14100A, 0xE8C15A, 0xFFF1C1, 0x8A6A1F]
        case .americana: [0x1B2A4A, 0xE7A6A1, 0xB3202A, 0xF3C9A0, 0xFFF1D6]
        case .coastline: [0x9CC3E6, 0xF6D5C8, 0x3B6E9E, 0xF7B7A3, 0xFFF4E3]
        case .slime: [0x030503, 0x0A140A, 0x7CFF3F, 0xB6FF3B, 0x2B5E1A]
        case .rage: [0x0E0806, 0x2A1810, 0xC46A2B, 0xE3B26B, 0x8A3B12]
        case .sadBlue: [0x02040C, 0x0A1633, 0x2F6BFF, 0x8FB3FF, 0xFFFFFF]
        case .crimson: [0x080102, 0x220307, 0xE11D2A, 0xFF5A5F, 0xFFD1D1]
        case .opium: [0x000000, 0x120000, 0x8B0000, 0xFF1A1A, 0xE0E0E0]
        case .blond: [0xF2E6D0, 0xF7C98B, 0xF28C28, 0xE35D1C, 0xFFF3DC]
        }
        return hex.map(WidgetColor.init(hex:))
    }

    /// Words people search for that should find this palette.
    public var tags: String {
        switch self {
        case .sunset: "orange warm golden"
        case .ocean: "blue sea teal"
        case .aurora: "green night"
        case .neon: "neon cyberpunk pink blue"
        case .midnight: "dark night blue purple"
        case .lavender: "purple lilac soft"
        case .forest: "green nature cottagecore"
        case .desert: "brown sand warm boho"
        case .mono: "black white grey gray noir grunge monochrome minimal"
        case .pastel: "pastel soft kawaii"
        case .peach: "peach orange soft"
        case .candy: "candy pink sweet kawaii"
        case .sky: "blue baby blue sky cloud clean"
        case .blush: "pink blush soft girl rose"
        case .coquette: "pink coquette bow ribbon red cute"
        case .diva: "leopard brown black diva baddie"
        case .mocha: "brown coffee sepia vintage latte"
        case .matcha: "green sage clean girl minimal matcha"
        case .cherry: "red cherry black dark y2k gothic goth"
        case .shadow: "black dark night yellow gotham batman vigilante stealth"
        case .ember: "orange fire warm dark ember"
        case .emerald: "green gold dark academia forest emerald"
        case .floodlit: "stadium floodlights night football green"
        case .redGreen: "red green gold football portugal seven"
        case .skyWhite: "sky blue white stripes football ten"
        case .canary: "yellow green blue samba football flair"
        case .royal: "white gold navy royal galactic football"
        case .miami: "pink black miami football"
        case .classicRed: "red white classic football night"
        case .rossoneri: "red black stripes flares milan football"
        case .blaugrana: "blue garnet claret gold football young"
        case .bleu: "navy blue gold france paris football"
        case .hallOfFame: "gold black legends hall of fame football"
        case .americana: "americana vintage cherry red navy dusty pink hollywood sad"
        case .coastline: "coastal pastel ocean california beach soft blue"
        case .slime: "neon green black slime alt"
        case .rage: "brown orange rage desert earth cactus"
        case .sadBlue: "blue sad night emo rain"
        case .crimson: "red neon crimson night casino"
        case .opium: "red black punk gothic opium vamp"
        case .blond: "orange cream summer blond warm"
        }
    }

    /// Light backgrounds need dark text on top.
    public var isLight: Bool {
        let top = colors[0]
        return 0.299 * top.red + 0.587 * top.green + 0.114 * top.blue > 0.6
    }
}

extension WidgetColor {
    public init(hex: Int) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// Short lines for the Quote widget, written for All Set.
public enum Affirmations {
    public static let all = [
        "Slow progress is still progress.",
        "Do the next small thing.",
        "Rest is part of the work.",
        "You've handled hard days before.",
        "Make it simple, then make it good.",
        "Curiosity beats certainty.",
        "Small steps, every day.",
        "Be where your feet are.",
        "Done is a kind of beautiful.",
        "Breathe in. Begin again.",
        "The best time is now.",
        "Stay soft, stay strong.",
        "Keep the promises you make to yourself.",
        "Focus on what you can move.",
        "Good things take a while.",
        "Your pace is the right pace.",
        "Create more than you scroll.",
        "Clear desk, clear mind.",
        "One tab at a time.",
        "Today is a fresh page.",
        "Kindness is a superpower.",
        "Aim for better, not perfect.",
        "Enjoy the process.",
        "You are allowed to take up space.",
        "Let it be easy.",
        "Tiny wins add up.",
        "Drink some water.",
        "Make today count, gently.",
        "Build the thing you wish existed.",
        "Quiet mind, bright ideas.",
        "Good things are coming.",
        "It comes in waves.",
        "You can create the life you want.",
        "Protect your peace.",
        "Romanticize your life.",
        "Main character energy.",
        "Everything is working out for me.",
        "Glow up in progress.",
        "Soft life, strong mind.",
        "Success comes from what you do consistently.",
    ]

    /// Changes every hour, the same for everyone looking at that hour.
    public static func line(at date: Date) -> String {
        all[Int(date.timeIntervalSince1970 / 3600) % all.count]
    }
}
