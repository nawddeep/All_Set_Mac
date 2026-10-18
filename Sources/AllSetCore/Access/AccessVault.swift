import Foundation

/// Where the access key and its token are kept: the Keychain in the app
/// (`KeychainAccessVault`), memory in tests. Never UserDefaults or a file.
@MainActor
public protocol AccessVault: AnyObject {
    var key: String? { get }
    var session: AccessSession? { get }
    /// Nil forgets it.
    func store(key: String?)
    func store(session: AccessSession?)
}

/// Two generic-password items under one service: the key as typed (in
/// capitals), and the token with its owner's name and expiry as JSON.
@MainActor
public final class KeychainAccessVault: AccessVault {
    public static let defaultService = "com.pratik.allset.access"
    private let service: String
    /// Read once; the Keychain is asked again only after a change here.
    private var cachedKey: String??
    private var cachedSession: AccessSession??

    public init(service: String = defaultService) {
        self.service = service
    }

    public var key: String? {
        if let cachedKey { return cachedKey }
        let key = KeychainItem.read(service: service, account: "access-key")
        cachedKey = .some(key)
        return key
    }

    public var session: AccessSession? {
        if let cachedSession { return cachedSession }
        let session = KeychainItem.read(service: service, account: "session")
            .flatMap { try? Self.decoder.decode(AccessSession.self, from: Data($0.utf8)) }
        cachedSession = .some(session)
        return session
    }

    public func store(key: String?) {
        KeychainItem.store(key, service: service, account: "access-key")
        cachedKey = nil
    }

    public func store(session: AccessSession?) {
        let text = session.flatMap { try? Self.encoder.encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
        KeychainItem.store(text, service: service, account: "session")
        cachedSession = nil
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
