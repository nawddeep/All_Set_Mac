import Foundation
import CoreGraphics

/// JSON avoids delimiter collisions in imported video filenames. Existing
/// catalog favorites written as pipe-separated IDs remain readable.
public enum StudioSavedIDs {
    public static func decode(_ value: String) -> Set<String> {
        if value.first == "[" {
            return Set((try? JSONDecoder().decode([String].self, from: Data(value.utf8))) ?? [])
        }
        return Set(value.split(separator: "|").map(String.init))
    }
    public static func encode(_ ids: Set<String>) -> String {
        String(decoding: (try? JSONEncoder().encode(ids.sorted())) ?? Data("[]".utf8), as: UTF8.self)
    }
    /// The first cinematic Art shelf saved style-only IDs for midnight pieces.
    /// Keep those favorites and selections valid as the full palette library returns.
    public static func wallpaperID(_ piece: ArtPiece) -> String {
        piece.palette == .midnight ? "art:\(piece.style.rawValue)" : "art:\(piece.id)"
    }
}

/// The compact discovery rail groups by purpose rather than hiding catalog entries.
public enum StudioWidgetFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All", clocks = "Clocks", weather = "Weather", calendar = "Calendar"
    case system = "System", focus = "Focus", music = "Music", photos = "Photos"
    public var id: String { rawValue }
    public func includes(_ entry: CatalogEntry) -> Bool {
        includes(kind: entry.kind, category: entry.category)
    }
    public func includes(kind: WidgetKind, category: WidgetCategory) -> Bool {
        switch self {
        case .all: true
        case .clocks: kind == .clock || kind == .date
        case .weather: kind == .weather || kind == .airQuality || kind == .daylight
        case .calendar: kind == .calendar || kind == .nextEvent || kind == .countdown
        case .system: category == .system || category == .developer
        case .focus: category == .productivity && kind != .calendar && kind != .nextEvent
        case .music: category == .music || kind == .nowPlaying || kind == .vinyl
        case .photos: kind == .photo || kind == .polaroids || kind == .magazine
        }
    }
    public func themeWidgets(query: String = "") -> [ThemeWidget] {
        ThemeWidgetCatalog.all.filter {
            includes(kind: $0.instance.kind, category: $0.instance.kind.category) &&
            (SearchMatch.normalize(query).isEmpty || SearchMatch.containsAll(query, in: $0.searchText))
        }
    }
    public func entries(query: String = "") -> [CatalogEntry] {
        let entries = WidgetCatalog.entries.filter(includes)
        guard !SearchMatch.normalize(query).isEmpty else { return entries }
        let ranked = SearchMatch.rank(entries, by: query, name: \.title)
        let ids = Set(ranked.map(\.id))
        return ranked + entries.filter { !ids.contains($0.id) && SearchMatch.containsAll(query, in: $0.searchText) }
    }
}

/// Geometry shared by the actual page and its responsive checks.
public struct StudioLayout: Sendable {
    public let width: CGFloat
    public let height: CGFloat
    public init(width: CGFloat, height: CGFloat) { self.width = max(1, width); self.height = max(1, height) }
    public var margin: CGFloat { width < 1050 ? 24 : 46 }
    public var spotlightWidth: CGFloat { min(680, width * 0.405) }
    public var spotlightHeight: CGFloat { spotlightWidth / 2.46 }
    public var sideWidth: CGFloat { max(1, min(290, width * 0.182, (width - spotlightWidth - 220) / 2)) }
    public var stageHeight: CGFloat { spotlightHeight + 40 }
    public var columns: Int { width < 1050 ? 3 : 5 }
    public var tileGap: CGFloat { 22 }
    public var tileWidth: CGFloat { (width - 2 * margin - CGFloat(columns - 1) * tileGap) / CGFloat(columns) }
    public func tileWidth(at column: Int) -> CGFloat {
        guard columns == 5 else { return tileWidth }
        return tileWidth * (column == 0 || column == 4 ? 1.06 : 0.96)
    }
    public var tileHeight: CGFloat { max(108, min(168, tileWidth / 1.58)) }
    public var filmstripHeight: CGFloat { max(150, min(254, height * 0.257)) }
    public var wallpaperCaptionBottom: CGFloat { filmstripHeight + 24 }

    /// Both the preview and its lighting use this frame, so a square widget
    /// never inherits the wide clock's surrounding rectangle.
    public static func fitting(_ footprint: CGSize, in bounds: CGSize) -> CGSize {
        guard footprint.width > 0, footprint.height > 0, bounds.width > 0, bounds.height > 0,
              footprint.width.isFinite, footprint.height.isFinite,
              bounds.width.isFinite, bounds.height.isFinite else { return .zero }
        let scale = min(bounds.width / footprint.width, bounds.height / footprint.height)
        return CGSize(width: footprint.width * scale, height: footprint.height * scale)
    }

    public static func wrapped(_ value: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return ((value % count) + count) % count
    }
}

/// Uniform wallpaper rows, with the same widths even in an incomplete final row.
public struct StudioWallpaperGrid: Sendable {
    public let width: CGFloat
    public init(width: CGFloat) { self.width = max(1, width) }
    public var gap: CGFloat { 20 }
    public var contentWidth: CGFloat { max(1, width - 148) }
    public var columns: Int { max(1, min(5, Int((contentWidth + gap) / 250))) }
    public var cardWidth: CGFloat { max(1, (contentWidth - CGFloat(columns - 1) * gap) / CGFloat(columns)) }
    public var imageHeight: CGFloat { cardWidth * 0.5625 }
    public var rowHeight: CGFloat { imageHeight + 52 }
}

/// Original offline artwork; shared by the page, previews and applied wallpaper.
public enum StudioScenery {
    public static let wallpaper = "cinema-alpine.jpg"
    public static let widgets = "cinema-midnight.jpg"
    public static let coast = "cinema-coast.jpg"
    public static let dunes = "cinema-dunes.jpg"
    public static let orbit = "cinema-orbit.jpg"
    public static let aurora = "midnight-aurora.jpg"
    public static func url(_ name: String) -> URL? {
        let bundle = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main : Bundle.module
        return bundle.url(forResource: name, withExtension: nil, subdirectory: "ThemeArt")
    }
}
