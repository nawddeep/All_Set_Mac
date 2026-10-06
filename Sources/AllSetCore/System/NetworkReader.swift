import Darwin
import Foundation

/// Network throughput summed over physical interfaces (en0 Wi-Fi, USB/Thunderbolt
/// Ethernet). VPN tunnels are skipped since their traffic also crosses en*.
final class NetworkReader {
    private struct Counters {
        var received: UInt32
        var sent: UInt32
    }

    private var previous: [String: Counters] = [:]
    private var previousTime: TimeInterval?

    func read() -> NetworkRates {
        let now = ProcessInfo.processInfo.systemUptime
        let current = Self.readCounters()
        defer {
            previous = current
            previousTime = now
        }
        guard let previousTime, now > previousTime else { return NetworkRates() }

        // if_data counters are 32-bit; wrapping subtraction survives one wrap
        // between samples, which would take 4 GB in a few seconds.
        var received: UInt64 = 0
        var sent: UInt64 = 0
        for (name, counters) in current {
            guard let old = previous[name] else { continue }
            received += UInt64(counters.received &- old.received)
            sent += UInt64(counters.sent &- old.sent)
        }
        let elapsed = now - previousTime
        return NetworkRates(downloadBytesPerSecond: Double(received) / elapsed,
                            uploadBytesPerSecond: Double(sent) / elapsed)
    }

    private static func readCounters() -> [String: Counters] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [:] }
        defer { freeifaddrs(head) }

        var result: [String: Counters] = [:]
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            let flags = Int32(entry.ifa_flags)
            guard let address = entry.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK),
                  let data = entry.ifa_data,
                  flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }
            let name = String(cString: entry.ifa_name)
            guard name.hasPrefix("en") else { continue }
            let stats = data.assumingMemoryBound(to: if_data.self).pointee
            result[name] = Counters(received: stats.ifi_ibytes, sent: stats.ifi_obytes)
        }
        return result
    }
}
