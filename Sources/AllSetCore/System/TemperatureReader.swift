import Foundation
import IOKit.hidsystem
import CPrivateAPIs

public enum TemperatureSensorKind: Sendable {
    case soc
    case battery
    case ssd

    /// Classifies Apple Silicon HID sensor names such as "PMU tdie3",
    /// "gas gauge battery" and "NAND CH0 temp". Other sensors ("tdev", "tcal")
    /// are calibration or board readings and are ignored.
    public static func classify(_ productName: String) -> TemperatureSensorKind? {
        if productName.contains("tdie") { return .soc }
        if productName.hasPrefix("gas gauge") { return .battery }
        if productName.hasPrefix("NAND") { return .ssd }
        return nil
    }
}

/// Reads temperatures through the private IOHIDEventSystem API. Returns empty
/// readings on Macs where the sensors aren't exposed this way (Intel).
final class TemperatureReader {
    private static let temperatureEventType: Int64 = 15 // kIOHIDEventTypeTemperature
    private static let temperatureField: UInt32 = 15 << 16
    private static let plausibleRange = 1.0...130.0

    private let client: IOHIDEventSystemClient?
    private var sensors: [(service: IOHIDServiceClient, kind: TemperatureSensorKind)] = []

    init() {
        client = IOHIDEventSystemClientCreate(kCFAllocatorDefault)
        if let client {
            // Apple vendor page 0xff00, usage 5: temperature sensors.
            _ = IOHIDEventSystemClientSetMatching(client, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
        }
    }

    func read() -> Temperatures {
        if sensors.isEmpty { loadSensors() }
        var readings: [TemperatureSensorKind: [Double]] = [:]
        for sensor in sensors {
            guard let event = IOHIDServiceClientCopyEvent(sensor.service, Self.temperatureEventType, 0, 0) else { continue }
            let value = IOHIDEventGetFloatValue(event, Self.temperatureField)
            guard Self.plausibleRange.contains(value) else { continue }
            readings[sensor.kind, default: []].append(value)
        }
        return Temperatures(
            soc: average(readings[.soc]),
            socHottest: readings[.soc]?.max(),
            battery: average(readings[.battery]),
            ssd: average(readings[.ssd])
        )
    }

    private func loadSensors() {
        guard let client,
              let services = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient] else { return }
        sensors = services.compactMap { service in
            guard let name = IOHIDServiceClientCopyProperty(service, "Product" as CFString) as? String,
                  let kind = TemperatureSensorKind.classify(name) else { return nil }
            return (service, kind)
        }
    }

    private func average(_ values: [Double]?) -> Double? {
        guard let values, !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
