import Foundation
import IOKit
import IOKit.ps

public enum BatteryMath {
    /// Capacities and temperature from a registry lookup. Newer macOS moved these
    /// from the top level of the AppleSmartBattery entry into its `BatteryData`
    /// dictionary, so both places are tried (top level first).
    public struct Capacities: Equatable, Sendable {
        public var design: Int?
        public var fullCharge: Int?
        public var temperatureCelsius: Double?
    }

    public static func capacities(_ value: (String) -> Any?) -> Capacities {
        let nested = value("BatteryData") as? [String: Any] ?? [:]
        func topLevel(_ keys: [String]) -> Int? {
            for key in keys { if let found = IORegistry.int(value(key)) { return found } }
            return nil
        }
        func inside(_ keys: [String]) -> Int? {
            for key in keys { if let found = IORegistry.int(nested[key]) { return found } }
            return nil
        }
        var result = Capacities()
        result.design = topLevel(["DesignCapacity"]) ?? inside(["DesignCapacity"])
        // Apple Silicon reports "MaxCapacity" as a percentage; the mAh figures live under these keys
        // instead. Inside `BatteryData`, "NominalChargeCapacity" can exceed the design capacity, so the
        // measured full-charge figure comes first there.
        result.fullCharge = topLevel(["NominalChargeCapacity", "AppleRawMaxCapacity"])
            ?? inside(["FullChargeCapacity", "AppleRawMaxCapacity", "NominalChargeCapacity"])
        // Hundredths of a degree. Absent on newer macOS: the battery gauge sensor stands in (see SystemSampler).
        if let centi = topLevel(["Temperature"]) ?? inside(["Temperature"]) { result.temperatureCelsius = Double(centi) / 100 }
        return result
    }

    public static func health(fullChargeCapacity: Int?, designCapacity: Int?) -> Double? {
        guard let full = fullChargeCapacity, let design = designCapacity, design > 0, full > 0 else { return nil }
        return min(Double(full) / Double(design), 1)
    }
}

/// Battery state from IOPowerSources plus detail (health, cycles, power draw)
/// from the AppleSmartBattery registry entry.
enum BatteryReader {
    /// Nil on Macs without a battery.
    static func read() -> BatteryInfo? {
        guard let source = powerSourceDescription() else { return nil }
        var info = batteryInfo(from: source)
        addRegistryDetails(to: &info)
        // What System Settings reports, when the registry can't say (newer macOS).
        let reported = BatteryHealthSource.shared.current()
        info.reportedMaximumCapacity = reported.maximumCapacity
        info.reportedHealthIsPending = reported.isPending
        if info.condition == nil { info.condition = reported.condition }
        return info
    }

    /// Just the fields needed to detect plug/unplug and low battery.
    static func powerState() -> PowerState? {
        guard let source = powerSourceDescription() else { return nil }
        let info = batteryInfo(from: source)
        return PowerState(percent: info.percent, isPluggedIn: info.isPluggedIn, isCharging: info.isCharging)
    }

    private static func powerSourceDescription() -> [String: Any]? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  description["Type"] as? String == "InternalBattery" else { continue }
            return description
        }
        return nil
    }

    private static func batteryInfo(from source: [String: Any]) -> BatteryInfo {
        let current = IORegistry.int(source["Current Capacity"]) ?? 0
        let max = IORegistry.int(source["Max Capacity"]) ?? 100
        let percent = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
        let isCharging = source["Is Charging"] as? Bool ?? false
        let isPluggedIn = source["Power Source State"] as? String == "AC Power"
        // -1 means macOS is still estimating; 0 means not applicable.
        let minutes = IORegistry.int(source[isCharging ? "Time to Full Charge" : "Time to Empty"]).flatMap { $0 > 0 ? $0 : nil }

        var info = BatteryInfo(
            percent: percent,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            isFullyCharged: source["Is Charged"] as? Bool ?? false,
            minutesRemaining: isPluggedIn && !isCharging ? nil : minutes,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
        info.condition = source["BatteryHealth"] as? String
        return info
    }

    private static func addRegistryDetails(to info: inout BatteryInfo) {
        let battery = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("AppleSmartBattery"))
        guard battery != 0 else { return }
        defer { IOObjectRelease(battery) }
        func value(_ key: String) -> Any? { IORegistry.property(battery, key) }

        info.cycleCount = IORegistry.int(value("CycleCount"))
        let capacities = BatteryMath.capacities(value)
        info.designCapacity = capacities.design
        info.fullChargeCapacity = capacities.fullCharge
        info.temperatureCelsius = capacities.temperatureCelsius
        if let millivolts = IORegistry.int(value("Voltage")) {
            info.voltage = Double(millivolts) / 1000
        }
        if let milliamps = IORegistry.signedInt(value("InstantAmperage") ?? value("Amperage")) {
            info.amperage = Double(milliamps) / 1000
        }
        if let telemetry = value("PowerTelemetryData") as? [String: Any] {
            let powerIn = IORegistry.int(telemetry["SystemPowerIn"]) ?? 0
            let load = IORegistry.int(telemetry["SystemLoad"]) ?? 0
            let milliwatts = powerIn > 0 ? powerIn : load
            if milliwatts > 0 { info.systemPowerWatts = Double(milliwatts) / 1000 }
        }
        if info.isPluggedIn, let adapter = value("AdapterDetails") as? [String: Any] {
            info.adapterWatts = IORegistry.int(adapter["Watts"])
        }
    }
}
