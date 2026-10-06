import Foundation

/// One video in a wallpaper library that lives outside All Set (a folder or a
/// drive), described by `scripts/wallpaper_library.py import`. It plays from
/// where it is; nothing is copied, except a transcoded copy for the few files
/// the Mac can't play efficiently as they are.
public struct LibraryVideo: Codable, Identifiable, Hashable, Sendable {
    /// Whether it may be shown, and to whom.
    public enum Status: String, Codable, Sendable {
        /// Who made it and whether it may be shared are unknown: it plays on
        /// this Mac from the owner's own files, and is never bundled or published.
        case quarantined
        /// Licensed for sharing.
        case published
        /// Can't play here (and couldn't be converted).
        case unsupported
    }

    /// A moving video, or a still picture (a Wallpaper Engine scene's
    /// artwork, which plays with the photo wallpaper's slow motion).
    public enum Kind: String, Codable, Sendable {
        case video, image
    }

    public struct Provenance: Codable, Hashable, Sendable {
        public var source: String?
        public var workshopId: String?
        public var originalTitle: String?
        public var author: String?
        public var license: String?
    }

    /// The first 16 hex digits of the file's SHA-256: the same video keeps
    /// its id wherever it moves or whatever it's called.
    public var id: String
    public var title: String
    public var kind: Kind
    public var category: WallpaperCategory
    public var tags: [String]
    /// Which library folder it's in (`WallpaperLibraryCatalog.roots`).
    public var root: String
    /// Its path inside that folder.
    public var file: String
    /// A picture of it, relative to the library directory.
    public var thumbnail: String?
    /// A converted copy to play instead, relative to the library directory.
    public var playback: String?
    /// For a live scene loop, its still picture (the loop's fallback and the
    /// thumbnail source), relative to the library directory.
    public var still: String?
    public var duration: Double?
    public var width: Int?
    public var height: Int?
    public var fps: Double?
    public var size: Int64?
    public var status: Status
    public var statusReason: String?
    public var provenance: Provenance?
    public var contentRating: String?
    public var addedAt: String?

    /// Everything search looks through, lowercased once.
    public var searchText: String {
        ([title, category.title] + tags + [provenance?.originalTitle ?? ""]).joined(separator: " ").lowercased()
    }

    public var resolutionLabel: String {
        let long = max(width ?? 0, height ?? 0)
        return long >= 7680 ? "8K" : long >= 3840 ? "4K" : long >= 2560 ? "1440p" : long >= 1920 ? "1080p" : "HD"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, kind, category, tags, root, file, thumbnail, playback, still, duration, width, height, fps, size
        case status, statusReason, provenance, contentRating, addedAt
    }

    public init(id: String, title: String, kind: Kind = .video, category: WallpaperCategory, tags: [String] = [], root: String, file: String,
                thumbnail: String? = nil, playback: String? = nil, still: String? = nil, duration: Double? = nil, width: Int? = nil,
                height: Int? = nil, fps: Double? = nil, size: Int64? = nil, status: Status = .quarantined,
                statusReason: String? = nil, provenance: Provenance? = nil, contentRating: String? = nil, addedAt: String? = nil) {
        self.id = id
        self.title = title
        self.kind = kind
        self.category = category
        self.tags = tags
        self.root = root
        self.file = file
        self.thumbnail = thumbnail
        self.playback = playback
        self.still = still
        self.duration = duration
        self.width = width
        self.height = height
        self.fps = fps
        self.size = size
        self.status = status
        self.statusReason = statusReason
        self.provenance = provenance
        self.contentRating = contentRating
        self.addedAt = addedAt
    }

    /// Tolerant: a catalog from a newer or older importer still loads, with
    /// anything unknown falling back rather than dropping the whole library.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? "Untitled video"
        kind = (try? c.decodeIfPresent(Kind.self, forKey: .kind)) ?? .video
        category = (try? c.decodeIfPresent(WallpaperCategory.self, forKey: .category)) ?? .abstract
        tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        root = try c.decode(String.self, forKey: .root)
        file = try c.decode(String.self, forKey: .file)
        thumbnail = try? c.decodeIfPresent(String.self, forKey: .thumbnail)
        playback = try? c.decodeIfPresent(String.self, forKey: .playback)
        still = try? c.decodeIfPresent(String.self, forKey: .still)
        duration = try? c.decodeIfPresent(Double.self, forKey: .duration)
        width = try? c.decodeIfPresent(Int.self, forKey: .width)
        height = try? c.decodeIfPresent(Int.self, forKey: .height)
        fps = try? c.decodeIfPresent(Double.self, forKey: .fps)
        size = try? c.decodeIfPresent(Int64.self, forKey: .size)
        // Unknown status: treat as the most careful one.
        status = (try? c.decodeIfPresent(Status.self, forKey: .status)) ?? .quarantined
        statusReason = try? c.decodeIfPresent(String.self, forKey: .statusReason)
        provenance = try? c.decodeIfPresent(Provenance.self, forKey: .provenance)
        contentRating = try? c.decodeIfPresent(String.self, forKey: .contentRating)
        addedAt = try? c.decodeIfPresent(String.self, forKey: .addedAt)
    }
}

/// What the importer writes: the folders videos come from, and the videos.
public struct WallpaperLibraryCatalog: Codable, Sendable {
    public struct Root: Codable, Hashable, Sendable {
        public var id: String
        public var path: String
        public var label: String?
    }

    public var version = 1
    public var roots: [Root] = []
    public var items: [LibraryVideo] = []

    public init(roots: [Root] = [], items: [LibraryVideo] = []) {
        self.roots = roots
        self.items = items
    }

    enum CodingKeys: String, CodingKey { case version, roots, items }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? 1
        roots = (try? c.decodeIfPresent([Root].self, forKey: .roots)) ?? []
        // One unreadable entry skips that entry, not the library.
        var list = try c.nestedUnkeyedContainer(forKey: .items)
        var items: [LibraryVideo] = []
        while !list.isAtEnd {
            if let item = try? list.decode(LibraryVideo.self) {
                items.append(item)
            } else {
                _ = try? list.decode(Skip.self)
            }
        }
        self.items = items
    }

    private struct Skip: Decodable {}
}

/// Ordering for the library grid, all from real catalog data.
public enum LibrarySort: String, CaseIterable, Identifiable, Sendable {
    case title, newest, longest, resolution

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .title: "Name"
        case .newest: "Recently Added"
        case .longest: "Longest"
        case .resolution: "Sharpest"
        }
    }

    public func sorted(_ videos: [LibraryVideo]) -> [LibraryVideo] {
        switch self {
        case .title:
            videos.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .newest:
            videos.sorted { ($0.addedAt ?? "", $1.title) > ($1.addedAt ?? "", $0.title) }
        case .longest:
            videos.sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
        case .resolution:
            videos.sorted { ($0.width ?? 0) * ($0.height ?? 0) > ($1.width ?? 0) * ($1.height ?? 0) }
        }
    }
}

extension LibraryVideo {
    /// Whether it matches every word typed (in title, tags, category or original title).
    public func matches(_ query: String) -> Bool {
        let words = SearchMatch.words(query)
        guard !words.isEmpty else { return true }
        let text = SearchMatch.normalize(searchText)
        return words.allSatisfy { text.contains($0) }
    }
}
