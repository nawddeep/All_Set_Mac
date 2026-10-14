import Foundation
import Testing
@testable import AllSetCore

@Suite struct PerformancePolicyTests {
    @Test func tiersFollowPowerAndHeat() {
        #expect(PerformancePolicy().tier == .full)
        #expect(PerformancePolicy(isOnBattery: true).tier == .balanced)
        #expect(PerformancePolicy(thermal: .fair).tier == .balanced)
        #expect(PerformancePolicy(isLowPower: true).tier == .saver)
        #expect(PerformancePolicy(isOnBattery: true, thermal: .serious).tier == .saver)
        // The hottest signal wins over everything else.
        #expect(PerformancePolicy(isLowPower: true, thermal: .critical).tier == .minimal)
    }

    @Test func slowerTiersNeverSpeedAnythingUp() {
        let tiers = [PerformancePolicy(), PerformancePolicy(isOnBattery: true), PerformancePolicy(isLowPower: true),
                     PerformancePolicy(thermal: .critical)]
        for (calmer, busier) in zip(tiers.dropFirst(), tiers) {
            #expect(calmer.monitorIdleInterval >= busier.monitorIdleInterval)
            #expect(calmer.monitorMinimumInterval >= busier.monitorMinimumInterval)
            #expect(calmer.clipboardInterval >= busier.clipboardInterval)
            #expect(calmer.networkRefreshScale >= busier.networkRefreshScale)
            #expect(calmer.artFrameRate <= busier.artFrameRate)
        }
    }

    @Test func motionPausesOnlyWhenItShould() {
        // Same as before on battery and in Low Power Mode.
        #expect(!PerformancePolicy(isOnBattery: true).pausesDecorativeMotion)
        #expect(PerformancePolicy(isLowPower: true).pausesDecorativeMotion)
        #expect(PerformancePolicy(reducesMotion: true).pausesDecorativeMotion)
        // New: a hot Mac rests its decorative motion too.
        #expect(PerformancePolicy(thermal: .serious).pausesDecorativeMotion)
        #expect(!PerformancePolicy(thermal: .fair).pausesDecorativeMotion)
    }

    @Test func batteryAndLowPowerValues() {
        // Off the charger idle sampling slows to one reading every ten seconds.
        #expect(PerformancePolicy().clipboardInterval == 0.5)
        #expect(PerformancePolicy(isOnBattery: true).clipboardInterval == 1)
        #expect(PerformancePolicy().artFrameRate == 24 && PerformancePolicy(isOnBattery: true).artFrameRate == 15)
        #expect(PerformancePolicy().monitorIdleInterval == 3)
        #expect(PerformancePolicy(isOnBattery: true).monitorIdleInterval == 10)
        #expect(PerformancePolicy(isLowPower: true).monitorIdleInterval == 20)
    }
}
