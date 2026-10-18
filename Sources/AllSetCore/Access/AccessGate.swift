import Foundation
import Observation

/// Where the app stands with its access key. Nothing in All Set starts until
/// it's one of the two unlocked states.
public enum AccessState: Equatable, Sendable {
    /// Waiting for a key; `message` says why the last one didn't open it.
    case locked(message: String?)
    /// Asking the library server.
    case checking
    case unlocked(name: String)
    /// The server didn't answer, but the saved token hasn't run out: what's
    /// already on this Mac works, and the key is checked again when the
    /// network comes back.
    case offlineUnlocked(name: String)

    public var isUnlocked: Bool {
        switch self {
        case .unlocked, .offlineUnlocked: true
        case .locked, .checking: false
        }
    }
}

/// What the server gave for a key: the token library requests carry, whose
/// key it is, and when the token runs out.
public struct AccessSession: Codable, Equatable, Sendable {
    public var token: String
    public var name: String
    public var expiresAt: Date

    public init(token: String, name: String, expiresAt: Date) {
        self.token = token
        self.name = name
        self.expiresAt = expiresAt
    }
}

/// How the gate reaches the server: `URLSession` in the app, a stub in tests.
public protocol AccessTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: AccessTransport {
    public func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request)
    }
}

/// The access key screen's state machine, against the library server's
/// `api/activate` and `api/me` (Documentation/operations.md, "Access keys"):
///
/// - A typed key is activated; a token comes back and both are kept (`AccessVault`).
/// - At launch a saved token is checked with `api/me`. Turned down (401), the
///   saved key is activated again, quietly; only a 401 to that locks the app.
/// - No answer: a token that hasn't run out unlocks in offline mode.
/// - A 401 from the library itself (`LibraryAuthorization`) goes the same way.
@Observable @MainActor
public final class AccessGate {
    public private(set) var state: AccessState = .locked(message: nil)

    public static let unreachableMessage = "Can't reach the server. Check your internet and try again."
    public static let invalidMessage = "This key isn't valid."
    public static let tooManyMessage = "Too many attempts. Try again in a few minutes."
    /// How long a token lasts when the server doesn't say.
    static let tokenLifetime: TimeInterval = 90 * 24 * 60 * 60
    /// A library 401 renews the token at most this often, so a server that
    /// turns down every file can't make the app activate in a loop.
    static let renewalSpacing: TimeInterval = 60

    @ObservationIgnored private let server: URL
    @ObservationIgnored private let transport: AccessTransport
    @ObservationIgnored private let vault: AccessVault
    @ObservationIgnored private let authorization: LibraryAuthorization
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var session: AccessSession?
    @ObservationIgnored private var isAsking = false
    @ObservationIgnored private var lastRenewal: Date?

    /// `server` is the library's address; `api/activate` and `api/me` are under it.
    public init(server: URL, transport: AccessTransport, vault: AccessVault,
                authorization: LibraryAuthorization, now: @escaping @Sendable () -> Date = { Date() }) {
        self.server = server
        self.transport = transport
        self.vault = vault
        self.authorization = authorization
        self.now = now
    }

    /// Whom the key belongs to and when its token runs out, once unlocked.
    public var current: AccessSession? { session }

    /// A key is saved: Continue with an empty field tries it again.
    public var hasSavedKey: Bool { vault.key != nil }

    /// At launch, and again when the network comes back: the saved token,
    /// else the saved key, else the key screen.
    public func start() async {
        guard !isAsking else { return }
        isAsking = true
        defer { isAsking = false }
        guard let saved = session ?? vault.session else {
            if let key = vault.key {
                state = .checking
                await activate(savedKey: key)
            } else {
                state = .locked(message: nil)
            }
            return
        }
        session = saved
        authorization.token = saved.token
        // A recheck while unlocked doesn't take the app down while it asks.
        if !state.isUnlocked { state = .checking }
        switch await ask(me(saved.token)) {
        case .granted(let answer):
            keep(AccessSession(token: saved.token, name: answer.name ?? saved.name,
                               expiresAt: answer.expiresAt ?? saved.expiresAt))
        case .refused(401, _):
            await renew(saved)
        case .refused, .unreachable:
            goOffline(with: saved)
        }
    }

    /// Continue on the key screen. An empty field retries the saved key.
    public func activate(typed: String) async {
        guard !isAsking else { return }
        let key = Self.normalized(typed)
        guard !key.isEmpty else {
            if let saved = vault.key {
                isAsking = true
                defer { isAsking = false }
                state = .checking
                await activate(savedKey: saved)
            } else {
                state = .locked(message: "Enter your access key.")
            }
            return
        }
        isAsking = true
        defer { isAsking = false }
        state = .checking
        switch await ask(activation(key)) {
        case .granted(let answer):
            vault.store(key: key)
            keep(session(from: answer))
        case .refused(let status, let message):
            state = .locked(message: message ?? Self.message(for: status))
        case .unreachable:
            state = .locked(message: Self.unreachableMessage)
        }
    }

    /// The library turned the token down while the app was running.
    public func libraryRejectedToken() async {
        guard state.isUnlocked, !isAsking, let saved = session else { return }
        if let lastRenewal, now().timeIntervalSince(lastRenewal) < Self.renewalSpacing { return }
        isAsking = true
        defer { isAsking = false }
        await renew(saved)
    }

    /// The network is back: offline mode, or a lock that was only for want of
    /// an answer, asks the server again.
    public func networkReturned() async {
        switch state {
        case .offlineUnlocked:
            await start()
        case .locked(Self.unreachableMessage) where session != nil || vault.key != nil:
            await start()
        default:
            break
        }
    }

    /// "Remove access key": forgets the key and the token.
    public func remove() {
        forget()
        state = .locked(message: nil)
    }

    /// Spaces and line breaks dropped (a key pasted from a message), in capitals.
    public static func normalized(_ typed: String) -> String {
        String(typed.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }).uppercased()
    }

    // MARK: Steps

    /// A saved key, activated without the person typing it.
    private func activate(savedKey key: String) async {
        switch await ask(activation(key)) {
        case .granted(let answer):
            keep(session(from: answer))
        case .refused(401, let message):
            forget()
            state = .locked(message: message ?? Self.invalidMessage)
        case .refused(let status, let message):
            state = .locked(message: message ?? Self.message(for: status))
        case .unreachable:
            state = .locked(message: Self.unreachableMessage)
        }
    }

    /// The token was turned down: the saved key gets a new one. Only a 401
    /// to that means the key itself is gone.
    private func renew(_ previous: AccessSession) async {
        lastRenewal = now()
        guard let key = vault.key else {
            forget()
            state = .locked(message: nil)
            return
        }
        switch await ask(activation(key)) {
        case .granted(let answer):
            keep(session(from: answer))
        case .refused(401, let message):
            forget()
            state = .locked(message: message ?? Self.invalidMessage)
        case .refused, .unreachable:
            goOffline(with: previous)
        }
    }

    private func goOffline(with saved: AccessSession) {
        state = saved.expiresAt > now() ? .offlineUnlocked(name: saved.name) : .locked(message: Self.unreachableMessage)
    }

    private func keep(_ fresh: AccessSession) {
        session = fresh
        authorization.token = fresh.token
        vault.store(session: fresh)
        state = .unlocked(name: fresh.name)
    }

    private func forget() {
        session = nil
        authorization.token = nil
        vault.store(key: nil)
        vault.store(session: nil)
    }

    private func session(from answer: Answer.Granted) -> AccessSession {
        AccessSession(token: answer.token ?? "", name: answer.name ?? "",
                      expiresAt: answer.expiresAt ?? now().addingTimeInterval(Self.tokenLifetime))
    }

    private static func message(for status: Int) -> String {
        switch status {
        case 401, 403: invalidMessage
        case 429: tooManyMessage
        default: unreachableMessage
        }
    }

    // MARK: Requests

    private func activation(_ key: String) -> URLRequest {
        var request = URLRequest(url: server.appendingPathComponent("api/activate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["key": key])
        return prepared(request)
    }

    private func me(_ token: String) -> URLRequest {
        var request = URLRequest(url: server.appendingPathComponent("api/me"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return prepared(request)
    }

    private func prepared(_ request: URLRequest) -> URLRequest {
        var request = request
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        return request
    }

    private enum Answer {
        struct Granted {
            var token: String?
            var name: String?
            var expiresAt: Date?
        }
        case granted(Granted)
        case refused(Int, message: String?)
        case unreachable
    }

    private struct Body: Decodable {
        var token: String?
        var name: String?
        var expiresAt: String?
        var error: String?
    }

    /// A 200 that isn't the JSON the contract names counts as no answer, and
    /// so does an activation without a token.
    private func ask(_ request: URLRequest) async -> Answer {
        guard let (data, response) = try? await transport.send(request),
              let http = response as? HTTPURLResponse else { return .unreachable }
        let body = try? JSONDecoder().decode(Body.self, from: data)
        guard http.statusCode == 200 else {
            let message = body?.error?.trimmingCharacters(in: .whitespacesAndNewlines)
            return .refused(http.statusCode, message: message?.isEmpty == false ? message : nil)
        }
        guard let body else { return .unreachable }
        let isActivation = request.httpMethod == "POST"
        if isActivation, body.token?.isEmpty ?? true { return .unreachable }
        return .granted(.init(token: body.token, name: body.name, expiresAt: body.expiresAt.flatMap(Self.date)))
    }

    /// ISO 8601, with or without fractions of a second.
    static func date(_ text: String) -> Date? {
        let plain = ISO8601DateFormatter()
        if let date = plain.date(from: text) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text)
    }
}
