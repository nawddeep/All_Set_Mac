import Foundation
import Testing
@testable import AllSetCore

@Suite struct BatteryTests {
    /// Settings saved before the option existed rest on battery, the new default.
    @Test func tapTapRestsOnBatteryUnlessTurnedOff() throws {
        let old = try JSONDecoder().decode(KnockSettings.self, from: Data(#"{"isEnabled": true, "restInLowPowerMode": true}"#.utf8))
        #expect(old.restOnBattery)
        var settings = KnockSettings()
        settings.restOnBattery = false
        let again = try JSONDecoder().decode(KnockSettings.self, from: JSONEncoder().encode(settings))
        #expect(!again.restOnBattery)
    }

    @Test func idleSamplingSlowsOffTheCharger() {
        #expect(PerformancePolicy(isOnBattery: true).monitorIdleInterval > PerformancePolicy().monitorIdleInterval)
        #expect(PerformancePolicy(isOnBattery: true).artFrameRate < PerformancePolicy().artFrameRate)
    }
}

@Suite struct WallpaperBatteryDefaultTests {
    /// Settings saved before the change get Pause on battery once...
    @Test func olderSettingsPauseOnBatteryOnce() throws {
        let old = try JSONDecoder().decode(WallpaperConfig.self, from: Data(#"{"isEnabled": true, "pauseOnBattery": false}"#.utf8))
        #expect(old.pauseOnBattery)
        #expect(old.defaultsVersion == WallpaperConfig.currentDefaultsVersion)
    }

    /// ...and turning it off afterwards sticks.
    @Test func turningItOffAgainIsKept() throws {
        var config = WallpaperConfig()
        #expect(config.pauseOnBattery)
        config.pauseOnBattery = false
        let again = try JSONDecoder().decode(WallpaperConfig.self, from: JSONEncoder().encode(config))
        #expect(!again.pauseOnBattery)
    }
}
