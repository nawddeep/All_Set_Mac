import Foundation

/// Whether a build can check for updates: Sparkle needs a real EdDSA public
/// key and an https feed, and a packaged app. Until then it isn't created at
/// all, so it makes no checks and no network requests.
public enum UpdateConfiguration {
    public static let placeholderKey = "PLACEHOLDER-run-sparkle-generate_keys"

    public static func isConfigured(info: [String: Any]?, isPackaged: Bool) -> Bool {
        guard isPackaged,
              let key = info?["SUPublicEDKey"] as? String, !key.isEmpty, key != placeholderKey,
              let feed = (info?["SUFeedURL"] as? String).flatMap(URL.init(string:)), feed.scheme == "https" else { return false }
        return true
    }
}
