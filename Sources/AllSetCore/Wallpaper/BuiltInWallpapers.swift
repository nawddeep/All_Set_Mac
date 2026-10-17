import Foundation

/// Live wallpapers that come with All Set: original generative art drawn on
/// the Mac (`ArtPiece`, animated by the same path as any art wallpaper), so a
/// new install has a full Wallpaper page with nothing downloaded or imported.
/// Every one is All Set's own; none is a photo, a video or anyone's artwork.
public struct BuiltInWallpaper: Identifiable, Hashable, Sendable {
    public enum Category: String, CaseIterable, Identifiable, Sendable {
        case calm, night, color, cosmic, texture

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .calm: "Calm"
            case .night: "Night"
            case .color: "Color"
            case .cosmic: "Cosmic"
            case .texture: "Texture"
            }
        }
    }

    public let name: String
    public let category: Category
    public let piece: ArtPiece

    public var id: String { piece.id }
    public var source: WallpaperSource { .art(piece) }

    init(_ name: String, _ category: Category, _ style: ArtStyle, _ palette: ArtPalette) {
        self.name = name
        self.category = category
        piece = ArtPiece(style: style, palette: palette)
    }

    public static func inCategory(_ category: Category) -> [BuiltInWallpaper] { all.filter { $0.category == category } }

    public static let all: [BuiltInWallpaper] = [
        // Calm
        BuiltInWallpaper("Tidal Drift", .calm, .waves, .ocean),
        BuiltInWallpaper("Sage Morning", .calm, .clouds, .matcha),
        BuiltInWallpaper("Lavender Cloud", .calm, .clouds, .lavender),
        BuiltInWallpaper("Dune Hour", .calm, .dunes, .desert),
        BuiltInWallpaper("Soft Glow", .calm, .blobs, .pastel),
        BuiltInWallpaper("Sky Blush", .calm, .clouds, .blush),
        BuiltInWallpaper("Rainy Window", .calm, .rain, .sadBlue),
        BuiltInWallpaper("Forest Bokeh", .calm, .bokeh, .forest),
        // Night
        BuiltInWallpaper("Northern Lights", .night, .aurora, .aurora),
        BuiltInWallpaper("Midnight Skyline", .night, .skyline, .midnight),
        BuiltInWallpaper("Neon Rain", .night, .rain, .neon),
        BuiltInWallpaper("Red Light City", .night, .skyline, .crimson),
        BuiltInWallpaper("Ember Night", .night, .embers, .ember),
        BuiltInWallpaper("Floodlit Pitch", .night, .stadium, .floodlit),
        BuiltInWallpaper("Palm Dusk", .night, .palms, .americana),
        BuiltInWallpaper("Smoke Room", .night, .smoke, .mono),
        // Color
        BuiltInWallpaper("Sunset Drive", .color, .synthwave, .sunset),
        BuiltInWallpaper("Peach Lava", .color, .lava, .peach),
        BuiltInWallpaper("Candy Waves", .color, .waves, .candy),
        BuiltInWallpaper("Cherry Hearts", .color, .hearts, .cherry),
        BuiltInWallpaper("Coastline Stripes", .color, .stripes, .coastline),
        BuiltInWallpaper("Acid Glow", .color, .blobs, .slime),
        BuiltInWallpaper("Sunflower Blobs", .color, .blobs, .blond),
        BuiltInWallpaper("Coral Sunset", .color, .sunset, .sunset),
        // Cosmic
        BuiltInWallpaper("Starry Night", .cosmic, .stars, .midnight),
        BuiltInWallpaper("Orbit Field", .cosmic, .orbits, .neon),
        BuiltInWallpaper("Violet Orbit", .cosmic, .orbits, .lavender),
        BuiltInWallpaper("Deep Space Bokeh", .cosmic, .bokeh, .midnight),
        BuiltInWallpaper("Hypnotic Spiral", .cosmic, .spiral, .mono),
        BuiltInWallpaper("Aurora Stars", .cosmic, .stars, .aurora),
        // Texture
        BuiltInWallpaper("Film Grain", .texture, .film, .mono),
        BuiltInWallpaper("Leopard Noir", .texture, .leopard, .diva),
        BuiltInWallpaper("Mocha Checker", .texture, .checker, .mocha),
        BuiltInWallpaper("Emerald Stripes", .texture, .stripes, .emerald),
        BuiltInWallpaper("Shadow Smoke", .texture, .smoke, .shadow),
        BuiltInWallpaper("Coquette Hearts", .texture, .hearts, .coquette),
    ]
}
