import Foundation
import Testing
@testable import AllSetCore

@Suite struct BatteryHealthTests {
    // MARK: Registry layouts

    /// What this Mac (macOS 27) reports: nothing at the top level, the figures in `BatteryData`.
    @Test func newerMacOSKeepsCapacitiesInsideBatteryData() {
        let properties: [String: Any] = [
            "CycleCount": 83,
            "BatteryData": ["FullChargeCapacity": 4607, "NominalChargeCapacity": 4734, "DesignCapacity": 4629, "MaxCapacity": 100],
        ]
        let found = BatteryMath.capacities { properties[$0] }
        #expect(found.design == 4629)
        // The measured full charge, not the nominal figure that is larger than the design capacity.
        #expect(found.fullCharge == 4607)
        #expect(found.temperatureCelsius == nil)
    }

    @Test func olderMacOSKeepsThemAtTheTopLevelAsBefore() {
        let properties: [String: Any] = [
            "DesignCapacity": 4400, "NominalChargeCapacity": 4200, "AppleRawMaxCapacity": 4180, "Temperature": 3123,
            "BatteryData": ["FullChargeCapacity": 1, "DesignCapacity": 2],
        ]
        let found = BatteryMath.capacities { properties[$0] }
        #expect(found.design == 4400)
        #expect(found.fullCharge == 4200)
        #expect(found.temperatureCelsius == 31.23)
    }

    @Test func missingEverywhereIsUnknownNotZero() {
        let found = BatteryMath.capacities { _ in nil }
        #expect(found == BatteryMath.Capacities())
    }

    // MARK: What macOS reports

    private let profiler = Data("""
    {"SPPowerDataType": [
      {"_name": "spbattery_information",
       "sppower_battery_charge_info": {"sppower_battery_state_of_charge": 100},
       "sppower_battery_health_info": {"sppower_battery_cycle_count": 83, "sppower_battery_health": "Good",
                                       "sppower_battery_health_maximum_capacity": "96%"}},
      {"_name": "sppower_ac_charger_information"}]}
    """.utf8)

    @Test func readsMaximumCapacityAndConditionFromSystemProfiler() {
        let reading = BatteryHealthSource.parse(profiler)
        #expect(reading == BatteryHealthSource.Reading(maximumCapacity: 0.96, condition: "Good"))
    }

    @Test func aMacWithNoBatteryOrOddOutputGivesNothing() {
        #expect(BatteryHealthSource.parse(Data(#"{"SPPowerDataType": [{"_name": "x"}]}"#.utf8)) == nil)
        #expect(BatteryHealthSource.parse(Data("not json".utf8)) == nil)
        #expect(BatteryHealthSource.parse(Data()) == nil)
    }

    @Test func implausiblePercentagesAreIgnored() {
        func parse(_ text: String) -> BatteryHealthSource.Reading? {
            BatteryHealthSource.parse(Data(#"{"SPPowerDataType": [{"sppower_battery_health_info": {"sppower_battery_health_maximum_capacity": "\#(text)"}}]}"#.utf8))
        }
        #expect(parse("0%") == nil)
        #expect(parse("140%") == nil)
        #expect(parse("abc") == nil)
        #expect(parse("100%")?.maximumCapacity == 1)
    }

    // MARK: Health preference

    @Test func healthPrefersWhatMacOSReports() {
        var info = BatteryInfo(percent: 100, isCharging: false, isPluggedIn: true)
        #expect(info.health == nil)
        info.designCapacity = 4629
        info.fullChargeCapacity = 4607
        #expect(info.health.map { ($0 * 1000).rounded() } == 995)
        info.reportedMaximumCapacity = 0.96
        #expect(info.health == 0.96)
    }

    @Test func healthIsUnknownRatherThanJumpingWhileTheLookupIsPending() {
        var info = BatteryInfo(percent: 100, isCharging: false, isPluggedIn: true)
        info.designCapacity = 4629
        info.fullChargeCapacity = 4607
        info.reportedHealthIsPending = true
        #expect(info.health == nil)
        info.reportedMaximumCapacity = 0.96
        #expect(info.health == 0.96)
    }

    // MARK: Refreshing

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func next() -> Int { lock.withLock { value += 1; return value } }
        var count: Int { lock.withLock { value } }
    }

    private func settled(_ source: BatteryHealthSource, now: Date, until done: (BatteryHealthSource.Reading) -> Bool) -> BatteryHealthSource.Reading {
        var reading = source.current(now: now)
        for _ in 0..<200 where !done(reading) {
            Thread.sleep(forTimeInterval: 0.01)
            reading = source.current(now: now)
        }
        return reading
    }

    @Test func unknownUntilTheFirstAnswerThenCachedUntilStale() {
        let runs = Counter()
        let data = profiler
        let source = BatteryHealthSource(refreshInterval: 3600) { _ = runs.next(); return data }
        let start = Date(timeIntervalSince1970: 1_000_000)
        #expect(source.current(now: start).isPending)
        let answered = settled(source, now: start) { $0.maximumCapacity != nil }
        #expect(answered.maximumCapacity == 0.96)

        // Within the interval: no new run.
        _ = source.current(now: start.addingTimeInterval(60))
        _ = source.current(now: start.addingTimeInterval(1800))
        #expect(runs.count == 1)
        // Past it: one more, and the old reading stays meanwhile.
        #expect(source.current(now: start.addingTimeInterval(4000)).maximumCapacity == 0.96)
        for _ in 0..<200 where runs.count < 2 { Thread.sleep(forTimeInterval: 0.01) }
        #expect(runs.count == 2)
    }

    @Test func aFailedRunIsRetriedLaterNotOnEverySample() {
        let runs = Counter()
        let source = BatteryHealthSource(refreshInterval: 3600) { _ = runs.next(); return nil }
        let start = Date(timeIntervalSince1970: 2_000_000)
        _ = source.current(now: start)
        for _ in 0..<200 where runs.count < 1 { Thread.sleep(forTimeInterval: 0.01) }
        Thread.sleep(forTimeInterval: 0.05)
        for offset in [1.0, 5, 60, 600] { _ = source.current(now: start.addingTimeInterval(offset)) }
        #expect(runs.count == 1)
        // Nothing was learned, but the first attempt is over: not pending any more.
        let after = source.current(now: start.addingTimeInterval(3601))
        #expect(after.maximumCapacity == nil && !after.isPending)
    }
}
