/// Stable categories in imported wallpaper catalogs. Raw values retain
/// compatibility with existing local and server library data.
public enum WallpaperCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case landscapes, cities, underwater, space
    /// For video libraries: game worlds and characters, and everything
    /// that isn't a place.
    case games, abstract

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .landscapes: "Landscapes"
        case .cities: "Cities"
        case .underwater: "Underwater"
        case .space: "Space"
        case .games: "Games"
        case .abstract: "Abstract"
        }
    }

    public var symbol: String {
        switch self {
        case .landscapes: "mountain.2.fill"
        case .cities: "building.2.fill"
        case .underwater: "fish.fill"
        case .space: "globe.americas.fill"
        case .games: "gamecontroller.fill"
        case .abstract: "scribble.variable"
        }
    }
}

