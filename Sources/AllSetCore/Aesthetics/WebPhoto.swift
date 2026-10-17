import AppKit
import ImageIO
import Observation
import OSLog
import UniformTypeIdentifiers

/// Where a photo widget's image comes from.
public enum ImageSource: Codable, Hashable, Sendable {
    /// Generated art from the built-in library.
    case art(ArtPiece)
    /// A photo from the online library (Unsplash photos served by Picsum).
    case web(WebPhoto)
    /// A picture the user imported, stored in All Set's own folder by file name.
    case file(String)
    /// Original artwork shipped with the app; available without a download.
    case bundled(String)
}

/// An online photo: from Picsum (Unsplash photos, free to use) when `provider`
/// is nil, or from an Openverse search (Creative Commons photos). Photos picked
/// from Wallhaven before its search was removed keep `provider: "wallhaven"`
/// and still show from their own address.
public struct WebPhoto: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var author: String
    public var width: Int
    public var height: Int
    /// "openverse" for search results; nil for Picsum.
    public var provider: String?
    public var imageURLString: String?
    public var thumbnailURLString: String?
    /// e.g. "CC BY-SA 2.0", shown as attribution.
    public var license: String?
    public var title: String?
    /// Where an Openverse photo lives: "wordpress", "rawpixel", "flickr"...
    public var origin: String?

    public init(id: String, author: String, width: Int, height: Int, provider: String? = nil,
                imageURLString: String? = nil, thumbnailURLString: String? = nil, license: String? = nil,
                title: String? = nil, origin: String? = nil) {
        self.id = id
        self.author = author
        self.width = width
        self.height = height
        self.provider = provider
        self.imageURLString = imageURLString
        self.thumbnailURLString = thumbnailURLString
        self.license = license
        self.title = title
        self.origin = origin
    }

    /// A photo shipped inside the app (`provider: "bundled"`): the theme
    /// photos in `LicensedPhotos.swift`, public domain, checked when bundled.
    public static let bundledProvider = "bundled"

    /// The app's own copy of a bundled photo. Theme photos saved in a layout
    /// before they were bundled (`provider: "openverse"`) find it too.
    var bundledFile: URL? {
        provider == Self.bundledProvider || provider == "openverse" ? ImageLibrary.bundledURL("licensed-\(id).jpg") : nil
    }

    /// A small version for grids. Taken straight from the photo's own site
    /// where it offers sizes, which spares Openverse's daily thumbnail limit.
    public func thumbnailURL(side: Int = 240) -> URL {
        if let bundledFile { return bundledFile }
        if let direct = Self.resized(imageURLString, origin: origin, small: true) { return direct }
        return thumbnailURLString.flatMap(URL.init(string:)) ?? Self.picsum(id, side, side)
    }

    /// Openverse's own thumbnail, for when the site's small version fails.
    public var fallbackThumbnailURL: URL? {
        thumbnailURLString.flatMap(URL.init(string:))
    }

    /// Picsum scales on its server; other sources give a large version, which
    /// is scaled down after downloading.
    public var displayURL: URL {
        if let bundledFile { return bundledFile }
        if let large = Self.resized(imageURLString, origin: origin, small: false) { return large }
        if let url = imageURLString.flatMap(URL.init(string:)) { return url }
        let width = 2400
        let height = max(Int(Double(width) * Double(self.height) / Double(max(self.width, 1))), 1)
        return Self.picsum(id, width, height)
    }

    /// Picsum's URL for a photo; the id is escaped, since it comes from a server.
    private static func picsum(_ id: String, _ width: Int, _ height: Int) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "picsum.photos"
        components.path = "/id/\(id)/\(width)/\(height)"
        return components.url ?? URL(fileURLWithPath: "/")
    }

    /// Other sizes of the same picture, where the site names them predictably.
    static func resized(_ urlString: String?, origin: String?, small: Bool) -> URL? {
        guard let urlString, let origin else { return nil }
        switch origin {
        case "wordpress":
            // "…-2048x1365.jpg": WordPress keeps a 768-wide copy of every photo.
            guard small, let match = urlString.firstMatch(of: /-(\d+)x(\d+)\.(jpe?g|png|webp)$/),
                  let width = Double(match.1), let height = Double(match.2), width > 0 else { return nil }
            let smallHeight = Int((768 * height / width).rounded())
            return URL(string: urlString.replacingCharacters(in: match.range, with: "-768x\(smallHeight).\(match.3)"))
        case "rawpixel":
            // "…/editor_1024/…" also comes as image_600 and image_1300.
            guard urlString.contains("/editor_1024/") else { return nil }
            return URL(string: urlString.replacingOccurrences(of: "/editor_1024/", with: small ? "/image_600/" : "/image_1300/"))
        case "flickr":
            // Flickr's size letters: n is 320 px, b is 1024.
            guard small, let match = urlString.firstMatch(of: /_[a-z]\.jpg$/) else { return nil }
            return URL(string: urlString.replacingCharacters(in: match.range, with: "_n.jpg"))
        default:
            return nil
        }
    }

    /// The creator plus the licence for a search result, the photographer
    /// plus "Unsplash" for a Picsum photo: shown wherever the photo is offered.
    public var credit: String {
        let source = provider == nil ? "Unsplash" : license
        return [author, source].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Where the picture came from, to credit it or find its creator.
    public var pageURL: URL? {
        switch provider {
        case "openverse", Self.bundledProvider: URL(string: "https://openverse.org/image/\(id)")
        default: nil
        }
    }

    var cacheName: String { "\(provider ?? "picsum")-\(id).jpg" }
}
