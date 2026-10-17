import Foundation
import Observation
import OSLog
import UniformTypeIdentifiers

/// Freeing space, deleting library wallpapers, and your own videos.
extension WallpaperStore {
    // MARK: Freeing space

    /// What one "free up space" run did.
    public struct OffloadResult: Sendable {
        public var freedFiles = 0
        public var freedBytes: Int64 = 0
        /// Relative paths kept on this Mac because the server couldn't be
        /// shown to hold an identical copy.
        public var kept: [String] = []
    }

    struct OffloadCandidate: Sendable {
        let id: String
        let relative: String
        let size: Int64
    }

    /// A wallpaper's playable files that exist on this Mac right now: the
    /// video or still it plays, plus a live loop's still. Thumbnails stay —
    /// they're tiny, and keep the grid instant and browsable offline. The
    /// wallpaper on the desktop stays too: freeing it would only download it
    /// straight back. The disk checks run off the main thread.
    func offloadCandidates(only ids: Set<String>?) async -> [OffloadCandidate] {
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
        let bearer = libraryBearer?()
        offloadProgress = (0, candidates.count)
        defer { offloadProgress = nil }
        var confirmed: [OffloadCandidate] = []
        // A few at a time: thousands one by one is needlessly slow, all at
        // once is needlessly hard on a home server.
        await withTaskGroup(of: (OffloadCandidate, Bool).self) { group in
            var pending = candidates.makeIterator()
            for _ in 0..<8 {
                guard let next = pending.next() else { break }
                group.addTask { (next, await Self.serverHolds(next, root: root, session: session, directory: directory, bearer: bearer)) }
            }
            while let (candidate, held) = await group.next() {
                if held { confirmed.append(candidate) } else { result.kept.append(candidate.relative) }
                offloadProgress = ((offloadProgress?.done ?? 0) + 1, candidates.count)
                if let next = pending.next() {
                    group.addTask { (next, await Self.serverHolds(next, root: root, session: session, directory: directory, bearer: bearer)) }
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
    func recordOffloaded(_ relatives: [String]) -> Bool {
        guard !relatives.isEmpty else { return true }
        return updateOffloaded { $0.formUnion(relatives) }
    }

    func unrecordOffloaded(_ relatives: [String]) {
        updateOffloaded { $0.subtract(relatives) }
    }

    @discardableResult
    func updateOffloaded(_ change: (inout Set<String>) -> Void) -> Bool {
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
                                                directory: URL, bearer: String?) async -> Bool {
        let remote = root.appendingPathComponent(candidate.relative)
        let head = libraryRequest(remote, method: "HEAD", bearer: bearer)
        guard let (_, response) = try? await session.data(for: head),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let length = http.value(forHTTPHeaderField: "Content-Length").flatMap(Int64.init),
              length == candidate.size else { return false }
        guard let (downloaded, getResponse) = try? await session.download(for: libraryRequest(remote, bearer: bearer)) else { return false }
        defer { try? FileManager.default.removeItem(at: downloaded) }  // Best effort: a cache or temporary file; failing only means doing it again.
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
    /// The library catalog has fields (`sha256`, `sceneNotes`,
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

    var pendingDeletesURL: URL { libraryDirectory.appendingPathComponent("pending-deletes.json") }

    var pendingDeleteRecords: [String: [String]] {
        (try? Data(contentsOf: pendingDeletesURL)).flatMap { try? JSONDecoder().decode([String: [String]].self, from: $0) } ?? [:]
    }

    @discardableResult
    func updatePendingDeletes(_ change: (inout [String: [String]]) -> Void) -> Bool {
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
    /// The copying happens off the main thread: a film on an external drive or
    /// another volume is a real copy, and the window froze for as long as it took.
    @discardableResult
    public func importVideos(from urls: [URL]) async -> [String] {
        let folder = videosFolder, log = log
        let imported = await Task.detached(priority: .userInitiated) {
            urls.filter(Self.isVideo).compactMap { url -> String? in
                let name = UUID().uuidString + "." + url.pathExtension.lowercased()
                do {
                    try FileManager.default.copyItem(at: url, to: folder.appendingPathComponent(name))
                    return name
                } catch {
                    log.error("Couldn't import \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    return nil
                }
            }
        }.value
        reloadVideos()
        return imported
    }

    public func deleteVideo(_ name: String) {
        FileAttempt.run("delete the video \(name)") { try FileManager.default.removeItem(at: videoURL(name)) }
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

    /// Picks up files that arrived in the videos folder, like videos copied in by hand.
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


    func save() {
        do {
            try JSONEncoder().encode(config).write(to: fileURL, options: .atomic)
            if saveError != nil { saveError = nil }
        } catch {
            log.error("Couldn't save wallpaper settings: \(error.localizedDescription, privacy: .public)")
            saveError = error.localizedDescription
        }
    }
}
