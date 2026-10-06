import CoreGraphics
import Foundation

/// Wallhaven (wallhaven.cc): about a million wallpapers (films, games, anime,
/// cars, art, space) searchable by tag, free and without a key. Only its
/// safe-for-work collection is ever asked for. Pictures are uploaded by its
/// community and belong to their creators, so each links back to its page.
/// Anonymous use allows 45 requests a minute.
public enum Wallhaven {
    /// How results are ordered.
    public enum Sort: String, CaseIterable, Identifiable, Sendable {
        case relevance, popular, top, newest, random

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .relevance: "Best Match"
            case .popular: "Most Loved"
            case .top: "Top This Year"
            case .newest: "Newest"
            case .random: "Shuffle"
            }
        }

        var parameter: String {
            switch self {
            case .relevance: "relevance"
            case .popular: "favorites"
            case .top: "toplist"
            case .newest: "date_added"
            case .random: "random"
            }
        }
    }

    /// The colors Wallhaven can filter by (it only knows these).
    public static let colors = ["660000", "cc0000", "ea4c88", "993399", "663399", "333399", "0066cc", "0099cc", "66cccc",
                                "77cc33", "336600", "cccc33", "ffcc33", "ff6600", "996633", "000000", "999999", "ffffff"]

    public struct Filters: Hashable, Sendable {
        public var sort: Sort = .relevance
        /// Smallest acceptable size in pixels; nil for any.
        public var minimumPixels: CGSize?
        public var orientation: PhotoSearch.Orientation = .any
        /// One of `colors`.
        public var color: String?
        /// Keeps shuffled pages in one order while paging.
        public var seed: String?

        public init() {}
    }

    static func url(for query: WallpaperQuery, page: Int, filters: Filters) -> URL {
        var components = URLComponents(string: "https://wallhaven.cc/api/v1/search")!
        var items = [
            URLQueryItem(name: "q", value: query.categories == "010" && query.positive == "anime" ? "" : query.quotedText),
            URLQueryItem(name: "categories", value: query.categories),
            URLQueryItem(name: "purity", value: "100"),
            URLQueryItem(name: "sorting", value: filters.sort.parameter),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "page", value: String(page)),
        ]
        if filters.sort == .top { items.append(URLQueryItem(name: "topRange", value: "1y")) }
        if filters.sort == .random, let seed = filters.seed { items.append(URLQueryItem(name: "seed", value: seed)) }
        if let size = filters.minimumPixels {
            items.append(URLQueryItem(name: "atleast", value: "\(Int(size.width))x\(Int(size.height))"))
        }
        switch filters.orientation {
        case .any: break
        case .landscape: items.append(URLQueryItem(name: "ratios", value: "landscape"))
        case .portrait: items.append(URLQueryItem(name: "ratios", value: "portrait"))
        }
        if let color = filters.color { items.append(URLQueryItem(name: "colors", value: color)) }
        components.queryItems = items
        return components.url!
    }

    /// A page of results, best first, and how many pages there are.
    static func decode(_ data: Data, sort: Sort) throws -> (photos: [WebPhoto], pageCount: Int) {
        struct Response: Decodable {
            struct Result: Decodable {
                struct Thumbs: Decodable {
                    var large: String?
                    var original: String?
                    var small: String?
                }
                var id: String
                var purity: String?
                var category: String?
                var dimension_x: Int?
                var dimension_y: Int?
                var favorites: Int?
                var path: String?
                var thumbs: Thumbs?
            }
            struct Meta: Decodable {
                var last_page: Int?
            }
            var data: [Result]
            var meta: Meta?
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        var results = response.data.filter { $0.purity == nil || $0.purity == "sfw" }
        if sort == .relevance {
            // Within a page Wallhaven's match order is rough: lift the pictures
            // people saved most, without moving anything far from where it was.
            results = results.enumerated().sorted { a, b in
                score(a.offset, a.element.favorites) > score(b.offset, b.element.favorites)
            }.map(\.element)
        }
        let photos = results.compactMap { result -> WebPhoto? in
            guard let path = result.path, path.hasPrefix("https://") else { return nil }
            return WebPhoto(id: result.id, author: "Wallhaven", width: result.dimension_x ?? 0, height: result.dimension_y ?? 0,
                            provider: "wallhaven", imageURLString: path,
                            thumbnailURLString: result.thumbs?.large ?? result.thumbs?.original,
                            title: result.category, origin: "wallhaven")
        }
        return (photos, response.meta?.last_page ?? 1)
    }

    /// Place in the page, nudged up by how many people saved it.
    private static func score(_ position: Int, _ favorites: Int?) -> Double {
        -Double(position) + log2(Double(max(favorites ?? 0, 0)) + 1) * 0.6
    }

    /// The picture's page on Wallhaven, for credit and the uploader's source.
    public static func pageURL(id: String) -> URL? {
        URL(string: "https://wallhaven.cc/w/\(id)")
    }
}
