import Foundation

/// The home server's delete-service bearer token, kept in the login
/// keychain. Same shape as `GitHubKeychain` — see that for why.
/// Set once, on the server, with:
///   security add-generic-password -s com.pratik.allset.delete -a token -w '<token>'
public enum DeleteAPIKeychain {
    private static let service = "com.pratik.allset.delete"

    public static var token: String? {
        var result: CFTypeRef?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: "token", kSecReturnData as String: true,
        ]
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
