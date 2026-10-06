import Foundation

/// Forgiving matching for search boxes: ignores case and accents, takes words
/// in any order, and for short names like apps also accepts initials
/// ("vsc" for Visual Studio Code) and letters in order ("pshop" for Photoshop).
public enum SearchMatch {
    /// Lowercased, without accents or extra spaces.
    public static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The query's words, normalized.
    public static func words(_ query: String) -> [Substring] {
        normalize(query).split(whereSeparator: \.isWhitespace)
    }

    /// Whether every word of the query appears somewhere in `text`, in any order.
    public static func containsAll(_ query: String, in text: String) -> Bool {
        let words = words(query)
        guard !words.isEmpty else { return true }
        let haystack = normalize(text)
        return words.allSatisfy { haystack.contains($0) }
    }

    /// How well a short name matches, higher is better; nil if it doesn't.
    /// Exact beats prefix, beats a word's start, beats anywhere inside, beats
    /// initials, beats letters in order.
    public static func score(_ query: String, name: String) -> Int? {
        let needle = normalize(query)
        guard !needle.isEmpty else { return 0 }
        let haystack = normalize(name)
        if haystack == needle { return 1000 }
        if haystack.hasPrefix(needle) { return 900 - haystack.count }
        let nameWords = haystack.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        if nameWords.contains(where: { $0.hasPrefix(needle) }) { return 800 - haystack.count }
        if haystack.contains(needle) { return 700 - haystack.count }
        // Every query word starts some word of the name: "studio vis".
        let queryWords = needle.split(whereSeparator: \.isWhitespace)
        if queryWords.count > 1, queryWords.allSatisfy({ word in nameWords.contains { $0.hasPrefix(word) } }) {
            return 650 - haystack.count
        }
        if needle.count >= 2, initials(of: name).contains(where: { $0.contains(needle) }) {
            return 600 - haystack.count
        }
        if needle.count >= 3, isSubsequence(needle.filter { !$0.isWhitespace }, of: haystack) {
            return 300 - haystack.count
        }
        return nil
    }

    /// Items whose name matches, best first; all of them, in order, for an empty query.
    public static func rank<T>(_ items: [T], by query: String, name: (T) -> String) -> [T] {
        guard !normalize(query).isEmpty else { return items }
        return items.enumerated()
            .compactMap { index, item in score(query, name: name(item)).map { (item, $0, index) } }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.2 < $1.2 }
            .map(\.0)
    }

    /// First letters of each word ("vsc" for Visual Studio Code), and of each
    /// capitalised part ("pp" for PowerPoint).
    static func initials(of name: String) -> [String] {
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let wordInitials = normalize(String(words.compactMap(\.first)))
        var humps = ""
        for word in words {
            for (index, character) in word.enumerated() where index == 0 || character.isUppercase {
                humps.append(character)
            }
        }
        return [wordInitials, normalize(humps)]
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var remaining = needle[...]
        for character in haystack where character == remaining.first {
            remaining = remaining.dropFirst()
            if remaining.isEmpty { return true }
        }
        return remaining.isEmpty
    }
}
