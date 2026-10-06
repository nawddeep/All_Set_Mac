import Foundation
import Observation
import notify

public struct PowerState: Equatable, Sendable {
    public var percent: Int
    public var isPluggedIn: Bool
    public var isCharging: Bool

    public init(percent: Int, isPluggedIn: Bool, isCharging: Bool) {
        self.percent = percent
        self.isPluggedIn = isPluggedIn
        self.isCharging = isCharging
    }
}

public enum PowerEvent: Equatable, Sendable {
    case pluggedIn(percent: Int)
    case unplugged(percent: Int)
    case lowBattery(percent: Int)
}

/// Turns power source notifications into plug, unplug and low battery events.
@Observable @MainActor
public final class PowerSourceMonitor {
    public private(set) var state: PowerState?
    @ObservationIgnored public var onEvent: (@MainActor (PowerEvent) -> Void)?
    @ObservationIgnored private var token: Int32?

    nonisolated public static let lowBatteryThresholds = [20, 10, 5]

    public init() {}

    public func start() {
        guard token == nil else { return }
        state = BatteryReader.powerState()
        var token: Int32 = 0
        let status = notify_register_dispatch("com.apple.system.powersources", &token, .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        if status == NOTIFY_STATUS_OK { self.token = token }
    }

    private func update() {
        guard let new = BatteryReader.powerState() else { return }
        let old = state
        guard new != old else { return }
        state = new
        guard let old else { return }
        for event in Self.events(from: old, to: new) {
            onEvent?(event)
        }
    }

    nonisolated public static func events(from old: PowerState, to new: PowerState) -> [PowerEvent] {
        var events: [PowerEvent] = []
        if old.isPluggedIn != new.isPluggedIn {
            events.append(new.isPluggedIn ? .pluggedIn(percent: new.percent) : .unplugged(percent: new.percent))
        }
        if !new.isPluggedIn, lowBatteryThresholds.contains(where: { old.percent > $0 && new.percent <= $0 }) {
            events.append(.lowBattery(percent: new.percent))
        }
        return events
    }
}
