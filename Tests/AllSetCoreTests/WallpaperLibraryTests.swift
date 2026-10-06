import Foundation
import Testing
@testable import AllSetCore

@Suite struct WallpaperLibraryTests {
    @Test func legacyCategoriesSurviveRemovingTheAerialCatalog() throws {
        for raw in ["landscapes", "cities", "underwater", "space", "games", "abstract"] {
            let data = Data("{\"id\":\"legacy\",\"title\":\"Saved wallpaper\",\"category\":\"\(raw)\",\"root\":\"disk\",\"file\":\"saved.mp4\"}".utf8)
            let saved = try JSONDecoder().decode(LibraryVideo.self, from: data)
            #expect(saved.category.rawValue == raw)
            let copy = try JSONDecoder().decode(LibraryVideo.self, from: JSONEncoder().encode(saved))
            #expect(copy.category == saved.category)
            #expect(copy.id == saved.id && copy.file == saved.file)
        }
    }
    private func video(_ id: String, _ title: String, category: WallpaperCategory = .games, tags: [String] = [],
                       width: Int = 1920, duration: Double = 10, added: String = "2026-09-27T10:00:00") -> LibraryVideo {
        LibraryVideo(id: id, title: title, category: category, tags: tags, root: "r1", file: "\(id).mp4",
                     duration: duration, width: width, height: width * 9 / 16, addedAt: added)
    }

    @Test func catalogSurvivesBadEntriesAndUnknownValues() throws {
        let json = """
            {"version": 1, "roots": [{"id": "r1", "path": "/Volumes/Drive/Walls", "label": "Walls"}],
             "items": [
               {"id": "a", "title": "Neon Alley", "category": "cities", "root": "r1", "file": "1/a.mp4", "status": "quarantined"},
               {"id": "b", "root": "r1", "file": "2/b.mp4", "category": "someNewKind", "status": "someNewStatus"},
               {"title": "no id, no file"},
               {"id": "c", "title": "Broken", "category": "space", "root": "r1", "file": "3/c.mp4", "status": "unsupported"}
             ]}
            """
        let catalog = try JSONDecoder().decode(WallpaperLibraryCatalog.self, from: Data(json.utf8))
        #expect(catalog.items.map(\.id) == ["a", "b", "c"])
        #expect(catalog.items[1].category == .abstract)
        // Unknown status is treated as the most careful one.
        #expect(catalog.items[1].status == .quarantined)
        #expect(catalog.items[1].title == "Untitled video")
        // Catalogs from before stills existed are all videos.
        #expect(catalog.items[0].kind == .video)
        #expect(catalog.roots.first?.label == "Walls")
    }

    @Test func searchLooksAtTitleTagsAndCategory() {
        let alley = video("a", "Alley Shops - Winter Neon City", category: .cities, tags: ["landscape", "4k"])
        #expect(alley.matches("neon"))
        #expect(alley.matches("winter 4k"))
        #expect(alley.matches("Cities"))
        #expect(!alley.matches("underwater"))
        #expect(alley.matches(""))
    }

    @Test func sortsUseRealMetadataOnly() {
        let videos = [video("a", "Beta", width: 1920, duration: 30, added: "2026-09-01T00:00:00"),
                      video("b", "alpha", width: 3840, duration: 5, added: "2026-09-27T00:00:00"),
                      video("c", "Gamma", width: 2560, duration: 60, added: "2026-09-10T00:00:00")]
        #expect(LibrarySort.title.sorted(videos).map(\.id) == ["b", "a", "c"])
        #expect(LibrarySort.newest.sorted(videos).map(\.id) == ["b", "c", "a"])
        #expect(LibrarySort.longest.sorted(videos).map(\.id) == ["c", "a", "b"])
        #expect(LibrarySort.resolution.sorted(videos).map(\.id) == ["b", "c", "a"])
        #expect(videos[1].resolutionLabel == "4K")
    }

    @Test func librarySourceRoundTrips() throws {
        var config = WallpaperConfig()
        config.source = .library("0123456789abcdef")
        let again = try JSONDecoder().decode(WallpaperConfig.self, from: JSONEncoder().encode(config))
        #expect(again.source == .library("0123456789abcdef"))
    }

    @MainActor @Test func resolvesPlaybackCopyOriginalOrNothing() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("wallpaper-\(UUID())")
        let drive = home.appendingPathComponent("Drive")
        defer { try? FileManager.default.removeItem(at: home) }
        let store = WallpaperStore(directory: home.appendingPathComponent("AllSet"))
        try FileManager.default.createDirectory(at: drive.appendingPathComponent("1"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: store.libraryDirectory.appendingPathComponent("transcoded"), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: drive.appendingPathComponent("1/a.mp4"))
        try Data("y".utf8).write(to: store.libraryDirectory.appendingPathComponent("transcoded/b.mp4"))
        try FileManager.default.createDirectory(at: store.libraryDirectory.appendingPathComponent("stills"), withIntermediateDirectories: true)
        try Data("z".utf8).write(to: store.libraryDirectory.appendingPathComponent("stills/e.jpg"))
        let catalog = WallpaperLibraryCatalog(
            roots: [.init(id: "r1", path: drive.path, label: "Drive")],
            items: [LibraryVideo(id: "a", title: "A", category: .games, root: "r1", file: "1/a.mp4"),
                    LibraryVideo(id: "b", title: "B", category: .games, root: "r1", file: "2/b.mp4", playback: "transcoded/b.mp4"),
                    LibraryVideo(id: "c", title: "C", category: .games, root: "r1", file: "missing.mp4"),
                    LibraryVideo(id: "d", title: "D", category: .games, root: "r1", file: "1/a.mp4", status: .unsupported),
                    LibraryVideo(id: "e", title: "E", kind: .image, category: .abstract, root: "r1", file: "3/scene.pkg",
                                 playback: "stills/e.jpg"),
                    LibraryVideo(id: "f", title: "F", kind: .image, category: .abstract, root: "r1", file: "1/a.mp4",
                                 playback: "stills/missing.jpg")])
        try JSONEncoder().encode(catalog).write(to: store.libraryDirectory.appendingPathComponent("catalog.json"))
        store.reloadLibrary()
        for _ in 0..<100 where store.library.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        // Unsupported entries never reach the gallery.
        #expect(store.library.map(\.id) == ["a", "b", "c", "e", "f"])
        // A still resolves to its picture, never to the scene package it came from.
        #expect(store.libraryURL("e")?.lastPathComponent == "e.jpg")
        #expect(store.libraryURL("f") == nil)
        #expect(store.libraryURL("a")?.path == drive.appendingPathComponent("1/a.mp4").path)
        // The converted copy wins over the original.
        #expect(store.libraryURL("b")?.lastPathComponent == "b.mp4")
        #expect(store.libraryURL("b")?.path.contains("transcoded") == true)
        #expect(store.libraryURL("c") == nil)
        // Unplugging the drive: nothing resolves from it (the local copy still does).
        try FileManager.default.removeItem(at: drive)
        store.refreshLibraryReachability()
        #expect(store.libraryURL("a") == nil)
        #expect(store.libraryURL("b") != nil)
        // Stills live on this Mac: still playable with the drive gone.
        #expect(store.libraryURL("e") != nil)
        #expect(store.canPlay(store.libraryVideo("e")!))
        #expect(!store.canPlay(store.libraryVideo("a")!))
    }

    /// The user's delete button: gone from the app, gone from disk, and it
    /// never comes back — without silently losing data the importer wrote
    /// for every *other* wallpaper (the risk in editing the catalog by hand).
    @MainActor @Test func deletingALibraryVideoIsPermanentAndLeavesOthersIntact() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("wallpaper-\(UUID())")
        defer { try? FileManager.default.removeItem(at: home) }
        let store = WallpaperStore(directory: home.appendingPathComponent("AllSet"))
        for folder in ["live", "stills", "thumbnails"] {
            try FileManager.default.createDirectory(at: store.libraryDirectory.appendingPathComponent(folder),
                                                    withIntermediateDirectories: true)
        }
        try Data("loop".utf8).write(to: store.libraryDirectory.appendingPathComponent("live/a.mp4"))
        try Data("still".utf8).write(to: store.libraryDirectory.appendingPathComponent("stills/a.jpg"))
        try Data("thumb-a".utf8).write(to: store.libraryDirectory.appendingPathComponent("thumbnails/a.jpg"))
        try Data("thumb-b".utf8).write(to: store.libraryDirectory.appendingPathComponent("thumbnails/b.jpg"))
        // Fields the importer writes that the app's model doesn't know about
        // (a stand-in for sha256, sceneNotes, movement…): must survive.
        let catalog: [String: Any] = [
            "version": 1, "roots": [["id": "r1", "path": "/Volumes/Drive", "label": "Drive"]],
            "items": [
                ["id": "a", "title": "Delete Me", "category": "games", "root": "r1", "file": "1/a.mp4",
                 "playback": "live/a.mp4", "still": "stills/a.jpg", "thumbnail": "thumbnails/a.jpg", "sha256": "deadbeef"],
                ["id": "b", "title": "Keep Me", "category": "games", "root": "r1", "file": "2/b.mp4",
                 "thumbnail": "thumbnails/b.jpg", "sha256": "cafef00d", "sceneNotes": ["unsupported": ["particle object": 3]]],
            ],
        ]
        let catalogURL = store.libraryDirectory.appendingPathComponent("catalog.json")
        try JSONSerialization.data(withJSONObject: catalog).write(to: catalogURL)
        store.reloadLibrary()
        for _ in 0..<100 where store.library.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        #expect(store.library.map(\.id).sorted() == ["a", "b"])

        store.deleteLibraryVideo("a")

        #expect(store.libraryVideo("a") == nil)
        #expect(store.library.map(\.id) == ["b"])
        for path in ["live/a.mp4", "stills/a.jpg", "thumbnails/a.jpg"] {
            #expect(!FileManager.default.fileExists(atPath: store.libraryDirectory.appendingPathComponent(path).path))
        }
        // Untouched: not this wallpaper's file, and not referenced by it.
        #expect(FileManager.default.fileExists(atPath: store.libraryDirectory.appendingPathComponent("thumbnails/b.jpg").path))

        let removed = try JSONSerialization.jsonObject(with: Data(contentsOf: store.libraryDirectory.appendingPathComponent("removed.json")))
        #expect((removed as? [String: Any])?["a"] != nil)

        // The rewritten catalog.json still has "b"'s importer-only fields —
        // proof this went through raw JSON, not a lossy decode/re-encode.
        let after = try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        let items = after?["items"] as? [[String: Any]]
        #expect(items?.count == 1)
        #expect(items?.first?["id"] as? String == "b")
        #expect(items?.first?["sha256"] as? String == "cafef00d")
        #expect(items?.first?["sceneNotes"] != nil)

        // A re-import of the same folder must not bring "a" back: this is
        // what makes the delete permanent, not just a session-local hide.
        #expect((removed as? [String: Any])?.keys.contains("a") == true)
    }

    /// `library` fills in asynchronously; a real regression this session
    /// (`WallpaperView` rendering before the catalog loaded, giving up on a
    /// fetch permanently instead of retrying once real data arrived) was
    /// only found by testing against the actual running app, not a mock.
    /// This is the property that fix depends on: it must start false and
    /// flip true once, not before.
    @MainActor @Test func hasLoadedLibraryStartsFalseAndFlipsOnceLoaded() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("wallpaper-\(UUID())")
        defer { try? FileManager.default.removeItem(at: home) }
        let store = WallpaperStore(directory: home)
        // The async load's Task can't have run yet: init() hasn't awaited
        // anything, so nothing has yielded back to the run loop for it to
        // start on. This is exactly the window WallpaperView can render in.
        #expect(!store.hasLoadedLibrary)
        for _ in 0..<200 where !store.hasLoadedLibrary { try await Task.sleep(for: .milliseconds(10)) }
        #expect(store.hasLoadedLibrary)
    }

    /// The promise behind `--self-contained`: once every wallpaper has a copy
    /// here, deleting the folder they came from changes nothing.
    @MainActor @Test func copiedLibraryOutlivesTheFolderItCameFrom() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("wallpaper-\(UUID())")
        let drive = home.appendingPathComponent("Pendrive")
        defer { try? FileManager.default.removeItem(at: home) }
        let store = WallpaperStore(directory: home.appendingPathComponent("AllSet"))
        try FileManager.default.createDirectory(at: drive, withIntermediateDirectories: true)
        try Data("source".utf8).write(to: drive.appendingPathComponent("clip.mp4"))
        for folder in ["originals", "live"] {
            try FileManager.default.createDirectory(at: store.libraryDirectory.appendingPathComponent(folder),
                                                    withIntermediateDirectories: true)
        }
        try Data("copy".utf8).write(to: store.libraryDirectory.appendingPathComponent("originals/a.mp4"))
        try Data("loop".utf8).write(to: store.libraryDirectory.appendingPathComponent("live/b.mp4"))
        let catalog = WallpaperLibraryCatalog(
            roots: [.init(id: "r1", path: drive.path, label: "Pendrive")],
            items: [LibraryVideo(id: "a", title: "Copied", category: .games, root: "r1", file: "clip.mp4",
                                 playback: "originals/a.mp4"),
                    LibraryVideo(id: "b", title: "Scene loop", category: .abstract, root: "r1", file: "scene.pkg",
                                 playback: "live/b.mp4")])
        try JSONEncoder().encode(catalog).write(to: store.libraryDirectory.appendingPathComponent("catalog.json"))
        store.reloadLibrary()
        for _ in 0..<100 where store.library.isEmpty { try await Task.sleep(for: .milliseconds(20)) }

        // The pendrive is wiped and unplugged.
        try FileManager.default.removeItem(at: drive)
        store.refreshLibraryReachability()
        #expect(!store.reachableRoots.contains("r1"))
        for id in ["a", "b"] {
            let video = try #require(store.libraryVideo(id))
            #expect(store.canPlay(video))
            #expect(store.libraryURL(id) != nil)
            // It plays from this Mac, never from the folder that's gone.
            #expect(store.libraryURL(id)?.path.hasPrefix(store.libraryDirectory.path) == true)
        }
    }
}

/// A request handler installed per test, so `StubURLProtocol` never has to
/// guess which test it's answering for.
private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (status: Int, body: Data?))?
    /// Seconds before answering, so a test can cancel mid-download.
    nonisolated(unsafe) static var delay: TimeInterval = 0
    /// GET requests seen (downloads, not HEAD checks).
    nonisolated(unsafe) static var downloads = 0
    /// A Content-Length that disagrees with the body: a truncated response.
    nonisolated(unsafe) static var claimedLength: Int?
    private let stopped = NSLock()
    nonisolated(unsafe) private var isStopped = false

    static func reset() {
        handler = nil
        delay = 0
        downloads = 0
        claimedLength = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if request.httpMethod != "HEAD" { Self.downloads += 1 }
        if Self.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.delay) { self.answer() }
        } else {
            answer()
        }
    }

    private func answer() {
        stopped.lock()
        let stop = isStopped
        stopped.unlock()
        if stop { return }
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        let (status, body) = handler(request)
        // Like a real file server: a HEAD answers with the file's length and
        // no body, so a handler just describes the file either way.
        let headers = body.map { ["Content-Length": "\(Self.claimedLength ?? $0.count)"] }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let body, request.httpMethod != "HEAD" { client?.urlProtocol(self, didLoad: body) }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        stopped.lock()
        isStopped = true
        stopped.unlock()
    }
}

/// `.serialized`: every test here points the shared `StubURLProtocol.handler`
/// at its own behaviour, which a concurrently-running sibling would stomp on.
@Suite(.serialized) struct LibraryServerFetchTests {
    /// A store with one catalog entry that has no local copy and no
    /// reachable source root, plus a server configured to answer over a
    /// stubbed session — everything the fetch path actually needs, nothing
    /// it doesn't.
    @MainActor private func missingLibraryVideo(relative: String = "live/f1.mp4") async throws -> (store: WallpaperStore, id: String) {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("wallpaper-\(UUID())")
        let store = WallpaperStore(directory: home)
        let id = "f1"
        let catalog: [String: Any] = [
            "version": 1, "roots": [],
            "items": [["id": id, "title": "Fetchable", "category": "games", "root": "gone", "file": "1/f1.mp4",
                      "playback": relative, "thumbnail": "thumbnails/f1.jpg"]],
        ]
        try FileManager.default.createDirectory(at: store.libraryDirectory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: catalog).write(to: store.libraryDirectory.appendingPathComponent("catalog.json"))
        store.reloadLibrary()
        for _ in 0..<100 where store.library.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        store.config.libraryServerURL = "http://stub.invalid"
        StubURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        store.fetchSession = URLSession(configuration: configuration)
        return (store, id)
    }

    /// Review U5: a configured server and a path in the catalog aren't proof the
    /// server has the file; without a check it's only expected there.
    @MainActor @Test func aServerCopyNobodyCheckedIsOnlyExpected() async throws {
        let (store, id) = try await missingLibraryVideo()
        let video = try #require(store.libraryVideo(id))
        #expect(store.copyLocation(video) == .expectedOnServer)
        store.config.libraryServerURL = nil
        #expect(store.copyLocation(video) == .unavailable)
    }

    @MainActor @Test func alreadyLocalNeverTouchesTheNetwork() async throws {
        let (store, id) = try await missingLibraryVideo()
        // No handler installed: any network attempt fails loudly, not silently.
        StubURLProtocol.handler = nil
        let relative = "live/f1.mp4"
        try FileManager.default.createDirectory(at: store.libraryDirectory.appendingPathComponent("live"), withIntermediateDirectories: true)
        try Data("already here".utf8).write(to: store.libraryDirectory.appendingPathComponent(relative))
        let url = try await store.fetchLibraryVideo(id)
        #expect(url.path == store.libraryDirectory.appendingPathComponent(relative).path)
    }

    @MainActor @Test func fetchesAndCachesInTheSameRelativePath() async throws {
        let (store, id) = try await missingLibraryVideo()
        let bytes = Data("stub-video-bytes".utf8)
        StubURLProtocol.handler = { request in
            #expect(request.url?.absoluteString == "http://stub.invalid/live/f1.mp4")
            return (200, bytes)
        }
        let video = try #require(store.libraryVideo(id))
        #expect(!store.canPlay(video))

        let url = try await store.fetchLibraryVideo(id)

        #expect(url.path == store.libraryDirectory.appendingPathComponent("live/f1.mp4").path)
        #expect(try Data(contentsOf: url) == bytes)
        #expect(store.canPlay(video))
        // Ordinary resolution finds it now too, with no server involved.
        #expect(store.libraryURL(id) == url)
    }

    @MainActor @Test func unreachableServerThrowsAndLeavesNoPartialFile() async throws {
        let (store, id) = try await missingLibraryVideo()
        StubURLProtocol.handler = { _ in (500, nil) }

        await #expect(throws: (any Error).self) {
            try await store.fetchLibraryVideo(id)
        }

        let destination = store.libraryDirectory.appendingPathComponent("live/f1.mp4")
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        let video = try #require(store.libraryVideo(id))
        #expect(!store.canPlay(video))
    }

    @MainActor @Test func missingThumbnailComesBackFromTheServer() async throws {
        let (store, id) = try await missingLibraryVideo()
        let bytes = Data("stub-thumbnail".utf8)
        StubURLProtocol.handler = { request in
            #expect(request.url?.absoluteString == "http://stub.invalid/thumbnails/f1.jpg")
            return (200, bytes)
        }
        let url = try await store.fetchThumbnail(id)
        #expect(url.path == store.libraryDirectory.appendingPathComponent("thumbnails/f1.jpg").path)
        #expect(try Data(contentsOf: url) == bytes)
    }

    /// Keyed by relative path, not id: a wallpaper's video and its thumbnail
    /// can both be on their way at once.
    @MainActor @Test func videoAndThumbnailFetchesDontCollide() async throws {
        let (store, id) = try await missingLibraryVideo()
        StubURLProtocol.handler = { request in (200, Data((request.url?.lastPathComponent ?? "").utf8)) }
        async let video = store.fetchLibraryVideo(id)
        async let thumbnail = store.fetchThumbnail(id)
        let (videoURL, thumbnailURL) = try await (video, thumbnail)
        #expect(try Data(contentsOf: videoURL) == Data("f1.mp4".utf8))
        #expect(try Data(contentsOf: thumbnailURL) == Data("f1.jpg".utf8))
    }

    /// Three local wallpapers: the server holds an identical copy of one, has
    /// never heard of another, and holds a copy of the third that's the
    /// wrong size (a truncated upload, say). Only the first may go.
    @MainActor private func offloadableLibrary() async throws -> WallpaperStore {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("wallpaper-\(UUID())")
        let store = WallpaperStore(directory: home)
        let items: [[String: Any]] = ["a", "b", "c"].map { id in
            ["id": id, "title": id.uppercased(), "category": "games", "root": "gone", "file": "\(id).mp4",
             "playback": "live/\(id).mp4", "thumbnail": "thumbnails/\(id).jpg"]
        }
        let live = store.libraryDirectory.appendingPathComponent("live")
        let thumbnails = store.libraryDirectory.appendingPathComponent("thumbnails")
        try FileManager.default.createDirectory(at: live, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: thumbnails, withIntermediateDirectories: true)
        for id in ["a", "b", "c"] {
            try Data("\(id)\(id)\(id)\(id)".utf8).write(to: live.appendingPathComponent("\(id).mp4"))
            try Data("thumb".utf8).write(to: thumbnails.appendingPathComponent("\(id).jpg"))
        }
        try JSONSerialization.data(withJSONObject: ["version": 1, "roots": [], "items": items] as [String: Any])
            .write(to: store.libraryDirectory.appendingPathComponent("catalog.json"))
        store.reloadLibrary()
        for _ in 0..<100 where !store.hasLoadedLibrary { try await Task.sleep(for: .milliseconds(20)) }
        store.config.libraryServerURL = "http://stub.invalid"
        StubURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        store.fetchSession = URLSession(configuration: configuration)
        StubURLProtocol.handler = { request in
            switch request.url?.lastPathComponent {
            case "a.mp4": (200, Data("aaaa".utf8))
            case "c.mp4": (200, Data("cc".utf8))
            default: (404, nil)
            }
        }
        return store
    }

    @MainActor @Test func freeingSpaceDeletesOnlyWhatTheServerConfirms() async throws {
        let store = try await offloadableLibrary()
        let catalogURL = store.libraryDirectory.appendingPathComponent("catalog.json")
        let catalogBefore = try Data(contentsOf: catalogURL)
        #expect(await store.offloadableSpace() == (3, 12))

        let result = await store.offloadAll()

        #expect(result.freedFiles == 1)
        #expect(result.freedBytes == 4)
        #expect(result.kept.sorted() == ["live/b.mp4", "live/c.mp4"])
        let live = store.libraryDirectory.appendingPathComponent("live")
        #expect(!FileManager.default.fileExists(atPath: live.appendingPathComponent("a.mp4").path))
        #expect(FileManager.default.fileExists(atPath: live.appendingPathComponent("b.mp4").path))
        #expect(FileManager.default.fileExists(atPath: live.appendingPathComponent("c.mp4").path))
        // Thumbnails stay, so the grid is still instant.
        #expect(FileManager.default.fileExists(atPath: store.libraryDirectory.appendingPathComponent("thumbnails/a.jpg").path))
        // Still in the library, never removed: only its local copy went.
        #expect(try Data(contentsOf: catalogURL) == catalogBefore)
        #expect(!FileManager.default.fileExists(atPath: store.libraryDirectory.appendingPathComponent("removed.json").path))
        let a = try #require(store.libraryVideo("a"))
        #expect(!store.canPlay(a))
        #expect(store.canPlay(try #require(store.libraryVideo("b"))))
        #expect(store.offloadProgress == nil)
        // Review U5: only a copy checked on the server is called confirmed there.
        #expect(store.copyLocation(a) == .confirmedOnServer)
        #expect(store.copyLocation(try #require(store.libraryVideo("b"))) == .thisMac)

        // And the round trip: played again, it comes straight back.
        let url = try await store.fetchLibraryVideo("a")
        #expect(try Data(contentsOf: url) == Data("aaaa".utf8))
        #expect(store.canPlay(a))
    }

    /// The same size isn't the same file: a server copy with different bytes keeps ours.
    @MainActor @Test func freeingSpaceKeepsAFileWhoseServerCopyDiffers() async throws {
        let store = try await offloadableLibrary()
        StubURLProtocol.handler = { request in
            request.url?.lastPathComponent == "a.mp4" ? (200, Data("zzzz".utf8)) : (404, nil)
        }
        let result = await store.offloadAll()
        #expect(result.freedFiles == 0)
        #expect(FileManager.default.fileExists(atPath: store.libraryDirectory.appendingPathComponent("live/a.mp4").path))
    }

    /// If what was freed can't be written down first, nothing is freed.
    @MainActor @Test func freeingSpaceDeletesNothingWhenItCantRecordIt() async throws {
        let store = try await offloadableLibrary()
        // A folder where the record file goes: it can't be written.
        try FileManager.default.createDirectory(at: store.libraryDirectory.appendingPathComponent("offloaded.json"),
                                                withIntermediateDirectories: true)
        let result = await store.offloadAll()
        #expect(result.freedFiles == 0)
        #expect(result.kept.contains("live/a.mp4"))
        #expect(FileManager.default.fileExists(atPath: store.libraryDirectory.appendingPathComponent("live/a.mp4").path))
    }

    @MainActor @Test func freeingSpaceWithoutAServerKeepsEverything() async throws {
        let store = try await offloadableLibrary()
        store.config.libraryServerURL = nil
        let result = await store.offloadAll()
        #expect(result.freedFiles == 0)
        #expect(result.kept.count == 3)
        for id in ["a", "b", "c"] {
            #expect(FileManager.default.fileExists(atPath: store.libraryDirectory.appendingPathComponent("live/\(id).mp4").path))
        }
    }

    @MainActor @Test func freeingSpaceCanBeLimitedToSomeWallpapers() async throws {
        let store = try await offloadableLibrary()
        #expect(await store.offloadableSpace(only: ["a"]) == (1, 4))
        let result = await store.offloadAll(only: ["a", "b"])
        #expect(result.freedFiles == 1)
        #expect(result.kept == ["live/b.mp4"])
        #expect(FileManager.default.fileExists(atPath: store.libraryDirectory.appendingPathComponent("live/c.mp4").path))
    }

    // MARK: Audit fixes (2026-09-29)

    /// The server was down (or Tailscale still connecting) on the first try:
    /// the wallpaper must still arrive once it's back, not stay on art.
    @MainActor @Test func failedFetchIsRetriedUntilTheServerAnswers() async throws {
        let (store, id) = try await missingLibraryVideo()
        nonisolated(unsafe) var attempts = 0
        StubURLProtocol.handler = { _ in
            attempts += 1
            return attempts < 3 ? (500, nil) : (200, Data("late".utf8))
        }
        let url = await store.fetchLibraryVideoRetrying(id, delays: [.milliseconds(10)])
        #expect(try Data(contentsOf: try #require(url)) == Data("late".utf8))
        #expect(attempts == 3)
    }

    @MainActor @Test func retryingStopsWhenThereIsNoServer() async throws {
        let (store, id) = try await missingLibraryVideo()
        store.config.libraryServerURL = nil
        #expect(await store.fetchLibraryVideoRetrying(id, delays: [.milliseconds(10)]) == nil)
    }

    /// Two views asking at once share one download instead of one failing.
    @MainActor @Test func simultaneousFetchesShareOneDownload() async throws {
        let (store, id) = try await missingLibraryVideo()
        StubURLProtocol.delay = 0.1
        StubURLProtocol.handler = { _ in (200, Data("once".utf8)) }
        async let first = store.fetchLibraryVideo(id)
        async let second = store.fetchLibraryVideo(id)
        let (a, b) = try await (first, second)
        #expect(a == b)
        #expect(StubURLProtocol.downloads == 1)
    }

    /// Nobody waiting any more: the download stops, and leaves nothing behind.
    @MainActor @Test func cancelledFetchStopsAndLeavesNothing() async throws {
        let (store, id) = try await missingLibraryVideo()
        StubURLProtocol.delay = 0.5
        StubURLProtocol.handler = { _ in (200, Data("too late".utf8)) }
        let task = Task { try await store.fetchLibraryVideo(id) }
        try await Task.sleep(for: .milliseconds(50))
        #expect(store.isFetching(id))
        task.cancel()
        await #expect(throws: (any Error).self) { try await task.value }
        try await Task.sleep(for: .milliseconds(600))
        #expect(!FileManager.default.fileExists(atPath: store.libraryDirectory.appendingPathComponent("live/f1.mp4").path))
        #expect(!store.isFetching(id))
    }

    /// The Cancel button: the download stops for everyone waiting, nothing
    /// partial is left, and retrying doesn't start it again until the
    /// wallpaper is picked once more.
    @MainActor @Test func cancellingStopsTheDownloadAndItsRetries() async throws {
        let (store, id) = try await missingLibraryVideo()
        StubURLProtocol.delay = 0.5
        StubURLProtocol.handler = { _ in (200, Data("too late".utf8)) }
        let retrying = Task { await store.fetchLibraryVideoRetrying(id, delays: [.milliseconds(10)]) }
        try await Task.sleep(for: .milliseconds(50))
        #expect(store.isFetching(id))
        store.cancelFetch(id)
        #expect(await retrying.value == nil)
        try await Task.sleep(for: .milliseconds(600))
        #expect(!FileManager.default.fileExists(atPath: store.libraryDirectory.appendingPathComponent("live/f1.mp4").path))
        #expect(!store.isFetching(id))
        #expect(await store.fetchLibraryVideoRetrying(id) == nil)
        // Picking it again lets it download.
        store.set(.library(id))
        #expect(!store.cancelledFetches.contains(id))
    }

    /// A response shorter than its Content-Length never becomes the file.
    @MainActor @Test func truncatedDownloadIsRejected() async throws {
        let (store, id) = try await missingLibraryVideo()
        StubURLProtocol.claimedLength = 1_000
        StubURLProtocol.handler = { _ in (200, Data("short".utf8)) }
        await #expect(throws: (any Error).self) { try await store.fetchLibraryVideo(id) }
        #expect(!FileManager.default.fileExists(atPath: store.libraryDirectory.appendingPathComponent("live/f1.mp4").path))
    }

    /// The wallpaper on the desktop isn't freed: it would only download straight back.
    @MainActor @Test func freeingSpaceKeepsTheActiveWallpaper() async throws {
        let store = try await offloadableLibrary()
        store.set(.library("a"))
        #expect(await store.offloadableSpace() == (2, 8))
        let result = await store.offloadAll()
        #expect(result.freedFiles == 0)
        #expect(FileManager.default.fileExists(atPath: store.libraryDirectory.appendingPathComponent("live/a.mp4").path))
    }

    /// What was freed is recorded for the importer, so a re-import keeps it.
    @MainActor @Test func freeingSpaceRecordsWhatWasFreed() async throws {
        let store = try await offloadableLibrary()
        await store.offloadAll()
        let data = try Data(contentsOf: store.libraryDirectory.appendingPathComponent("offloaded.json"))
        #expect(try JSONDecoder().decode([String].self, from: data) == ["live/a.mp4"])
    }

    @MainActor @Test func overlappingFreeUpSpaceRunsOnlyOnce() async throws {
        let store = try await offloadableLibrary()
        async let first = store.offloadAll()
        async let second = store.offloadAll()
        let (a, b) = await (first, second)
        #expect(a.freedFiles + b.freedFiles == 1)
    }

    /// `fetchProgress` is what the download bar reads: nil when idle, then
    /// real progress while a download is under way.
    @MainActor @Test func fetchProgressReflectsAnUnderwayDownload() async throws {
        let (store, id) = try await missingLibraryVideo()
        #expect(store.fetchProgress(for: id) == nil)
        StubURLProtocol.delay = 0.3
        StubURLProtocol.handler = { _ in (200, Data(repeating: 0, count: 200_000)) }
        let task = Task { try await store.fetchLibraryVideo(id) }
        try await Task.sleep(for: .milliseconds(50))
        #expect(store.isFetching(id))
        #expect(store.fetchProgress(for: id) != nil)
        _ = try await task.value
        #expect(store.fetchProgress(for: id) == nil)
    }

    // MARK: deleteEverywhere

    @MainActor @Test func deleteEverywhereRemovesLocallyAndCallsTheDeleteService() async throws {
        let (store, id) = try await missingLibraryVideo()
        try FileManager.default.createDirectory(at: store.libraryDirectory.appendingPathComponent("live"), withIntermediateDirectories: true)
        try Data("here".utf8).write(to: store.libraryDirectory.appendingPathComponent("live/f1.mp4"))
        StubURLProtocol.handler = { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            // request.httpBody, not .httpBodyStream: URLSession may convert
            // a body to a stream before a URLProtocol sees it, and reading
            // that stream outside a run loop can block indefinitely.
            if let body = request.httpBody, let sent = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                #expect(sent["id"] as? String == id)
                #expect(sent["paths"] as? [String] == ["live/f1.mp4"])
            }
            return (200, Data("{}".utf8))
        }
        store.deleteServiceURL = URL(string: "http://stub.invalid/wallpaper")!
        store.deleteServiceToken = "test-token"

        let outcome = await store.deleteEverywhere(id)

        #expect(outcome == .success)
        #expect(!FileManager.default.fileExists(atPath: store.libraryDirectory.appendingPathComponent("live/f1.mp4").path))
        #expect(store.libraryVideo(id) == nil)
    }

    /// A server failure deletes nothing anywhere: the wallpaper stays on this Mac and
    /// in the library, the delete is remembered, and asking again finishes it.
    /// Review D6: the server confirmed, but this Mac's record of the delete couldn't
    /// be written; that is reported, not called a success, and stays retryable.
    @MainActor @Test func aLocalCleanupFailureAfterTheServerDeleteIsReported() async throws {
        let (store, id) = try await missingLibraryVideo()
        // A folder where removed.json goes: recording the delete fails.
        try FileManager.default.createDirectory(at: store.libraryDirectory.appendingPathComponent("removed.json"),
                                                withIntermediateDirectories: true)
        StubURLProtocol.handler = { _ in (200, Data("{}".utf8)) }
        store.deleteServiceURL = URL(string: "http://stub.invalid/wallpaper")!
        store.deleteServiceToken = "test-token"

        let outcome = await store.deleteEverywhere(id)

        guard case .deletedOnServer(let problem) = outcome else {
            Issue.record("expected .deletedOnServer, got \(String(describing: outcome))"); return
        }
        #expect(problem.contains("removed.json"))
        #expect(store.lastLocalDeleteProblem != nil)
        #expect(store.pendingDeletes == [id])
    }

    @MainActor @Test func aFailedDeleteEverywhereDeletesNothingAndCanBeRetried() async throws {
        let (store, id) = try await missingLibraryVideo()
        let file = store.libraryDirectory.appendingPathComponent("live/f1.mp4")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("here".utf8).write(to: file)
        StubURLProtocol.handler = { _ in (500, Data("{\"error\":\"db down\"}".utf8)) }
        store.deleteServiceURL = URL(string: "http://stub.invalid/wallpaper")!
        store.deleteServiceToken = "test-token"

        let outcome = await store.deleteEverywhere(id)

        guard case .notDeleted = outcome else { Issue.record("expected .notDeleted, got \(String(describing: outcome))"); return }
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(store.libraryVideo(id) != nil)
        #expect(store.pendingDeletes == [id])

        // Fixed on the server: the same call now finishes it.
        StubURLProtocol.handler = { _ in (200, Data("{}".utf8)) }
        #expect(await store.deleteEverywhere(id) == .success)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(store.libraryVideo(id) == nil)
        #expect(store.pendingDeletes.isEmpty)
    }

    /// The server has nothing left for it (an earlier attempt finished there): done.
    @MainActor @Test func deleteEverywhereFinishesWhenTheServerHasNothingLeft() async throws {
        let (store, id) = try await missingLibraryVideo()
        StubURLProtocol.handler = { _ in (404, Data("{\"error\":\"unknown id\"}".utf8)) }
        store.deleteServiceURL = URL(string: "http://stub.invalid/wallpaper")!
        store.deleteServiceToken = "test-token"
        #expect(await store.deleteEverywhere(id) == .success)
        #expect(store.libraryVideo(id) == nil)
        #expect(store.pendingDeletes.isEmpty)
    }
}
