import Foundation
import OSLog

/// The battery's Maximum Capacity and Condition exactly as System Settings reports
/// them. On newer macOS they are not in the IOKit registry (and the registry's
/// capacities don't reproduce Apple's percentage), so the one source is
/// `system_profiler`. It takes about a second, so it runs off to the side at most
/// every six hours; until it has answered the figures are simply unknown.
final class BatteryHealthSource: @unchecked Sendable {
    static let shared = BatteryHealthSource()

    struct Reading: Equatable, Sendable {
        /// 0...1, as the percentage System Settings shows.
        var maximumCapacity: Double?
        /// "Good", "Service Recommended"...
        var condition: String?
        /// True until the first lookup has finished (found something or not).
        var isPending = true
    }

    private let lock = NSLock()
    private var reading = Reading()
    private var fetchedAt: Date?
    private var isFetching = false
    private let refreshInterval: TimeInterval
    private let run: @Sendable () -> Data?
    private let log = Logger(subsystem: "com.pratik.allset", category: "battery")

    init(refreshInterval: TimeInterval = 6 * 3600, run: @escaping @Sendable () -> Data? = BatteryHealthSource.systemProfiler) {
        self.refreshInterval = refreshInterval
        self.run = run
    }

    /// The last reading. Starts a refresh in the background when it's out of date.
    func current(now: Date = .now) -> Reading {
        lock.lock()
        let stale = fetchedAt.map { now.timeIntervalSince($0) >= refreshInterval } ?? true
        let start = stale && !isFetching
        if start { isFetching = true }
        let result = reading
        lock.unlock()
        if start {
            DispatchQueue.global(qos: .utility).async { [self] in
                let parsed = run().flatMap(Self.parse)
                lock.lock()
                // A failed run is retried at the next interval, not every sample.
                fetchedAt = now
                if let parsed { reading = parsed }
                reading.isPending = false
                isFetching = false
                lock.unlock()
                if parsed == nil { log.error("Couldn't read the battery's reported health") }
            }
        }
        return result
    }

    /// `system_profiler SPPowerDataType -json` output to a reading.
    static func parse(_ data: Data) -> Reading? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["SPPowerDataType"] as? [[String: Any]] else { return nil }
        for item in items {
            guard let health = item["sppower_battery_health_info"] as? [String: Any] else { continue }
            var reading = Reading()
            if let text = health["sppower_battery_health_maximum_capacity"] as? String {
                let digits = text.filter { $0.isNumber || $0 == "." }
                if let percent = Double(digits), (1...100).contains(percent) { reading.maximumCapacity = percent / 100 }
            }
            if let condition = health["sppower_battery_health"] as? String, !condition.isEmpty {
                reading.condition = condition
            }
            return reading.maximumCapacity != nil || reading.condition != nil ? reading : nil
        }
        return nil
    }

    private static func systemProfiler() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPPowerDataType", "-json"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }
}
