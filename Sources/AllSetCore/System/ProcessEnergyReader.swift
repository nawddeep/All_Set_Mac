import Darwin
import Foundation

public enum ProcessGrouping {
    /// The outermost app bundle in an executable path, so helpers nested inside
    /// an app (renderers, XPC services) count toward it. Nil outside any app.
    public static func appBundlePath(forExecutable path: String) -> String? {
        if let range = path.range(of: ".app/") {
            return String(path[..<range.lowerBound]) + ".app"
        }
        return path.hasSuffix(".app") ? path : nil
    }

    public static func displayName(forGroup path: String) -> String {
        let name = (path as NSString).lastPathComponent
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    private typealias ResponsiblePIDFunction = @convention(c) (pid_t) -> pid_t
    /// Private libsystem function Activity Monitor relies on; maps a helper
    /// (say, a Safari web page) to the app that launched it.
    private static let responsibleFunction: ResponsiblePIDFunction? =
        dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid")
            .map { unsafeBitCast($0, to: ResponsiblePIDFunction.self) }

    /// The process macOS holds responsible for `pid`: the app, for its
    /// helpers; the process itself otherwise.
    public static func responsiblePID(for pid: pid_t) -> pid_t {
        guard let owner = responsibleFunction?(pid), owner > 0 else { return pid }
        return owner
    }

    public static func executablePath(of pid: pid_t) -> String? {
        var buffer = [UInt8](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)), as: UTF8.self)
    }
}

/// Per-app CPU time and energy, grouped the way Activity Monitor's Energy tab
/// groups them: every process counts toward the app responsible for it.
///
/// Only processes owned by the current user are readable without root, which
/// covers the apps people care about but leaves out system daemons.
final class ProcessEnergyReader {
    private struct Tracked {
        var startTime: UInt64
        /// Mach absolute time units.
        var cpuTime: UInt64
        /// Nanojoules. Zero on Intel, which doesn't report it.
        var energy: UInt64
        var groupID: String
    }

    private var tracked: [pid_t: Tracked] = [:]
    private var smoothed: [String: (watts: Double, cpu: Double)] = [:]
    private var previousTime: TimeInterval?
    private var lastEnergy: [AppUsage] = []
    /// Readings further apart than this (the window was closed meanwhile) say nothing
    /// about now: they average a long stretch. They only reset the baseline.
    private static let longestGap: TimeInterval = 8
    private let nanosecondsPerTick: Double

    init() {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        nanosecondsPerTick = Double(timebase.numer) / Double(timebase.denom)
    }

    /// The heaviest apps since the previous call, heaviest first (empty on
    /// the first call, which only establishes a baseline), and the apps using
    /// the most memory right now.
    func read(limit: Int) -> (energy: [AppUsage], memory: [AppMemory]) {
        let now = ProcessInfo.processInfo.systemUptime
        var current: [pid_t: Tracked] = [:]
        var totals: [String: (energy: Double, cpuNanoseconds: Double)] = [:]
        var memory: [String: UInt64] = [:]

        for pid in Self.allPIDs() {
            guard let usage = Self.resourceUsage(of: pid) else { continue }
            let old = tracked[pid].flatMap { $0.startTime == usage.ri_proc_start_abstime ? $0 : nil }
            guard let groupID = old?.groupID ?? groupID(for: pid) else { continue }

            let entry = Tracked(startTime: usage.ri_proc_start_abstime,
                                cpuTime: usage.ri_user_time + usage.ri_system_time,
                                energy: usage.ri_energy_nj,
                                groupID: groupID)
            current[pid] = entry
            memory[groupID, default: 0] += usage.ri_phys_footprint
            guard let old else { continue }
            let energy = entry.energy >= old.energy ? Double(entry.energy - old.energy) : 0
            let cpu = entry.cpuTime >= old.cpuTime ? Double(entry.cpuTime - old.cpuTime) * nanosecondsPerTick : 0
            totals[groupID, default: (0, 0)].energy += energy
            totals[groupID, default: (0, 0)].cpuNanoseconds += cpu
        }

        defer {
            tracked = current
            previousTime = now
        }
        let memoryApps = memory
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { AppMemory(id: $0.key, name: ProcessGrouping.displayName(forGroup: $0.key),
                             isApp: $0.key.hasSuffix(".app"), bytes: $0.value) }
        guard let previousTime, now > previousTime, now - previousTime <= Self.longestGap else {
            smoothed = [:]
            return (lastEnergy, memoryApps)
        }
        let elapsed = now - previousTime

        // Blend with the previous reading so the ranking doesn't jump around
        // with every one-second burst.
        var next: [String: (watts: Double, cpu: Double)] = [:]
        for id in Set(totals.keys).union(smoothed.keys) {
            let raw = totals[id].map { (watts: $0.energy / 1e9 / elapsed, cpu: $0.cpuNanoseconds / 1e9 / elapsed * 100) }
                ?? (watts: 0, cpu: 0)
            let value = smoothed[id].map { (watts: ($0.watts + raw.watts) / 2, cpu: ($0.cpu + raw.cpu) / 2) } ?? raw
            if value.watts > 0.0005 || value.cpu > 0.05 {
                next[id] = value
            }
        }
        smoothed = next

        let hasEnergy = next.values.contains { $0.watts > 0 }
        let energyApps = next
            .map { id, value in
                AppUsage(id: id, name: ProcessGrouping.displayName(forGroup: id),
                         isApp: id.hasSuffix(".app"), watts: value.watts, cpuPercent: value.cpu)
            }
            .sorted { hasEnergy ? $0.watts > $1.watts : $0.cpuPercent > $1.cpuPercent }
            .prefix(limit)
            .map { $0 }
        lastEnergy = energyApps
        return (energyApps, memoryApps)
    }

    private func groupID(for pid: pid_t) -> String? {
        let owner = ProcessGrouping.responsiblePID(for: pid)
        guard let path = ProcessGrouping.executablePath(of: owner) ?? ProcessGrouping.executablePath(of: pid) else {
            return nil
        }
        return ProcessGrouping.appBundlePath(forExecutable: path) ?? path
    }

    private static func allPIDs() -> [pid_t] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 64)
        let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        return pids.prefix(Int(max(count, 0))).filter { $0 > 0 }
    }

    private static func resourceUsage(of pid: pid_t) -> rusage_info_v6? {
        var info = rusage_info_v6()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V6, $0)
            }
        }
        return result == 0 ? info : nil
    }
}
