import Foundation

/// What someone typed into wallpaper search, understood: nicknames spelled
/// out ("jjk" → "jujutsu kaisen", "lambo" → "lamborghini"), filler dropped
/// ("4k wallpaper"), "-word" kept as an exclusion, and whether it names a
/// film, game, anime, car or other pop culture, which free photo libraries
/// don't have but wallpaper collections do.
public struct WallpaperQuery: Equatable, Sendable {
    /// The search as sent to a wallpaper site, exclusions included ("batman -lego").
    public var text: String
    /// What was meant, nicknames spelled out and without exclusions: what
    /// Openverse and the spelling check work from.
    public var meaning: String
    /// Words to leave out, without their minus signs.
    public var excluded: [String]
    /// Names a franchise, character, brand or game.
    public var isPopCulture: Bool
    /// Wallhaven's category switches: general, anime, people. Anime alone for "anime".
    public var categories: String
    /// False for aesthetics Wallhaven has no tag for ("coquette" there is a
    /// car in a video game): those go to Openverse alone.
    public var searchesWallhaven = true
    /// Shown under the search box when the words were changed: "Showing results for jujutsu kaisen".
    public var note: String?

    /// The search for Wallhaven: names of more than one word kept together in
    /// quotes, so "iron man" doesn't also find the Iron Throne.
    public var quotedText: String {
        var result = text
        for phrase in Self.multiWordNames where result.contains(phrase) {
            // Longest first, so "dragon ball z" stays whole; parts of a quoted name are skipped.
            guard !result.contains("\"\(phrase)"), !result.contains("\(phrase)\"") else { continue }
            result = result.replacingOccurrences(of: phrase, with: "\"\(phrase)\"")
        }
        return result
    }

    static let multiWordNames = popCulture.filter { $0.contains(" ") }.sorted { $0.count != $1.count ? $0.count > $1.count : $0 < $1 }

    /// The words without exclusions, for sources that can't exclude.
    public var positive: String {
        text.split(separator: " ").filter { !$0.hasPrefix("-") }.joined(separator: " ")
    }

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
        let expanded = expandAliases(typed)
        var categories = "111"
        if expanded == "anime" || expanded == "manga" { categories = "010" }
        // An aesthetic: Wallhaven's own tag for it, or leave it to Openverse.
        var wallhavenWords = expanded
        var searchesWallhaven = true
        if !isPopCulture(expanded), let key = AestheticSearch.aestheticName(in: expanded) {
            if let tag = wallhavenAesthetics[key] { wallhavenWords = tag } else { searchesWallhaven = false }
        }
        let text = ([wallhavenWords] + excluded.map { "-\($0)" }).filter { !$0.isEmpty }.joined(separator: " ")
        let note = expanded != typed && !expanded.isEmpty ? "Showing results for \u{201C}\(expanded)\u{201D}" : nil
        return WallpaperQuery(text: text, meaning: expanded, excluded: excluded, isPopCulture: isPopCulture(expanded),
                              categories: categories, searchesWallhaven: searchesWallhaven, note: note)
    }

    /// Aesthetics Wallhaven tags well, by the tag it uses.
    static let wallhavenAesthetics: [String: String] = [
        "vaporwave": "vaporwave", "grunge": "grunge", "gothic": "gothic", "goth": "gothic", "kawaii": "kawaii",
        "lofi": "lofi", "dark academia": "dark academia", "cyberpunk": "cyberpunk", "minimalist": "minimalism",
        "dark": "dark", "dark aesthetic": "dark", "night": "night", "midnight": "night", "gotham": "gotham city",
        "retro": "retro", "vintage": "vintage", "emo": "dark", "villain era": "villain",
    ]

    /// Nicknames and run-together names written the way wallpaper sites tag them.
    static let aliases: [String: String] = [
        // Superheroes
        "ironman": "iron man", "spiderman": "spider-man", "spider man": "spider-man", "spidey": "spider-man",
        "cap america": "captain america", "captainamerica": "captain america", "blackpanther": "black panther",
        "dr strange": "doctor strange", "drstrange": "doctor strange", "scarletwitch": "scarlet witch",
        "mcu": "marvel", "marvel cinematic universe": "marvel", "avenger": "avengers", "xmen": "x-men", "x men": "x-men",
        "wonderwoman": "wonder woman", "harley": "harley quinn", "dceu": "dc comics", "dc": "dc comics",
        "the dark knight": "batman", "dark knight": "batman",
        // Anime
        "aot": "attack on titan", "snk": "attack on titan", "shingeki no kyojin": "attack on titan",
        "jjk": "jujutsu kaisen", "kny": "demon slayer", "kimetsu no yaiba": "demon slayer",
        "mha": "my hero academia", "bnha": "my hero academia", "boku no hero academia": "my hero academia",
        "dbz": "dragon ball z", "dbs": "dragon ball super", "dragonball": "dragon ball",
        "csm": "chainsaw man", "hxh": "hunter x hunter", "fma": "fullmetal alchemist", "fmab": "fullmetal alchemist",
        "opm": "one punch man", "onepiece": "one piece", "op": "one piece", "sxf": "spy x family", "spy family": "spy x family",
        "eva": "neon genesis evangelion", "evangelion": "neon genesis evangelion", "ghibli": "studio ghibli",
        "kimi no na wa": "your name", "tokyoghoul": "tokyo ghoul", "deathnote": "death note", "bluelock": "blue lock",
        // Cars and motorsport
        "lambo": "lamborghini", "lamborgini": "lamborghini", "lamborghni": "lamborghini", "ferari": "ferrari",
        "porshe": "porsche", "porche": "porsche", "bugati": "bugatti", "mc laren": "mclaren",
        "beamer": "bmw", "bimmer": "bmw", "merc": "mercedes-benz", "mercedes": "mercedes-benz", "benz": "mercedes-benz",
        "amg": "mercedes-amg", "gtr": "nissan gt-r", "gt-r": "nissan gt-r", "r34": "nissan skyline gt-r r34",
        "rolls royce": "rolls-royce", "rollsroyce": "rolls-royce", "aston": "aston martin", "vette": "corvette",
        "f1": "formula 1", "formula one": "formula 1", "motogp": "motorcycle racing", "bike": "motorcycle", "superbike": "motorcycle",
        "supercars": "supercar", "hypercar": "supercar", "sportscar": "sports car", "jdm cars": "jdm",
        // Games, films and series
        "gta": "grand theft auto", "gta 5": "grand theft auto v", "gta5": "grand theft auto v", "gta v": "grand theft auto v",
        "gta 6": "grand theft auto vi", "gta6": "grand theft auto vi", "rdr2": "red dead redemption 2", "rdr": "red dead redemption",
        "cod": "call of duty", "gow": "god of war", "lol": "league of legends", "cp2077": "cyberpunk 2077",
        "botw": "the legend of zelda", "zelda": "the legend of zelda", "genshin": "genshin impact", "valo": "valorant",
        "mc": "minecraft", "apex": "apex legends", "tlou": "the last of us", "ac": "assassin's creed",
        "lotr": "the lord of the rings", "lord of the rings": "the lord of the rings", "got": "game of thrones",
        "hotd": "house of the dragon", "sw": "star wars", "starwars": "star wars", "hp": "harry potter",
        "st": "stranger things", "bb": "breaking bad", "johnwick": "john wick",
        // Places and things people shorten
        "nyc": "new york city", "la": "los angeles", "sf": "san francisco",
    ]

    /// Spells out a whole query that's a nickname, then any nickname words or pairs inside it.
    static func expandAliases(_ text: String) -> String {
        if let whole = aliases[text] { return whole }
        let words = text.split(separator: " ").map(String.init)
        var result: [String] = []
        var index = 0
        while index < words.count {
            if index + 1 < words.count, let pair = aliases["\(words[index]) \(words[index + 1])"] {
                result.append(pair)
                index += 2
            } else {
                // Nicknames that are also ordinary words or other things ("lol",
                // "got", "op") only count as the whole search.
                let word = words[index]
                result.append(ambiguous.contains(word) && words.count > 1 ? word : aliases[word] ?? word)
                index += 1
            }
        }
        return result.joined(separator: " ")
    }

    static let ambiguous: Set<String> = ["lol", "cod", "got", "eva", "op", "mc", "ac", "la", "hp", "st", "bb", "sw", "sf", "gow",
                                         "apex", "merc", "benz", "bike", "harley", "dc", "amg", "aston", "rdr", "hotd", "valo"]

    /// Franchises, characters, brands and games: what wallpaper collections
    /// are full of and free photo libraries don't have.
    static let popCulture: Set<String> = [
        "marvel", "avengers", "iron man", "spider-man", "captain america", "thor", "hulk", "black panther", "deadpool",
        "wolverine", "venom", "thanos", "loki", "doctor strange", "scarlet witch", "black widow", "guardians of the galaxy",
        "x-men", "dc comics", "batman", "superman", "joker", "wonder woman", "the flash", "harley quinn", "aquaman", "gotham",
        "anime", "manga", "naruto", "sasuke", "itachi", "kakashi", "one piece", "luffy", "zoro", "demon slayer", "tanjiro",
        "nezuko", "jujutsu kaisen", "gojo", "sukuna", "attack on titan", "levi", "eren", "dragon ball", "dragon ball z",
        "dragon ball super", "goku", "vegeta", "my hero academia", "chainsaw man", "makima", "bleach", "death note",
        "tokyo ghoul", "hunter x hunter", "spy x family", "studio ghibli", "your name", "neon genesis evangelion",
        "cowboy bebop", "one punch man", "solo leveling", "berserk", "haikyuu", "blue lock", "frieren", "fullmetal alchemist",
        "lamborghini", "ferrari", "porsche", "bugatti", "mclaren", "bmw", "mercedes-benz", "mercedes-amg", "audi", "nissan gt-r",
        "nissan skyline gt-r r34", "skyline", "supra", "mustang", "corvette", "tesla", "rolls-royce", "bentley", "aston martin",
        "koenigsegg", "pagani", "jdm", "supercar", "sports car", "drift", "formula 1", "motorcycle", "cars", "car",
        "grand theft auto", "grand theft auto v", "grand theft auto vi", "minecraft", "valorant", "league of legends",
        "fortnite", "elden ring", "cyberpunk 2077", "the witcher", "halo", "god of war", "call of duty", "red dead redemption",
        "red dead redemption 2", "the legend of zelda", "pokemon", "mario", "genshin impact", "overwatch", "apex legends",
        "the last of us", "assassin's creed", "star wars", "darth vader", "the lord of the rings", "harry potter",
        "game of thrones", "house of the dragon", "stranger things", "breaking bad", "john wick", "dune", "interstellar",
        "the batman", "peaky blinders", "the matrix", "blade runner", "gaming", "video games", "games",
    ]

    static func isPopCulture(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        if popCulture.contains(text) { return true }
        // Any named thing inside a longer search: "batman rain", "red ferrari".
        let words = text.split(separator: " ").map(String.init)
        for length in stride(from: min(words.count, 4), through: 1, by: -1) where length <= words.count {
            for start in 0...(words.count - length) {
                let phrase = words[start..<(start + length)].joined(separator: " ")
                if phrase.count >= 3, popCulture.contains(phrase) { return true }
            }
        }
        return false
    }

    /// Words wallpaper searches are made of, for fixing typos in names
    /// ("lamborgini", "naurto").
    static let dictionary: Set<String> = {
        var words = AestheticSearch.dictionary
        for phrase in popCulture.union(aliases.values) {
            for word in phrase.split(whereSeparator: { $0 == " " || $0 == "-" }) where word.count >= 3 { words.insert(String(word)) }
        }
        return words
    }()

    /// The query with each unknown word swapped for the nearest known one, or
    /// nil if nothing needed fixing. Only used when a search finds little, so
    /// a rare name that happens to be close to a common word isn't "fixed".
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

    /// Topic chips for the Photos page: the big wallpaper subjects first.
    public static let topics = ["Marvel", "Anime", "Supercars", "JDM", "Gaming", "Batman", "Star Wars", "Space",
                                "Cyberpunk", "Nature", "Minimal", "Dark", "Formula 1", "Studio Ghibli", "Motorcycle"]
}
