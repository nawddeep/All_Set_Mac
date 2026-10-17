import Foundation

/// The wallpaper library server's API key on this Mac: one permanent key, given
/// out by the library's owner and saved with `AllSet library <key>`. It lives in
/// the Keychain, never in a file, and goes with every request to the library
/// server (scripts/cloud/catalog_service.py checks it).
public enum LibraryKey {
    public static let keychainService = "com.pratik.allset.library"
    private static let account = "api-key"

    /// Posted between processes when the `library` command has saved a key or
    /// changed what's in the library folder, so the running app shows it.
    public static let changed = Notification.Name("com.pratik.allset.libraryChanged")

    public static func read(service: String = keychainService) -> String? {
        KeychainItem.read(service: service, account: account)
    }

    /// Saves the key; nil or an empty one forgets it. True when the Keychain now holds it.
    @discardableResult
    public static func store(_ key: String?, service: String = keychainService) -> Bool {
        KeychainItem.store(key, service: service, account: account)
    }

    public static func announceChange() {
        DistributedNotificationCenter.default().postNotificationName(changed, object: nil, userInfo: nil, deliverImmediately: true)
    }
}
