import Foundation

/// Makes photo search understand how people actually search: by aesthetic
/// ("coquette", "dark academia") rather than by what's in the picture, with
/// typos. Openverse matches titles and tags literally and has no OR or fuzzy
/// operators, so an aesthetic becomes a few concrete searches that pages of
/// results take turns through, and a misspelled word is corrected locally.
public enum AestheticSearch {
    /// Aesthetics people search for by name, and searches that find them.
    /// The first search of each is the strongest.
    static let vocabulary: [String: [String]] = [
        "coquette": ["pink bow", "pearls", "pink roses", "lace", "ballet"],
        "y2k": ["butterfly", "disco ball", "glitter", "chrome"],
        "clean girl": ["minimal interior", "linen", "matcha", "white flowers"],
        "that girl": ["matcha", "yoga", "journal", "morning coffee"],
        "dark academia": ["library books", "old books", "candle", "gothic architecture"],
        "light academia": ["old books", "museum", "classical sculpture", "sunlight window"],
        "cottagecore": ["cottage garden", "wildflowers", "meadow", "picnic"],
        "fairycore": ["mushrooms forest", "moss", "fairy lights", "enchanted forest"],
        "grunge": ["black and white portrait", "concert", "graffiti", "black and white city"],
        "soft girl": ["pink flowers", "pastel", "cherry blossom", "pink sky"],
        "old money": ["tennis", "yacht", "horse riding", "mansion"],
        "vaporwave": ["neon", "palm trees sunset", "roman statue", "retro"],
        "cyberpunk": ["neon city", "tokyo night", "neon sign"],
        "lofi": ["rain window", "cozy room", "night city", "desk lamp"],
        "kawaii": ["pastel", "plush toy", "candy", "cute cat"],
        "baddie": ["neon night", "luxury car", "city night", "sunglasses"],
        "coastal": ["beach house", "seaside", "sailboat", "hydrangea"],
        "coastal grandma": ["beach house", "hydrangea", "seaside", "linen"],
        "boho": ["macrame", "dried flowers", "rattan", "desert"],
        "indie": ["film camera", "vintage car", "road trip", "vinyl records"],
        "gothic": ["cathedral", "dark forest", "black roses", "gothic architecture"],
        "goth": ["cathedral", "dark forest", "black roses", "gothic architecture"],
        "cozy": ["candle", "fireplace", "coffee", "blanket"],
        "aesthetic": ["pastel sky", "flowers", "minimal", "sunset"],
        "dreamy": ["clouds", "pastel sky", "fairy lights"],
        "barbiecore": ["pink", "pink car", "pink flowers"],
        "barbie": ["pink", "pink car", "pink flowers"],
        "preppy": ["tennis", "pink", "beach"],
        "skater": ["skateboard", "graffiti", "skatepark"],
        "anime": ["tokyo", "cherry blossom", "japan street"],
        "clean": ["minimal interior", "white flowers", "linen"],
        "minimalist": ["minimal", "minimal interior", "white"],
        "luxury": ["luxury", "city night", "champagne", "fashion"],
        "night luxe": ["city night", "skyline", "champagne"],
        "vintage": ["vintage", "antique", "film camera"],
        "retro": ["retro", "vintage car", "70s"],
        "dark": ["night city", "dark forest", "black and white portrait", "moon"],
        "dark aesthetic": ["night city", "dark forest", "black and white portrait", "moon"],
        "gotham": ["city night rain", "skyline night", "dark alley", "searchlight"],
        "emo": ["black and white concert", "rain window", "dark room"],
        "villain era": ["dark city night", "black roses", "smoke", "red light"],
        "midnight": ["night city", "moon", "stars", "neon night"],
        "dark feminine": ["black roses", "red lipstick", "candle", "black lace"],
        "night": ["night city", "night sky", "moon", "neon night"],
    ]

    /// Aesthetic chips for the Photos page, in the order people reach for them.
    public static let suggestions = ["Coquette", "Y2K", "Dark", "Clean girl", "Dark academia", "Gotham", "Cottagecore",
                                     "Grunge", "Soft girl", "Lo-fi", "Villain era", "Old money", "Vaporwave"]

    /// Words that describe what someone wants the photo for, not what's in it.
    static let fillerWords: Set<String> = ["wallpaper", "wallpapers", "background", "backgrounds", "aesthetic", "aesthetics",
                                           "pics", "pictures", "photos", "photo", "images", "vibe", "vibes", "core", "mac", "macbook",
                                           "desktop", "pinterest", "hd", "4k"]

    /// The searches to run for what was typed, strongest first: an aesthetic
    /// becomes its concrete searches, anything else is searched as typed
    /// (without filler words like "wallpaper").
    public static func searches(for query: String) -> [String] {
        let normalized = SearchMatch.normalize(query)
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !normalized.isEmpty else { return [] }
        if let match = aesthetic(in: normalized) { return match }
        let kept = normalized.split(separator: " ").filter { !fillerWords.contains(String($0)) }
        // "Aesthetic wallpaper" alone: all filler, which still means something.
        if kept.isEmpty { return vocabulary["aesthetic"] ?? [normalized] }
        return [kept.joined(separator: " ")]
    }

    /// The aesthetic named in `text`, with or without filler words or spaces
    /// ("coquette wallpaper", "lofi", "lo fi").
    static func aesthetic(in text: String) -> [String]? {
        if let exact = vocabulary[text] { return exact }
        let words = text.split(separator: " ").map(String.init)
        let kept = words.filter { !fillerWords.contains($0) }
        let joined = kept.joined(separator: " ")
        if let match = vocabulary[joined] ?? vocabulary[kept.joined()] { return match }
        // "aesthetic" is filler unless it's all there is; "core" joins as in "cottage core".
        let squashed = words.filter { $0 != "aesthetic" && $0 != "wallpaper" }.joined()
        return vocabulary[squashed]
    }

    /// The name of the aesthetic in `text`, as the vocabulary knows it ("lo fi" → "lofi").
    static func aestheticName(in text: String) -> String? {
        if vocabulary[text] != nil { return text }
        let words = text.split(separator: " ").map(String.init)
        let kept = words.filter { !fillerWords.contains($0) }
        for candidate in [kept.joined(separator: " "), kept.joined(), words.filter { $0 != "aesthetic" && $0 != "wallpaper" }.joined()]
            where vocabulary[candidate] != nil {
            return candidate
        }
        return nil
    }

    /// What an aesthetic search is looking for, to show under the search box:
    /// "pink bow, pearls, pink roses". Nil for plain searches.
    public static func explanation(for query: String) -> String? {
        let normalized = SearchMatch.normalize(query).replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard let searches = aesthetic(in: normalized) else { return nil }
        return searches.prefix(4).joined(separator: ", ")
    }

    /// Which search and page of it a page of results comes from: searches
    /// take turns, so every page mixes in something new.
    public static func request(forPage page: Int, of searches: [String]) -> (query: String, page: Int)? {
        guard !searches.isEmpty, page >= 1 else { return nil }
        return (searches[(page - 1) % searches.count], (page - 1) / searches.count + 1)
    }

    // MARK: Spelling

    /// Words photo searches are made of, for fixing typos.
    static let dictionary: Set<String> = {
        var words = Set<String>()
        for phrase in vocabulary.keys + vocabulary.values.flatMap({ $0 }) + commonWords {
            for word in phrase.split(separator: " ") where word.count >= 3 { words.insert(String(word)) }
        }
        return words
    }()

    static let commonWords = [
        "landscape", "mountains", "mountain", "ocean", "beach", "night", "sky", "stars", "galaxy", "space", "moon", "sun",
        "sunset", "sunrise", "forest", "trees", "flowers", "flower", "roses", "tulips", "daisies", "lavender", "rain",
        "snow", "winter", "summer", "autumn", "spring", "fall", "desert", "architecture", "abstract", "coffee", "city",
        "cities", "street", "bridge", "lake", "river", "waterfall", "island", "tropical", "palm", "clouds", "cloudy",
        "storm", "lightning", "aurora", "neon", "lights", "minimal", "pastel", "pink", "purple", "blue", "green", "black",
        "white", "gold", "golden", "silver", "red", "orange", "yellow", "brown", "beige", "cream", "vintage", "retro",
        "cat", "cats", "dog", "dogs", "puppy", "kitten", "horse", "bird", "birds", "butterfly", "animals", "fashion",
        "portrait", "people", "friends", "love", "hearts", "heart", "paris", "tokyo", "london", "york", "italy",
        "japan", "france", "travel", "road", "car", "cars", "train", "books", "library", "music", "guitar", "piano",
        "vinyl", "records", "camera", "film", "art", "painting", "museum", "sculpture", "texture", "marble", "wood",
        "paper", "glitter", "sparkle", "crystal", "pearls", "ribbon", "lace", "candle", "cozy", "bedroom", "interior",
        "kitchen", "cafe", "bakery", "dessert", "cake", "strawberry", "cherry", "fruit", "garden", "meadow", "field",
        "wildflowers", "sunflowers", "cherry", "blossom", "sakura", "skyline", "skyscraper", "night", "evening",
        "aesthetic", "dreamy", "grunge", "gothic", "cathedral", "castle", "church", "temple", "mosque", "fireworks",
    ]

    /// The query with each unknown word swapped for the nearest known one,
    /// or nil if nothing needed fixing: "mountians" → "mountains".
    public static func correctedSpelling(of query: String) -> String? {
        let words = SearchMatch.normalize(query).split(whereSeparator: \.isWhitespace).map(String.init)
        var changed = false
        var fixed: [String] = []
        for word in words {
            let replacement = nearestKnownWord(to: word)
            if replacement != word { changed = true }
            fixed.append(replacement)
        }
        return changed ? fixed.joined(separator: " ") : nil
    }

    /// The closest dictionary word within one edit (two for long words); the
    /// word itself when it's known, short, or nothing is close.
    static func nearestKnownWord(to word: String) -> String {
        guard word.count >= 4, !dictionary.contains(word), word.allSatisfy(\.isLetter) else { return word }
        let limit = word.count >= 7 ? 2 : 1
        var best: (word: String, distance: Int)?
        for candidate in dictionary where abs(candidate.count - word.count) <= limit {
            let distance = editDistance(word, candidate, limit: limit)
            guard distance <= limit else { continue }
            if let current = best, current.distance < distance || (current.distance == distance && current.word < candidate) { continue }
            best = (candidate, distance)
        }
        return best?.word ?? word
    }

    /// Levenshtein distance with adjacent swaps ("teh" → "the" is one), giving
    /// up past `limit`.
    static func editDistance(_ a: String, _ b: String, limit: Int) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty || b.isEmpty { return max(a.count, b.count) }
        var previousPrevious = [Int](repeating: 0, count: b.count + 1)
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            var rowBest = current[0]
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    current[j] = min(current[j], previousPrevious[j - 2] + 1)
                }
                rowBest = min(rowBest, current[j])
            }
            if rowBest > limit { return limit + 1 }
            (previousPrevious, previous, current) = (previous, current, previousPrevious)
        }
        return previous[b.count]
    }

    // MARK: Art

    /// Art from the built-in library that fits the words, best first: found
    /// instantly, with no network, while photos load.
    public static func art(matching query: String, limit: Int = 12) -> [ArtPiece] {
        let words = SearchMatch.words(query).map(String.init).filter { !fillerWords.contains($0) || $0 == "aesthetic" }
        guard !words.isEmpty else { return [] }
        func score(_ text: String, _ tags: String) -> Int {
            let haystack = SearchMatch.normalize("\(text) \(tags)").split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            return words.reduce(0) { total, word in
                total + (haystack.contains { $0 == word } ? 3 : haystack.contains { $0.hasPrefix(word) && word.count >= 3 } ? 1 : 0)
            }
        }
        let styles = ArtStyle.allCases.map { ($0, score($0.title, $0.tags)) }
        let palettes = ArtPalette.allCases.map { ($0, score($0.title, $0.tags)) }
        guard styles.contains(where: { $0.1 > 0 }) || palettes.contains(where: { $0.1 > 0 }) else { return [] }
        var pieces: [(ArtPiece, Int)] = []
        for (style, styleScore) in styles {
            for (palette, paletteScore) in palettes where styleScore + paletteScore > 0 {
                // A style that matches wants a palette that does too, and the other way round.
                let total = styleScore * 2 + paletteScore * 2 + (styleScore > 0 && paletteScore > 0 ? 4 : 0)
                pieces.append((ArtPiece(style: style, palette: palette), total))
            }
        }
        // Best first; among equals, vary the style so the row isn't twelve of one.
        var seenStyles: [ArtStyle: Int] = [:]
        return pieces
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.id < $1.0.id }
            .map { piece, score -> (ArtPiece, Int) in
                let repeats = seenStyles[piece.style, default: 0]
                seenStyles[piece.style] = repeats + 1
                return (piece, score - repeats * 3)
            }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.id < $1.0.id }
            .prefix(limit)
            .map(\.0)
    }
}

/// Keeps searches under Openverse's anonymous limit (about 20 a minute) by
/// telling each request how long to wait, instead of letting it fail.
public struct SearchPacer: Sendable {
    public let limit: Int
    public let window: TimeInterval
    private(set) var recent: [Date] = []

    public init(limit: Int = 18, window: TimeInterval = 60) {
        self.limit = limit
        self.window = window
    }

    /// Seconds to wait before a request made `now`, recording it as sent then.
    public mutating func delay(at now: Date) -> TimeInterval {
        recent.removeAll { now.timeIntervalSince($0) >= window }
        recent.sort()
        // No more than `limit` in any window: go once the one `limit` back has aged out.
        var send = now
        if recent.count >= limit {
            send = max(now, recent[recent.count - limit].addingTimeInterval(window))
        }
        recent.append(send)
        return send.timeIntervalSince(now)
    }
}
