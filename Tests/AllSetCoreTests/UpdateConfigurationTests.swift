import Foundation
import Testing
@testable import AllSetCore

@Suite struct UpdateConfigurationTests {
    let feed = "https://github.com/nawddeep/All_Set_Mac/releases/latest/download/appcast.xml"

    @Test func offUntilTheOwnerSetsAKey() {
        #expect(!UpdateConfiguration.isConfigured(info: ["SUPublicEDKey": UpdateConfiguration.placeholderKey, "SUFeedURL": feed], isPackaged: true))
        #expect(!UpdateConfiguration.isConfigured(info: ["SUFeedURL": feed], isPackaged: true))
        #expect(!UpdateConfiguration.isConfigured(info: nil, isPackaged: true))
        #expect(UpdateConfiguration.isConfigured(info: ["SUPublicEDKey": "abc123=", "SUFeedURL": feed], isPackaged: true))
    }

    @Test func onlyPackagedAppsOverHTTPS() {
        #expect(!UpdateConfiguration.isConfigured(info: ["SUPublicEDKey": "abc123=", "SUFeedURL": feed], isPackaged: false))
        #expect(!UpdateConfiguration.isConfigured(info: ["SUPublicEDKey": "abc123=", "SUFeedURL": "http://x/appcast.xml"], isPackaged: true))
    }

    @Test func theShippedInfoPlistIsStillThePlaceholder() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let info = try #require(NSDictionary(contentsOf: root.appendingPathComponent("Resources/Info.plist")) as? [String: Any])
        // The key is the owner's to add (OWNER_ACTIONS); a real one belongs in the release variable, not here by accident.
        #expect(info["SUPublicEDKey"] as? String == UpdateConfiguration.placeholderKey)
        #expect((info["SUFeedURL"] as? String)?.hasPrefix("https://") == true)
    }
}
