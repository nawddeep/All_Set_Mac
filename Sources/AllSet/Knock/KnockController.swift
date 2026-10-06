import AllSetCore
import AppKit
import Observation

/// TapTap in All Set: knock on the Mac's case once, twice or three times to
/// run an action. Keeps the listener in step with the settings and carries
/// out each knock.
@Observable @MainActor
final class KnockController {
    struct Outcome: Equatable {
        let count: KnockCount
        let action: KnockAction?
        let date: Date
        let failure: String?
    }

    let listener = KnockListener()
    /// The last knock and what came of it.
    private(set) var lastOutcome: Outcome?

    @ObservationIgnored private unowned let services: AppServices

    init(services: AppServices) {
        self.services = services
    }

    var store: KnockStore { services.knockStore }

    func start() {
        listener.onKnock = { [weak self] event in self?.handle(event) }
        apply(store.settings)
        observe({ [store] in store.settings }) { [weak self] settings in self?.apply(settings) }
        listener.isOnBattery = services.power.state?.isPluggedIn == false
        observe({ [services] in services.power.state?.isPluggedIn }) { [weak self] pluggedIn in
            self?.listener.isOnBattery = pluggedIn == false
        }
    }

    func stop() {
        listener.shutDown()
        store.save()
    }

    /// The settings page is showing its live meter, which needs the sensor on
    /// even with nothing assigned.
    var isTuning = false {
        didSet { if isTuning != oldValue { apply(store.settings) } }
    }

    /// Runs an action as if knocked, from the settings page.
    func test(_ action: KnockAction, count: KnockCount) async {
        await perform(action, count: count)
    }

    private func apply(_ settings: KnockSettings) {
        listener.configuration = settings.detectorConfiguration
        listener.restsInLowPowerMode = settings.restInLowPowerMode
        // The settings page's meter works either way.
        listener.restsOnBattery = settings.restOnBattery && !isTuning
        // Nothing to run means nothing to listen for: the sensor stays off,
        // unless the settings page is open to try knocking.
        listener.isEnabled = settings.isEnabled && (!settings.assignedCounts.isEmpty || isTuning)
    }

    private func handle(_ event: KnockEvent) {
        let settings = store.settings
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard let action = settings.action(for: event.count, frontmost: frontmost) else { return }
        if settings.playSound {
            NSSound(named: "Tink")?.play()
        }
        Task { await perform(action, count: event.count) }
    }

    private func perform(_ action: KnockAction, count: KnockCount) async {
        // Shown first, so the knock feels answered even if the action takes a moment.
        showInIsland(action, count: count, failed: false)
        let failure = await KnockActionRunner.run(action, services: services)
        lastOutcome = Outcome(count: count, action: action, date: .now, failure: failure)
        if failure != nil {
            showInIsland(action, count: count, failed: true)
        }
    }

    private func showInIsland(_ action: KnockAction, count: KnockCount, failed: Bool) {
        guard store.settings.showInIsland else { return }
        // Opening the island is its own answer.
        if !failed, action == .toggleIsland || action.isIslandTab { return }
        services.notch?.showKnock(count: count, symbol: action.symbol, failed: failed)
    }
}

private extension KnockAction {
    var isIslandTab: Bool {
        if case .openIsland = self { true } else { false }
    }
}
