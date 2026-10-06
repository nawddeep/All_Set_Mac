import Foundation
import IOKit

/// Reads GPU utilization from the accelerator's PerformanceStatistics, which
/// Apple Silicon and most Intel/AMD drivers publish in the IORegistry.
final class GPUReader {
    func read() -> GPUUsage? {
        var usage: GPUUsage?
        IORegistry.forEachService(matching: "IOAccelerator") { service in
            guard usage == nil,
                  let stats = IORegistry.property(service, "PerformanceStatistics") as? [String: Any],
                  let percent = IORegistry.int(stats["Device Utilization %"]) else { return }
            usage = GPUUsage(
                utilization: Double(min(max(percent, 0), 100)) / 100,
                memoryInUse: (stats["In use system memory"] as? NSNumber)?.uint64Value
            )
        }
        return usage
    }
}
