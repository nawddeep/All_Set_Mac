import Foundation

/// Brings a wallpaper library to a Mac that only receives it: the catalog from
/// the library server, then its pictures, then the wallpapers themselves, each
/// into the place in the library folder the app looks for it.
///
/// Two kinds of server. With a key (`AllSet library <key>`), the owner's own:
/// the list is at `api/library` and every request carries the key. Without one,
/// a public library (scripts/cloud/publish_catalog.py): the list is
/// `catalog.json`, anyone may read it, and the app keeps it up to date by
/// itself (`update()`). Either way the app shows each wallpaper as it lands,
/// and fetches any that isn't here yet when it's picked (`WallpaperStore`).
public struct LibrarySync: Sendable {
    public enum Failure: LocalizedError, Equatable {
        case wrongKey
        case unreachable
        case refused(Int)
        case unreadable
        case ownLibrary
        case corrupt

        public var errorDescription: String? {
            switch self {
            case .wrongKey: "The library didn't accept that key. Check it against the one you were sent."
            case .unreachable: "Couldn't reach the wallpaper library. Check this Mac's internet connection, then run the command again."
            case .refused(let status): "The wallpaper library answered with an error (\(status)). Try again in a minute."
            case .unreadable: "The wallpaper library sent a list this version of All Set can't read."
            case .ownLibrary: "This Mac keeps a wallpaper library of its own, so its list isn't replaced."
            case .corrupt: "A wallpaper arrived damaged and was thrown away. It downloads again next time."
            }
        }
    }

    /// One file of the library that isn't on this Mac.
    public struct Missing: Hashable, Sendable {
        public let relative: String
        public let title: String
        /// 0 when the catalog doesn't say.
        public let size: Int64
        /// The SHA-256 the catalog gives for it, if it gives one.
        public var checksum: String?
    }

    public struct Options: Sendable {
        /// The list and its pictures only; each wallpaper downloads when it's picked.
        public var catalogOnly = false
        /// Free space the downloads leave on the disk.
        public var reserve: Int64 = 10 << 30

        public init(catalogOnly: Bool = false, reserve: Int64 = 10 << 30) {
            self.catalogOnly = catalogOnly
            self.reserve = reserve
        }
    }

    public struct Summary: Equatable, Sendable {
        public var downloaded = 0
        public var failed = 0
        /// Wallpapers not started because the disk was down to the reserve.
        public var leftForLater = 0
    }

    /// The `root` every entry of a received catalog names: no folder on this
    /// Mac, so a wallpaper plays from its copy in the library folder or not at all.
    public static let root = "server"

    public let server: URL
    public let directory: URL
    public let progress = LibrarySyncProgress()
    private let key: String?
    private let session: URLSession
    private let authorization: LibraryAuthorization

    /// `server` is the library's address (its files; the account API is under
    /// `api/`), `directory` the app's library folder. No `key`: a public
    /// library, whose requests carry the access token (`authorization`).
    public init(server: URL, key: String?, directory: URL, session: URLSession? = nil,
                authorization: LibraryAuthorization = .shared) {
        self.server = server
        self.key = key
        self.directory = directory
        self.authorization = authorization
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 30
            self.session = URLSession(configuration: configuration)
        }
    }

    private var catalogFile: URL { directory.appendingPathComponent("catalog.json") }
    /// The ETag the public library gave with the catalog saved here.
    private var catalogTagFile: URL { directory.appendingPathComponent("catalog.etag") }

    /// Whether this Mac's catalog came from its own folders (the importer's):
    /// that one is never replaced.
    public var hasOwnLibrary: Bool {
        guard let data = try? Data(contentsOf: catalogFile),
              let existing = try? JSONDecoder().decode(WallpaperLibraryCatalog.self, from: data) else { return false }
        return !existing.roots.isEmpty || existing.items.contains { $0.root != Self.root }
    }

    /// The library's list, from the server. A key the server doesn't accept
    /// throws `.wrongKey`, so this is also how a key is checked.
    public func fetchCatalog() async throws -> WallpaperLibraryCatalog {
        guard let (data, response) = try? await session.data(for: request(server.appendingPathComponent("api/library"))),
              let http = response as? HTTPURLResponse else { throw Failure.unreachable }
        switch http.statusCode {
        case 200: break
        case 401, 403: throw Failure.wrongKey
        default: throw Failure.refused(http.statusCode)
        }
        return try received(data)
    }

    /// Brings this Mac's list up to date with a public library's, and returns
    /// the new list, or nil when the one saved here is still the library's (the
    /// server says so from the ETag it gave last time, without sending it again).
    /// A Mac with a library of its own keeps it: `.ownLibrary`.
    public func update() async throws -> WallpaperLibraryCatalog? {
        guard !hasOwnLibrary else { throw Failure.ownLibrary }
        var request = request(server.appendingPathComponent("catalog.json"))
        // The session's own cache would answer from memory with a 200 and the
        // old list; the question goes to the server, with the tag kept on disk.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if FileManager.default.fileExists(atPath: catalogFile.path),
           let tag = try? String(contentsOf: catalogTagFile, encoding: .utf8), !tag.isEmpty {
            request.setValue(tag, forHTTPHeaderField: "If-None-Match")
        }
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else { throw Failure.unreachable }
        authorization.check(http)
        switch http.statusCode {
        case 200: break
        case 304: return nil
        default: throw Failure.refused(http.statusCode)
        }
        let catalog = try received(data)
        try save(catalog)
        // After the list: a tag without its list would hide the list for good.
        if let tag = http.value(forHTTPHeaderField: "ETag") {
            try? tag.write(to: catalogTagFile, atomically: true, encoding: .utf8)  // Best effort: a cache or temporary file; failing only means doing it again.
        } else {
            try? FileManager.default.removeItem(at: catalogTagFile)  // Best effort: a cache or temporary file; failing only means doing it again.
        }
        return catalog
    }

    /// A list as a server sent it, cut down to what may be kept here.
    private func received(_ data: Data) throws -> WallpaperLibraryCatalog {
        guard var catalog = try? JSONDecoder().decode(WallpaperLibraryCatalog.self, from: data) else { throw Failure.unreadable }
        // Every path is written to and read from disk: one that would leave
        // the library folder drops its entry.
        catalog.roots = []
        catalog.items = catalog.items.filter { video in
            video.root == Self.root && [video.playback, video.still, video.thumbnail].allSatisfy { relative in
                relative.map { ContainedPath.resolve($0, in: directory) != nil } ?? true
            }
        }
        return catalog
    }

    /// Makes `catalog` this Mac's library list.
    public func save(_ catalog: WallpaperLibraryCatalog) throws {
        guard !hasOwnLibrary else { throw Failure.ownLibrary }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(catalog).write(to: catalogFile, options: .atomic)
    }

    /// The catalog's files that aren't on this Mac: its pictures (thumbnails,
    /// stills and still wallpapers), and its videos, smallest first.
    public func missing(in catalog: WallpaperLibraryCatalog) -> (pictures: [Missing], videos: [Missing]) {
        var seen = Set<String>()
        var pictures: [Missing] = [], videos: [Missing] = []
        func isMissing(_ relative: String?) -> String? {
            guard let relative, seen.insert(relative).inserted,
                  !FileManager.default.fileExists(atPath: directory.appendingPathComponent(relative).path) else { return nil }
            return relative
        }
        for video in catalog.items {
            for picture in [video.thumbnail, video.still] + (video.kind == .image ? [video.playback] : []) {
                if let relative = isMissing(picture) {
                    pictures.append(Missing(relative: relative, title: video.title, size: 0, checksum: video.checksum(of: relative)))
                }
            }
            if video.kind == .video, let relative = isMissing(video.playback) {
                videos.append(Missing(relative: relative, title: video.title, size: video.size ?? 0, checksum: video.checksum(of: relative)))
            }
        }
        return (pictures, videos.sorted { ($0.size, $0.relative) < ($1.size, $1.relative) })
    }

    /// Downloads everything `catalog` lists that isn't here: the pictures, then
    /// (unless `options.catalogOnly`) the videos, stopping before the disk is
    /// down to `options.reserve`. `finished` hears about each video as it ends,
    /// with how many are done of how many; `changed` when the app has something
    /// new to show. A file that fails is counted and left for the next run.
    public func download(_ catalog: WallpaperLibraryCatalog, options: Options = Options(),
                         freeSpace: @escaping @Sendable () -> Int64? = { nil },
                         finished: @escaping @Sendable (Missing, _ done: Int, _ total: Int, _ error: Error?) -> Void = { _, _, _, _ in },
                         changed: @escaping @Sendable () -> Void = {}) async -> Summary {
        let (pictures, videos) = missing(in: catalog)
        var summary = Summary()
        // Pictures are small and what the app's grid is made of: all of them first.
        await each(pictures, atOnce: 6) { _ in true } done: { _, error in
            if error != nil { summary.failed += 1 }
        }
        changed()
        guard !options.catalogOnly else { return summary }
        var ended = 0
        await each(videos, atOnce: 3) { video in
            guard let free = freeSpace() else { return true }
            return free - video.size >= options.reserve
        } done: { video, error in
            ended += 1
            if error == nil { summary.downloaded += 1 } else { summary.failed += 1 }
            finished(video, ended, videos.count, error)
            if error == nil { changed() }
        }
        summary.leftForLater = videos.count - ended
        return summary
    }

    /// Downloads one file into its place in the library folder. A response
    /// shorter than it said it would be never lands, nor one whose SHA-256
    /// isn't `checksum` (when the catalog gave one).
    public func download(_ relative: String, checksum: String? = nil) async throws {
        guard let destination = ContainedPath.resolve(relative, in: directory) else { throw Failure.unreadable }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let handle = TaskHandle()
        let progress = progress
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let task = session.downloadTask(with: request(server.appendingPathComponent(relative))) { temporary, response, error in
                    // The temporary file is gone once this returns, so move it now.
                    let size = temporary.flatMap { (try? FileManager.default.attributesOfItem(atPath: $0.path))?[.size] as? Int64 } ?? 0
                    handle.task.map { progress.ended($0, bytes: size) }
                    authorization.check(response)
                    guard let temporary, let http = response as? HTTPURLResponse else {
                        continuation.resume(throwing: error ?? Failure.unreachable)
                        return
                    }
                    guard http.statusCode == 200 else {
                        continuation.resume(throwing: [401, 403].contains(http.statusCode) ? Failure.wrongKey : Failure.refused(http.statusCode))
                        return
                    }
                    if http.expectedContentLength > 0, size != http.expectedContentLength {
                        continuation.resume(throwing: URLError(.networkConnectionLost))
                        return
                    }
                    if let checksum, FileDigest.sha256(of: temporary) != checksum.lowercased() {
                        continuation.resume(throwing: Failure.corrupt)
                        return
                    }
                    do {
                        try? FileManager.default.removeItem(at: destination)  // Best effort: a cache or temporary file; failing only means doing it again.
                        try FileManager.default.moveItem(at: temporary, to: destination)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                handle.task = task
                progress.began(task)
                task.resume()
            }
        } onCancel: {
            handle.task?.cancel()
        }
    }

    /// Downloads `files` a few at a time, in order. `mayStart` is asked before
    /// each one; the first no ends the run with the rest not started.
    private func each(_ files: [Missing], atOnce: Int, mayStart: (Missing) -> Bool,
                      done: (Missing, Error?) -> Void) async {
        await withTaskGroup(of: (Missing, Error?).self) { group in
            var pending = files.makeIterator()
            func startNext() -> Bool {
                guard let next = pending.next(), mayStart(next) else { return false }
                group.addTask {
                    do {
                        try await download(next.relative, checksum: next.checksum)
                        return (next, nil)
                    } catch {
                        return (next, error)
                    }
                }
                return true
            }
            var open = true
            for _ in 0..<atOnce where open { open = startNext() }
            while let (file, error) = await group.next() {
                done(file, error)
                if open { open = startNext() }
            }
        }
    }

    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let key {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        } else {
            authorization.authorize(&request)
        }
        return request
    }
}

/// Bytes a sync has received so far, across the downloads under way and the
/// ones that ended: for a progress line.
// Sendable because: every stored var is under `lock`.
public final class LibrarySyncProgress: @unchecked Sendable {
    private let lock = NSLock()
    private var ended: Int64 = 0
    private var active: [Int: URLSessionTask] = [:]

    public var received: Int64 {
        lock.withLock { ended + active.values.reduce(0) { $0 + $1.countOfBytesReceived } }
    }

    func began(_ task: URLSessionTask) {
        lock.withLock { active[task.taskIdentifier] = task }
    }

    func ended(_ task: URLSessionTask, bytes: Int64) {
        lock.withLock {
            active[task.taskIdentifier] = nil
            ended += bytes
        }
    }
}

/// The download a cancelled `LibrarySync.download(_:)` has to stop.
// Sendable because: `held` is only read and written under `lock`.
private final class TaskHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var held: URLSessionDownloadTask?

    var task: URLSessionDownloadTask? {
        get { lock.withLock { held } }
        set { lock.withLock { held = newValue } }
    }
}
