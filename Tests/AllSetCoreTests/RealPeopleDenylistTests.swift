import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

/// No real person, club or nation is named or targeted anywhere in the app:
/// not in what's shown, not in hidden search tags, not in a comment. A theme
/// may be inspired by a mood or an era, never sold on someone's name.
@Suite struct RealPeopleDenylistTests {
    /// Real people (players, artists), and clubs or nicknames that point at one.
    static let denylist = [
        "ronaldo", "cristiano", "cr7", "messi", "pele", "pelé", "maradona", "neymar", "mbappe", "mbappé", "kylian",
        "beckham", "zidane", "kaka", "kaká", "maldini", "yamal", "haaland", "lana del rey", "del rey", "weeknd",
        "travis scott", "playboi", "carti", "frank ocean", "billie", "eilish", "drake", "kanye", "taylor swift", "sza",
        "harry styles", "xxxtentacion", "real madrid", "barcelona", "barça", "barca", "manchester united", "red devils",
        "ac milan", "rossoneri", "blaugrana", "galáctico", "galactico", "albiceleste", "o rei", "san siro",
        "ultraviolence", "joga bonito", "goat", "g.o.a.t", "ultimate team",
    ]

    /// Every word a theme, its widgets, the gallery or a palette can show or search by.
    static var catalogText: [(String, String)] {
        var texts: [(String, String)] = []
        for set in ThemeLibrary.all {
            texts.append((set.id, "\(set.name) \(set.tagline) \(set.description) \(set.philosophy) \(set.inspiration ?? "") \(set.tags) \(set.searchText)"))
            let widgets = set.widgets(screenName: nil, bounds: CGSize(width: 1136, height: 768))
            texts.append(("\(set.id) widgets", widgets.map(Self.words).joined(separator: " ")))
        }
        for theme in WidgetTheme.fandom {
            texts.append((theme.id, "\(theme.title) \(theme.tagline)"))
        }
        for entry in WidgetCatalog.entries {
            texts.append(("catalog \(entry.id)", "\(entry.title) \(entry.summary) \(entry.keywords) \(Self.words(entry.make()))"))
        }
        for palette in ArtPalette.allCases {
            texts.append(("palette \(palette.id)", "\(palette.title) \(palette.tags)"))
        }
        return texts
    }

    static func words(_ widget: WidgetInstance) -> String {
        let o = widget.options
        return "\(o.customText) \(o.caption) \(o.noteText) \(o.player.name) \(o.player.tagline) \(o.match.home) \(o.match.away) "
            + "\(o.match.competition) \(o.ticket.headline) \(o.ticket.subtitle) \(o.ticket.venue) \(o.ticket.seat) "
            + "\(o.milestone.label) \(o.milestone.caption)"
    }

    static func hits(in text: String) -> [String] {
        let lower = " " + text.lowercased() + " "
        return denylist.filter { name in
            // Whole words only: "goat" is a name, "goatee" isn't.
            lower.range(of: "(?<![\\p{L}\\p{N}])\(NSRegularExpression.escapedPattern(for: name))(?![\\p{L}\\p{N}])",
                        options: .regularExpression) != nil
        }
    }

    @Test func noThemeWidgetOrPaletteNamesARealPerson() {
        for (what, text) in Self.catalogText {
            let found = Self.hits(in: text)
            #expect(found.isEmpty, "\(what) names \(found)")
        }
    }

    @Test func searchingForARealPersonFindsNothing() {
        for name in ["ronaldo", "messi", "lana del rey", "billie eilish", "the weeknd", "travis scott"] {
            #expect(ThemeLibrary.search(name).isEmpty, "\(name) finds a theme")
        }
    }

    /// Hidden tags live in source, so the source is scanned too: nothing slips in as a string or a comment.
    @Test func noSourceFileNamesARealPerson() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources")
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        #expect(files.count > 100)
        // The table that reads ids saved before the rename spells the old ones on purpose.
        let exempt: Set<String> = ["LegacyIdentifiers.swift"]
        for file in files {
            if exempt.contains(file.lastPathComponent) { continue }
            let text = try String(contentsOf: file, encoding: .utf8)
            let found = Self.hits(in: text)
            #expect(found.isEmpty, "\(file.lastPathComponent) names \(found)")
        }
    }

    @Test func theDenylistCatchesWhatItShould() {
        #expect(Self.hits(in: "Inspired by Ronaldo") == ["ronaldo"])
        #expect(Self.hits(in: "a goatee and a messier desk").isEmpty)
        #expect(Self.hits(in: "THE G.O.A.T.").contains("g.o.a.t"))
    }
}

@Suite struct LegacyIdentifierTests {
    @Test func renamedThemesStillLoad() throws {
        let old = "setup." + "se" + "ven"
        #expect(ThemeLibrary.set(old)?.id == "setup.floodlightGold")
        #expect(WidgetTheme.named("se" + "ven")?.id == "floodlightGold")
        #expect(ThemeLibrary.set("setup.americana")?.id == "setup.americana")
        let migrated = LegacyIdentifiers.themeKeys([old: 1, "setup.americana": 2])
        #expect(migrated == ["setup.floodlightGold": 1, "setup.americana": 2])
        // Saved under both: the new key wins.
        #expect(LegacyIdentifiers.themeKeys([old: 1, "setup.floodlightGold": 3]) == ["setup.floodlightGold": 3])
    }

    @Test func renamedPalettesStillDecode() throws {
        let old = try JSONDecoder().decode([ArtPalette].self, from: Data(#"["op"# .utf8) + Data(#"ium","ocean"]"#.utf8))
        #expect(old == [.bloodRed, .ocean])
        #expect(String(decoding: try JSONEncoder().encode(ArtPalette.bloodRed), as: UTF8.self) == #""bloodRed""#)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ArtPalette.self, from: Data(#""nope""#.utf8)) }
    }
}
