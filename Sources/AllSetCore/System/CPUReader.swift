import Darwin
import Foundation
import IOKit
import CPrivateAPIs

/// Raw scheduler ticks for one core. The kernel keeps these as 32-bit counters.
public struct CPUTicks: Equatable, Sendable {
    public var user: UInt32
    public var system: UInt32
    public var idle: UInt32
    public var nice: UInt32

    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

public enum CPUMath {
    /// Usage between two tick samples. Counters can wrap, so differences use
    /// wrapping subtraction.
    public static func usage(from old: [CPUTicks], to new: [CPUTicks]) -> CPUUsage {
        var usage = CPUUsage()
        guard old.count == new.count, !new.isEmpty else {
            usage.perCore = Array(repeating: 0, count: new.count)
            return usage
        }
        var totals = (user: 0.0, system: 0.0, all: 0.0)
        usage.perCore = zip(old, new).map { a, b in
            let user = Double(b.user &- a.user) + Double(b.nice &- a.nice)
            let system = Double(b.system &- a.system)
            let all = user + system + Double(b.idle &- a.idle)
            totals.user += user
            totals.system += system
            totals.all += all
            return all > 0 ? (user + system) / all : 0
        }
        if totals.all > 0 {
            usage.user = totals.user / totals.all
            usage.system = totals.system / totals.all
            usage.total = usage.user + usage.system
        }
        return usage
    }
}

final class CPUReader {
    private let host = HostPort.shared
    private var previous: [CPUTicks] = []
    private let kindsByCore = CPUReader.readCoreKinds()

    func read() -> CPUUsage {
        let current = readTicks()
        var usage = CPUMath.usage(from: previous, to: current)
        usage.coreKinds = current.indices.map { kindsByCore[$0] ?? .unknown }
        previous = current
        return usage
    }

    private func readTicks() -> [CPUTicks] {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount) == KERN_SUCCESS,
              let info else {
            return []
        }
        defer {
            vm_deallocate(allset_mach_task_self(), vm_address_t(bitPattern: info),
                          vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }
        return (0..<Int(cpuCount)).map { core in
            let base = core * Int(CPU_STATE_MAX)
            return CPUTicks(
                user: UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                idle: UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                nice: UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
            )
        }
    }

    /// Apple Silicon lists each core under IODeviceTree:/cpus with its logical id
    /// and cluster type ("E" or "P"). Empty on Intel, where every core is the same.
    private static func readCoreKinds() -> [Int: CoreKind] {
        let cpus = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/cpus")
        guard cpus != 0 else { return [:] }
        defer { IOObjectRelease(cpus) }
        var iterator: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(cpus, kIODeviceTreePlane, &iterator) == KERN_SUCCESS else { return [:] }
        defer { IOObjectRelease(iterator) }

        var kinds: [Int: CoreKind] = [:]
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            let rawID = IORegistry.property(entry, "logical-cpu-id")
            let id: Int? = if let number = rawID as? NSNumber {
                number.intValue
            } else if let data = rawID as? Data, data.count >= 4 {
                Int(data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian)
            } else {
                nil
            }
            guard let id, let type = IORegistry.property(entry, "cluster-type") as? Data else { continue }
            switch type.first {
            case UInt8(ascii: "E"): kinds[id] = .efficiency
            case UInt8(ascii: "P"): kinds[id] = .performance
            default: kinds[id] = .unknown
            }
        }
        return kinds
    }
}
