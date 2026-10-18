import AllSetCore
import AppKit

/// One part of All Set that starts and stops as a unit: it owns its stores
/// and services, and `AppServices` only holds the features and starts them in
/// order. The four pillars (island, widgets, themes, wallpaper) and the extras.
@MainActor
protocol AppFeature: AnyObject {
    func start()
    func stop()
}

/// The Dynamic Island's live sources: system readings, Now Playing, volume,
/// power, and the notes the Notes tab keeps.
@MainActor
final class IslandFeature: AppFeature {
    let monitor = SystemMonitor()
    let media = MediaController()
    let volume = VolumeMonitor()
    let power = PowerSourceMonitor()
    let notes = NotesStore()

    func start() {
        monitor.start()
        media.start()
        volume.start()
        power.start()
    }

    func stop() {
        notes.save()
        media.stop()
        monitor.stop()
    }
}

/// Desktop widgets and the services only widgets read.
@MainActor
final class WidgetsFeature: AppFeature {
    let store: WidgetStore
    let weather = WeatherService()
    let github = GitHubService()
    let status = StatusService()
    let calendar = CalendarService()
    let images = ImageLibrary()
    let search = PhotoSearch()
    /// Finishes focus-timer phases on time, whether or not a focus widget is showing.
    private(set) lazy var focusTimers = FocusTimerCoordinator(widgets: store) { breakEnded in
        NSSound(named: breakEnded ? "Glass" : "Hero")?.play()
    }

    init(fileURL: URL) {
        store = WidgetStore(fileURL: fileURL)
    }

    func start() {
        // Any timer due while the app was closed finishes now; then each on time.
        focusTimers.finishDuePhases()
        focusTimers.reschedule()
        observe({ [store] in store.widgets.map(\.options.focus.endsAt) }) { [weak self] _ in self?.focusTimers.reschedule() }
        Task { [images] in await images.trimDownloadedPhotos() }
        calendar.start()
    }

    func stop() {
        focusTimers.stop()
        store.saveNow()
    }
}

/// Whole-desktop themes: the library's previews, its use counts, the
/// person's own photos per set, and the record of desktop changes.
@MainActor
final class ThemesFeature: AppFeature {
    let stats = ThemeStats()
    /// The person's own photos for each theme set.
    let photos = ThemePhotos()
    /// Durable records of desktop changes: an unfinished preview, the previous desktop.
    let journal: DesktopJournal
    /// Wallpaper-aware accents for design themes.
    let manager = ThemeManager()
    private(set) lazy var previews: ThemePreviewCache = {
        hasPreviews = true
        return ThemePreviewCache(photos: photos)
    }()
    /// Whether the previews exist yet, so freeing memory doesn't create them.
    private(set) var hasPreviews = false
    private unowned let services: AppServices

    init(journalDirectory: URL, services: AppServices) {
        journal = DesktopJournal(directory: journalDirectory)
        self.services = services
    }

    func start() {
        manager.start(services: services)
    }

    func stop() {}
}

/// The live wallpaper's store, and the wallpaper library someone else serves.
@MainActor
final class WallpaperFeature: AppFeature {
    let store = WallpaperStore()

    /// The library server's API key (`AllSet library <key>` saves it). Read from
    /// the Keychain when a library request first needs it, never at launch, and
    /// again after the command says it changed.
    private var libraryKey: String?
    private var hasReadLibraryKey = false
    private var libraryChanges: NSObjectProtocol?
    private var libraryReload: Task<Void, Never>?
    private var publicLibraryUpdates: Task<Void, Never>?

    /// Where the library is, the key that opens it, and showing what the
    /// `library` command downloads as it lands.
    func start() {
        // A public library is built in (scripts/build-app.sh): its list and
        // files are open to anyone, so there is no key and nothing to set up.
        if let address = Bundle.main.object(forInfoDictionaryKey: "AllSetPublicLibraryURL") as? String,
           let server = URL(string: address), server.host != nil {
            startPublicLibrary(server)
            return
        }
        // A copy made for someone else has the library's address built in
        // (scripts/build-app.sh), so there is nothing for them to set up.
        if store.config.libraryServerURL == nil,
           let builtIn = Bundle.main.object(forInfoDictionaryKey: "AllSetLibraryServerURL") as? String {
            store.config.libraryServerURL = builtIn
        }
        store.libraryBearer = { [weak self] in
            guard let self else { return nil }
            if !hasReadLibraryKey {
                libraryKey = LibraryKey.read()
                hasReadLibraryKey = true
            }
            return libraryKey
        }
        libraryChanges = DistributedNotificationCenter.default().addObserver(
            forName: LibraryKey.changed, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.libraryChanged() }
        }
    }

    func stop() {}

    /// Keeps this Mac's list the public library's: now, then a few times a day.
    /// Pictures and wallpapers download when the pages ask for them
    /// (`WallpaperStore`). A Mac with a library of its own keeps it, and its
    /// wallpapers keep coming from wherever they did.
    private func startPublicLibrary(_ server: URL) {
        // Downloads come from here unless this Mac saved a server of its own;
        // the retired Tailscale address is replaced, whatever library this Mac keeps.
        let address = WallpaperConfig.libraryAddress(saved: store.config.libraryServerURL, publicLibrary: server)
        if store.config.libraryServerURL != address { store.config.libraryServerURL = address }
        let sync = LibrarySync(server: server, key: nil, directory: store.libraryDirectory)
        guard !sync.hasOwnLibrary else { return }
        // The library's key, if this Mac has one, belongs to another server:
        // nothing sent to this one carries it (the access token goes instead,
        // `LibraryAuthorization`).
        store.libraryBearer = nil
        store.config.libraryServerURL = server.absoluteString
        publicLibraryUpdates = Task { [weak self] in
            var retriedSoon = false
            while !Task.isCancelled {
                do {
                    if try await sync.update() != nil { self?.store.reloadLibrary() }
                    retriedSoon = false
                } catch LibrarySync.Failure.refused(401) where !retriedSoon {
                    // The token was turned down and is being renewed: once soon, not in six hours.
                    retriedSoon = true
                    try? await Task.sleep(for: .seconds(90))
                    continue
                } catch {}
                try? await Task.sleep(for: .seconds(6 * 60 * 60))
            }
        }
    }

    /// The command reports every wallpaper it downloads; the list is read again
    /// at most once a second however fast they come.
    private func libraryChanged() {
        hasReadLibraryKey = false
        guard libraryReload == nil else { return }
        libraryReload = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.libraryReload = nil
            self?.store.reloadLibrary()
        }
    }
}

// MARK: Extras, one feature each (see `Extra`)

/// Workspaces and the window moves they make. Window snapping's shortcuts and
/// drag-to-edge live in `WindowManager`, which the app delegate owns.
@MainActor
final class WorkspacesFeature: AppFeature {
    let store = WorkspaceStore()
    private(set) lazy var controller = WorkspaceController(services: services)
    private unowned let services: AppServices

    init(services: AppServices) { self.services = services }
    func start() {}
    func stop() {}
}

@MainActor
final class ClipboardFeature: AppFeature {
    let store = ClipboardStore()
    private(set) lazy var monitor = ClipboardMonitor(services: services)
    private unowned let services: AppServices

    init(services: AppServices) { self.services = services }

    /// The monitor is started by the app delegate once windows exist; it keeps
    /// no timer while history or the Clipboard extra is off.
    func start() {}

    func stop() {
        if store.settings.clearOnQuit { store.clear() }
        store.save()
    }
}

@MainActor
final class ShelfFeature: AppFeature {
    let store = ShelfStore()
    func start() {}
    func stop() {}
}

/// Per-app volume. Taps Core Audio only while the Sound Mixer extra is on.
@MainActor
final class MixerFeature: AppFeature {
    let volumes = AppVolumeStore()
    let controller: MixerController
    private let extras: ExtrasSettings

    init(output: VolumeMonitor, extras: ExtrasSettings) {
        controller = MixerController(store: volumes, output: output)
        self.extras = extras
    }

    func start() {
        if extras.isOn(.mixer) { controller.start() }
        observe({ [extras] in extras.isOn(.mixer) }) { [weak self] on in
            guard let self else { return }
            if on { controller.start() } else { controller.stop() }
        }
    }

    func stop() {
        if extras.isOn(.mixer) { controller.stop() }
    }
}

/// TapTap: the settings and the listener. Reads the sensor only while the
/// TapTap extra and knocks are both on.
@MainActor
final class KnocksFeature: AppFeature {
    let store: KnockStore
    private(set) lazy var controller = KnockController(services: services)
    private unowned let services: AppServices

    init(services: AppServices, enabledWithoutFile: Bool) {
        store = KnockStore(enabledWithoutFile: enabledWithoutFile)
        self.services = services
    }

    func start() { controller.start() }
    func stop() { controller.stop() }
}

/// The AI screenshot's global shortcut, and taking or giving back macOS's ⌘⇧5.
@MainActor
final class ScreenshotFeature: AppFeature {
    private(set) lazy var shortcut = ScreenshotShortcutController(services: services)
    private unowned let services: AppServices

    init(services: AppServices) { self.services = services }

    func start() {
        // New installs get ⌃⌥⌘5, which takes nothing from macOS; an install from
        // before keeps what it had when it never chose (no shortcut).
        if services.extras.isLegacyInstall, UserDefaults.standard.object(forKey: "screenshot.shortcut") == nil {
            services.settings.screenshotShortcut = .off
        }
        shortcut.start()
    }

    func stop() { shortcut.stop() }
}
