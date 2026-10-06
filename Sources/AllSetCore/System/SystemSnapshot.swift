import Foundation

public enum CoreKind: Sendable {
    case efficiency
    case performance
    case unknown
}

public struct CPUUsage: Equatable, Sendable {
    /// Busy fraction across all cores, 0...1.
    public var total: Double = 0
    public var user: Double = 0
    public var system: Double = 0
    public var perCore: [Double] = []
    /// Parallel to `perCore`.
    public var coreKinds: [CoreKind] = []

    public init() {}
}

public struct GPUUsage: Equatable, Sendable {
    public var utilization: Double
    public var memoryInUse: UInt64?
}

public enum MemoryPressure: Sendable {
    case normal
    case warning
    case critical

    public var title: String {
        switch self {
        case .normal: "Normal"
        case .warning: "Elevated"
        case .critical: "Critical"
        }
    }
}

public struct MemoryUsage: Equatable, Sendable {
    public var total: UInt64 = 0
    /// What Activity Monitor calls Memory Used: app + wired + compressed.
    public var used: UInt64 = 0
    public var app: UInt64 = 0
    public var wired: UInt64 = 0
    public var compressed: UInt64 = 0
    public var cached: UInt64 = 0
    public var swapUsed: UInt64 = 0
    public var pressure: MemoryPressure = .normal

    public init() {}

    public var usedFraction: Double {
        total > 0 ? Double(used) / Double(total) : 0
    }
}

public struct NetworkRates: Equatable, Sendable {
    public var downloadBytesPerSecond: Double = 0
    public var uploadBytesPerSecond: Double = 0

    public init(downloadBytesPerSecond: Double = 0, uploadBytesPerSecond: Double = 0) {
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
    }
}

public struct DiskUsage: Equatable, Sendable {
    public var total: UInt64 = 0
    public var available: UInt64 = 0
    public var readBytesPerSecond: Double = 0
    public var writeBytesPerSecond: Double = 0

    public init() {}

    public var usedFraction: Double {
        total > 0 ? Double(total - min(available, total)) / Double(total) : 0
    }
}

public struct BatteryInfo: Equatable, Sendable {
    public var percent: Int
    public var isCharging: Bool
    public var isPluggedIn: Bool
    public var isFullyCharged: Bool
    /// Minutes until empty on battery, or until full while charging.
    public var minutesRemaining: Int?
    public var cycleCount: Int?
    /// mAh.
    public var designCapacity: Int?
    /// mAh.
    public var fullChargeCapacity: Int?
    /// "Good", "Fair", "Poor"... as macOS reports it.
    public var condition: String?
    public var temperatureCelsius: Double?
    public var voltage: Double?
    /// Amps; negative while discharging.
    public var amperage: Double?
    /// Whole-system draw, as measured by the power controller.
    public var systemPowerWatts: Double?
    public var adapterWatts: Int?
    public var isLowPowerMode: Bool

    public init(percent: Int, isCharging: Bool, isPluggedIn: Bool, isFullyCharged: Bool = false,
                minutesRemaining: Int? = nil, isLowPowerMode: Bool = false) {
        self.percent = percent
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.isFullyCharged = isFullyCharged
        self.minutesRemaining = minutesRemaining
        self.isLowPowerMode = isLowPowerMode
    }

    /// Maximum capacity as macOS itself reports it (0...1), when it can be read.
    public var reportedMaximumCapacity: Double?
    /// The lookup for `reportedMaximumCapacity` hasn't finished yet. Health stays unknown
    /// meanwhile, rather than showing a computed figure that then jumps.
    public var reportedHealthIsPending = false

    /// The maximum capacity System Settings shows, else (when it can't be read) the
    /// full-charge capacity as a fraction of design capacity. Nil when neither is known.
    public var health: Double? {
        if let reportedMaximumCapacity { return reportedMaximumCapacity }
        guard !reportedHealthIsPending else { return nil }
        return BatteryMath.health(fullChargeCapacity: fullChargeCapacity, designCapacity: designCapacity)
    }

    /// Power flowing into (positive) or out of (negative) the battery.
    public var batteryWatts: Double? {
        guard let voltage, let amperage else { return nil }
        return voltage * amperage
    }
}

public struct Temperatures: Equatable, Sendable {
    /// Average of the SoC die sensors.
    public var soc: Double?
    public var socHottest: Double?
    public var battery: Double?
    public var ssd: Double?

    public init(soc: Double? = nil, socHottest: Double? = nil, battery: Double? = nil, ssd: Double? = nil) {
        self.soc = soc
        self.socHottest = socHottest
        self.battery = battery
        self.ssd = ssd
    }
}

public enum ThermalLevel: Sendable {
    case nominal
    case fair
    case serious
    case critical

    public init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }

    public var title: String {
        switch self {
        case .nominal: "Cool"
        case .fair: "Warm"
        case .serious: "Hot"
        case .critical: "Throttling"
        }
    }
}

/// One app's share of the machine, with its helper processes folded in.
/// An app and the memory its processes use, as Activity Monitor's Memory column counts it.
public struct AppMemory: Identifiable, Equatable, Sendable {
    /// The app bundle path, or the executable path for processes outside an app.
    public var id: String
    public var name: String
    public var isApp: Bool
    public var bytes: UInt64

    public init(id: String, name: String, isApp: Bool, bytes: UInt64) {
        self.id = id
        self.name = name
        self.isApp = isApp
        self.bytes = bytes
    }
}

public struct AppUsage: Identifiable, Equatable, Sendable {
    /// The app bundle path, or the executable path for processes outside an app.
    public var id: String
    public var name: String
    public var isApp: Bool
    /// CPU power in watts. Zero on Intel Macs, which don't report energy.
    public var watts: Double
    /// CPU time as a percentage of one core, as in Activity Monitor (can pass 100).
    public var cpuPercent: Double

    public init(id: String, name: String, isApp: Bool, watts: Double, cpuPercent: Double) {
        self.id = id
        self.name = name
        self.isApp = isApp
        self.watts = watts
        self.cpuPercent = cpuPercent
    }
}

public struct SystemSnapshot: Equatable, Sendable {
    public var cpu = CPUUsage()
    public var gpu: GPUUsage?
    public var memory = MemoryUsage()
    public var network = NetworkRates()
    public var disk = DiskUsage()
    public var battery: BatteryInfo?
    public var temperatures = Temperatures()
    public var thermal: ThermalLevel = .nominal
    /// The apps using the most energy, heaviest first.
    public var topApps: [AppUsage] = []
    /// The apps using the most memory, most first.
    public var memoryApps: [AppMemory] = []

    public init() {}
}

/// Keeps a ranked list of live numbers from reshuffling every second: an item
/// only moves above the one before it when it's clearly ahead.
public enum StableOrder {
    public static func arrange<Item, ID: Hashable>(_ items: [Item], previous: [ID], id: (Item) -> ID,
                                                  value: (Item) -> Double, margin: Double = 0.25) -> [Item] {
        let rank = Dictionary(previous.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        // Last time's order first, newcomers after, best first among themselves.
        var order = items.enumerated().sorted { a, b in
            let rankA = rank[id(a.element)] ?? Int.max, rankB = rank[id(b.element)] ?? Int.max
            return rankA != rankB ? rankA < rankB : a.offset < b.offset
        }.map(\.element)
        // Then let anything clearly ahead climb past what's above it.
        for index in order.indices.dropFirst() {
            var position = index
            while position > 0, value(order[position]) > value(order[position - 1]) * (1 + margin) + 1e-9 {
                order.swapAt(position, position - 1)
                position -= 1
            }
        }
        return order
    }
}
