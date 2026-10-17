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
    public internal(set) var videos: [String] = []
    /// Videos in libraries outside All Set (`Library/catalog.json`, written by
    /// the library's `catalog.json`), in catalog order.
    public internal(set) var library: [LibraryVideo] = []
    /// Whether `reloadLibrary()` has completed at least once. `library`
    /// starts empty and fills in asynchronously (a big catalog is a big
    /// file); a caller that needs to tell "genuinely not here" apart from
    /// "hasn't loaded yet" reads this, not just whether `library` is empty.
    public internal(set) var hasLoadedLibrary = false
    /// Library folders by id, and whether each can be reached right now (a
    /// drive may be unplugged).
    public internal(set) var libraryRoots: [String: WallpaperLibraryCatalog.Root] = [:]
    public internal(set) var reachableRoots: Set<String> = []
    @ObservationIgnored var libraryIndex: [String: Int] = [:]
    /// Ids whose converted copy is on disk: checked when the catalog loads,
    /// then kept up to date as copies are fetched back or freed. Observed, so
    /// a tile's "can this play" (and the wallpaper itself) redraws the moment
    /// that changes; it changes rarely, so this costs nothing while scrolling.
    var libraryCopies: Set<String> = []
    /// Relative paths freed from this Mac after the server's copy was checked
    /// to be the same file (size and SHA-256): `offloaded.json`. The only
    /// evidence this Mac has of what the server really holds.
    var serverConfirmed: Set<String> = []

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
    @ObservationIgnored public internal(set) var fetches: [String: Double] = [:]
    /// Relative paths being downloaded right now.
    public internal(set) var fetching: Set<String> = []
    /// Bumped each time a wallpaper's playable file lands, so anything that
    /// depends on one (the system-wallpaper still) can redo its work.
    public internal(set) var fetchGeneration = 0
    /// A "free up space" run in progress: files checked so far, of how many.
    public internal(set) var offloadProgress: (done: Int, total: Int)?
    @ObservationIgnored var isOffloading = false
    /// Whether `config.libraryServerURL` answered recently. Nil: not checked
    /// yet. Checked at most once per `Self.reachabilityMaxAge`, however many
    /// callers ask, same shape as `StatusService`.
    public internal(set) var serverReachable: Bool?
    @ObservationIgnored var serverCheckedAt: Date?
    @ObservationIgnored var serverCheckInFlight = false
    /// One download per relative path, shared by everyone who asks for it;
    /// `waiters` counts them so the last one to give up cancels it.
    @ObservationIgnored var inflight: [String: (token: UUID, task: Task<URL, Error>, waiters: Int)] = [:]
    /// Wallpapers whose download the person cancelled. Nothing fetches them
    /// on its own again (the desktop's retrying included) until they ask:
    /// picking the wallpaper, or opening its preview.
    public internal(set) var cancelledFetches = Set<String>()
    @ObservationIgnored static let reachabilityMaxAge: TimeInterval = 30
    /// Instance, not static: each `WallpaperStore` (one per test, one in the
    /// running app) gets its own session, so a test can point it at a stub
    /// without any risk of a concurrently-running test's session changing
    /// underneath it.
    @ObservationIgnored var fetchSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        return URLSession(configuration: configuration)
    }()

    /// The library server's API key (`LibraryKey`), read when a request starts.
    /// Nil when this Mac has none; the request then goes without one.
    @ObservationIgnored public var libraryBearer: (@MainActor () -> String?)?

    @ObservationIgnored let fileURL: URL
    @ObservationIgnored public let directory: URL
    @ObservationIgnored let log = Logger(subsystem: "com.pratik.allset", category: "wallpaper")

    /// Where the app keeps its wallpaper settings, videos and library.
    public nonisolated static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AllSet/Wallpaper", isDirectory: true)
    }

    public init(directory: URL? = nil) {
        let root = directory ?? Self.defaultDirectory
        self.directory = root
        fileURL = root.appendingPathComponent("wallpaper.json")
        FileAttempt.run("create the Videos folder") { try FileManager.default.createDirectory(at: root.appendingPathComponent("Videos"), withIntermediateDirectories: true) }
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


    @ObservationIgnored var hasDebugLibrary = false

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
    public internal(set) var lastLocalDeleteProblem: String?

    /// Why the last settings save failed; nil once one works. Shown in the main window.
    public internal(set) var saveError: String?
}

/// A download that can be cancelled from any thread, including before it
/// has started.
// Sendable because: `task` and `cancelled` are only touched under `lock`.
final class DownloadHandle: @unchecked Sendable {
    let lock = NSLock()
    var task: URLSessionDownloadTask?
    var cancelled = false

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

/// A request to the library server, carrying its API key when this Mac has one.
func libraryRequest(_ url: URL, method: String? = nil, bearer: String?) -> URLRequest {
    var request = URLRequest(url: url)
    if let method { request.httpMethod = method }
    if let bearer {
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    }
    return request
}
