import AllSetCore
import AppKit
import CoreAudio
import Observation

/// An app that has set up sound, with every process that plays for it
/// (browsers play from helper processes, for instance).
struct AudioApp: Identifiable, Equatable {
    /// The bundle ID.
    let id: String
    let name: String
    /// The app bundle, for its icon.
    let path: String
    /// Has a Dock icon. Background apps (login chimes, Siri) are only listed
    /// while they play.
    let isRegular: Bool
    var processes: [AudioObjectID]
    var isPlaying: Bool
}

/// Per-app volume: which apps are making sound, and routing the ones turned
/// up or down through All Set. Apps left at 100% are never touched.
@Observable @MainActor
final class MixerController {
    /// Every app with sound set up, by name.
    private(set) var apps: [AudioApp] = []
    private(set) var permission = AudioCapturePermission.Status.unknown
    /// Whether to route app audio: granted, or this macOS can't say (then
    /// macOS itself asks on first use).
    var canRoute: Bool { permission == .authorized || permission == .unverifiable }
    /// Apps whose sound couldn't be routed, and why.
    private(set) var failures: [String: String] = [:]

    let store: AppVolumeStore
    @ObservationIgnored private let output: VolumeMonitor
    @ObservationIgnored private let router = AppAudioRouter()
    @ObservationIgnored private var gains: [String: GainBox] = [:]
    @ObservationIgnored private var owners: [AudioObjectID: Owner] = [:]
    @ObservationIgnored private var processListListener: AudioPropertyListener?
    @ObservationIgnored private var playingListeners: [AudioObjectID: AudioPropertyListener] = [:]
    @ObservationIgnored private var lastHeard: [String: Date] = [:]
    @ObservationIgnored private var lastApplied: (requests: [AppAudioRouter.Request], outputUID: String)?
    @ObservationIgnored private var isAskingPermission = false
    @ObservationIgnored private var isRefreshScheduled = false
    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    private struct Owner {
        let id: String
        let name: String
        let path: String
        let isRegular: Bool
    }

    init(store: AppVolumeStore, output: VolumeMonitor) {
        self.store = store
        self.output = output
    }

    func start() {
        guard processListListener == nil else { return }
        permission = AudioCapturePermission.status
        processListListener = AudioPropertyListener(AudioObjectID(kAudioObjectSystemObject),
                                                    kAudioHardwarePropertyProcessObjectList) { [weak self] in
            self?.setNeedsRefresh()
        }
        output.onOutputChange = { [weak self] in self?.route() }
        // Permission may have been given in System Settings meanwhile.
        activationObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                                                    object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPermission() }
        }
        refresh()
    }

    /// Hands every app its sound back.
    func stop() {
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        activationObserver = nil
        router.removeAll()
        store.save()
    }

    // MARK: Volumes

    func volume(for id: String) -> AppVolume {
        store.volume(for: id)
    }

    func setLevel(_ level: Double, for id: String) {
        var volume = store.volume(for: id)
        volume.level = min(max(level, 0), 1)
        volume.isMuted = false
        update(volume, for: id)
    }

    func toggleMute(_ id: String) {
        var volume = store.volume(for: id)
        volume.isMuted.toggle()
        update(volume, for: id)
    }

    func reset(_ id: String) {
        update(AppVolume(), for: id)
    }

    func resetAll() {
        store.resetAll()
        for gain in gains.values {
            gain.gain = 1
        }
        route()
    }

    /// Apps that aren't set to 100%.
    var hasChanges: Bool {
        !store.volumes.isEmpty
    }

    /// The apps worth a row in the notch: making sound, set to something
    /// other than 100%, or (with a Dock icon) heard in the last ten minutes.
    var activeApps: [AudioApp] {
        let recently = Date.now.addingTimeInterval(-600)
        return apps.filter { app in
            app.isPlaying || !store.volume(for: app.id).isUnchanged
                || (app.isRegular && (lastHeard[app.id] ?? .distantPast) > recently)
        }
    }

    /// The apps on the Sound Mixer page: every app with a Dock icon that has
    /// set up sound, and background ones while they play or aren't at 100%.
    var listedApps: [AudioApp] {
        apps.filter { $0.isRegular || $0.isPlaying || !store.volume(for: $0.id).isUnchanged }
    }

    /// Changed volumes need permission that hasn't been given.
    var needsPermission: Bool {
        !canRoute && hasChanges
    }

    private func update(_ volume: AppVolume, for id: String) {
        store.set(volume, for: id)
        gains[id]?.gain = volume.gain
        if !volume.isUnchanged, !canRoute {
            askPermission()
        }
        route()
    }

    // MARK: Permission

    func checkPermission() {
        let status = AudioCapturePermission.status
        guard status != permission else { return }
        permission = status
        route()
    }

    /// The system prompt the first time; after a refusal, only System Settings can change it.
    func askPermission() {
        checkPermission()
        // A development build run outside its app bundle would ask on behalf
        // of the terminal it was started from.
        guard permission == .unknown, !isAskingPermission, Bundle.main.bundleIdentifier != nil else { return }
        isAskingPermission = true
        AudioCapturePermission.request { [weak self] _ in
            Task { @MainActor in
                self?.isAskingPermission = false
                self?.checkPermission()
            }
        }
    }

    func openPermissionSettings() {
        NSWorkspace.shared.open(AudioCapturePermission.settingsURL)
    }

    // MARK: Following the apps

    /// Changes arrive in bursts (a process starting announces three); one
    /// look at the processes covers them all.
    private func setNeedsRefresh() {
        guard !isRefreshScheduled else { return }
        isRefreshScheduled = true
        Task { @MainActor [weak self] in
            self?.isRefreshScheduled = false
            self?.refresh()
        }
    }

    private func refresh() {
        let own = ProcessInfo.processInfo.processIdentifier
        var found: [String: AudioApp] = [:]
        var alive = Set<AudioObjectID>()
        for process in AudioProcesses.all() where process.pid != own {
            alive.insert(process.objectID)
            guard let owner = owner(of: process) else { continue }
            found[owner.id, default: AudioApp(id: owner.id, name: owner.name, path: owner.path,
                                              isRegular: owner.isRegular, processes: [], isPlaying: false)]
                .processes.append(process.objectID)
            if process.isPlaying {
                found[owner.id]?.isPlaying = true
            }
        }

        // Hear about each process starting and stopping sound. That's
        // announced as "is running" and "devices", never as "is running
        // output" itself, so listen for any change.
        for id in alive where playingListeners[id] == nil {
            playingListeners[id] = AudioPropertyListener(id, kAudioObjectPropertySelectorWildcard,
                                                         scope: kAudioObjectPropertyScopeWildcard,
                                                         element: kAudioObjectPropertyElementWildcard) { [weak self] in
                self?.setNeedsRefresh()
            }
        }
        for id in playingListeners.keys where !alive.contains(id) {
            playingListeners.removeValue(forKey: id)?.invalidate()
        }
        owners = owners.filter { alive.contains($0.key) }

        for app in found.values where app.isPlaying {
            lastHeard[app.id] = .now
        }
        let sorted = found.values
            .map { app -> AudioApp in
                var app = app
                app.processes.sort()
                return app
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if sorted != apps {
            apps = sorted
        }
        route()
    }

    /// The app a process plays for: itself, or the app responsible for it.
    private func owner(of process: AudioProcess) -> Owner? {
        if let owner = owners[process.objectID] { return owner }
        let responsible = ProcessGrouping.responsiblePID(for: process.pid)
        var owner: Owner?
        for pid in [responsible, process.pid] {
            if let app = NSRunningApplication(processIdentifier: pid), let id = app.bundleIdentifier,
               let url = app.bundleURL, url.pathExtension == "app" {
                // Some names carry invisible direction marks ("\u{200E}WhatsApp").
                let name = String((app.localizedName ?? ProcessGrouping.displayName(forGroup: url.path))
                    .unicodeScalars.filter { $0.properties.generalCategory != .format })
                owner = Owner(id: id, name: name, path: url.path, isRegular: app.activationPolicy == .regular)
                break
            }
        }
        if owner == nil,
           let executable = ProcessGrouping.executablePath(of: responsible) ?? ProcessGrouping.executablePath(of: process.pid),
           let path = ProcessGrouping.appBundlePath(forExecutable: executable),
           let id = Bundle(path: path)?.bundleIdentifier {
            owner = Owner(id: id, name: ProcessGrouping.displayName(forGroup: path), path: path, isRegular: false)
        }
        // System services with no app, and All Set itself, get no slider.
        guard let owner, owner.id != Bundle.main.bundleIdentifier else { return nil }
        owners[process.objectID] = owner
        return owner
    }

    /// Hands the router the apps to play through All Set.
    private func route() {
        guard let outputUID = VolumeMonitor.uid(of: output.deviceID) else { return }
        var requests: [AppAudioRouter.Request] = []
        if canRoute {
            for app in apps where !app.processes.isEmpty {
                let volume = store.volume(for: app.id)
                guard !volume.isUnchanged else { continue }
                let gain = gains[app.id] ?? GainBox(volume.gain)
                gains[app.id] = gain
                requests.append(AppAudioRouter.Request(id: app.id, name: app.name, processes: app.processes,
                                                       isPlaying: app.isPlaying, gain: gain))
            }
        }
        if let lastApplied, lastApplied.requests == requests, lastApplied.outputUID == outputUID { return }
        lastApplied = (requests, outputUID)
        router.apply(requests, outputUID: outputUID) { [weak self] failures in
            guard let self, failures != self.failures else { return }
            self.failures = failures
        }
    }
}
