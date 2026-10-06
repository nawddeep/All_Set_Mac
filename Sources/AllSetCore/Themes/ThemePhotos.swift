import Foundation
import Observation
import OSLog

/// The person's own photos for each theme set, kept on this Mac only: the
/// pictures they chose with "Use My Photos…". Wherever a set is drawn
/// (previews, the live hero, the desktop) these take the picture slots in
/// place of the theme's own photos. The files live in All Set's images
/// folder; nothing here ships with the app.
@Observable @MainActor
public final class ThemePhotos {
    public private(set) var photos: [String: [String]] = [:]

    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "themes")

    public init(fileURL: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("AllSet", isDirectory: true).appendingPathComponent("theme-photos.json")) {
        self.fileURL = fileURL
        if let fileURL { photos = StoreFile.load([String: [String]].self, from: fileURL) ?? [:] }
    }

    /// The person's pictures for a set, in the order they fill its slots.
    public func sources(for setID: String) -> [ImageSource] {
        (photos[setID] ?? []).map { ImageSource.file($0) }
    }

    public func hasPhotos(_ setID: String) -> Bool { !(photos[setID] ?? []).isEmpty }

    public func set(_ names: [String], for setID: String) {
        photos[setID] = names.isEmpty ? nil : names
        save()
    }

    public func clear(_ setID: String) { set([], for: setID) }

    /// A short fingerprint of a set's photos, so pictures of it redraw when they change.
    public func version(of setID: String) -> String {
        guard let names = photos[setID], !names.isEmpty else { return "0" }
        var hash: UInt64 = 5381
        for byte in names.joined(separator: "|").utf8 { hash = hash &* 33 &+ UInt64(byte) }
        return String(hash % 1_000_000_007, radix: 36)
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(photos).write(to: fileURL, options: .atomic)
        } catch {
            log.error("Couldn't save theme photos: \(error.localizedDescription, privacy: .public)")
        }
    }
}
