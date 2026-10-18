import Foundation
import Testing
@testable import AllSetCore

/// Answers as the library server's `api/activate` and `api/me` would, from
/// what each test installs; a nil answer is no connection at all.
private final class AccessServerStub: AccessTransport, @unchecked Sendable {
    typealias Answer = (status: Int, body: [String: String])?
    private let lock = NSLock()
    private var activate: [Answer] = []
    private var me: [Answer] = []
    private var seen: [URLRequest] = []

    /// Each call takes the next answer; the last one repeats.
    func answerActivate(_ answers: Answer...) { lock.withLock { activate = answers } }
    func answerMe(_ answers: Answer...) { lock.withLock { me = answers } }

    var requests: [URLRequest] { lock.withLock { seen } }
    var paths: [String] { requests.compactMap { $0.url?.path } }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let answer: Answer = lock.withLock {
            seen.append(request)
            let isMe = request.url?.path == "/api/me"
            var queue = isMe ? me : activate
            let next = queue.count > 1 ? queue.removeFirst() : queue.first ?? nil
            if isMe { me = queue } else { activate = queue }
            return next
        }
        guard let answer, let url = request.url else { throw URLError(.notConnectedToInternet) }
        let response = HTTPURLResponse(url: url, statusCode: answer.status, httpVersion: "HTTP/1.1", headerFields: nil)!
        return (try JSONSerialization.data(withJSONObject: answer.body), response)
    }
}

@MainActor
private final class MemoryVault: AccessVault {
    var key: String?
    var session: AccessSession?
    func store(key: String?) { self.key = key }
    func store(session: AccessSession?) { self.session = session }
}

@MainActor @Suite struct AccessGateTests {
    private static let server = URL(string: "https://library.test")!
    private nonisolated static let today = Date(timeIntervalSince1970: 1_800_000_000)
    private static let granted: [String: String] = ["token": "fresh-token", "name": "Sam", "expiresAt": "2027-01-16T00:00:00Z"]

    private let stub = AccessServerStub()
    private let vault = MemoryVault()
    private let authorization = LibraryAuthorization(host: "library.test")

    private func makeGate(now: Date = AccessGateTests.today) -> AccessGate {
        AccessGate(server: Self.server, transport: stub, vault: vault, authorization: authorization, now: { now })
    }

    private func saveSession(expiring expiresAt: Date, key: String? = "ALLSET-AAAA-BBBB-CCCC") {
        vault.key = key
        vault.session = AccessSession(token: "old-token", name: "Sam", expiresAt: expiresAt)
    }

    // MARK: Typing a key

    @Test func anAcceptedKeyUnlocksAndIsKeptWithItsToken() async throws {
        stub.answerActivate((200, Self.granted))
        let gate = makeGate()
        await gate.activate(typed: "  allset-abcd efgh-ijkl \n")
        #expect(gate.state == .unlocked(name: "Sam"))
        // Trimmed and in capitals before it's sent, and kept as sent.
        let sent = try #require(stub.requests.first)
        #expect(sent.httpMethod == "POST")
        #expect(sent.url?.path == "/api/activate")
        let body = try JSONDecoder().decode([String: String].self, from: try #require(sent.httpBody))
        #expect(body == ["key": "ALLSET-ABCDEFGH-IJKL"])
        #expect(vault.key == "ALLSET-ABCDEFGH-IJKL")
        #expect(vault.session?.token == "fresh-token")
        #expect(vault.session?.expiresAt == AccessGate.date("2027-01-16T00:00:00Z"))
        // Library requests now carry it.
        #expect(authorization.headers(for: URL(string: "https://library.test/catalog.json")!) == ["Authorization": "Bearer fresh-token"])
    }

    @Test func aRefusedKeyShowsTheServersWordsAndKeepsNothing() async {
        stub.answerActivate((401, ["error": "This key isn't valid."]))
        let gate = makeGate()
        await gate.activate(typed: "ALLSET-WRONG-WRONG-WRONG")
        #expect(gate.state == .locked(message: "This key isn't valid."))
        #expect(vault.key == nil && vault.session == nil)
        #expect(authorization.token == nil)
    }

    @Test func tooManyAttemptsSaysSo() async {
        stub.answerActivate((429, ["error": "Too many attempts. Try again in a few minutes."]))
        let gate = makeGate()
        await gate.activate(typed: "ALLSET-AAAA-BBBB-CCCC")
        #expect(gate.state == .locked(message: "Too many attempts. Try again in a few minutes."))
        #expect(vault.key == nil)
        // Without the server's words, its meaning.
        stub.answerActivate((429, [:]))
        await gate.activate(typed: "ALLSET-AAAA-BBBB-CCCC")
        #expect(gate.state == .locked(message: AccessGate.tooManyMessage))
    }

    @Test func noConnectionOrAServerErrorIsCantReach() async {
        stub.answerActivate(nil)
        let gate = makeGate()
        await gate.activate(typed: "ALLSET-AAAA-BBBB-CCCC")
        #expect(gate.state == .locked(message: AccessGate.unreachableMessage))
        stub.answerActivate((502, [:]))
        await gate.activate(typed: "ALLSET-AAAA-BBBB-CCCC")
        #expect(gate.state == .locked(message: AccessGate.unreachableMessage))
        // A 200 without a token isn't a yes.
        stub.answerActivate((200, ["name": "Sam"]))
        await gate.activate(typed: "ALLSET-AAAA-BBBB-CCCC")
        #expect(gate.state == .locked(message: AccessGate.unreachableMessage))
        #expect(vault.key == nil)
    }

    // MARK: Launch

    @Test func nothingSavedIsTheKeyScreenWithoutAsking() async {
        let gate = makeGate()
        await gate.start()
        #expect(gate.state == .locked(message: nil))
        #expect(stub.requests.isEmpty)
    }

    @Test func aSavedTokenTheServerKnowsUnlocks() async throws {
        saveSession(expiring: Self.today.addingTimeInterval(86_400))
        stub.answerMe((200, ["name": "Sam R", "expiresAt": "2027-02-01T00:00:00.000Z"]))
        let gate = makeGate()
        await gate.start()
        #expect(gate.state == .unlocked(name: "Sam R"))
        #expect(stub.paths == ["/api/me"])
        #expect(stub.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer old-token")
        #expect(vault.session?.token == "old-token")
        #expect(vault.session?.expiresAt == AccessGate.date("2027-02-01T00:00:00Z"))
    }

    @Test func aTurnedDownTokenIsRenewedQuietlyWithTheSavedKey() async throws {
        saveSession(expiring: Self.today.addingTimeInterval(86_400))
        stub.answerMe((401, [:]))
        stub.answerActivate((200, Self.granted))
        let gate = makeGate()
        await gate.start()
        #expect(gate.state == .unlocked(name: "Sam"))
        #expect(stub.paths == ["/api/me", "/api/activate"])
        let body = try JSONDecoder().decode([String: String].self, from: try #require(stub.requests.last?.httpBody))
        #expect(body == ["key": "ALLSET-AAAA-BBBB-CCCC"])
        #expect(vault.session?.token == "fresh-token")
        #expect(authorization.token == "fresh-token")
    }

    @Test func aRevokedKeyLocksAndForgetsEverything() async {
        saveSession(expiring: Self.today.addingTimeInterval(86_400))
        stub.answerMe((401, [:]))
        stub.answerActivate((401, ["error": "This key isn't valid."]))
        let gate = makeGate()
        await gate.start()
        #expect(gate.state == .locked(message: "This key isn't valid."))
        #expect(vault.key == nil && vault.session == nil)
        #expect(authorization.token == nil)
    }

    @Test func renewingWithoutAnAnswerIsOfflineNotLocked() async {
        saveSession(expiring: Self.today.addingTimeInterval(86_400))
        stub.answerMe((401, [:]))
        stub.answerActivate((429, [:]))
        let gate = makeGate()
        await gate.start()
        #expect(gate.state == .offlineUnlocked(name: "Sam"))
        #expect(vault.key != nil)
    }

    // MARK: Offline

    @Test func offlineWithATokenStillValidUnlocksUntilTheNetworkIsBack() async {
        saveSession(expiring: Self.today.addingTimeInterval(86_400))
        stub.answerMe(nil)
        let gate = makeGate()
        await gate.start()
        #expect(gate.state == .offlineUnlocked(name: "Sam"))
        #expect(authorization.token == "old-token")
        // Back online: asked again, and fully unlocked.
        stub.answerMe((200, ["name": "Sam", "expiresAt": "2027-02-01T00:00:00Z"]))
        await gate.networkReturned()
        #expect(gate.state == .unlocked(name: "Sam"))
        #expect(stub.paths == ["/api/me", "/api/me"])
    }

    @Test func offlineWithAnExpiredTokenLocks() async {
        saveSession(expiring: Self.today.addingTimeInterval(-60))
        stub.answerMe(nil)
        let gate = makeGate()
        await gate.start()
        #expect(gate.state == .locked(message: AccessGate.unreachableMessage))
        // Kept for when the network comes back.
        #expect(vault.session != nil && vault.key != nil)
        stub.answerMe((401, [:]))
        stub.answerActivate((200, Self.granted))
        await gate.networkReturned()
        #expect(gate.state == .unlocked(name: "Sam"))
    }

    // MARK: While running

    @Test func aLibrary401RenewsOnceAMinuteAtMost() async {
        stub.answerActivate((200, Self.granted))
        let gate = makeGate()
        await gate.activate(typed: "ALLSET-AAAA-BBBB-CCCC")
        stub.answerActivate((200, ["token": "newer-token", "name": "Sam", "expiresAt": "2027-03-01T00:00:00Z"]))
        await gate.libraryRejectedToken()
        #expect(authorization.token == "newer-token")
        await gate.libraryRejectedToken()
        #expect(stub.paths == ["/api/activate", "/api/activate"])
        // A later one renews again; a revoked key then locks.
        stub.answerActivate((401, [:]))
        let later = AccessGate(server: Self.server, transport: stub, vault: vault, authorization: authorization,
                               now: { Self.today.addingTimeInterval(120) })
        await later.start()
        await later.libraryRejectedToken()
        #expect(later.state == .locked(message: AccessGate.invalidMessage))
        #expect(vault.key == nil)
    }

    @Test func removingTheKeyForgetsItAndLocks() async {
        stub.answerActivate((200, Self.granted))
        let gate = makeGate()
        await gate.activate(typed: "ALLSET-AAAA-BBBB-CCCC")
        gate.remove()
        #expect(gate.state == .locked(message: nil))
        #expect(vault.key == nil && vault.session == nil)
        #expect(authorization.token == nil)
    }

    @Test func anEmptyFieldRetriesTheSavedKey() async {
        let gate = makeGate()
        await gate.activate(typed: "  ")
        #expect(gate.state == .locked(message: "Enter your access key."))
        #expect(stub.requests.isEmpty)
        vault.key = "ALLSET-AAAA-BBBB-CCCC"
        stub.answerActivate((200, Self.granted))
        await gate.activate(typed: "")
        #expect(gate.state == .unlocked(name: "Sam"))
    }
}

@Suite struct LibraryAuthorizationTests {
    @Test func onlyTheLibrarysHostGetsTheToken() {
        let authorization = LibraryAuthorization(host: "Wallpapers.Example.com", token: "t")
        var library = URLRequest(url: URL(string: "https://wallpapers.example.com/live/a.mp4")!)
        authorization.authorize(&library)
        #expect(library.value(forHTTPHeaderField: "Authorization") == "Bearer t")
        var other = URLRequest(url: URL(string: "https://api.open-meteo.com/v1")!)
        authorization.authorize(&other)
        #expect(other.value(forHTTPHeaderField: "Authorization") == nil)
        // A private library's own key stays.
        var keyed = URLRequest(url: URL(string: "https://wallpapers.example.com/api/library")!)
        keyed.setValue("Bearer own-key", forHTTPHeaderField: "Authorization")
        authorization.authorize(&keyed)
        #expect(keyed.value(forHTTPHeaderField: "Authorization") == "Bearer own-key")
        #expect(authorization.headers(for: URL(fileURLWithPath: "/tmp/a.mp4")).isEmpty)
        authorization.token = nil
        #expect(authorization.headers(for: URL(string: "https://wallpapers.example.com/a")!).isEmpty)
    }

    @Test func only401sFromTheLibraryAreReported() {
        let authorization = LibraryAuthorization(host: "wallpapers.example.com", token: "t")
        let count = Counter()
        authorization.onRejected { count.add() }
        func answer(_ address: String, _ status: Int) -> HTTPURLResponse {
            HTTPURLResponse(url: URL(string: address)!, statusCode: status, httpVersion: nil, headerFields: nil)!
        }
        authorization.check(answer("https://wallpapers.example.com/catalog.json", 401))
        authorization.check(answer("https://wallpapers.example.com/catalog.json", 404))
        authorization.check(answer("https://elsewhere.example.com/catalog.json", 401))
        authorization.check(nil)
        #expect(count.value == 1)
    }

    @Test func aFreshInstallAndTheRetiredTailscaleServerUseThePublicLibrary() {
        let library = URL(string: "https://wallpapers.example.com")!
        #expect(WallpaperConfig.libraryAddress(saved: nil, publicLibrary: library) == "https://wallpapers.example.com")
        #expect(WallpaperConfig.libraryAddress(saved: " ", publicLibrary: library) == "https://wallpapers.example.com")
        #expect(WallpaperConfig.libraryAddress(saved: "http://100.71.191.101:8080", publicLibrary: library) == "https://wallpapers.example.com")
        #expect(WallpaperConfig.libraryAddress(saved: "http://100.64.0.9:8080/", publicLibrary: library) == "https://wallpapers.example.com")
        // A server of this Mac's own stays.
        #expect(WallpaperConfig.libraryAddress(saved: "http://192.168.1.20:8080", publicLibrary: library) == "http://192.168.1.20:8080")
        #expect(WallpaperConfig.libraryAddress(saved: "https://my.server.example", publicLibrary: library) == "https://my.server.example")
    }
}

// Sendable because: `count` is only read and written under `lock`.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func add() { lock.withLock { count += 1 } }
}

@MainActor @Suite struct KeychainAccessVaultTests {
    /// Its own throwaway service, never the app's real items.
    private let service = "com.pratik.allset.tests.\(UUID().uuidString)"

    @Test func theKeyAndTokenRoundTripAndAreForgotten() throws {
        let vault = KeychainAccessVault(service: service)
        defer { vault.store(key: nil); vault.store(session: nil) }
        #expect(vault.key == nil && vault.session == nil)
        let session = AccessSession(token: "t", name: "Sam", expiresAt: Date(timeIntervalSince1970: 1_800_000_000))
        vault.store(key: "ALLSET-AAAA-BBBB-CCCC")
        vault.store(session: session)
        let again = KeychainAccessVault(service: service)
        #expect(again.key == "ALLSET-AAAA-BBBB-CCCC")
        #expect(again.session == session)
        again.store(key: nil)
        again.store(session: nil)
        #expect(KeychainAccessVault(service: service).key == nil)
        #expect(KeychainAccessVault(service: service).session == nil)
    }
}
