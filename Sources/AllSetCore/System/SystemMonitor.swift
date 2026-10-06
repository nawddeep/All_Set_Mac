import Foundation
import Observation

/// Samples system stats on a timer. It samples quickly while something is on
/// screen (the expanded notch or the menu bar panel) and slowly otherwise, just
/// enough to keep the sparkline history and menu bar readout current. The
/// reading itself happens off the main thread in `SystemSampler`.
@Observable @MainActor
public final class SystemMonitor {
    public private(set) var snapshot = SystemSnapshot()
    public private(set) var cpuHistory = RollingSeries(capacity: historyLength)
    public private(set) var gpuHistory = RollingSeries(capacity: historyLength)
    public private(set) var memoryHistory = RollingSeries(capacity: historyLength)
    public private(set) var downloadHistory = RollingSeries(capacity: historyLength)
    public private(set) var uploadHistory = RollingSeries(capacity: historyLength)

    public static let historyLength = 60

    /// The same readings, refreshed every few seconds, for previews.
    @ObservationIgnored public let calm = CalmReadings()

    /// Seconds between samples while a viewer is visible.
    public var activeInterval: Double = 1 {
        didSet { if oldValue != activeInterval, isRunning { restartLoop() } }
    }
    @ObservationIgnored public var idleInterval: Double = 3 {
        didSet { if oldValue != idleInterval, isRunning, viewers.isEmpty { restartLoop() } }
    }

    @ObservationIgnored private let sampler = SystemSampler()
    /// Visible viewers and the interval each wants; 0 means `activeInterval`.
    @ObservationIgnored private var viewers: [String: Double] = [:]
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var isSampling = false
    @ObservationIgnored private var loop: Task<Void, Never>?

    public init() {}

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        requestSample(detailed: true)
        restartLoop()
    }

    public func stop() {
        isRunning = false
        loop?.cancel()
        loop = nil
    }

    /// Registers whether a UI that shows live stats is visible. Glanceable
    /// surfaces like desktop widgets can ask for a slower `interval`.
    public func setViewer(_ id: String, visible: Bool, interval: Double? = nil) {
        let wasIdle = viewers.isEmpty
        let oldInterval = currentInterval
        viewers[id] = visible ? (interval ?? 0) : nil
        guard isRunning else { return }
        if wasIdle, !viewers.isEmpty {
            requestSample(detailed: true)
            // Rates need two readings close together: one a second later.
            Task { try? await Task.sleep(for: .seconds(1)); await sample(detailed: true) }
        }
        if currentInterval != oldInterval { restartLoop() }
    }

    #if DEBUG
    /// Who is asking for live readings, and how often (for probes).
    public var debugViewers: [String: Double] { viewers }
    #endif

    private var isIdle: Bool { viewers.isEmpty }

    private var currentInterval: Double {
        viewers.values.map { $0 > 0 ? $0 : activeInterval }.min() ?? idleInterval
    }

    private func restartLoop() {
        loop?.cancel()
        let interval = currentInterval
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval), tolerance: .seconds(interval * 0.1))
                guard !Task.isCancelled, let self else { return }
                await self.tick()
            }
        }
    }

    private func tick() async {
        // With nothing on screen, only the cheap readings, for the sparkline
        // history and the menu bar's CPU figure. Temperatures, battery detail,
        // disk and per-app usage (a walk over every process) wait until a
        // viewer appears, which samples them at once (`setViewer`).
        await sample(detailed: !isIdle)
    }

    /// Samples right away without waiting, so a panel that just opened fills in.
    private func requestSample(detailed: Bool) {
        Task { await sample(detailed: detailed) }
    }

    private func sample(detailed: Bool) async {
        // An overlapping request would only duplicate the work in flight.
        guard !isSampling else { return }
        isSampling = true
        defer { isSampling = false }

        var next = await sampler.sample(detailed: detailed, previous: snapshot)
        guard isRunning else { return }
        if detailed {
            // Lists that reshuffle every second are hard to read (and costly to animate).
            next.topApps = StableOrder.arrange(next.topApps, previous: snapshot.topApps.map(\.id), id: \.id,
                                               value: { $0.watts > 0 ? $0.watts : $0.cpuPercent })
            next.memoryApps = StableOrder.arrange(next.memoryApps, previous: snapshot.memoryApps.map(\.id), id: \.id,
                                                  value: { Double($0.bytes) }, margin: 0.1)
        }
        snapshot = next
        cpuHistory.append(next.cpu.total)
        gpuHistory.append(next.gpu?.utilization ?? 0)
        memoryHistory.append(next.memory.usedFraction)
        downloadHistory.append(next.network.downloadBytesPerSecond)
        uploadHistory.append(next.network.uploadBytesPerSecond)
        calm.copy(from: self)
    }
}

/// What a stats view reads: the live monitor, or its calm mirror.
@MainActor
public protocol SystemReadings: AnyObject {
    var snapshot: SystemSnapshot { get }
    var cpuHistory: RollingSeries { get }
    var gpuHistory: RollingSeries { get }
    var memoryHistory: RollingSeries { get }
    var downloadHistory: RollingSeries { get }
    var uploadHistory: RollingSeries { get }
}

extension SystemMonitor: SystemReadings {}

/// The monitor's readings, copied at most every few seconds: for previews
/// nobody is looking at closely (a gallery of twenty stats cards), which then
/// redraw every five seconds instead of every second.
@Observable @MainActor
public final class CalmReadings: SystemReadings {
    public private(set) var snapshot = SystemSnapshot()
    public private(set) var cpuHistory = RollingSeries(capacity: SystemMonitor.historyLength)
    public private(set) var gpuHistory = RollingSeries(capacity: SystemMonitor.historyLength)
    public private(set) var memoryHistory = RollingSeries(capacity: SystemMonitor.historyLength)
    public private(set) var downloadHistory = RollingSeries(capacity: SystemMonitor.historyLength)
    public private(set) var uploadHistory = RollingSeries(capacity: SystemMonitor.historyLength)

    public static let interval: TimeInterval = 5
    @ObservationIgnored private var copied = Date.distantPast

    public init() {}

    func copy(from monitor: SystemMonitor, now: Date = .now) {
        guard now.timeIntervalSince(copied) >= Self.interval else { return }
        copied = now
        snapshot = monitor.snapshot
        cpuHistory = monitor.cpuHistory
        gpuHistory = monitor.gpuHistory
        memoryHistory = monitor.memoryHistory
        downloadHistory = monitor.downloadHistory
        uploadHistory = monitor.uploadHistory
    }
}
