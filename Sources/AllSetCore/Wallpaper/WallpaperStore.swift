import Foundation
import Observation
import OSLog
import UniformTypeIdentifiers

/// What the live wallpaper shows.
public enum WallpaperSource: Codable, Hashable, Sendable {
    /// Generative art, animated.
    case art(ArtPiece)
    /// A photo, with slow movement.
    case photo(ImageSource)
    /// A looping video, by file name in the wallpaper videos folder.
    case video(String)
    /// A video in a wallpaper library outside All Set, by its id
    /// (`LibraryVideo.id`); it plays from where it lives.
    case library(String)
}

/// How a photo wallpaper moves.
public enum WallpaperMotion: String, Codable, CaseIterable, Identifiable, Sendable {
    case still
    case drift
    case breathe

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .still: "Still"
        case .drift: "Drift"
        case .breathe: "Breathe"
        }
    }
}

public struct WallpaperConfig: Codable, Equatable, Sendable {
    public var isEnabled = false
    public var source: WallpaperSource = .art(ArtPiece(style: .aurora, palette: .aurora))
    /// Frames per second for art.
    public var frameRate = 30
    /// Animation speed for art.
    public var speed = 1.0
    /// Draw art at full resolution. Off draws at half and scales up, which
    /// looks the same for soft styles and costs a quarter of the work.
    public var sharpArt = false
    public var motion: WallpaperMotion = .drift
    /// 0...0.6: darkens the wallpaper so icons and widgets stand out.
    public var dim = 0.0
    /// Stop moving while the Mac runs on its battery. On by default: a
    /// moving wallpaper is the most power All Set can use.
    public var pauseOnBattery = true
    /// Stop animating while windows cover the whole desktop.
    public var pauseWhenCovered = true
    /// Also set a matching still as the system wallpaper, which Mission Control,
    /// Spaces and the lock screen show.
    public var matchSystemWallpaper = true
    /// System wallpapers from before All Set changed them, by screen name, so
    /// turning the live wallpaper off can put them back.
    public var originalWallpapers: [String: URL] = [:]
    /// A personal server holding a backup of the library's `live/`, `stills/`
    /// and `thumbnails/` folders (e.g. a Tailscale address), so a wallpaper
    /// missing locally can be fetched back instead of falling back to art.
    /// Nil: no server configured, missing means missing.
    public var libraryServerURL: String?
    /// Which round of changed defaults this config has been through. Round 2
    /// (2026-09-30) turned Pause on battery on once for settings saved before
    /// it; turning it off again afterwards is kept.
    public var defaultsVersion = WallpaperConfig.currentDefaultsVersion
    public static let currentDefaultsVersion = 2

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = WallpaperConfig()
        isEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isEnabled)) ?? defaults.isEnabled
        source = (try? container.decodeIfPresent(WallpaperSource.self, forKey: .source)) ?? defaults.source
        frameRate = (try? container.decodeIfPresent(Int.self, forKey: .frameRate)) ?? defaults.frameRate
        speed = (try? container.decodeIfPresent(Double.self, forKey: .speed)) ?? defaults.speed
        sharpArt = (try? container.decodeIfPresent(Bool.self, forKey: .sharpArt)) ?? defaults.sharpArt
        motion = (try? container.decodeIfPresent(WallpaperMotion.self, forKey: .motion)) ?? defaults.motion
        dim = (try? container.decodeIfPresent(Double.self, forKey: .dim)) ?? defaults.dim
        pauseOnBattery = (try? container.decodeIfPresent(Bool.self, forKey: .pauseOnBattery)) ?? defaults.pauseOnBattery
        pauseWhenCovered = (try? container.decodeIfPresent(Bool.self, forKey: .pauseWhenCovered)) ?? defaults.pauseWhenCovered
        matchSystemWallpaper = (try? container.decodeIfPresent(Bool.self, forKey: .matchSystemWallpaper)) ?? defaults.matchSystemWallpaper
        originalWallpapers = (try? container.decodeIfPresent([String: URL].self, forKey: .originalWallpapers)) ?? [:]
        libraryServerURL = try? container.decodeIfPresent(String.self, forKey: .libraryServerURL)
        let savedVersion = (try? container.decodeIfPresent(Int.self, forKey: .defaultsVersion)) ?? 1
        if savedVersion < 2 { pauseOnBattery = true }
        defaultsVersion = Self.currentDefaultsVersion
    }
}

/// The live wallpaper's settings and imported videos.
@Observable @MainActor
public final class WallpaperStore {
    public var config: WallpaperConfig { didSet { if config != oldValue { save() } } }
    /// Imported video file names, newest first.
    public private(set) var videos: [String] = []
    /// Videos in libraries outside All Set (`Library/catalog.json`, written by
    /// `scripts/wallpaper_library.py`), in catalog order.
    public private(set) var library: [LibraryVideo] = []
    /// Whether `reloadLibrary()` has completed at least once. `library`
    /// starts empty and fills in asynchronously (a big catalog is a big
    /// file); a caller that needs to tell "genuinely not here" apart from
    /// "hasn't loaded yet" reads this, not just whether `library` is empty.
    public private(set) var hasLoadedLibrary = false
    /// Library folders by id, and whether each can be reached right now (a
    /// drive may be unplugged).
    public private(set) var libraryRoots: [String: WallpaperLibraryCatalog.Root] = [:]
    public private(set) var reachableRoots: Set<String> = []
    @ObservationIgnored private var libraryIndex: [String: Int] = [:]
    /// Ids whose converted copy is on disk: checked when the catalog loads,
    /// then kept up to date as copies are fetched back or freed. Observed, so
    /// a tile's "can this play" (and the wallpaper itself) redraws the moment
    /// that changes; it changes rarely, so this costs nothing while scrolling.
    private var libraryCopies: Set<String> = []
    /// Relative paths freed from this Mac after the server's copy was checked
    /// to be the same file (size and SHA-256): `offloaded.json`. The only
    /// evidence this Mac has of what the server really holds.
    private var serverConfirmed: Set<String> = []

    /// Where a wallpaper can be played from, as far as this Mac can tell.
    public enum CopyLocation: Equatable, Sendable {
        case thisMac
        /// Freed from this Mac after its server copy was checked to match.
        case confirmedOnServer
        /// A server is set up and the catalog names the file, but nothing has
        /// checked that the server has it: it may need downloading, or be missing.
        case expectedOnServer
        /// Not here, and no server to ask.
        case unavailable
    }

    public func copyLocation(_ video: LibraryVideo) -> CopyLocation {
        if canPlay(video) { return .thisMac }
        let paths = [video.playback, video.still].compactMap(\.self)
        guard config.libraryServerURL != nil, !paths.isEmpty else { return .unavailable }
        return paths.allSatisfy(serverConfirmed.contains) ? .confirmedOnServer : .expectedOnServer
    }

    /// Fetches from `config.libraryServerURL` under way, fraction done, by
    /// relative path (`live/<id>.mp4`, `thumbnails/<id>.jpg`…) — not by id, so
    /// a wallpaper's video and its thumbnail never share one slot.
    /// Observation-ignored: it ticks four times a second per download, and a
    /// view reading it would redraw that often. Views read `fetching` (which
    /// changes only when a download starts or ends) instead.
    @ObservationIgnored public private(set) var fetches: [String: Double] = [:]
    /// Relative paths being downloaded right now.
    public private(set) var fetching: Set<String> = []
    /// Bumped each time a wallpaper's playable file lands, so anything that
    /// depends on one (the system-wallpaper still) can redo its work.
    public private(set) var fetchGeneration = 0
    /// A "free up space" run in progress: files checked so far, of how many.
    public private(set) var offloadProgress: (done: Int, total: Int)?
    @ObservationIgnored private var isOffloading = false
    /// Whether `config.libraryServerURL` answered recently. Nil: not checked
    /// yet. Checked at most once per `Self.reachabilityMaxAge`, however many
    /// callers ask, same shape as `StatusService`.
    public private(set) var serverReachable: Bool?
    @ObservationIgnored private var serverCheckedAt: Date?
    @ObservationIgnored private var serverCheckInFlight = false
    /// One download per relative path, shared by everyone who asks for it;
    /// `waiters` counts them so the last one to give up cancels it.
    @ObservationIgnored private var inflight: [String: (token: UUID, task: Task<URL, Error>, waiters: Int)] = [:]
    /// Wallpapers whose download the person cancelled. Nothing fetches them
    /// on its own again (the desktop's retrying included) until they ask:
    /// picking the wallpaper, or opening its preview.
    public private(set) var cancelledFetches = Set<String>()
    @ObservationIgnored private static let reachabilityMaxAge: TimeInterval = 30
    /// Instance, not static: each `WallpaperStore` (one per test, one in the
    /// running app) gets its own session, so a test can point it at a stub
    /// without any risk of a concurrently-running test's session changing
    /// underneath it.
    @ObservationIgnored var fetchSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        return URLSession(configuration: configuration)
    }()

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored public let directory: URL
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "wallpaper")

    public init(directory: URL? = nil) {
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AllSet/Wallpaper", isDirectory: true)
        self.directory = root
        fileURL = root.appendingPathComponent("wallpaper.json")
        try? FileManager.default.createDirectory(at: root.appendingPathComponent("Videos"), withIntermediateDirectories: true)
        config = StoreFile.load(WallpaperConfig.self, from: fileURL) ?? WallpaperConfig()
        reloadVideos()
        reloadLibrary()
        // A video deleted outside All Set can't play; fall back to art.
        if case .video(let name) = config.source, !FileManager.default.fileExists(atPath: videoURL(name).path) {
            config.isEnabled = false
            config.source = WallpaperConfig().source
        }
    }

    public func set(_ source: WallpaperSource) {
        if case .library(let id) = source { cancelledFetches.remove(id) }
        config.source = source
        config.isEnabled = true
    }

    /// Stops this wallpaper's download now, for everyone waiting on it, and
    /// keeps it from starting again by itself. Nothing partial is left.
    public func cancelFetch(_ id: String) {
        cancelledFetches.insert(id)
        guard let video = libraryVideo(id), let relative = video.playback ?? video.still,
              let entry = inflight[relative] else { return }
        inflight[relative] = nil
        entry.task.cancel()
    }

    /// The person asked for this wallpaper again: downloads may start.
    public func allowFetch(_ id: String) {
        cancelledFetches.remove(id)
    }

    public func videoURL(_ name: String) -> URL {
        directory.appendingPathComponent("Videos").appendingPathComponent(name)
    }

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
            let directory = libraryDirectory
            // An entry whose files would lie outside the library is never used:
            // every read, download and delete below trusts these paths.
            let items = (catalog?.items ?? []).filter { video in
                guard video.status != .unsupported else { return false }
                let contained = [video.playback, video.still, video.thumbnail].allSatisfy { relative in
                    relative.map { ContainedPath.resolve($0, in: directory) != nil } ?? true
                }
                if !contained { log.error("Ignoring library entry \(video.id, privacy: .public): a path leaves the library") }
                return contained
            }
            libraryCopies = Set(items.filter { video in
                video.playback.map { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path) } ?? false
            }.map(\.id))
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
    @ObservationIgnored private var hasDebugLibrary = false

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
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
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

    public enum LibraryFetchError: Error { case noServer, incomplete }

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
    private func fetch(relative: String) async throws -> URL {
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
            let newToken = UUID()
            token = newToken
            task = Task {
                defer { self.finish(relative, token: newToken) }
                return try await self.download(remote, to: destination, relative: relative)
            }
            inflight[relative] = (newToken, task, 1)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            Task { @MainActor [weak self] in self?.abandon(relative, token: token) }
        }
    }

    private func finish(_ relative: String, token: UUID) {
        if inflight[relative]?.token == token { inflight[relative] = nil }
    }

    private func abandon(_ relative: String, token: UUID) {
        guard let entry = inflight[relative], entry.token == token else { return }
        if entry.waiters > 1 {
            inflight[relative]?.waiters -= 1
        } else {
            inflight[relative] = nil
            entry.task.cancel()
        }
    }

    private func download(_ remote: URL, to destination: URL, relative: String) async throws -> URL {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        fetches[relative] = 0
        fetching.insert(relative)
        defer { fetches[relative] = nil; fetching.remove(relative) }
        let handle = DownloadHandle()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let task = fetchSession.downloadTask(with: remote) { temporary, response, error in
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
                        do {
                            try? FileManager.default.removeItem(at: destination)
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

    // MARK: Freeing space

    /// What one "free up space" run did.
    public struct OffloadResult: Sendable {
        public var freedFiles = 0
        public var freedBytes: Int64 = 0
        /// Relative paths kept on this Mac because the server couldn't be
        /// shown to hold an identical copy.
        public var kept: [String] = []
    }

    private struct OffloadCandidate: Sendable {
        let id: String
        let relative: String
        let size: Int64
    }

    /// A wallpaper's playable files that exist on this Mac right now: the
    /// video or still it plays, plus a live loop's still. Thumbnails stay —
    /// they're tiny, and keep the grid instant and browsable offline. The
    /// wallpaper on the desktop stays too: freeing it would only download it
    /// straight back. The disk checks run off the main thread.
    private func offloadCandidates(only ids: Set<String>?) async -> [OffloadCandidate] {
        let active: String? = if case .library(let id) = config.source { id } else { nil }
        let wanted = library.filter { (ids?.contains($0.id) ?? true) && $0.id != active }
            .map { video in (video.id, Set([video.playback, video.still].compactMap { $0 }).sorted()) }
        let directory = libraryDirectory
        return await Task.detached(priority: .userInitiated) {
            wanted.flatMap { id, relatives in
                relatives.compactMap { relative -> OffloadCandidate? in
                    guard let path = ContainedPath.resolve(relative, in: directory)?.path,
                          let size = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int64 else { return nil }
                    return OffloadCandidate(id: id, relative: relative, size: size)
                }
            }
        }.value
    }

    /// How much `offloadAll()` could free right now, before checking the server.
    public func offloadableSpace(only ids: Set<String>? = nil) async -> (files: Int, bytes: Int64) {
        let candidates = await offloadCandidates(only: ids)
        return (candidates.count, candidates.reduce(0) { $0 + $1.size })
    }

    /// Frees space by deleting this Mac's copy of each playable file the
    /// personal server is confirmed to hold: a HEAD request for that exact
    /// path must answer 200 with the same size, and then the server's copy is
    /// downloaded and must hash (SHA-256) the same as this Mac's, or the file
    /// stays. Same size isn't proof: a corrupt or different file can match it. The
    /// catalog and `removed.json` are untouched — the wallpaper stays in the
    /// library and is fetched back the next time it's played. What was freed
    /// is listed in `offloaded.json`, so the importer keeps it rather than
    /// re-rendering or dropping it. `ids` limits the run (nil: all). A second
    /// call while one runs does nothing.
    @discardableResult
    public func offloadAll(only ids: Set<String>? = nil) async -> OffloadResult {
        var result = OffloadResult()
        guard !isOffloading else { return result }
        isOffloading = true
        defer { isOffloading = false }
        let candidates = await offloadCandidates(only: ids)
        guard let base = config.libraryServerURL, let root = URL(string: base) else {
            result.kept = candidates.map(\.relative)
            return result
        }
        let session = fetchSession
        let directory = libraryDirectory
        offloadProgress = (0, candidates.count)
        defer { offloadProgress = nil }
        var confirmed: [OffloadCandidate] = []
        // A few at a time: thousands one by one is needlessly slow, all at
        // once is needlessly hard on a home server.
        await withTaskGroup(of: (OffloadCandidate, Bool).self) { group in
            var pending = candidates.makeIterator()
            for _ in 0..<8 {
                guard let next = pending.next() else { break }
                group.addTask { (next, await Self.serverHolds(next, root: root, session: session, directory: directory)) }
            }
            while let (candidate, held) = await group.next() {
                if held { confirmed.append(candidate) } else { result.kept.append(candidate.relative) }
                offloadProgress = ((offloadProgress?.done ?? 0) + 1, candidates.count)
                if let next = pending.next() {
                    group.addTask { (next, await Self.serverHolds(next, root: root, session: session, directory: directory)) }
                }
            }
        }
        // Written down (and read back) before anything is deleted, so the importer
        // always knows a freed file was freed on purpose. If that can't be
        // recorded, nothing is deleted.
        guard recordOffloaded(confirmed.map(\.relative)) else {
            result.kept += confirmed.map(\.relative)
            return result
        }
        let toDelete = confirmed
        let deleted = await Task.detached(priority: .userInitiated) {
            toDelete.filter { candidate in
                guard let url = ContainedPath.resolve(candidate.relative, in: directory) else { return false }
                return (try? FileManager.default.removeItem(at: url)) != nil
            }
        }.value
        let deletedPaths = Set(deleted.map(\.relative))
        result.kept += confirmed.map(\.relative).filter { !deletedPaths.contains($0) }
        for candidate in deleted {
            result.freedFiles += 1
            result.freedBytes += candidate.size
            if libraryVideo(candidate.id)?.playback == candidate.relative { libraryCopies.remove(candidate.id) }
        }
        // Anything that couldn't be deleted is still here: not offloaded after all.
        let notDeleted = confirmed.map(\.relative).filter { !deletedPaths.contains($0) }
        if !notDeleted.isEmpty { unrecordOffloaded(notDeleted) }
        return result
    }

    /// Adds to `offloaded.json`: relative paths deliberately freed from this
    /// Mac because the server holds them. Read by the importer. True only once
    /// the file has been written and reads back with them in it.
    @discardableResult
    private func recordOffloaded(_ relatives: [String]) -> Bool {
        guard !relatives.isEmpty else { return true }
        return updateOffloaded { $0.formUnion(relatives) }
    }

    private func unrecordOffloaded(_ relatives: [String]) {
        updateOffloaded { $0.subtract(relatives) }
    }

    @discardableResult
    private func updateOffloaded(_ change: (inout Set<String>) -> Void) -> Bool {
        let url = libraryDirectory.appendingPathComponent("offloaded.json")
        var paths = Set((try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [])
        change(&paths)
        do {
            try JSONEncoder().encode(paths.sorted()).write(to: url, options: .atomic)
            serverConfirmed = paths
            return Set(try JSONDecoder().decode([String].self, from: Data(contentsOf: url))) == paths
        } catch {
            log.error("Couldn't record offloaded files: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Whether the server's copy of a file is the same as this Mac's: same size
    /// (a cheap HEAD first), then the same SHA-256 over its downloaded bytes.
    private nonisolated static func serverHolds(_ candidate: OffloadCandidate, root: URL, session: URLSession,
                                                directory: URL) async -> Bool {
        let remote = root.appendingPathComponent(candidate.relative)
        var head = URLRequest(url: remote)
        head.httpMethod = "HEAD"
        guard let (_, response) = try? await session.data(for: head),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let length = http.value(forHTTPHeaderField: "Content-Length").flatMap(Int64.init),
              length == candidate.size else { return false }
        guard let (downloaded, getResponse) = try? await session.download(for: URLRequest(url: remote)) else { return false }
        defer { try? FileManager.default.removeItem(at: downloaded) }
        guard (getResponse as? HTTPURLResponse)?.statusCode == 200,
              let theirs = FileDigest.sha256(of: downloaded),
              let local = ContainedPath.resolve(candidate.relative, in: directory),
              let ours = FileDigest.sha256(of: local) else { return false }
        return theirs == ours
    }

    /// Takes a library wallpaper out for good: deletes this Mac's own copies
    /// of it (never anything on the drive or folder it came from), records it
    /// in `removed.json` so re-importing that folder won't bring it back, and
    /// removes it from `catalog.json` on disk and in memory.
    ///
    /// Both files are edited as loose JSON, not through the typed models:
    /// `scripts/wallpaper_library.py` writes fields (`sha256`, `sceneNotes`,
    /// `movement`…) that the app's model doesn't carry, and a decode-reencode
    /// through it would silently drop those for every other wallpaper too.
    @discardableResult
    public func deleteLibraryVideo(_ id: String) -> LibraryVideo? {
        guard let video = libraryVideo(id) else { return nil }
        var problems: [String] = []
        if config.source == .library(id) {
            config.isEnabled = false
            config.source = WallpaperConfig().source
        }
        for relative in Set([video.playback, video.thumbnail, video.still].compactMap({ $0 })) {
            // Only inside the library: a catalog path that escapes it is never deleted.
            guard let url = ContainedPath.resolve(relative, in: libraryDirectory) else {
                log.error("Not deleting \(relative, privacy: .public): it isn't inside the library")
                continue
            }
            do {
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            } catch {
                problems.append("\(relative): \(error.localizedDescription)")
            }
        }
        let removedURL = libraryDirectory.appendingPathComponent("removed.json")
        var removed = (try? Data(contentsOf: removedURL)).flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        } ?? [:]
        removed[id] = ["reason": "removed by the user in the app"]
        do {
            try JSONSerialization.data(withJSONObject: removed, options: [.prettyPrinted, .sortedKeys]).write(to: removedURL, options: .atomic)
        } catch {
            problems.append("removed.json: \(error.localizedDescription)")
        }
        let catalogURL = libraryDirectory.appendingPathComponent("catalog.json")
        if let data = try? Data(contentsOf: catalogURL),
           var catalog = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           var items = catalog["items"] as? [[String: Any]] {
            items.removeAll { ($0["id"] as? String) == id }
            catalog["items"] = items
            do {
                try JSONSerialization.data(withJSONObject: catalog, options: [.sortedKeys]).write(to: catalogURL, options: .atomic)
            } catch {
                problems.append("catalog.json: \(error.localizedDescription)")
            }
        }
        lastLocalDeleteProblem = problems.isEmpty ? nil : problems.joined(separator: "; ")
        if let problem = lastLocalDeleteProblem { log.error("Local delete of \(id, privacy: .public) incomplete: \(problem, privacy: .public)") }
        library.removeAll { $0.id == id }
        libraryIndex = Dictionary(library.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        libraryCopies.remove(id)
        return video
    }

    /// The delete service's own address: always the SSH tunnel's local
    /// forward (`scripts/cloud/tunnel.sh`), never the Tailscale address —
    /// unlike fetching, a permanent cross-system delete is deliberately
    /// only reachable this way. Overridable for tests.
    public var deleteServiceURL = URL(string: "http://localhost:8081/wallpaper")!
    /// Instance, not a direct `DeleteAPIKeychain.token` read — so a test
    /// doesn't have to overwrite the real Keychain entry to exercise this.
    /// Nil reads Keychain, only when a permanent delete actually runs: reading
    /// it at launch made macOS ask for the login password after every rebuild.
    public var deleteServiceToken: String?

    /// What the last `deleteLibraryVideo` couldn't remove or record, or nil if it
    /// all went. Without this a failed write was silent and the wallpaper could
    /// come back at the next import.
    public private(set) var lastLocalDeleteProblem: String?

    public enum DeleteEverywhereOutcome: Sendable, Equatable {
        /// Gone here, on the server, and from the database.
        case success
        /// The server didn't confirm the delete, so nothing was deleted on this Mac
        /// either: says why. It stays in the library and in `pendingDeletes`, and
        /// calling `deleteEverywhere` again retries it.
        case notDeleted(String)
        /// Gone from the server and the database, but this Mac's copy or its record
        /// couldn't be fully removed: says what. Deleting it again finishes the job.
        case deletedOnServer(String)
    }

    /// Permanent deletes started but not confirmed by the server, by id: written
    /// before the server is asked, removed once it confirms. Survives a relaunch.
    public var pendingDeletes: [String] { pendingDeleteRecords.keys.sorted() }

    private var pendingDeletesURL: URL { libraryDirectory.appendingPathComponent("pending-deletes.json") }

    private var pendingDeleteRecords: [String: [String]] {
        (try? Data(contentsOf: pendingDeletesURL)).flatMap { try? JSONDecoder().decode([String: [String]].self, from: $0) } ?? [:]
    }

    @discardableResult
    private func updatePendingDeletes(_ change: (inout [String: [String]]) -> Void) -> Bool {
        var records = pendingDeleteRecords
        change(&records)
        do {
            try FileManager.default.createDirectory(at: libraryDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(records).write(to: pendingDeletesURL, options: .atomic)
            return pendingDeleteRecords == records
        } catch {
            log.error("Couldn't record a pending delete: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Deletes a wallpaper everywhere: the server's copy of its files and its
    /// Postgres row (through the delete service) first, and only once the server
    /// confirms, this Mac's copy (via `deleteLibraryVideo`). Until then it's
    /// recorded in `pendingDeletes`, so a failure leaves everything in place and
    /// calling this again retries. Call only after `AdminGate.authorize` — this
    /// function itself doesn't gate anything. Nil: no such wallpaper or pending delete.
    @discardableResult
    public func deleteEverywhere(_ id: String) async -> DeleteEverywhereOutcome? {
        let paths: [String]
        if let video = libraryVideo(id) {
            paths = Set([video.playback, video.thumbnail, video.still].compactMap { $0 }).sorted()
        } else if let pending = pendingDeleteRecords[id] {
            paths = pending
        } else {
            return nil
        }
        guard updatePendingDeletes({ $0[id] = paths }) else {
            return .notDeleted("Couldn't record the delete before starting it, so nothing was deleted.")
        }
        guard let token = deleteServiceToken ?? DeleteAPIKeychain.token else {
            return .notDeleted("No delete-service token in Keychain — see DeleteAPIKeychain.swift.")
        }
        var request = URLRequest(url: deleteServiceURL)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // The server works out the wallpaper's files from its id; `paths` is sent
        // for older servers only and isn't trusted by the current one.
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["id": id, "paths": paths])
        guard let (data, response) = try? await fetchSession.data(for: request),
              let http = response as? HTTPURLResponse else {
            return .notDeleted("Couldn't reach the delete service — is the tunnel open (scripts/cloud/tunnel.sh)?")
        }
        // 404: the server has no row and no files for it (an earlier attempt finished there).
        guard http.statusCode == 200 || http.statusCode == 404 else {
            let body = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?.description ?? "HTTP \(http.statusCode)"
            return .notDeleted(body)
        }
        deleteLibraryVideo(id)
        if let problem = lastLocalDeleteProblem {
            // Kept pending: asking again finds nothing left on the server (404) and retries here.
            return .deletedOnServer(problem)
        }
        updatePendingDeletes { $0[id] = nil }
        return .success
    }

    /// Copies videos in, so the wallpaper keeps working if the originals move.
    @discardableResult
    public func importVideos(from urls: [URL]) -> [String] {
        let imported = urls.filter(Self.isVideo).compactMap { url -> String? in
            let name = UUID().uuidString + "." + url.pathExtension.lowercased()
            do {
                try FileManager.default.copyItem(at: url, to: videoURL(name))
                return name
            } catch {
                log.error("Couldn't import \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        reloadVideos()
        return imported
    }

    public func deleteVideo(_ name: String) {
        try? FileManager.default.removeItem(at: videoURL(name))
        if config.source == .video(name) {
            config.isEnabled = false
            config.source = WallpaperConfig().source
        }
        reloadVideos()
    }

    public nonisolated static func isVideo(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) ?? false
    }

    /// The folder videos live in, for downloads to land in.
    public var videosFolder: URL { directory.appendingPathComponent("Videos") }

    /// Picks up files that arrived in the videos folder, like downloaded aerials.
    public func reloadVideos() {
        let folder = directory.appendingPathComponent("Videos")
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])) ?? []
        videos = urls.filter(Self.isVideo)
            .sorted {
                ((try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast)
                    > ((try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast)
            }
            .map(\.lastPathComponent)
    }

    /// Writes the settings now. True when they're on disk and read back the same.
    @discardableResult
    public func saveNow() -> Bool {
        save()
        return StoreFile.load(WallpaperConfig.self, from: fileURL) == config
    }

    /// Why the last settings save failed; nil once one works. Shown in the main window.
    public private(set) var saveError: String?

    private func save() {
        do {
            try JSONEncoder().encode(config).write(to: fileURL, options: .atomic)
            if saveError != nil { saveError = nil }
        } catch {
            log.error("Couldn't save wallpaper settings: \(error.localizedDescription, privacy: .public)")
            saveError = error.localizedDescription
        }
    }
}

/// A download that can be cancelled from any thread, including before it
/// has started.
private final class DownloadHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDownloadTask?
    private var cancelled = false

    func start(_ task: URLSessionDownloadTask) {
        lock.lock()
        self.task = task
        let cancelled = self.cancelled
        lock.unlock()
        task.resume()
        if cancelled { task.cancel() }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let task = self.task
        lock.unlock()
        task?.cancel()
    }
}
