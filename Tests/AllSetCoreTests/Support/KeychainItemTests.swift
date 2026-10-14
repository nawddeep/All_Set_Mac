import Foundation
import Testing
@testable import AllSetCore

/// Review D4: replacing a key deleted the old one first, so a failed add lost it.
/// Uses its own throwaway service, never the app's real items.
@Suite struct KeychainItemTests {
    private let service = "com.pratik.allset.tests.\(UUID().uuidString)"

    @Test func replacingUpdatesInPlaceAndEmptyRemoves() {
        defer { KeychainItem.store(nil, service: service, account: "key") }
        #expect(KeychainItem.read(service: service, account: "key") == nil)
        #expect(KeychainItem.store("first", service: service, account: "key"))
        #expect(KeychainItem.read(service: service, account: "key") == "first")
        // An existing item is updated, not deleted and re-added.
        #expect(KeychainItem.store("  second \n", service: service, account: "key"))
        #expect(KeychainItem.read(service: service, account: "key") == "second")
        #expect(KeychainItem.store("", service: service, account: "key"))
        #expect(KeychainItem.read(service: service, account: "key") == nil)
        // Removing what isn't there is fine.
        #expect(KeychainItem.store(nil, service: service, account: "key"))
    }
}
