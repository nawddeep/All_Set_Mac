import CoreGraphics
import Foundation
import Observation
import OSLog

/// Wallpaper and photo search across two libraries at once:
///
/// - **Wallhaven**, about a million wallpapers tagged by what's in them:
///   films, games, anime, cars, space, art. Safe-for-work only.
/// - **Openverse**, free-licensed photos from the WordPress Photo Directory,
///   Rawpixel and Flickr: strong on aesthetics, nature and everyday things.
///
/// What's typed is understood first (`WallpaperQuery`): nicknames spelled out,
/// filler dropped, "-word" excluded. Names from pop culture go to Wallhaven
/// alone (Openverse has none of them, only things that share the words);
/// everything else asks both and interleaves the pages. An aesthetic
/// ("coquette") becomes concrete Openverse searches, and a search that finds
/// little is retried with its spelling fixed. Requests are paced under each
/// site's anonymous limit and every page is cached for a day (and kept a
/// month, for when the network or a limit says no).
@Observable @MainActor
public final class PhotoSearch {
    public enum Orientation: String, CaseIterable, Identifiable, Sendable {
        case any, landscape, portrait

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .any: "Any Shape"
            case .landscape: "Landscape"
            case .portrait: "Portrait"
            }
        }
    }

    public enum MinimumSize: String, CaseIterable, Identifiable, Sendable {
        case any, hd, uhd, screen

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .any: "Any Size"
            case .hd: "HD and Up"
            case .uhd: "4K"
            case .screen: "Sharp on This Screen"
            }
        }
    }

    public private(set) var query = ""
    public private(set) var results: [WebPhoto] = []
    public private(set) var isSearching = false
    public private(set) var hasMore = false
    public private(set) var errorMessage: String?
    /// How the words were understood, to show under the search box:
    /// "pink bow, pearls, pink roses" or "Showing results for jujutsu kaisen".
    public private(set) var interpretation: String?
    /// Searches that led somewhere, newest first.
    public private(set) var recent: [String] = []

    public var minimumSize = MinimumSize.hd { didSet { if oldValue != minimumSize { restart() } } }
    public var orientation = Orientation.any { didSet { if oldValue != orientation { restart() } } }
    public var sort = Wallhaven.Sort.relevance { didSet { if oldValue != sort { restart() } } }
    /// One of `Wallhaven.colors`, or nil for any.
    public var color: String? { didSet { if oldValue != color { restart() } } }
    /// The main screen's size in pixels, for "Sharp on This Screen".
    public var screenPixels = CGSize(width: 2560, height: 1600)

    public static let suggestions = WallpaperQuery.topics + AestheticSearch.suggestions + [
        "Landscape", "Mountains", "Ocean", "Night sky", "Neon city", "Aesthetic", "Forest",
        "Flowers", "Rain", "Sunset", "Snow", "Desert", "Architecture", "Abstract", "Coffee",
    ]

    /// Curated collections, searched first.
    static let curatedSources = "wordpress,rawpixel"
    /// Wider, noisier, used when the curated search comes back thin.
    static let fallbackSources = "flickr"
    /// Openverse turns away anonymous requests for more than 20 (with a 401).
    static let pageSize = 20

    @ObservationIgnored private var page = 1
    @ObservationIgnored private var understood = WallpaperQuery.understand("")
    /// The concrete Openverse searches behind `query`; pages take turns through them.
    @ObservationIgnored private var searches: [String] = []
    @ObservationIgnored private var usesOpenverse = true
    @ObservationIgnored private var wallhavenMore = true
    @ObservationIgnored private var openverseMore = true
    @ObservationIgnored private var seed = ""
    @ObservationIgnored private var openversePacer = SearchPacer()
    @ObservationIgnored private var wallhavenPacer = SearchPacer(limit: 40)
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Recent pages in memory (older ones are read back from disk).
    @ObservationIgnored private var memoryCache = CostCache<String, CachedPage>(costLimit: 200)
    @ObservationIgnored private let cacheDirectory: URL
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "search")

    private struct CachedPage: Codable {
        var photos: [WebPhoto]
        var pageCount: Int
        var date: Date
    }

    public init(cacheDirectory: URL? = nil, defaults: UserDefaults = .standard) {
        self.cacheDirectory = cacheDirectory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AllSet/Search", isDirectory: true)
        self.defaults = defaults
        recent = defaults.stringArray(forKey: Self.recentKey) ?? []
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }

    /// Starts a search after a short pause in typing. Clearing the text clears results.
    public func search(_ text: String, immediately: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // "Neon  City" and "neon city" are the same search.
        guard SearchMatch.normalize(trimmed) != SearchMatch.normalize(query) || (results.isEmpty && !isSearching) else { return }
        task?.cancel()
        query = trimmed
        page = 1
        results = []
        errorMessage = nil
        hasMore = false
        isSearching = false
        understood = WallpaperQuery.understand(trimmed)
        searches = AestheticSearch.searches(for: understood.meaning)
        // Openverse has no films, games or cars, and can't sort or filter by color.
        usesOpenverse = !understood.isPopCulture && !searches.isEmpty
            && (sort == .relevance && color == nil || !understood.searchesWallhaven)
        wallhavenMore = understood.searchesWallhaven
        openverseMore = usesOpenverse
        seed = String((0..<6).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })
        interpretation = understood.note ?? (usesOpenverse ? AestheticSearch.explanation(for: understood.meaning) : nil)
        guard trimmed.count >= 2, !understood.meaning.isEmpty else { return }
        task = Task { [weak self] in
            if !immediately {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
            }
            await self?.load(page: 1)
        }
    }

    public func loadMore() {
        guard hasMore, !isSearching, !query.isEmpty else { return }
        page += 1
        let next = page
        task = Task { [weak self] in await self?.load(page: next) }
    }

    /// Keeps a search that led somewhere, for the Recent row.
    public func remember(_ text: String? = nil) {
        let text = (text ?? query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2, !Self.suggestions.contains(text) else { return }
        recent = [text] + recent.filter { SearchMatch.normalize($0) != SearchMatch.normalize(text) }.prefix(7)
        defaults.set(recent, forKey: Self.recentKey)
    }

    public func clearRecent() {
        recent = []
        defaults.removeObject(forKey: Self.recentKey)
    }

    static let recentKey = "photoSearch.recent"

    private func restart() {
        let current = query
        query = ""
        search(current, immediately: true)
    }

    private var minimumPixels: CGSize? {
        switch minimumSize {
        case .any: nil
        case .hd: CGSize(width: 1920, height: 1080)
        case .uhd: CGSize(width: 3840, height: 2160)
        case .screen:
            // Turned to match the pictures asked for: a portrait search wants a tall screen.
            orientation == .portrait
                ? CGSize(width: min(screenPixels.width, screenPixels.height), height: max(screenPixels.width, screenPixels.height))
                : CGSize(width: max(screenPixels.width, screenPixels.height), height: min(screenPixels.width, screenPixels.height))
        }
    }

    private var filters: Wallhaven.Filters {
        var filters = Wallhaven.Filters()
        filters.sort = sort
        filters.minimumPixels = minimumPixels
        filters.orientation = orientation
        filters.color = color
        filters.seed = seed
        return filters
    }

    private func load(page: Int) async {
        isSearching = true
        defer { isSearching = false }
        let wantsWallhaven = wallhavenMore
        let wantsOpenverse = usesOpenverse && openverseMore
        async let wallhaven = wantsWallhaven ? wallhavenPage(page, query: understood) : nil
        async let openverse = wantsOpenverse ? openversePage(page) : nil
        var (wide, free) = await (wallhaven, openverse)
        guard !Task.isCancelled else { return }

        // Next to nothing, maybe from a typo: try the nearest real words.
        if page == 1, (wide?.photos.count ?? 0) + (free?.photos.count ?? 0) < 8,
           let corrected = WallpaperQuery.correctedSpelling(of: understood.meaning) {
            let fixed = WallpaperQuery.understand(corrected + understood.excluded.map { " -\($0)" }.joined())
            if fixed.searchesWallhaven, let retry = await wallhavenPage(1, query: fixed), retry.photos.count > (wide?.photos.count ?? 0) {
                guard !Task.isCancelled else { return }
                understood = fixed
                wide = retry
                free = nil
                usesOpenverse = false
                interpretation = "Showing results for \u{201C}\(fixed.meaning)\u{201D}"
            }
        }

        if wantsWallhaven { wallhavenMore = wide.map { page < $0.pageCount && !$0.photos.isEmpty } ?? false }
        if wantsOpenverse { openverseMore = free.map(\.hasMore) ?? false }
        hasMore = wallhavenMore || (usesOpenverse && openverseMore)

        if wide == nil, free == nil, wantsWallhaven || wantsOpenverse {
            errorMessage = lastError ?? "Search failed. Check your connection and try again."
            return
        }
        let merged = Self.interleave(wide?.photos ?? [], free?.photos ?? [])
            .filter { fits($0) }
        let seen = Set(results.map(\.id))
        let fresh = merged.filter { !seen.contains($0.id) }
        results = page == 1 ? fresh : results + fresh
        errorMessage = nil
        lastError = nil
    }

    @ObservationIgnored private var lastError: String?

    /// Two lists, alternating, the rest of the longer one after.
    nonisolated static func interleave(_ a: [WebPhoto], _ b: [WebPhoto]) -> [WebPhoto] {
        var merged: [WebPhoto] = []
        merged.reserveCapacity(a.count + b.count)
        for index in 0..<max(a.count, b.count) {
            if index < a.count { merged.append(a[index]) }
            if index < b.count { merged.append(b[index]) }
        }
        return merged
    }

    /// Big enough and the right shape, where the size is known.
    private func fits(_ photo: WebPhoto) -> Bool {
        guard photo.width > 0, photo.height > 0 else { return true }
        switch orientation {
        case .any: break
        case .landscape: if photo.width < photo.height { return false }
        case .portrait: if photo.height < photo.width { return false }
        }
        guard let minimum = minimumPixels, photo.provider != "wallhaven" else { return true }
        // Free photos are rarely 4K; a little short of the mark still looks sharp.
        return max(photo.width, photo.height) >= Int(max(minimum.width, minimum.height) * 0.75)
    }

    // MARK: Wallhaven

    private func wallhavenPage(_ page: Int, query: WallpaperQuery) async -> (photos: [WebPhoto], pageCount: Int)? {
        let url = Wallhaven.url(for: query, page: page, filters: filters)
        let key = "wh1|\(url.absoluteString)"
        let cacheable = sort != .random
        if cacheable, let cached = cachedPage(key, maxAge: 86_400) { return (cached.photos, cached.pageCount) }
        do {
            let data = try await fetch(url, pacer: \.wallhavenPacer, name: "Wallhaven", limit: "45")
            let decoded = try Wallhaven.decode(data, sort: sort)
            if cacheable { store(CachedPage(photos: decoded.photos, pageCount: decoded.pageCount, date: .now), key: key) }
            return decoded
        } catch {
            if cacheable, let stale = cachedPage(key, maxAge: 30 * 86_400) { return (stale.photos, stale.pageCount) }
            note(error, source: "Wallhaven")
            return nil
        }
    }

    // MARK: Openverse

    /// The next page of the Openverse searches, which take turns page by page.
    private func openversePage(_ page: Int) async -> (photos: [WebPhoto], hasMore: Bool)? {
        guard let request = AestheticSearch.request(forPage: page, of: searches) else { return nil }
        let key = cacheKey(request.query, page: request.page)
        let entry: CachedPage
        if let cached = cachedPage(key, maxAge: 86_400) {
            entry = cached
        } else {
            do {
                var decoded = try await openverse(request.query, page: request.page, sources: Self.curatedSources)
                // Thin results: top up from Flickr, curated photos first.
                if request.page == 1, decoded.photos.count < 12,
                   let wider = try? await openverse(request.query, page: 1, sources: Self.fallbackSources) {
                    let seen = Set(decoded.photos.map(\.id))
                    decoded.photos += wider.photos.filter { !seen.contains($0.id) }
                    decoded.pageCount = max(decoded.pageCount, 1)
                }
                entry = CachedPage(photos: Self.ranked(decoded.photos), pageCount: decoded.pageCount, date: .now)
                store(entry, key: key)
            } catch {
                if let stale = cachedPage(key, maxAge: 30 * 86_400) {
                    entry = stale
                } else {
                    note(error, source: "Openverse")
                    return nil
                }
            }
        }
        // Aesthetic searches go on while any of their searches has pages left.
        let round = (page - 1) / max(searches.count, 1) + 1
        let more = (round < entry.pageCount || page < searches.count) && !(entry.photos.isEmpty && searches.count == 1)
        return (entry.photos, more)
    }

    private func openverse(_ text: String, page: Int, sources: String) async throws -> (photos: [WebPhoto], pageCount: Int) {
        try Self.decode(try await fetch(url(text, page: page, sources: sources), pacer: \.openversePacer, name: "Openverse", limit: "20"))
    }

    // MARK: Requests

    private enum SearchError: LocalizedError {
        case rateLimited(String, String)

        var errorDescription: String? {
            switch self {
            case .rateLimited(let name, let limit): "\(name) allows about \(limit) searches a minute. Try again in a moment."
            }
        }
    }

    /// One request, paced to stay under the site's limit; a 429 with a short
    /// Retry-After is waited out and tried once more.
    private func fetch(_ url: URL, pacer: ReferenceWritableKeyPath<PhotoSearch, SearchPacer>, name: String, limit: String,
                       retrying: Bool = true) async throws -> Data {
        let wait = self[keyPath: pacer].delay(at: .now)
        if wait > 0 { try await Task.sleep(for: .seconds(wait)) }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("AllSet/1.0 (macOS wallpaper app)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            let retryAfter = (http.value(forHTTPHeaderField: "Retry-After")).flatMap(Double.init) ?? 60
            guard retrying, retryAfter <= 15 else { throw SearchError.rateLimited(name, limit) }
            try await Task.sleep(for: .seconds(retryAfter))
            return try await fetch(url, pacer: pacer, name: name, limit: limit, retrying: false)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func note(_ error: Error, source: String) {
        guard !Task.isCancelled, !(error is CancellationError) else { return }
        log.error("\(source, privacy: .public) search failed: \(error.localizedDescription, privacy: .public)")
        lastError = error is SearchError ? error.localizedDescription : "Search failed: \(error.localizedDescription)"
    }

    /// Big photos first, keeping Openverse's order otherwise.
    nonisolated static func ranked(_ photos: [WebPhoto]) -> [WebPhoto] {
        let sharp = photos.filter { max($0.width, $0.height) >= 1600 || $0.width == 0 }
        let soft = photos.filter { !(max($0.width, $0.height) >= 1600 || $0.width == 0) }
        return sharp + soft
    }

    func url(_ text: String, page: Int, sources: String) -> URL {
        var components = URLComponents(string: "https://api.openverse.org/v1/images/")!
        var items = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "source", value: sources),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(Self.pageSize)),
            URLQueryItem(name: "mature", value: "false"),
        ]
        // Flickr's big pool needs the size filter; the curated ones are all large.
        if minimumSize != .any, sources == Self.fallbackSources { items.append(URLQueryItem(name: "size", value: "large")) }
        switch orientation {
        case .any: break
        case .landscape: items.append(URLQueryItem(name: "aspect_ratio", value: "wide"))
        case .portrait: items.append(URLQueryItem(name: "aspect_ratio", value: "tall"))
        }
        components.queryItems = items
        return components.url!
    }

    // MARK: Cache

    private func cacheKey(_ text: String, page: Int) -> String {
        // "v4": keyed by the search actually sent, after aesthetics are expanded.
        "v4|\(SearchMatch.normalize(text))|\(minimumSize != .any)|\(orientation.rawValue)|\(page)"
    }

    private func cachedPage(_ key: String, maxAge: TimeInterval) -> CachedPage? {
        let entry = memoryCache.value(forKey: key) ?? (try? Data(contentsOf: cacheFile(key))).flatMap { try? JSONDecoder().decode(CachedPage.self, from: $0) }
        guard let entry else { return nil }
        memoryCache.insert(entry, forKey: key, cost: 1)
        return entry.date.timeIntervalSinceNow > -maxAge ? entry : nil
    }

    private func store(_ entry: CachedPage, key: String) {
        memoryCache.insert(entry, forKey: key, cost: 1)
        if let data = try? JSONEncoder().encode(entry) {
            try? data.write(to: cacheFile(key), options: .atomic)
        }
    }

    private func cacheFile(_ key: String) -> URL {
        // FNV-1a keeps file names short and safe for any query text.
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        return cacheDirectory.appendingPathComponent(String(format: "%016llx.json", hash))
    }

    // MARK: Decoding

    nonisolated static func decode(_ data: Data) throws -> (photos: [WebPhoto], pageCount: Int) {
        struct Response: Decodable {
            struct Result: Decodable {
                var id: String
                var title: String?
                var creator: String?
                var license: String?
                var license_version: String?
                var width: Int?
                var height: Int?
                var url: String?
                var thumbnail: String?
                var source: String?
                var filetype: String?
            }
            var page_count: Int?
            var results: [Result]
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        var seen = Set<String>()
        let photos = response.results.compactMap { result -> WebPhoto? in
            guard let url = result.url, isWallpaperWorthy(title: result.title, filetype: result.filetype,
                                                          width: result.width, height: result.height),
                  // The same shot is often listed twice under slightly different titles.
                  seen.insert("\(result.width ?? 0)x\(result.height ?? 0)|\(result.creator ?? "")|\((result.title ?? "").prefix(12))").inserted
            else { return nil }
            let license = result.license.map { name in
                name == "cc0" || name == "pdm"
                    ? name.uppercased()
                    : (["CC", name.uppercased(), result.license_version].compactMap { $0 }.joined(separator: " "))
            }
            return WebPhoto(id: result.id, author: result.creator ?? "Unknown", width: result.width ?? 0, height: result.height ?? 0,
                            provider: "openverse", imageURLString: url, thumbnailURLString: result.thumbnail,
                            license: license, title: result.title, origin: result.source)
        }
        return (photos, response.page_count ?? 1)
    }

    /// Words that mark cut-outs, stickers and design assets rather than photos.
    nonisolated static let junkWords: Set<String> = ["png", "sticker", "stickers", "clipart", "transparent", "mockup", "psd", "vector",
                                         "icon", "icons", "template", "logo", "badge", "emoji", "isolated"]
    nonisolated static let junkPhrases = ["clip art", "cut out", "design element", "remixed"]

    /// Big enough for a widget or wallpaper, and a photo or illustration rather than an asset.
    nonisolated static func isWallpaperWorthy(title: String?, filetype: String?, width: Int?, height: Int?) -> Bool {
        if let type = filetype?.lowercased(), ["png", "svg", "gif"].contains(type) { return false }
        if let width, let height, max(width, height) < 1000 { return false }
        let text = (title ?? "").lowercased()
        let words = Set(text.split { !$0.isLetter }.map(String.init))
        return words.isDisjoint(with: junkWords) && !junkPhrases.contains { text.contains($0) }
    }
}
