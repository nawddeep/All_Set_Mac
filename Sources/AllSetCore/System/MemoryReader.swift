import Darwin
import Foundation

/// Page counts from `vm_statistics64`, kept separate so the math is testable.
public struct VMPageCounts: Sendable {
    public var anonymous: UInt64
    public var purgeable: UInt64
    public var external: UInt64
    public var wired: UInt64
    public var compressed: UInt64

    public init(anonymous: UInt64, purgeable: UInt64, external: UInt64, wired: UInt64, compressed: UInt64) {
        self.anonymous = anonymous
        self.purgeable = purgeable
        self.external = external
        self.wired = wired
        self.compressed = compressed
    }
}

public enum MemoryMath {
    /// Matches Activity Monitor: App Memory is anonymous memory minus purgeable,
    /// Memory Used is app + wired + compressed, and cached files are file-backed
    /// pages plus purgeable ones.
    public static func usage(pages: VMPageCounts, pageSize: UInt64, total: UInt64) -> MemoryUsage {
        var usage = MemoryUsage()
        usage.total = total
        usage.app = (pages.anonymous - min(pages.purgeable, pages.anonymous)) * pageSize
        usage.wired = pages.wired * pageSize
        usage.compressed = pages.compressed * pageSize
        usage.cached = (pages.external + pages.purgeable) * pageSize
        usage.used = min(usage.app + usage.wired + usage.compressed, total)
        return usage
    }
}

final class MemoryReader {
    private let host = HostPort.shared
    private let total = ProcessInfo.processInfo.physicalMemory
    private let pageSize: UInt64

    init() {
        var size: vm_size_t = 0
        pageSize = host_page_size(HostPort.shared, &size) == KERN_SUCCESS ? UInt64(size) : UInt64(getpagesize())
    }

    func read() -> MemoryUsage {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            var usage = MemoryUsage()
            usage.total = total
            return usage
        }
        let pages = VMPageCounts(
            anonymous: UInt64(stats.internal_page_count),
            purgeable: UInt64(stats.purgeable_count),
            external: UInt64(stats.external_page_count),
            wired: UInt64(stats.wire_count),
            compressed: UInt64(stats.compressor_page_count)
        )
        var usage = MemoryMath.usage(pages: pages, pageSize: pageSize, total: total)
        usage.swapUsed = Self.swapUsed()
        usage.pressure = Self.pressure()
        return usage
    }

    private static func swapUsed() -> UInt64 {
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        return sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 ? swap.xsu_used : 0
    }

    private static func pressure() -> MemoryPressure {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else { return .normal }
        switch level {
        case 4: return .critical
        case 2: return .warning
        default: return .normal
        }
    }
}

extension MemoryUsage {
    /// Memory right now, read on the spot.
    public static func current() -> MemoryUsage {
        MemoryReader().read()
    }
}

/// The host port, fetched once: every `mach_host_self()` call adds a reference
/// to it that's never given back.
enum HostPort {
    static let shared = mach_host_self()
}
