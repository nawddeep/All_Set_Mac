import Foundation
import Observation

/// The last check of a site or API.
public struct StatusCheck: Codable, Equatable, Sendable {
    public enum Health: String, Codable, Sendable { case up, degraded, down }

    public var health: Health
    public var code: Int?
    /// Milliseconds for the answer to arrive.
    public var latency: Double?
    /// A status page's own words, or why it failed.
    public var message: String?
    public var checked: Date
    /// Recent latencies, oldest first; nil where a check failed.
    public var history: [Double?]
}

/// Checks endpoints with a HEAD request (a GET when HEAD isn't allowed, and
/// always for Statuspage feeds, whose words it reads). Nothing is cached by
/// URLSession, and each URL is checked at most once per interval however many
/// widgets show it.
@Observable @MainActor
public final class StatusService {
    public private(set) var checks: [String: StatusCheck] = [:]

    @ObservationIgnored private var inFlight = Set<String>()
    @ObservationIgnored private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    public init() {}

    public func check(_ endpoint: StatusEndpoint) -> StatusCheck? { checks[Self.key(endpoint.url)] }

    public func checkIfNeeded(_ endpoint: StatusEndpoint, maxAge: TimeInterval) {
        let key = Self.key(endpoint.url)
        guard let url = Self.url(endpoint.url) else { return }
        if let last = checks[key], Date.now.timeIntervalSince(last.checked) < maxAge { return }
        guard !inFlight.contains(key) else { return }
        inFlight.insert(key)
        Task {
            defer { inFlight.remove(key) }
            var result = await probe(url)
            let previous = checks[key]?.history ?? []
            result.history = Array((previous + [result.health == .down ? nil : result.latency]).suffix(24))
            checks[key] = result
        }
    }

    private func probe(_ url: URL) async -> StatusCheck {
        let isStatusPage = url.path.hasSuffix("status.json")
        do {
            let start = Date.now
            var request = URLRequest(url: url)
            request.httpMethod = isStatusPage ? "GET" : "HEAD"
            var (data, response) = try await session.data(for: request)
            var code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if !isStatusPage, code == 405 || code == 403 || code == 501 {
                request.httpMethod = "GET"
                (data, response) = try await session.data(for: request)
                code = (response as? HTTPURLResponse)?.statusCode ?? 0
            }
            let latency = Date.now.timeIntervalSince(start) * 1000
            if isStatusPage, let page = Self.statusPage(data) {
                return StatusCheck(health: page.health, code: code, latency: latency, message: page.message, checked: .now, history: [])
            }
            let health: StatusCheck.Health = (200..<400).contains(code) ? (latency > 3000 ? .degraded : .up) : code >= 500 ? .down : .degraded
            return StatusCheck(health: health, code: code, latency: latency, message: HTTPURLResponse.localizedString(forStatusCode: code).capitalized,
                               checked: .now, history: [])
        } catch {
            return StatusCheck(health: .down, code: nil, latency: nil, message: (error as? URLError)?.shortDescription ?? "No answer",
                               checked: .now, history: [])
        }
    }

    /// Statuspage.io's summary ("All Systems Operational").
    nonisolated static func statusPage(_ data: Data) -> (health: StatusCheck.Health, message: String)? {
        struct Page: Decodable {
            struct Status: Decodable {
                var indicator: String
                var description: String
            }
            var status: Status
        }
        guard let page = try? JSONDecoder().decode(Page.self, from: data) else { return nil }
        let health: StatusCheck.Health = switch page.status.indicator {
        case "none": .up
        case "minor", "maintenance": .degraded
        default: .down
        }
        return (health, page.status.description)
    }

    /// Which checks are the same check: the scheme and host don't care about
    /// case, but a path or query can (`/Status` and `/status` may differ), so
    /// only those two are folded. "example.com" is https://example.com/.
    nonisolated static func key(_ address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        guard let url = url(trimmed), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return trimmed }
        components.scheme = components.scheme?.lowercased()
        components.percentEncodedHost = components.percentEncodedHost?.lowercased()
        if components.percentEncodedPath.isEmpty { components.percentEncodedPath = "/" }
        return components.string ?? trimmed
    }

    /// "example.com" means https://example.com.
    nonisolated static func url(_ address: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed.contains("://") ? trimmed : "https://" + trimmed)
    }
}

extension URLError {
    var shortDescription: String {
        switch code {
        case .timedOut: "Timed out"
        case .cannotFindHost, .dnsLookupFailed: "Host not found"
        case .cannotConnectToHost: "Refused"
        case .notConnectedToInternet: "Offline"
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate: "TLS error"
        default: "No answer"
        }
    }
}
