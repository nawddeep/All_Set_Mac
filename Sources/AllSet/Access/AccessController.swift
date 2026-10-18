import AllSetCore
import AppKit
import Network
import Observation
import OSLog

/// The access key gate around the whole app. The app delegate hands `begin`
/// everything it would start; that runs only once the library server has
/// accepted a key (`AccessGate`). Until then the key window is all there is:
/// no main window, menu bar item, wallpaper, widgets, island or downloads.
///
/// `ALLSET_ACCESS_GATE=0` (in the environment, or given to build-app.sh,
/// which writes `AllSetAccessGate` into Info.plist) skips it while the
/// server's side isn't live. A debug build without a built-in library has
/// nothing to check a key against and skips it too.
@Observable @MainActor
final class AccessController {
    static let shared = AccessController()

    /// Nil when the gate is off, or there's no library to ask.
    private(set) var gate: AccessGate?
    /// False when the gate is skipped (so the debug harnesses, which never
    /// call `begin`, open windows as before).
    private(set) var isGated = !AccessController.isSwitchedOff
    /// Shown on the key screen of a copy that can't check a key at all.
    private(set) var buildProblem: String?

    /// Everything may run: the gate is off, or open.
    var isUnlocked: Bool { !isGated || gate?.state.isUnlocked == true }

    @ObservationIgnored private var startApp: (@MainActor () -> Void)?
    @ObservationIgnored private var hasStartedApp = false
    @ObservationIgnored private var isRestarting = false
    @ObservationIgnored private var network: NWPathMonitor?
    @ObservationIgnored private var wasOnline: Bool?
    @ObservationIgnored private var offlineRetries: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "access")

    /// The built-in public library (scripts/build-app.sh), which also checks keys.
    static var publicLibrary: URL? {
        guard let address = Bundle.main.object(forInfoDictionaryKey: "AllSetPublicLibraryURL") as? String,
              let url = URL(string: address), url.host != nil else { return nil }
        return url
    }

    static var isSwitchedOff: Bool {
        if ProcessInfo.processInfo.environment["ALLSET_ACCESS_GATE"] == "0" { return true }
        if (Bundle.main.object(forInfoDictionaryKey: "AllSetAccessGate") as? Bool) == false { return true }
        #if DEBUG
        if publicLibrary == nil { return true }
        #endif
        return false
    }

    /// Runs `start` now if the gate is off, else once a key is accepted.
    func begin(then start: @escaping @MainActor () -> Void) {
        startApp = start
        guard !Self.isSwitchedOff else {
            log.notice("Access gate skipped")
            isGated = false
            unlock()
            return
        }
        guard let server = Self.publicLibrary, let host = server.host else {
            buildProblem = "This copy of All Set was built without its library\u{2019}s address, so it can\u{2019}t check a key."
            AccessKeyWindow.shared.show(controller: self)
            return
        }
        let authorization = LibraryAuthorization.shared
        authorization.host = host
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        let gate = AccessGate(server: server, transport: URLSession(configuration: configuration),
                              vault: KeychainAccessVault(), authorization: authorization)
        self.gate = gate
        authorization.onRejected { Task { @MainActor in await AccessController.shared.gate?.libraryRejectedToken() } }
        AllSet.observe({ gate.state }) { [weak self] state in self?.changed(to: state) }
        watchNetwork()
        Task {
            await gate.start()
            changed(to: gate.state)
        }
        // A key entered before is checked out of sight: the window shows only
        // if it fails. A first launch shows it now.
        if !gate.hasSavedKey { AccessKeyWindow.shared.show(controller: self) }
    }

    /// The key screen's Continue.
    func submit(_ typed: String) {
        guard let gate else { return }
        Task { await gate.activate(typed: typed) }
    }

    /// Settings' "Remove access key": forgets it, and the app starts over at the key screen.
    func removeKey() {
        gate?.remove()
    }

    private func changed(to state: AccessState) {
        if case .offlineUnlocked = state { retryWhileOffline() } else { offlineRetries?.cancel(); offlineRetries = nil }
        switch state {
        case .unlocked, .offlineUnlocked:
            unlock()
        case .locked:
            // Everything is running: starting over is the one clean way back to only the key screen.
            if hasStartedApp {
                guard !isRestarting else { return }
                isRestarting = true
                log.notice("Access locked while running; restarting at the key screen")
                AppData.restart()
            } else {
                AccessKeyWindow.shared.show(controller: self)
            }
        case .checking:
            break
        }
    }

    private func unlock() {
        guard !hasStartedApp else { return }
        hasStartedApp = true
        AccessKeyWindow.shared.close()
        startApp?()
        startApp = nil
    }

    /// Offline mode, or a lock that was only for want of an answer, asks again
    /// when the Mac is back online.
    private func watchNetwork() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            let online = path.status == .satisfied
            Task { @MainActor in await AccessController.shared.networkChanged(online: online) }
        }
        monitor.start(queue: DispatchQueue(label: "com.pratik.allset.access.network"))
        network = monitor
    }

    /// The network can be up with the server down: offline mode asks again every few minutes too.
    private func retryWhileOffline() {
        guard offlineRetries == nil else { return }
        offlineRetries = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5 * 60))
                guard !Task.isCancelled else { return }
                await self?.gate?.networkReturned()
            }
        }
    }

    private func networkChanged(online: Bool) async {
        let cameBack = online && wasOnline == false
        wasOnline = online
        if cameBack { await gate?.networkReturned() }
    }
}
