import CryptoKit
import Foundation
import Observation
import OSLog

/// What a GitHub widget has to show, whichever mode it's in.
public enum GitHubData: Codable, Equatable, Sendable {
    case contributions(GitHubContributions)
    case events([GitHubEvent])
    case items(total: Int, [GitHubItem])
    case repository(GitHubRepository)
    case runs([GitHubRun])
}

public struct GitHubContributions: Codable, Equatable, Sendable {
    public struct Day: Codable, Equatable, Sendable {
        /// "2026-09-25"
        public var date: String
        /// 0 (none) to 4 (most), as GitHub shades it.
        public var level: Int
        public var count: Int
    }

    /// Oldest first, about a year.
    public var days: [Day]

    public var total: Int { days.reduce(0) { $0 + $1.count } }

    /// Days in a row with contributions, up to the last day (a quiet today doesn't break it).
    public var streak: Int {
        var run = 0
        for (offset, day) in days.reversed().enumerated() {
            if day.count > 0 { run += 1 } else if offset > 0 { break }
        }
        return run
    }
}

public struct GitHubEvent: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    /// "PushEvent", "PullRequestEvent"…
    public var type: String
    public var repository: String
    public var summary: String
    public var date: Date

    public var symbol: String {
        switch type {
        case "PushEvent": "arrow.up.circle.fill"
        case "PullRequestEvent", "PullRequestReviewEvent", "PullRequestReviewCommentEvent": "arrow.triangle.pull"
        case "IssuesEvent": "smallcircle.filled.circle"
        case "IssueCommentEvent": "text.bubble.fill"
        case "WatchEvent": "star.fill"
        case "ForkEvent": "tuningfork"
        case "CreateEvent": "plus.circle.fill"
        case "DeleteEvent": "trash.fill"
        case "ReleaseEvent": "tag.fill"
        default: "circle.fill"
        }
    }
}

/// A pull request or an issue.
public struct GitHubItem: Codable, Equatable, Identifiable, Sendable {
    public var id: Int
    public var number: Int
    public var title: String
    public var repository: String
    public var url: String
    public var updated: Date
    public var isDraft: Bool
    public var comments: Int
}

public struct GitHubRepository: Codable, Equatable, Sendable {
    public var name: String
    public var summary: String?
    public var stars: Int
    public var forks: Int
    public var openIssues: Int
    public var watchers: Int
    public var language: String?
    public var pushed: Date
    public var defaultBranch: String
    public var url: String
}

/// A GitHub Actions workflow run.
public struct GitHubRun: Codable, Equatable, Identifiable, Sendable {
    public var id: Int
    public var name: String
    /// "queued", "in_progress", "completed"
    public var status: String
    /// "success", "failure", "cancelled"… once completed.
    public var conclusion: String?
    public var branch: String
    public var number: Int
    public var created: Date
    public var url: String

    public enum Outcome: Sendable { case running, passed, failed, other }

    public var outcome: Outcome {
        if status != "completed" { return .running }
        switch conclusion {
        case "success": return .passed
        case "failure", "timed_out", "startup_failure": return .failed
        default: return .other
        }
    }
}

/// Talks to GitHub without an account (60 requests an hour), or with a
/// personal access token from the keychain (5,000).
public struct GitHubClient: Sendable {
    public enum Failure: Error, CustomStringConvertible {
        case notFound
        case rateLimited(until: Date)
        /// The saved token was refused: retrying won't help until it changes.
        case unauthorized
        case http(Int)

        public var description: String {
            switch self {
            case .notFound: "Not found on GitHub"
            case .rateLimited(let until):
                "GitHub's hourly limit is used up until \(until.formatted(date: .omitted, time: .shortened))"
            case .unauthorized: "GitHub refused the saved token. Update it in Settings."
            case .http(let code): "GitHub answered \(code)"
            }
        }
    }

    public var token: String?

    public init(token: String? = GitHubKeychain.token) {
        self.token = token
    }

    public func fetch(_ config: GitHubConfig) async throws -> GitHubData {
        let user = config.user.trimmingCharacters(in: .whitespaces)
        let repository = config.repository.trimmingCharacters(in: .whitespaces)
        switch config.mode {
        case .contributions:
            let (data, _) = try await get("https://github.com/users/\(user)/contributions", accept: "text/html")
            return .contributions(Self.parseContributions(String(decoding: data, as: UTF8.self)))
        case .activity:
            let (data, _) = try await get("https://api.github.com/users/\(user)/events/public?per_page=30")
            return .events(try Self.decodeEvents(data))
        case .pullRequests, .issues:
            let scope = repository.isEmpty ? (config.mode == .pullRequests ? "author:\(user)" : "assignee:\(user)") : "repo:\(repository)"
            let kind = config.mode == .pullRequests ? "is:pr" : "is:issue"
            var components = URLComponents(string: "https://api.github.com/search/issues")!
            components.queryItems = [URLQueryItem(name: "q", value: "\(scope) \(kind) is:open archived:false"),
                                     URLQueryItem(name: "sort", value: "updated"), URLQueryItem(name: "per_page", value: "12")]
            let (data, _) = try await get(components.url!.absoluteString)
            let decoded = try Self.decodeItems(data)
            return .items(total: decoded.total, decoded.items)
        case .repository:
            let (data, _) = try await get("https://api.github.com/repos/\(repository)")
            return .repository(try Self.decodeRepository(data))
        case .actions:
            let (data, _) = try await get("https://api.github.com/repos/\(repository)/actions/runs?per_page=8")
            return .runs(try Self.decodeRuns(data))
        }
    }

    private func get(_ address: String, accept: String = "application/vnd.github+json") async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: address) else { throw Failure.notFound }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token, !token.isEmpty, url.host() == "api.github.com" {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.http(0) }
        switch http.statusCode {
        case 200..<300:
            return (data, http)
        case 401:
            throw Failure.unauthorized
        case 404, 422:
            throw Failure.notFound
        case 403, 429:
            let reset = http.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(Double.init)
                .map(Date.init(timeIntervalSince1970:)) ?? Date.now.addingTimeInterval(15 * 60)
            throw Failure.rateLimited(until: reset)
        default:
            throw Failure.http(http.statusCode)
        }
    }

    // MARK: Parsing

    /// The contribution calendar is only on the profile page: each day is a
    /// table cell with a date and a shade, and its count is in a tooltip.
    static func parseContributions(_ html: String) -> GitHubContributions {
        func matches(_ pattern: String) -> [[String]] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
            let range = NSRange(html.startIndex..., in: html)
            return regex.matches(in: html, range: range).map { match in
                (1..<match.numberOfRanges).map { index in
                    Range(match.range(at: index), in: html).map { String(html[$0]) } ?? ""
                }
            }
        }
        var counts: [String: Int] = [:]
        for match in matches(#"<tool-tip[^>]*for="([^"]+)"[^>]*>\s*(No|[\d,]+) contributions?"#) {
            counts[match[0]] = Int(match[1].replacingOccurrences(of: ",", with: "")) ?? 0
        }
        let days = matches(#"<td[^>]*data-date="(\d{4}-\d{2}-\d{2})"[^>]*id="([^"]+)"[^>]*data-level="(\d)""#).map { match in
            GitHubContributions.Day(date: match[0], level: Int(match[2]) ?? 0, count: counts[match[1]] ?? (Int(match[2]) ?? 0 > 0 ? 1 : 0))
        }
        return GitHubContributions(days: days.sorted { $0.date < $1.date })
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func decodeEvents(_ data: Data) throws -> [GitHubEvent] {
        struct Event: Decodable {
            struct Repo: Decodable { var name: String }
            struct Payload: Decodable {
                struct Numbered: Decodable {
                    var number: Int?
                    var title: String?
                }
                var action: String?
                var size: Int?
                var ref: String?
                var ref_type: String?
                var pull_request: Numbered?
                var issue: Numbered?
                var release: Release?
                struct Release: Decodable { var tag_name: String? }
            }
            var id: String
            var type: String
            var repo: Repo
            var payload: Payload
            var created_at: Date
        }
        return try decoder.decode([Event].self, from: data).map { event in
            let repo = event.repo.name.split(separator: "/").last.map(String.init) ?? event.repo.name
            let payload = event.payload
            let action = (payload.action ?? "").capitalized
            let summary: String = switch event.type {
            case "PushEvent": payload.size.map { "Pushed \($0) commit\($0 == 1 ? "" : "s") to \(repo)" } ?? "Pushed to \(repo)"
            case "PullRequestEvent": "\(action) PR #\(payload.pull_request?.number ?? 0): \(payload.pull_request?.title ?? repo)"
            case "PullRequestReviewEvent": "Reviewed PR #\(payload.pull_request?.number ?? 0) in \(repo)"
            case "IssuesEvent": "\(action) issue #\(payload.issue?.number ?? 0): \(payload.issue?.title ?? repo)"
            case "IssueCommentEvent": "Commented on #\(payload.issue?.number ?? 0) in \(repo)"
            case "WatchEvent": "Starred \(event.repo.name)"
            case "ForkEvent": "Forked \(event.repo.name)"
            case "CreateEvent": "Created \(payload.ref_type ?? "repository") \(payload.ref ?? repo)"
            case "DeleteEvent": "Deleted \(payload.ref_type ?? "") \(payload.ref ?? "")"
            case "ReleaseEvent": "Released \(payload.release?.tag_name ?? "") in \(repo)"
            default: "\(event.type.replacingOccurrences(of: "Event", with: "")) in \(repo)"
            }
            return GitHubEvent(id: event.id, type: event.type, repository: event.repo.name, summary: summary, date: event.created_at)
        }
    }

    static func decodeItems(_ data: Data) throws -> (total: Int, items: [GitHubItem]) {
        struct Response: Decodable {
            struct Item: Decodable {
                var id: Int
                var number: Int
                var title: String
                var repository_url: String
                var html_url: String
                var updated_at: Date
                var draft: Bool?
                var comments: Int
            }
            var total_count: Int
            var items: [Item]
        }
        let response = try decoder.decode(Response.self, from: data)
        return (response.total_count, response.items.map { item in
            GitHubItem(id: item.id, number: item.number, title: item.title,
                       repository: item.repository_url.split(separator: "/").suffix(2).joined(separator: "/"),
                       url: item.html_url, updated: item.updated_at, isDraft: item.draft ?? false, comments: item.comments)
        })
    }

    static func decodeRepository(_ data: Data) throws -> GitHubRepository {
        struct Repo: Decodable {
            var full_name: String
            var description: String?
            var stargazers_count: Int
            var forks_count: Int
            var open_issues_count: Int
            var subscribers_count: Int?
            var watchers_count: Int
            var language: String?
            var pushed_at: Date
            var default_branch: String
            var html_url: String
        }
        let repo = try decoder.decode(Repo.self, from: data)
        return GitHubRepository(name: repo.full_name, summary: repo.description, stars: repo.stargazers_count, forks: repo.forks_count,
                                openIssues: repo.open_issues_count, watchers: repo.subscribers_count ?? repo.watchers_count,
                                language: repo.language, pushed: repo.pushed_at, defaultBranch: repo.default_branch, url: repo.html_url)
    }

    static func decodeRuns(_ data: Data) throws -> [GitHubRun] {
        struct Response: Decodable {
            struct Run: Decodable {
                var id: Int
                var name: String?
                var display_title: String?
                var status: String
                var conclusion: String?
                var head_branch: String?
                var run_number: Int
                var created_at: Date
                var html_url: String
            }
            var workflow_runs: [Run]
        }
        return try decoder.decode(Response.self, from: data).workflow_runs.map { run in
            GitHubRun(id: run.id, name: run.name ?? run.display_title ?? "Workflow", status: run.status, conclusion: run.conclusion,
                      branch: run.head_branch ?? "", number: run.run_number, created: run.created_at, url: run.html_url)
        }
    }
}

/// Keeps GitHub data per widget setup, fetched only when a widget that shows
/// it asks, shared between widgets that show the same thing, kept on disk,
/// and paused while GitHub's hourly limit is used up.
@Observable @MainActor
public final class GitHubService {
    public struct Snapshot: Codable, Equatable, Sendable {
        public var data: GitHubData
        public var fetched: Date
    }

    /// Keyed by the credential's scope (see `GitHubKeychain.credentialScope`) and
    /// then the widget's configuration: data fetched with one token is never shown
    /// under another, or without one.
    public private(set) var snapshots: [String: Snapshot] = [:]
    public private(set) var errors: [String: String] = [:]

    @ObservationIgnored private let requests = SharedRequests()
    @ObservationIgnored private var backoff = RetryBackoff()
    @ObservationIgnored private var pausedUntil: Date?
    @ObservationIgnored private let cacheURL: URL?
    @ObservationIgnored private let scope: () -> String
    @ObservationIgnored private let fetch: @Sendable (GitHubConfig) async throws -> GitHubData
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "github")

    public init(cacheURL: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("AllSet", isDirectory: true).appendingPathComponent("github.json"),
                scope: @escaping () -> String = { GitHubKeychain.credentialScope },
                fetch: @escaping @Sendable (GitHubConfig) async throws -> GitHubData = { try await GitHubClient().fetch($0) }) {
        self.cacheURL = cacheURL
        self.scope = scope
        self.fetch = fetch
        if let cacheURL, let data = try? Data(contentsOf: cacheURL),
           let saved = try? JSONDecoder().decode([String: Snapshot].self, from: data) {
            // Only what the current credential fetched; anything else is dropped from disk too.
            let prefix = scope() + "|"
            snapshots = saved.filter { $0.key.hasPrefix(prefix) }
            if snapshots.count != saved.count { save() }
        }
    }

    /// Forgets every cached answer and error, on disk too: called when the token
    /// is saved or removed, so another account's private data can't linger.
    public func purgeCache() {
        snapshots = [:]
        errors = [:]
        backoff.reset()
        pausedUntil = nil
        if let cacheURL { try? FileManager.default.removeItem(at: cacheURL) }
    }

    private func scopedKey(_ config: GitHubConfig) -> String { scope() + "|" + Self.key(config) }

    public nonisolated static func key(_ config: GitHubConfig) -> String {
        let who = config.mode.needsRepository ? config.repository : config.user
        return "\(config.mode.rawValue)|\(who.lowercased())|\(config.mode == .pullRequests || config.mode == .issues ? config.repository.lowercased() : "")"
    }

    /// Whether the widget has what it needs to ask GitHub.
    public nonisolated static func isConfigured(_ config: GitHubConfig) -> Bool {
        if config.mode.needsRepository { return config.repository.split(separator: "/").count == 2 }
        return !config.user.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public func snapshot(_ config: GitHubConfig) -> Snapshot? { snapshots[scopedKey(config)] }
    public func error(_ config: GitHubConfig) -> String? { errors[scopedKey(config)] }

    /// Fetches if the snapshot is older than `maxAge`, unless GitHub's limit is
    /// used up or a recent failure (keyed by credential, so a new token starts
    /// fresh) is still being waited out, and waits for it. Cancelling every
    /// caller waiting on the fetch cancels it.
    public func refresh(_ config: GitHubConfig, maxAge: TimeInterval) async {
        guard Self.isConfigured(config) else { return }
        let key = scopedKey(config)
        if let snapshot = snapshots[key], Date.now.timeIntervalSince(snapshot.fetched) < maxAge { return }
        if let pausedUntil, pausedUntil > .now { return }
        guard requests.isRunning(key) || backoff.allows(key) else { return }
        await requests.run(key) { [self] in
            do {
                let data = try await fetch(config)
                snapshots[key] = Snapshot(data: data, fetched: .now)
                errors[key] = nil
                backoff.succeeded(key)
                save()
            } catch where WeatherService.isCancellation(error) {
                // Every widget asking for it left the screen: not a failure.
            } catch let failure as GitHubClient.Failure {
                switch failure {
                case .rateLimited(let until): pausedUntil = until
                case .unauthorized: backoff.failed(key, atLeast: backoff.longest)
                default: backoff.failed(key)
                }
                errors[key] = failure.description
            } catch {
                log.error("GitHub failed: \(error.localizedDescription, privacy: .public)")
                errors[key] = error.localizedDescription
                backoff.failed(key)
            }
        }
    }

    /// Asked for by hand: fetches now, whatever failed before (GitHub's own limit still applies).
    public func refreshNow(_ config: GitHubConfig) async {
        backoff.succeeded(scopedKey(config))
        await refresh(config, maxAge: 0)
    }

    private func save() {
        guard let cacheURL else { return }
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(snapshots).write(to: cacheURL, options: .atomic)
    }
}

/// An optional personal access token, kept in the login keychain.
public enum GitHubKeychain {
    private static let service = "com.pratik.allset.github"

    /// Which credential cached data belongs to: "anonymous", or a fingerprint (part
    /// of a SHA-256) of the token, never the token. Kept in UserDefaults and updated
    /// whenever the token is saved or removed, so launching never reads the Keychain.
    public static var credentialScope: String {
        UserDefaults.standard.string(forKey: scopeKey) ?? "anonymous"
    }

    static let scopeKey = "github.credentialScope"

    public static func fingerprint(_ token: String?) -> String {
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return "anonymous" }
        return SHA256.hash(data: Data(token.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    public static var token: String? {
        var result: CFTypeRef?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: "token", kSecReturnData as String: true,
        ]
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Replaces the token (nil or empty removes it). A failed save keeps the previous token.
    @discardableResult
    public static func setToken(_ token: String?) -> Bool {
        let stored = KeychainItem.store(token, service: service, account: "token")
        if stored { UserDefaults.standard.set(fingerprint(token), forKey: scopeKey) }
        return stored
    }
}
