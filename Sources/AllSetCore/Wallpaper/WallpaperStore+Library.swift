import Foundation
import Observation
import OSLog
import UniformTypeIdentifiers

/// The imported wallpaper library: reading it, fetching from a server, playing from it.
extension WallpaperStore {
    // MARK: Library

    /// Where the catalog, thumbnails and the few converted copies live.
    public var libraryDirectory: URL { directory.appendingPathComponent("Library", isDirectory: true) }

    /// Reads the catalog off the main thread (a big library is a big file).
    public func reloadLibrary() {
        let file = libraryDirectory.appendingPathComponent("catalog.json")
        let offloaded = libraryDirectory.appendingPathComponent("offloaded.json")
        Task {
            let catalog = await Task.detached(priority: .utility) { () -> WallpaperLibraryCatalog? in
                guard let data = try? Data(contentsOf: file) else { return nil }
                return try? JSONDecoder().decode(WallpaperLibraryCatalog.self, from: data)
            }.value
            serverConfirmed = await Task.detached(priority: .utility) {
                Set((try? Data(contentsOf: offloaded)).flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [])
            }.value
            let directory = libraryDirectory, log = log
            let copiesBefore = libraryCopies
            // An entry whose files would lie outside the library is never used:
            // every read, download and delete below trusts these paths. Checked
            // off the main thread with the disk checks: resolving three paths
            // each for a thousand wallpapers held it for 80-95 ms at every launch.
            let (items, copies) = await Task.detached(priority: .utility) { () -> ([LibraryVideo], Set<String>) in
                let items = (catalog?.items ?? []).filter { video in
                    guard video.status != .unsupported else { return false }
                    let contained = [video.playback, video.still, video.thumbnail].allSatisfy { relative in
                        relative.map { ContainedPath.resolve($0, in: directory) != nil } ?? true
                    }
                    if !contained { log.error("Ignoring library entry \(video.id, privacy: .public): a path leaves the library") }
                    return contained
                }
                let copies = Set(items.filter { video in
                    video.playback.map { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path) } ?? false
                }.map(\.id))
                return (items, copies)
            }.value
            // A download landing or a copy freed while the disk was being read wins
            // over what the scan saw of that file.
            let landed = libraryCopies.subtracting(copiesBefore), freed = copiesBefore.subtracting(libraryCopies)
            libraryCopies = copies.union(landed).subtracting(freed)
            #if DEBUG
            if hasDebugLibrary { return }
            #endif
            library = items
            libraryIndex = Dictionary(items.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
            libraryRoots = Dictionary((catalog?.roots ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            refreshLibraryReachability()
            hasLoadedLibrary = true
        }
    }

    /// Checks which library folders can be reached, for when a drive comes or goes.
    public func refreshLibraryReachability() {
        let reachable = Set(libraryRoots.values.filter { FileManager.default.fileExists(atPath: $0.path) }.map(\.id))
        if reachable != reachableRoots { reachableRoots = reachable }
    }

    #if DEBUG

    /// Replaces the library in memory (never on disk), for scale probes.
    public func debugReplaceLibrary(_ videos: [LibraryVideo]) {
        hasDebugLibrary = true
        library = videos
        libraryIndex = Dictionary(videos.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        hasLoadedLibrary = true
    }
    #endif

    public func libraryVideo(_ id: String) -> LibraryVideo? {
        libraryIndex[id].map { library[$0] }
    }

    /// The file to play: the converted copy when there is one, otherwise the
    /// original where it lives. Nil when its drive isn't connected.
    public func libraryURL(_ id: String) -> URL? {
        guard let video = libraryVideo(id) else { return nil }
        if let playback = video.playback {
            let copy = libraryDirectory.appendingPathComponent(playback)
            if FileManager.default.fileExists(atPath: copy.path) { return copy }
        }
        // A still only exists as its extracted copy (the original is a scene package).
        guard video.kind == .video, let root = libraryRoots[video.root], reachableRoots.contains(video.root) else { return nil }
        let url = URL(fileURLWithPath: root.path).appendingPathComponent(video.file)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Whether it can play now, without touching the disk: its converted copy
    /// is known to exist, or its drive is connected. For drawing many cards
    /// (a file check per card on a USB drive stalls scrolling).
    public func canPlay(_ video: LibraryVideo) -> Bool {
        if libraryCopies.contains(video.id) { return true }
        // A still exists only as its extracted copy.
        return video.kind == .video && reachableRoots.contains(video.root)
    }

    public func libraryThumbnailURL(_ video: LibraryVideo) -> URL? {
        video.thumbnail.map { libraryDirectory.appendingPathComponent($0) }
    }

    /// Whether `config.libraryServerURL` answered recently enough to trust,
    /// checked at most once per `reachabilityMaxAge` no matter how many
    /// callers ask (same shape as `StatusService.checkIfNeeded`).
    public func checkServerReachable() {
        guard let base = config.libraryServerURL, let url = URL(string: base) else {
            serverReachable = nil
            return
        }
        if let checked = serverCheckedAt, Date.now.timeIntervalSince(checked) < Self.reachabilityMaxAge { return }
        guard !serverCheckInFlight else { return }
        serverCheckInFlight = true
        Task {
            defer { serverCheckInFlight = false }
            let request = libraryRequest(url, method: "HEAD", bearer: libraryBearer?())
            let reachable: Bool
            if let (_, response) = try? await fetchSession.data(for: request),
               let code = (response as? HTTPURLResponse)?.statusCode {
                reachable = (200..<400).contains(code)
            } else {
                reachable = false
            }
            serverReachable = reachable
            serverCheckedAt = .now
        }
    }

    public enum LibraryFetchError: Error { case noServer, incomplete, corrupt }

    /// Fetches a library video's file from `config.libraryServerURL` into the
    /// same relative path it lives at locally, so every other resolution
    /// method (`libraryURL`, `canPlay`) sees it exactly like a normal local
    /// copy afterward. Returns immediately, without touching the network, if
    /// it's already local or its source root is reachable.
    @discardableResult
    public func fetchLibraryVideo(_ id: String) async throws -> URL {
        if let url = libraryURL(id) { return url }
        guard let video = libraryVideo(id), let relative = video.playback ?? video.still else {
            throw LibraryFetchError.noServer
        }
        let fetched = try await fetch(relative: relative)
        libraryCopies.insert(id)
        fetchGeneration += 1
        return libraryURL(id) ?? fetched
    }

    /// `fetchLibraryVideo`, tried again with growing pauses until it works or
    /// the caller is cancelled: a server that's down, or Tailscale still
    /// connecting at login, must not leave the wallpaper on default art until
    /// the next relaunch. Stops only when there's nothing to fetch from.
    @discardableResult
    public func fetchLibraryVideoRetrying(_ id: String,
                                          delays: [Duration] = [2, 5, 10, 30, 60].map { .seconds($0) }) async -> URL? {
        var attempt = 0
        while !Task.isCancelled, !cancelledFetches.contains(id) {
            do {
                return try await fetchLibraryVideo(id)
            } catch {
                let video = libraryVideo(id)
                if config.libraryServerURL == nil || (hasLoadedLibrary && (video?.playback ?? video?.still) == nil) { return nil }
                if !(error is CancellationError), (error as? URLError)?.code != .cancelled {
                    log.error("Fetch of library wallpaper \(id, privacy: .public) failed (attempt \(attempt + 1)): \(error.localizedDescription, privacy: .public)")
                }
            }
            try? await Task.sleep(for: delays[min(attempt, delays.count - 1)])
            attempt += 1
        }
        return nil
    }

    /// The grid's picture of a wallpaper, fetched back the same way when it
    /// isn't on this Mac. Returns immediately if it already is.
    @discardableResult
    public func fetchThumbnail(_ id: String) async throws -> URL {
        guard let relative = libraryVideo(id)?.thumbnail,
              let local = ContainedPath.resolve(relative, in: libraryDirectory) else { throw LibraryFetchError.noServer }
        if FileManager.default.fileExists(atPath: local.path) { return local }
        return try await fetch(relative: relative)
    }

    /// Whether this wallpaper's playable file is downloading. Reading it is
    /// what redraws a view when a download starts and ends (`fetching` only
    /// changes then — never per progress tick).
    public func isFetching(_ id: String) -> Bool {
        let underway = fetching
        guard let video = libraryVideo(id), let relative = video.playback ?? video.still else { return false }
        return underway.contains(relative)
    }

    /// 0...1, or nil if it isn't downloading. Not observed — call this from a
    /// view's own timer while `isFetching(id)` is true, not from `body`
    /// directly: `fetches` ticks 4 times a second, too often to redraw on.
    public func fetchProgress(for id: String) -> Double? {
        guard let video = libraryVideo(id), let relative = video.playback ?? video.still else { return nil }
        return fetches[relative]
    }

    /// `<server>/<relative>` into `<library>/<relative>`. One download per
    /// path, shared by every caller asking for it at the same time; it's
    /// cancelled only when the last of them gives up.
    func fetch(relative: String) async throws -> URL {
        let token: UUID
        let task: Task<URL, Error>
        if let entry = inflight[relative] {
            token = entry.token
            task = entry.task
            inflight[relative]?.waiters += 1
        } else {
            guard let base = config.libraryServerURL, let root = URL(string: base) else { throw LibraryFetchError.noServer }
            guard let destination = ContainedPath.resolve(relative, in: libraryDirectory) else { throw LibraryFetchError.noServer }
            let remote = root.appendingPathComponent(relative)
            // What the catalog says the file hashes to, when it says (a public library does).
            let checksum = library.lazy.compactMap { $0.checksum(of: relative) }.first
            let newToken = UUID()
            token = newToken
            task = Task {
                defer { self.finish(relative, token: newToken) }
                return try await self.download(remote, to: destination, relative: relative, checksum: checksum)
            }
            inflight[relative] = (newToken, task, 1)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            Task { @MainActor [weak self] in self?.abandon(relative, token: token) }
        }
    }

    func finish(_ relative: String, token: UUID) {
        if inflight[relative]?.token == token { inflight[relative] = nil }
    }

    func abandon(_ relative: String, token: UUID) {
        guard let entry = inflight[relative], entry.token == token else { return }
        if entry.waiters > 1 {
            inflight[relative]?.waiters -= 1
        } else {
            inflight[relative] = nil
            entry.task.cancel()
        }
    }

    func download(_ remote: URL, to destination: URL, relative: String, checksum: String? = nil) async throws -> URL {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        fetches[relative] = 0
        fetching.insert(relative)
        defer { fetches[relative] = nil; fetching.remove(relative) }
        let handle = DownloadHandle()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let task = fetchSession.downloadTask(with: libraryRequest(remote, bearer: libraryBearer?())) { temporary, response, error in
                    // The temporary file is gone once this returns, so move it now.
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let temporary, let http = response as? HTTPURLResponse, http.statusCode == 200 {
                        // A body shorter than it said it would be never lands.
                        let size = (try? FileManager.default.attributesOfItem(atPath: temporary.path))?[.size] as? Int64
                        if http.expectedContentLength > 0, size != http.expectedContentLength {
                            continuation.resume(throwing: LibraryFetchError.incomplete)
                            return
                        }
                        // Nor one that isn't the file the catalog lists.
                        if let checksum, FileDigest.sha256(of: temporary) != checksum.lowercased() {
                            continuation.resume(throwing: LibraryFetchError.corrupt)
                            return
                        }
                        do {
                            try? FileManager.default.removeItem(at: destination)  // Best effort: a cache or temporary file; failing only means doing it again.
                            try FileManager.default.moveItem(at: temporary, to: destination)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
                handle.start(task)
                Task { [weak self] in
                    while task.state == .running {
                        self?.fetches[relative] = task.progress.fractionCompleted
                        try? await Task.sleep(for: .milliseconds(250))
                    }
                }
            }
        } onCancel: {
            handle.cancel()
        }
        return destination
    }

}
