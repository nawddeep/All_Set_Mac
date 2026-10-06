import Foundation
import Observation
import OSLog

/// A file parked on the shelf.
public struct ShelfItem: Codable, Identifiable, Hashable, Sendable {
    public var id = UUID()
    public var url: URL
    public var date = Date()

    public init(url: URL) {
        self.url = url
    }

    public var name: String { url.lastPathComponent }
}

/// Files dropped on the notch, kept until they're dragged out or removed. The
/// shelf only remembers where files are; it never moves or copies them, except
/// for pictures dropped from a browser, which have no file until it saves one.
@Observable @MainActor
public final class ShelfStore {
    public private(set) var items: [ShelfItem] = []

    @ObservationIgnored public let droppedFilesDirectory: URL
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "shelf")

    public init(directory: URL? = nil) {
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AllSet/Shelf", isDirectory: true)
        droppedFilesDirectory = root.appendingPathComponent("Dropped", isDirectory: true)
        fileURL = root.appendingPathComponent("shelf.json")
        try? FileManager.default.createDirectory(at: droppedFilesDirectory, withIntermediateDirectories: true)
        let saved = StoreFile.load([ShelfItem].self, from: fileURL) ?? []
        // Files deleted since last time are gone from the shelf too.
        items = saved.filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }

    public func add(_ urls: [URL]) {
        let fresh = urls.filter { url in !items.contains { $0.url == url } }
        guard !fresh.isEmpty else { return }
        items.insert(contentsOf: fresh.map(ShelfItem.init(url:)), at: 0)
        save()
    }

    public func remove(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        cleanUp(items.remove(at: index))
        save()
    }

    public func clear() {
        items.forEach(cleanUp)
        items.removeAll()
        save()
    }

    /// Files the shelf itself saved (browser pictures) go when they leave it.
    private func cleanUp(_ item: ShelfItem) {
        // Inside the shelf's own folder, compared by path component after resolving
        // symlinks: a sibling such as Dropped-Other, or a link out, isn't the shelf's.
        if ContainedPath.contains(item.url, in: droppedFilesDirectory) {
            try? FileManager.default.removeItem(at: item.url)
        }
    }

    /// Why the last save failed; nil once one works. Shown in the main window.
    public private(set) var saveError: String?

    /// Writes now. True when the shelf is on disk; on failure `saveError` says why.
    @discardableResult
    public func saveNow() -> Bool { save() }

    @discardableResult
    private func save() -> Bool {
        do {
            try JSONEncoder().encode(items).write(to: fileURL, options: .atomic)
            if saveError != nil { saveError = nil }
            return true
        } catch {
            log.error("Couldn't save the shelf: \(error.localizedDescription, privacy: .public)")
            saveError = error.localizedDescription
            return false
        }
    }
}
