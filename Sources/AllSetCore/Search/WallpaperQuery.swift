import Foundation

/// What someone typed into photo search, understood: filler dropped
/// ("4k wallpaper"), a few place nicknames spelled out ("nyc"), and "-word"
/// kept as an exclusion. Searches go to Openverse alone, whose free-licensed
/// photos are places and things; franchises, characters and brands aren't in
/// it, and All Set doesn't look for them anywhere else.
public struct WallpaperQuery: Equatable, Sendable {
    /// The words searched for, nicknames spelled out, without exclusions.
    public var meaning: String
    /// Words to leave out, without their minus signs.
    public var excluded: [String]
    /// Shown under the search box when the words were changed: "Showing results for new york city".
    public var note: String?

    public var positive: String { meaning }

    public static func understand(_ raw: String) -> WallpaperQuery {
        var words: [String] = []
        var excluded: [String] = []
        for token in SearchMatch.normalize(raw).split(whereSeparator: \.isWhitespace) {
            if token.hasPrefix("-"), token.count > 1 {
                excluded.append(String(token.dropFirst()))
            } else {
                words.append(String(token))
            }
        }
        let kept = words.filter { !AestheticSearch.fillerWords.contains($0) || $0 == "aesthetic" }
        // All filler ("4k wallpaper") still means something: search it as typed.
        let typed = (kept.isEmpty ? words : kept).joined(separator: " ")
        let expanded = typed.split(separator: " ").map { places[String($0)] ?? String($0) }.joined(separator: " ")
        let note = expanded != typed && !expanded.isEmpty ? "Showing results for \u{201C}\(expanded)\u{201D}" : nil
        return WallpaperQuery(meaning: expanded, excluded: excluded, note: note)
    }

    /// Places people shorten, the only nicknames left once searches stopped
    /// reaching wallpaper sites full of franchises.
    static let places: [String: String] = ["nyc": "new york city", "sf": "san francisco"]

    /// True when a photo's title has none of the excluded words (Openverse can't exclude).
    public func allows(title: String?) -> Bool {
        guard !excluded.isEmpty, let title else { return true }
        let words = Set(SearchMatch.normalize(title).split { !$0.isLetter && !$0.isNumber }.map(String.init))
        return excluded.allSatisfy { !words.contains($0) }
    }

    /// The query with each unknown word swapped for the nearest known one, or
    /// nil if nothing needed fixing. Only used when a search finds little, so
    /// a rare word that happens to be close to a common one isn't "fixed".
    public static func correctedSpelling(of text: String) -> String? {
        let words = SearchMatch.normalize(text).split(whereSeparator: \.isWhitespace).map(String.init)
        var changed = false
        let fixed = words.map { word -> String in
            guard !word.hasPrefix("-") else { return word }
            let replacement = nearestKnownWord(to: word)
            if replacement != word { changed = true }
            return replacement
        }
        return changed ? fixed.joined(separator: " ") : nil
    }

    static func nearestKnownWord(to word: String) -> String {
        let dictionary = AestheticSearch.dictionary
        guard word.count >= 4, !dictionary.contains(word), word.allSatisfy(\.isLetter) else { return word }
        let limit = word.count >= 7 ? 2 : 1
        var best: (word: String, distance: Int)?
        for candidate in dictionary where abs(candidate.count - word.count) <= limit {
            let distance = AestheticSearch.editDistance(word, candidate, limit: limit)
            guard distance <= limit else { continue }
            if let current = best, current.distance < distance || (current.distance == distance && current.word < candidate) { continue }
            best = (candidate, distance)
        }
        return best?.word ?? word
    }

    /// Topic chips for the Photos page: subjects free photo libraries are good at.
    public static let topics = ["Space", "Nature", "Minimal", "Dark", "Cyberpunk", "Mountains", "Ocean", "Night sky",
                                "Neon city", "Architecture", "Flowers", "Motorcycle"]
}
