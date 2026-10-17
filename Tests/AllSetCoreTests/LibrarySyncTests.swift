import Foundation
import Testing
@testable import AllSetCore

/// Answers as the library server would, from a handler the test installs.
private final class LibraryServerStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (status: Int, body: Data?))?
    /// A Content-Length that disagrees with the body: a truncated response.
    nonisolated(unsafe) static var claimedLength: Int?
    /// The ETag sent with every answer; a request that names it gets 304 and no body.
    nonisolated(unsafe) static var tag: String?
    private static let lock = NSLock()
    nonisolated(unsafe) private static var seen: [String] = []

    /// The paths asked for, in order.
    static var requested: [String] { lock.withLock { seen } }

    static func reset() {
        handler = nil
        claimedLength = nil
        tag = nil
        lock.withLock { seen = [] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        Self.lock.withLock { Self.seen.append(url.path) }
        var (status, body) = handler(request)
        if status == 200, let tag = Self.tag, request.value(forHTTPHeaderField: "If-None-Match") == tag {
            (status, body) = (304, nil)
        }
        var headers = body.map { ["Content-Length": "\(Self.claimedLength ?? $0.count)"] } ?? [:]
        headers["ETag"] = Self.tag
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!,
                            cacheStoragePolicy: .notAllowed)
        if let body { client?.urlProtocol(self, didLoad: body) }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// `.serialized`: every test points the one `LibraryServerStub.handler` at its own server.
@Suite(.serialized) struct LibrarySyncTests {
    private static let key = "the-permanent-key"

    private func makeSync(key: String? = LibrarySyncTests.key) throws -> LibrarySync {
        LibraryServerStub.reset()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("allset-sync-\(UUID().uuidString)/Library")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LibraryServerStub.self]
        return LibrarySync(server: URL(string: "http://library.test:8080")!, key: key, directory: directory,
                           session: URLSession(configuration: configuration))
    }

    private func video(_ id: String, size: Int64, kind: LibraryVideo.Kind = .video) -> LibraryVideo {
        LibraryVideo(id: id, title: id, kind: kind, category: .abstract, root: LibrarySync.root,
                     file: kind == .video ? "live/\(id).mp4" : "stills/\(id).jpg",
                     thumbnail: "thumbnails/\(id).jpg", playback: kind == .video ? "live/\(id).mp4" : "stills/\(id).jpg",
                     size: size)
    }

    /// A server holding `videos`: the list at /api/library, and for every other
    /// path a file whose bytes are that path. Only the right key gets in.
    private func serve(_ videos: [LibraryVideo]) throws {
        let list = try JSONEncoder().encode(WallpaperLibraryCatalog(items: videos))
        LibraryServerStub.handler = { request in
            guard request.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.key)" else { return (401, nil) }
            let path = request.url?.path ?? ""
            return (200, path == "/api/library" ? list : Data(path.utf8))
        }
    }

    @Test func theListComesWithTheKeyAndAWrongKeySaysSo() async throws {
        let sync = try makeSync()
        try serve([video("a", size: 10)])
        let catalog = try await sync.fetchCatalog()
        #expect(catalog.items.map(\.id) == ["a"])
        #expect(LibraryServerStub.requested == ["/api/library"])

        let wrong = try makeSync(key: "not-the-key")
        try serve([video("a", size: 10)])
        await #expect(throws: LibrarySync.Failure.wrongKey) { try await wrong.fetchCatalog() }

        let offline = try makeSync()
        await #expect(throws: LibrarySync.Failure.unreachable) { try await offline.fetchCatalog() }
    }

    @Test func entriesThatWouldLeaveTheLibraryFolderAreDropped() async throws {
        let sync = try makeSync()
        var outside = video("outside", size: 1)
        outside.playback = "../../Documents/outside.mp4"
        var elsewhere = video("elsewhere", size: 1)
        elsewhere.root = "a-drive"
        try serve([video("fine", size: 1), outside, elsewhere])
        #expect(try await sync.fetchCatalog().items.map(\.id) == ["fine"])
    }

    @Test func savingMakesItTheAppsLibraryButNeverReplacesThisMacsOwn() async throws {
        let sync = try makeSync()
        try serve([video("a", size: 10)])
        try sync.save(try await sync.fetchCatalog())
        let file = sync.directory.appendingPathComponent("catalog.json")
        #expect(try JSONDecoder().decode(WallpaperLibraryCatalog.self, from: Data(contentsOf: file)).items.map(\.id) == ["a"])
        // A received list can be replaced by a newer one.
        try serve([video("a", size: 10), video("b", size: 20)])
        try sync.save(try await sync.fetchCatalog())
        #expect(!sync.hasOwnLibrary)

        // The importer's catalog names the folders its videos live in.
        let own = WallpaperLibraryCatalog(roots: [.init(id: "drive", path: "/Volumes/Drive", label: nil)],
                                          items: [LibraryVideo(id: "mine", title: "Mine", category: .abstract, root: "drive", file: "mine.mp4")])
        try JSONEncoder().encode(own).write(to: file)
        #expect(sync.hasOwnLibrary)
        #expect(throws: LibrarySync.Failure.ownLibrary) { try sync.save(WallpaperLibraryCatalog()) }
        #expect(try JSONDecoder().decode(WallpaperLibraryCatalog.self, from: Data(contentsOf: file)).items.map(\.id) == ["mine"])
    }

    @Test func everythingLandsWhereTheAppLooksPicturesFirstThenVideosSmallestFirst() async throws {
        let sync = try makeSync()
        let videos = [video("big", size: 300), video("small", size: 100), video("still", size: 5, kind: .image)]
        try serve(videos)
        let catalog = try await sync.fetchCatalog()
        // One of them is here already: it isn't downloaded again.
        let here = sync.directory.appendingPathComponent("thumbnails/big.jpg")
        try FileManager.default.createDirectory(at: here.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("already here".utf8).write(to: here)

        #expect(sync.missing(in: catalog).videos.map(\.relative) == ["live/small.mp4", "live/big.mp4"])
        let order = Order()
        let summary = await sync.download(catalog, finished: { video, done, total, error in
            order.add("\(video.relative) \(done)/\(total) \(error == nil)")
        })
        #expect(summary == LibrarySync.Summary(downloaded: 2, failed: 0, leftForLater: 0))
        // Started smallest first; a few run at once, so they may end in either order.
        #expect(order.all.map { $0.split(separator: " ")[0] }.sorted() == ["live/big.mp4", "live/small.mp4"])
        #expect(order.all.map { $0.split(separator: " ").dropFirst().joined(separator: " ") } == ["1/2 true", "2/2 true"])
        for relative in ["thumbnails/small.jpg", "thumbnails/still.jpg", "stills/still.jpg", "live/small.mp4", "live/big.mp4"] {
            #expect(try String(contentsOf: sync.directory.appendingPathComponent(relative), encoding: .utf8) == "/\(relative)")
        }
        #expect(try String(contentsOf: here, encoding: .utf8) == "already here")
        let requested = LibraryServerStub.requested
        #expect(!requested.contains("/thumbnails/big.jpg"))
        // Every picture was asked for before any video.
        let firstVideo = try #require(requested.firstIndex { $0.hasPrefix("/live/") })
        #expect(requested[firstVideo...].allSatisfy { $0.hasPrefix("/live/") })
        // A second run has nothing left to do.
        #expect(sync.missing(in: catalog).pictures.isEmpty && sync.missing(in: catalog).videos.isEmpty)
        #expect(sync.progress.received > 0)
    }

    @Test func theListAloneLeavesTheVideosForWhenTheyArePicked() async throws {
        let sync = try makeSync()
        try serve([video("a", size: 100)])
        let catalog = try await sync.fetchCatalog()
        let summary = await sync.download(catalog, options: .init(catalogOnly: true))
        #expect(summary == LibrarySync.Summary())
        #expect(FileManager.default.fileExists(atPath: sync.directory.appendingPathComponent("thumbnails/a.jpg").path))
        #expect(!FileManager.default.fileExists(atPath: sync.directory.appendingPathComponent("live/a.mp4").path))
    }

    @Test func downloadsStopBeforeTheDiskIsDownToTheReserve() async throws {
        let sync = try makeSync()
        try serve([video("small", size: 100), video("big", size: 900)])
        let catalog = try await sync.fetchCatalog()
        // 1,000 free, 500 to stay free: the small one fits, the big one doesn't.
        let summary = await sync.download(catalog, options: .init(reserve: 500), freeSpace: { 1000 })
        #expect(summary == LibrarySync.Summary(downloaded: 1, failed: 0, leftForLater: 1))
        #expect(FileManager.default.fileExists(atPath: sync.directory.appendingPathComponent("live/small.mp4").path))
        #expect(!FileManager.default.fileExists(atPath: sync.directory.appendingPathComponent("live/big.mp4").path))
    }

    @Test func aFileThatFailsOrArrivesShortIsCountedAndNeverLands() async throws {
        let sync = try makeSync()
        try serve([video("a", size: 100)])
        let catalog = try await sync.fetchCatalog()
        LibraryServerStub.claimedLength = 5000
        var summary = await sync.download(catalog)
        #expect(summary.downloaded == 0 && summary.failed == 2)  // its picture and its video
        #expect(!FileManager.default.fileExists(atPath: sync.directory.appendingPathComponent("live/a.mp4").path))

        LibraryServerStub.claimedLength = nil
        LibraryServerStub.handler = { _ in (500, nil) }
        summary = await sync.download(catalog)
        #expect(summary.downloaded == 0 && summary.failed == 2)
        await #expect(throws: LibrarySync.Failure.refused(500)) { try await sync.download("live/a.mp4") }
    }

    /// A public library: the list at /catalog.json and its files, for anyone.
    /// A request that carries a key is refused, so a test passes only if none does.
    private func servePublicly(_ videos: [LibraryVideo], tag: String) throws {
        let list = try JSONEncoder().encode(WallpaperLibraryCatalog(items: videos))
        LibraryServerStub.tag = tag
        LibraryServerStub.handler = { request in
            guard request.value(forHTTPHeaderField: "Authorization") == nil else { return (400, nil) }
            let path = request.url?.path ?? ""
            return path == "/api/library" ? (404, nil) : (200, path == "/catalog.json" ? list : Data(path.utf8))
        }
    }

    private func saved(_ sync: LibrarySync) throws -> [String] {
        let file = sync.directory.appendingPathComponent("catalog.json")
        return try JSONDecoder().decode(WallpaperLibraryCatalog.self, from: Data(contentsOf: file)).items.map(\.id)
    }

    @Test func aPublicLibraryNeedsNoKeyAndIsOnlySentAgainWhenItChanged() async throws {
        let sync = try makeSync(key: nil)
        try servePublicly([video("a", size: 10)], tag: "\"one\"")
        #expect(try await sync.update()?.items.map(\.id) == ["a"])
        #expect(try saved(sync) == ["a"])
        #expect(LibraryServerStub.requested == ["/catalog.json"])
        // Nothing new: the server says so and the saved list stays.
        #expect(try await sync.update() == nil)
        #expect(try saved(sync) == ["a"])
        // A publish changed it.
        try servePublicly([video("a", size: 10), video("b", size: 20)], tag: "\"two\"")
        #expect(try await sync.update()?.items.map(\.id) == ["a", "b"])
        #expect(try saved(sync) == ["a", "b"])
        // Its files come without a key too.
        let file = sync.directory.appendingPathComponent("catalog.json")
        let summary = await sync.download(try JSONDecoder().decode(WallpaperLibraryCatalog.self, from: Data(contentsOf: file)))
        #expect(summary == LibrarySync.Summary(downloaded: 2, failed: 0, leftForLater: 0))
    }

    @Test func aSavedListThatWentMissingIsFetchedAgainWhateverTheTagSays() async throws {
        let sync = try makeSync(key: nil)
        try servePublicly([video("a", size: 10)], tag: "\"one\"")
        _ = try await sync.update()
        try FileManager.default.removeItem(at: sync.directory.appendingPathComponent("catalog.json"))
        #expect(try await sync.update()?.items.map(\.id) == ["a"])
        #expect(try saved(sync) == ["a"])
    }

    @Test func aPublicLibraryNeverReplacesThisMacsOwnOrAnUnreadableAnswer() async throws {
        let sync = try makeSync(key: nil)
        try servePublicly([video("a", size: 10)], tag: "\"one\"")
        _ = try await sync.update()
        // The server is down, then sends something that isn't a list: the saved one stays.
        LibraryServerStub.handler = { _ in (503, nil) }
        await #expect(throws: LibrarySync.Failure.refused(503)) { try await sync.update() }
        LibraryServerStub.tag = "\"junk\""
        LibraryServerStub.handler = { _ in (200, Data("<html>".utf8)) }
        await #expect(throws: LibrarySync.Failure.unreadable) { try await sync.update() }
        #expect(try saved(sync) == ["a"])
        // The junk's tag wasn't kept: the real list comes back when the server does.
        try servePublicly([video("a", size: 10), video("b", size: 20)], tag: "\"junk\"")
        #expect(try await sync.update()?.items.map(\.id) == ["a", "b"])

        let own = WallpaperLibraryCatalog(roots: [.init(id: "drive", path: "/Volumes/Drive", label: nil)],
                                          items: [LibraryVideo(id: "mine", title: "Mine", category: .abstract, root: "drive", file: "mine.mp4")])
        try JSONEncoder().encode(own).write(to: sync.directory.appendingPathComponent("catalog.json"))
        let before = LibraryServerStub.requested.count
        await #expect(throws: LibrarySync.Failure.ownLibrary) { try await sync.update() }
        #expect(LibraryServerStub.requested.count == before)
        #expect(try saved(sync) == ["mine"])
    }

    @Test func aFileThatIsNotTheOneTheListNamesNeverLands() async throws {
        let sync = try makeSync(key: nil)
        var right = video("right", size: 10), wrong = video("wrong", size: 10)
        // The stub's files are their own paths.
        right.checksums = ["playback": try #require(sha256("/live/right.mp4")), "thumbnail": try #require(sha256("/thumbnails/right.jpg")).uppercased()]
        wrong.checksums = ["playback": try #require(sha256("some other file"))]
        try servePublicly([right, wrong], tag: "\"one\"")
        let catalog = try #require(try await sync.update())
        #expect(catalog.items.first?.checksums?["playback"] == right.checksums?["playback"])
        let summary = await sync.download(catalog)
        #expect(summary == LibrarySync.Summary(downloaded: 1, failed: 1, leftForLater: 0))
        #expect(FileManager.default.fileExists(atPath: sync.directory.appendingPathComponent("live/right.mp4").path))
        #expect(FileManager.default.fileExists(atPath: sync.directory.appendingPathComponent("thumbnails/right.jpg").path))
        #expect(!FileManager.default.fileExists(atPath: sync.directory.appendingPathComponent("live/wrong.mp4").path))
        await #expect(throws: LibrarySync.Failure.corrupt) { try await sync.download("live/wrong.mp4", checksum: wrong.checksums?["playback"]) }
    }

    private func sha256(_ text: String) -> String? {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("allset-sha-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: file) }
        guard (try? Data(text.utf8).write(to: file)) != nil else { return nil }
        return FileDigest.sha256(of: file)
    }

    @Test func theKeyIsKeptInTheKeychainAndCanBeForgotten() {
        let service = "com.pratik.allset.tests.library-\(UUID().uuidString)"
        #expect(LibraryKey.read(service: service) == nil)
        #expect(LibraryKey.store("  a-key\n", service: service))
        #expect(LibraryKey.read(service: service) == "a-key")
        #expect(LibraryKey.store(nil, service: service))
        #expect(LibraryKey.read(service: service) == nil)
    }
}

/// The same code against a real public library, over real HTTP. Runs only when
/// told where one is:
///
///     scripts/cloud/server.sh serve      # in another terminal
///     ALLSET_PUBLIC_LIBRARY_TEST_URL=http://127.0.0.1:8090 swift test --filter PublicLibraryLiveTests
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ALLSET_PUBLIC_LIBRARY_TEST_URL"] != nil))
struct PublicLibraryLiveTests {
    @Test func theListAndEveryFileArriveWithoutAKeyAndMatchTheirChecksums() async throws {
        let address = try #require(ProcessInfo.processInfo.environment["ALLSET_PUBLIC_LIBRARY_TEST_URL"])
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("allset-live-\(UUID().uuidString)/Library")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        let sync = LibrarySync(server: try #require(URL(string: address)), key: nil, directory: directory)

        let catalog = try #require(try await sync.update())
        #expect(!catalog.items.isEmpty)
        #expect(catalog.items.allSatisfy { $0.status == .published && $0.provenance?.license?.isEmpty == false })
        let summary = await sync.download(catalog)
        #expect(summary.failed == 0 && summary.leftForLater == 0)
        var files = 0
        for video in catalog.items {
            for relative in [video.playback, video.still, video.thumbnail].compactMap(\.self) {
                let checksum = try #require(video.checksum(of: relative))
                #expect(FileDigest.sha256(of: directory.appendingPathComponent(relative)) == checksum)
                files += 1
            }
        }
        #expect(files > 0)
        // Nothing was published meanwhile: the server says the saved list is current.
        #expect(try await sync.update() == nil)
    }
}

private final class Order: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []

    var all: [String] { lock.withLock { lines } }

    func add(_ line: String) {
        lock.withLock { lines.append(line) }
    }
}
