import Foundation
import IOKit

/// Startup volume capacity plus read/write throughput across block devices.
final class DiskReader {
    private var previous: (read: UInt64, written: UInt64, time: TimeInterval)?
    private var capacity: (total: UInt64, available: UInt64) = (0, 0)
    private var lastRates: (read: Double, write: Double) = (0, 0)
    private var capacityReadAt: TimeInterval = -.infinity

    /// Free space barely moves and computing purgeable space isn't free, so
    /// capacity is refreshed less often than throughput.
    private static let capacityRefreshInterval: TimeInterval = 30

    func read() -> DiskUsage {
        let now = ProcessInfo.processInfo.systemUptime
        if now - capacityReadAt >= Self.capacityRefreshInterval {
            capacity = Self.readCapacity()
            capacityReadAt = now
        }

        var usage = DiskUsage()
        usage.total = capacity.total
        usage.available = capacity.available

        let bytes = Self.readTotalBytes()
        if let previous, now > previous.time {
            let elapsed = now - previous.time
            // Counters reset when a disk is ejected; treat that as no activity. After a
            // long gap (nothing was watching) the average says nothing about now: keep the last.
            if elapsed <= 8 {
                lastRates = (bytes.read >= previous.read ? Double(bytes.read - previous.read) / elapsed : 0,
                             bytes.written >= previous.written ? Double(bytes.written - previous.written) / elapsed : 0)
            }
        }
        usage.readBytesPerSecond = lastRates.read
        usage.writeBytesPerSecond = lastRates.write
        previous = (bytes.read, bytes.written, now)
        return usage
    }

    private static func readCapacity() -> (total: UInt64, available: UInt64) {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys) else { return (0, 0) }
        return (UInt64(values.volumeTotalCapacity ?? 0),
                UInt64(max(values.volumeAvailableCapacityForImportantUsage ?? 0, 0)))
    }

    private static func readTotalBytes() -> (read: UInt64, written: UInt64) {
        var read: UInt64 = 0
        var written: UInt64 = 0
        IORegistry.forEachService(matching: "IOBlockStorageDriver") { service in
            guard let stats = IORegistry.property(service, "Statistics") as? [String: Any] else { return }
            read += (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            written += (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
        }
        return (read, written)
    }
}
