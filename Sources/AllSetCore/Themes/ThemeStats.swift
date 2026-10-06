import Foundation
import Observation
import OSLog

/// How themes are used on this Mac: installs, applies, previews, favorites
/// and when each was last used. Recommended and Top Picks (the `trending` and `popular` scores) are ranked from these
/// plus each set's starting popularity, so a server's counts can replace the
/// local ones later without changing the ranking.
@Observable @MainActor
public final class ThemeStats {
    public struct Record: Codable, Equatable, Sendable {
        public var installs = 0
        public var applies = 0
        public var previews = 0
        public var favorite = false
        public var lastUsed: Date?

        public init() {}
    }

    public enum Event: Sendable { case install, apply, preview }

    public private(set) var records: [String: Record] = [:]

    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "themes")

    public init(fileURL: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("AllSet", isDirectory: true).appendingPathComponent("theme-stats.json")) {
        self.fileURL = fileURL
        if let fileURL { records = StoreFile.load([String: Record].self, from: fileURL) ?? [:] }
    }

    public func record(_ event: Event, for id: String, now: Date = .now) {
        var record = records[id] ?? Record()
        switch event {
        case .install: record.installs += 1
        case .apply: record.applies += 1
        case .preview: record.previews += 1
        }
        record.lastUsed = now
        records[id] = record
        save()
    }

    public func isFavorite(_ id: String) -> Bool { records[id]?.favorite ?? false }

    public func toggleFavorite(_ id: String) {
        var record = records[id] ?? Record()
        record.favorite.toggle()
        records[id] = record
        save()
    }

    public func trending(_ set: ThemeSet, now: Date = .now) -> Double {
        Self.trendingScore(baseline: set.baseline, record: records[set.id] ?? Record(), seasons: set.seasons, now: now)
    }

    public func popularity(_ set: ThemeSet) -> Double {
        Self.popularityScore(baseline: set.baseline, record: records[set.id] ?? Record())
    }

    /// What's hot now: recent use counts most and fades over two weeks;
    /// sets in season get a lift.
    public nonisolated static func trendingScore(baseline: Double, record: Record, seasons: [Int], now: Date) -> Double {
        let activity = Double(record.installs) * 3 + Double(record.applies) * 2 + Double(record.previews) * 0.5 + (record.favorite ? 5 : 0)
        let days = record.lastUsed.map { max(now.timeIntervalSince($0), 0) / 86_400 } ?? .infinity
        let recency = days.isFinite ? max(0, 1 - days / 14) : 0
        let month = Calendar(identifier: .gregorian).component(.month, from: now)
        let season = seasons.contains(month) ? 20.0 : 0
        return baseline * 0.5 + activity * (0.5 + recency) + recency * 10 + season
    }

    /// Liked over time, however recently.
    public nonisolated static func popularityScore(baseline: Double, record: Record) -> Double {
        baseline + Double(record.installs) * 3 + Double(record.applies) + (record.favorite ? 10 : 0)
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(records).write(to: fileURL, options: .atomic)
        } catch {
            log.error("Couldn't save theme stats: \(error.localizedDescription, privacy: .public)")
        }
    }
}
