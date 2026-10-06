import Foundation

/// One line of JSON from the media helper (see MediaHelper.m).
public struct MediaHelperMessage: Decodable, Sendable {
    public var type: String
    public var message: String?
    public var hasInfo: Bool?
    public var isPlaying: Bool?
    public var bundleIdentifier: String?
    public var parentBundleIdentifier: String?
    public var title: String?
    public var artist: String?
    public var album: String?
    public var duration: Double?
    public var elapsedTime: Double?
    /// Unix time at which `elapsedTime` was measured.
    public var timestamp: Double?
    public var playbackRate: Double?
    public var artworkID: String?
    /// Base64 image data, only sent when the artwork changes.
    public var artwork: String?
}

public struct NowPlayingInfo: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval?
    public var elapsedTime: TimeInterval
    public var timestamp: Date
    public var playbackRate: Double
    public var isPlaying: Bool
    /// The app to show and open. For web media this is the browser rather than
    /// its helper process.
    public var bundleIdentifier: String?
    public var artworkID: String?

    public init?(message: MediaHelperMessage, receivedAt: Date = .now) {
        guard message.type == "nowPlaying", message.hasInfo == true else { return nil }
        title = message.title ?? ""
        artist = message.artist ?? ""
        album = message.album ?? ""
        guard !title.isEmpty || !artist.isEmpty else { return nil }
        duration = message.duration.flatMap { $0 > 0 ? $0 : nil }
        elapsedTime = message.elapsedTime ?? 0
        timestamp = message.timestamp.map(Date.init(timeIntervalSince1970:)) ?? receivedAt
        playbackRate = message.playbackRate ?? 0
        isPlaying = message.isPlaying ?? false
        bundleIdentifier = message.parentBundleIdentifier ?? message.bundleIdentifier
        artworkID = message.artworkID
    }

    /// Players report elapsed time as of `timestamp`; extrapolate from there.
    public func elapsed(at date: Date = .now) -> TimeInterval {
        var value = elapsedTime
        if isPlaying {
            let rate = playbackRate > 0 ? playbackRate : 1
            value += date.timeIntervalSince(timestamp) * rate
        }
        if let duration { value = min(value, duration) }
        return max(value, 0)
    }

    public func progress(at date: Date = .now) -> Double? {
        guard let duration else { return nil }
        return elapsed(at: date) / duration
    }

    /// Identifies the track, independent of playback position.
    public var trackKey: String { "\(title)\u{1F}\(artist)\u{1F}\(album)" }
}
