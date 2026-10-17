import Foundation
import Testing
@testable import AllSetCore

@Suite struct CapabilitiesTests {
    @Test func killSwitchesAreReadFromDefaults() throws {
        let suite = "capabilities-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: Capability.nowPlaying.killSwitchKey)
        let capabilities = Capabilities(defaults: defaults)
        #expect(!capabilities.isEnabled(.nowPlaying))
        #expect(capabilities.isEnabled(.temperatures))
        #expect(capabilities.status(.nowPlaying) == .disabled)
        // A switched-off capability never reports anything else.
        capabilities.report(.nowPlaying, .available)
        #expect(capabilities.status(.nowPlaying) == .disabled)
    }

    @Test func reportsReplaceEachOther() {
        let capabilities = Capabilities(defaults: UserDefaults(suiteName: "capabilities-empty-\(UUID())")!)
        #expect(capabilities.status(.audioTaps) == .unknown && capabilities.status(.audioTaps).isUsable)
        capabilities.report(.audioTaps, .failed("boom"))
        #expect(!capabilities.status(.audioTaps).isUsable)
        #expect(capabilities.status(.audioTaps).label.contains("boom"))
        capabilities.report(.audioTaps, .available)
        #expect(capabilities.status(.audioTaps) == .available)
    }

    @Test func everyCapabilitySaysWhatItAffects() {
        for capability in Capability.allCases {
            #expect(!capability.title.isEmpty && !capability.feature.isEmpty)
            #expect(capability.killSwitchKey == "capability.\(capability.rawValue).disabled")
        }
    }

    @Test func theNowPlayingHelperBacksOffAndGivesUp() {
        #expect(MediaController.maximumRetries == 3)
        #expect([1, 2, 3].map(MediaController.retryDelay) == [.seconds(2), .seconds(4), .seconds(8)])
    }
}
