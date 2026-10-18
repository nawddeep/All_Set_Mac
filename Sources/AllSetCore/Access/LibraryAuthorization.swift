import Foundation

/// The access token every request to the public library's host carries, in one
/// place: the catalog, downloads, HEAD checks and thumbnails all build their
/// requests through `authorize(_:)`, and AVFoundation gets `headers(for:)`.
/// Requests to any other host never see it. A 401 from the library's host is
/// handed to `onRejected` (the access gate renews the token or locks the app).
// Sendable because: every stored var is under `lock`.
public final class LibraryAuthorization: @unchecked Sendable {
    /// The app's one. Tests make their own.
    public static let shared = LibraryAuthorization()

    private let lock = NSLock()
    private var heldHost: String?
    private var heldToken: String?
    private var rejected: (@Sendable () -> Void)?

    public init(host: String? = nil, token: String? = nil) {
        heldHost = host?.lowercased()
        heldToken = token
    }

    /// The library's host (`wallpapers.example.com`). Nil: nothing is sent anywhere.
    public var host: String? {
        get { lock.withLock { heldHost } }
        set { lock.withLock { heldHost = newValue?.lowercased() } }
    }

    public var token: String? {
        get { lock.withLock { heldToken } }
        set { lock.withLock { heldToken = newValue } }
    }

    /// Called (on whatever thread the response arrived) for each 401 from the library's host.
    public func onRejected(_ handler: (@Sendable () -> Void)?) {
        lock.withLock { rejected = handler }
    }

    /// The bearer for `url`, when it's on the library's host and there is a token.
    private func bearer(for url: URL?) -> String? {
        lock.withLock {
            guard let heldHost, let heldToken, url?.host?.lowercased() == heldHost else { return nil }
            return heldToken
        }
    }

    /// Adds the token to a request for the library's host. A request that
    /// already carries a key of its own (a private library's) keeps it.
    public func authorize(_ request: inout URLRequest) {
        guard request.value(forHTTPHeaderField: "Authorization") == nil, let token = bearer(for: request.url) else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    /// For `AVURLAssetHTTPHeaderFieldsKey`: empty for a local file or another host.
    public func headers(for url: URL) -> [String: String] {
        bearer(for: url).map { ["Authorization": "Bearer \($0)"] } ?? [:]
    }

    /// Reports a 401 from the library's host; anything else is ignored.
    public func check(_ response: URLResponse?) {
        guard let http = response as? HTTPURLResponse, http.statusCode == 401 else { return }
        let handler: (@Sendable () -> Void)? = lock.withLock {
            guard let heldHost, http.url?.host?.lowercased() == heldHost else { return nil }
            return rejected
        }
        handler?()
    }
}
