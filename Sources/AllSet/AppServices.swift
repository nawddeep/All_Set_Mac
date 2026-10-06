import AllSetCore
import AppKit
import Observation

/// UI state shared between windows: which page of the main window is showing,
/// and whether the desktop widgets are being arranged.
@Observable @MainActor
final class UIState {
    var page: AppPage? = .island
    var studioWidgetSelection = "digitalClock"
    var studioWidgetFilter = StudioWidgetFilter.all
    var isArrangingWidgets = false
    /// ⌘K is open.
    var isSearching = false
    /// The confirmation floating at the top of the window, if any.
    var toast: Toast?
    /// The full-bleed hero under the navigation right now, if one is: the
    /// navigation drops its fade so the picture runs to the top.
    var mediaUnderNavigation: UUID?
    /// False while the live wallpaper is paused to save energy.
    var wallpaperPlaying = true
    /// Window actions (by raw value) and workspaces (by id) whose shortcut
    /// another app already owns.
    var shortcutConflicts = Set<String>()
    var applyingWorkspace: UUID?
    /// What the last switch to each workspace did, shown on its card.
    var workspaceReports: [UUID: WorkspaceRestoreReport] = [:]
    /// The last whole-desktop change (a theme, or widgets cleared for a
    /// wallpaper) and the desktop from before it, for Undo.
    var desktopUndo: DesktopUndo?
    /// A theme set being tried on the desktop, with what to go back to.
    var themePreview: ThemePreview?
    /// The widget removed last, and where it was, for Undo.
    var removedWidget: RemovedWidget?
    /// A gallery widget being dragged toward the desktop.
    var widgetDrop: WidgetInstance?
    /// The Widget Gallery shows every theme's widgets instead of the catalog.
    var galleryFromThemes = false
    /// How hard All Set may work: from Low Power Mode, the Mac's temperature,
    /// Reduce Motion and the charger. Every subsystem reads its limits here.
    var performance = PerformancePolicy()
}

/// A widget just taken off the desktop, and its place in the list.
struct RemovedWidget: Equatable {
    let instance: WidgetInstance
    let index: Int
    let id = UUID()
}

/// The app's long-lived models, shared by the notch, widgets, menu bar and settings.
@MainActor
final class AppServices {
    let settings = AppSettings()
    let monitor = SystemMonitor()
    let media = MediaController()
    let volume = VolumeMonitor()
    let power = PowerSourceMonitor()
    let widgets = WidgetStore(fileURL: AppServices.widgetsFileURL)
    /// Finishes focus-timer phases on time, whether or not a focus widget is showing.
    private(set) lazy var focusTimers = FocusTimerCoordinator(widgets: widgets) { breakEnded in
        NSSound(named: breakEnded ? "Glass" : "Hero")?.play()
    }
    /// Durable records of desktop changes: an unfinished preview, the previous desktop.
    let desktopJournal = DesktopJournal(directory: AppServices.widgetsFileURL.deletingLastPathComponent())
    let weather = WeatherService()
    let themeStats = ThemeStats()
    /// The person's own photos for each theme set.
    let themePhotos = ThemePhotos()
    private(set) lazy var themePreviews: ThemePreviewCache = {
        hasThemePreviews = true
        return ThemePreviewCache(photos: themePhotos)
    }()
    /// Whether the previews exist yet, so freeing memory doesn't create them.
    private var hasThemePreviews = false
    let github = GitHubService()
    let status = StatusService()
    /// Wallpaper-aware accents for design themes.
    let themes = ThemeManager()
    let calendar = CalendarService()
    let images = ImageLibrary()
    let search = PhotoSearch()
    let wallpaper = WallpaperStore()
    let workspaces = WorkspaceStore()
    let clipboard = ClipboardStore()
    let shelf = ShelfStore()
    let appVolumes = AppVolumeStore()
    lazy var mixer = MixerController(store: appVolumes, output: volume)
    let knockStore = KnockStore()
    let notes = NotesStore()
    let lidPlane = LidPlaneController(settings: LidPlaneSettings())
    lazy var knocks = KnockController(services: self)
    lazy var screenshotShortcut = ScreenshotShortcutController(services: self)
    lazy var clipboardMonitor = ClipboardMonitor(services: self)
    lazy var workspaceController = WorkspaceController(services: self)
    /// Set by the app delegate.
    weak var windowManager: WindowManager?
    let ui = UIState()
    /// Set by the app delegate so pages can drive the island (for "Try it").
    weak var notch: NotchController?

    func start() {
        // A preview the app quit or crashed in the middle of: the real desktop comes back.
        recoverInterruptedPreview()
        startWatchingEnergy()
        startWatchingMemory()
        applyMonitorPace()
        observe({ [settings] in settings.refreshInterval }) { [weak self] _ in self?.applyMonitorPace() }
        // Any timer due while the app was closed finishes now; then each on time.
        focusTimers.finishDuePhases()
        focusTimers.reschedule()
        observe({ [widgets] in widgets.widgets.map(\.options.focus.endsAt) }) { [weak self] _ in self?.focusTimers.reschedule() }
        // What the downloaded-photo cache must never evict: the wallpaper's
        // photo (the system wallpaper reads that file itself) and every photo
        // a widget shows. Anything else downloads again if it's wanted.
        images.photosInUse = { [weak self] in
            guard let self else { return [] }
            var sources = widgets.widgets.flatMap(\.options.images)
            if case .photo(let source) = wallpaper.config.source { sources.append(source) }
            return sources
        }
        Task { await images.trimDownloadedPhotos() }
        monitor.start()
        media.start()
        volume.start()
        mixer.start()
        knocks.start()
        power.start()
        calendar.start()
        themes.start(services: self)
        lidPlane.start()
        screenshotShortcut.start()
    }

    func stop() {
        focusTimers.stop()
        // A preview nobody kept isn't the desktop: quitting puts the real one back.
        if ui.themePreview != nil { endThemePreview(keep: false) }
        knocks.stop()
        lidPlane.stop()
        screenshotShortcut.stop()
        notes.save()
        mixer.stop()
        media.stop()
        monitor.stop()
        widgets.saveNow()
        if clipboard.settings.clearOnQuit { clipboard.clear() }
        clipboard.save()
    }

    // MARK: Memory

    private var memoryPressure: DispatchSourceMemoryPressure?

    /// When macOS runs short of memory, hand back what can be rebuilt.
    private func startWatchingMemory() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self, weak source] in
            MainActor.assumeIsolated {
                let critical = source?.data.contains(.critical) ?? false
                self?.releaseCachedPictures(keeping: critical ? 0 : 0.5)
            }
        }
        source.resume()
        memoryPressure = source
    }

    /// Frees cached pictures (photos, artwork, theme previews) down to
    /// `fraction` of each cache's limit. Everything freed is rebuilt from disk
    /// or redrawn the next time it's needed; nothing on screen disappears,
    /// since views hold what they show.
    func releaseCachedPictures(keeping fraction: Double) {
        if hasThemePreviews { themePreviews.purge() }
        images.trimCaches(to: fraction)
        ArtworkCache.trim(to: fraction)
    }

    // MARK: Energy

    private var energyObservers: [NSObjectProtocol] = []

    private func startWatchingEnergy() {
        let update: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.updateEnergy() }
        }
        energyObservers = [
            NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main, using: update),
            NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil,
                                                   queue: .main, using: update),
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main, using: update),
        ]
        observe({ [power] in power.state?.isPluggedIn }) { [weak self] _ in self?.updateEnergy() }
        updateEnergy()
    }

    private func updateEnergy() {
        let policy = PerformancePolicy(isLowPower: ProcessInfo.processInfo.isLowPowerModeEnabled,
                                       reducesMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                                       isOnBattery: power.state.map { !$0.isPluggedIn } ?? false,
                                       thermal: ProcessInfo.processInfo.thermalState)
        guard policy != ui.performance else { return }
        ui.performance = policy
        applyMonitorPace()
    }

    /// Live stats follow the setting, but no faster than the policy allows;
    /// with nothing showing them, the monitor samples at the policy's idle pace.
    private func applyMonitorPace() {
        let policy = ui.performance
        monitor.activeInterval = max(settings.refreshInterval, policy.monitorMinimumInterval)
        monitor.idleInterval = policy.monitorIdleInterval
    }

    private static var widgetsFileURL: URL {
        #if DEBUG
        // `AllSet -widgetsFile /path/layout.json` tries a layout without
        // touching the real one.
        if let path = UserDefaults.standard.string(forKey: "widgetsFile") {
            return URL(fileURLWithPath: path)
        }
        #endif
        return WidgetStore.defaultFileURL
    }

    /// Brings up the main window, optionally on a given page.
    func openWindow(_ page: AppPage? = nil) {
        if let page { ui.page = page }
        MainWindowController.shared.show(services: self)
    }

    /// Dresses every widget on the desktop in a theme, sets its font and
    /// corners, and (if asked) its wallpaper.
    func apply(_ theme: WidgetTheme, wallpaper setsWallpaper: Bool) {
        settings.widgetFont = theme.font
        settings.widgetCornerRadius = theme.cornerRadius
        for widget in widgets.widgets {
            widgets.update(widget.id) { $0 = theme.styled($0) }
        }
        if setsWallpaper { wallpaper.set(theme.wallpaper) }
        settings.widgetTheme = theme.id
        settings.showWidgets = true
    }

    /// Draws every widget that has a card in a design theme, and makes it the
    /// theme for new widgets. Kinds with their own backgrounds keep them.
    func apply(_ theme: DesignTheme, wallpaper setsWallpaper: Bool) {
        for widget in widgets.widgets where !widget.kind.isFreeform && !widget.kind.paintsOwnBackground {
            widgets.update(widget.id) { widget in
                widget.options.designTheme = theme.id
                // The theme's own accent, unless it follows the wallpaper anyway.
                widget.options.accent = nil
            }
        }
        if setsWallpaper, let source = theme.wallpaper { wallpaper.set(source) }
        settings.widgetDesignTheme = theme.id
        settings.widgetTheme = nil
        settings.showWidgets = true
    }

    /// Follows an `allset://` link.
    func handle(_ link: DeepLink) {
        switch link {
        case .page(let name):
            let pages: [String: AppPage] = [
                "home": .island, "island": .island, "themes": .themes, "gallery": .gallery(nil), "monitor": .monitor,
                "wallpaper": .wallpaper, "art": .wallpaper, "clipboard": .clipboard, "notes": .notes,
                "workspaces": .workspaces, "mixer": .mixer, "settings": .general, "desktop": .desktop, "lid": .lidPlane,
            ]
            openWindow(pages[name] ?? WidgetCategory(rawValue: name).map { .gallery($0) } ?? .island)
        case .widget(let id):
            openWindow(widgets.instance(id) != nil ? .widget(id) : .gallery(nil))
        case .arrange:
            ui.isArrangingWidgets = true
        case .fit:
            fitWidgetsToScreen()
        case .theme(let id):
            if let theme = DesignTheme.named(id) {
                apply(theme, wallpaper: false)
            } else if let setup = WidgetTheme.named(id) {
                apply(setup, wallpaper: false)
            } else if let set = ThemeLibrary.set(id) {
                install(set, mode: .restyle, wallpaper: false)
            }
        case .focus(let action):
            guard let focus = widgets.widgets.first(where: { $0.kind == .focus }) else { return }
            widgets.update(focus.id) { widget in
                switch action {
                case .start: widget.options.focus.start(at: .now, focusMinutes: widget.options.focusMinutes, breakMinutes: widget.options.breakMinutes)
                case .pause: widget.options.focus.pause(at: .now)
                case .reset: widget.options.focus.reset()
                }
            }
        }
    }

    /// Takes a widget off the desktop, remembering it so Undo can put it back
    /// exactly as it was.
    func removeWidget(_ id: UUID) {
        guard let index = widgets.widgets.firstIndex(where: { $0.id == id }) else { return }
        let instance = widgets.widgets[index]
        if ui.page == .widget(id) { ui.page = .desktop }
        widgets.remove(id)
        ui.removedWidget = RemovedWidget(instance: instance, index: index)
    }

    func undoRemoveWidget() {
        guard let removed = ui.removedWidget else { return }
        ui.removedWidget = nil
        guard widgets.instance(removed.instance.id) == nil else { return }
        widgets.insert(removed.instance, at: removed.index)
    }

    /// Puts a widget in the first free slot on the primary screen, or in the
    /// slot given (a drop from the gallery).
    @discardableResult
    func addWidget(_ instance: WidgetInstance, at slot: (screen: NSScreen, offset: CGPoint)? = nil) -> WidgetInstance {
        var instance = instance
        // New widgets join the chosen design theme.
        if let theme = settings.widgetDesignTheme, instance.options.designTheme == nil,
           !instance.options.cinematicClock, !instance.options.cinematicStyle,
           !instance.kind.isFreeform, !instance.kind.paintsOwnBackground, instance.material != .clear {
            instance.options.designTheme = theme
        }
        if let slot {
            instance.place(on: slot.screen)
            instance.offset = slot.offset
        } else if let screen = NSScreen.screens.first {
            let occupied = occupiedRects(on: screen)
            let bounds = layoutBounds(of: screen)
            instance.place(on: screen)
            instance.offset = widgetGrid(on: screen).firstFree(instance.footprint, avoiding: occupied)
                ?? WidgetLayout.freeOffset(for: instance.footprint, avoiding: occupied, within: bounds)
        }
        settings.showWidgets = true
        return widgets.add(instance)
    }
}

// MARK: The widget grid

extension AppServices {
    /// A screen's visible area in layout points: divided by the widget size.
    /// How large widgets are drawn on a display: its own size, else the desktop-wide one.
    func widgetScale(on screen: NSScreen?) -> Double {
        settings.widgetScale(for: screen?.displayInfo)
    }

    func layoutBounds(of screen: NSScreen) -> CGSize {
        let scale = widgetScale(on: screen)
        return CGSize(width: screen.visibleFrame.width / scale, height: screen.visibleFrame.height / scale)
    }

    func widgetGrid(on screen: NSScreen) -> WidgetGrid {
        WidgetGrid(bounds: layoutBounds(of: screen), margin: WidgetLayout.margin / widgetScale(on: screen))
    }

    /// Where a widget shows: its display (by id, else by name), else the first.
    func screen(for instance: WidgetInstance) -> NSScreen? {
        NSScreen.matching(id: instance.screenID, name: instance.screenName) ?? NSScreen.screens.first
    }

    /// Whether a widget shows on `screen`. Compared by display, since
    /// `NSScreen.screens` can hand back new objects each time it's asked.
    func shows(_ instance: WidgetInstance, on screen: NSScreen) -> Bool {
        self.screen(for: instance)?.displayID == screen.displayID
    }

    /// The layout rects of the widgets on a screen, but one.
    func occupiedRects(on screen: NSScreen, except id: UUID? = nil) -> [CGRect] {
        widgets.widgets
            .filter { $0.id != id && shows($0, on: screen) }
            .map { CGRect(origin: $0.offset, size: $0.footprint) }
    }

    /// The widgets tidied onto each screen's grid (`WidgetGrid.arranged`);
    /// `kept` holds its spot while the others make room.
    func gridArranged(_ instances: [WidgetInstance], keeping kept: UUID? = nil) -> [WidgetInstance] {
        var result = instances
        for screen in NSScreen.screens {
            let indices = result.indices.filter { shows(result[$0], on: screen) }
            guard !indices.isEmpty else { continue }
            let arranged = widgetGrid(on: screen).arranged(indices.map { result[$0] }, keeping: kept)
            for (index, widget) in zip(indices, arranged) { result[index] = widget }
        }
        return result
    }

    /// Widgets laid out for one screen size, shown on another (a resolution
    /// change, a different display), are scaled and moved with it: the same
    /// picture, centered the same way, never bigger than the screen. A screen
    /// seen for the first time is only noted.
    func refitWidgetsToScreens() {
        for screen in NSScreen.screens {
            // Saved under the display's id from now on (found by name when saved before ids).
            let key = screen.stableID
            let size = screen.frame.size
            guard let fit = settings.screenFit(for: screen.displayInfo) else {
                settings.screenFits[key] = ScreenFit(scale: settings.widgetScale(for: screen.displayInfo), size: size)
                continue
            }
            if settings.screenFits[key] == nil { settings.screenFits[key] = fit }
            guard abs(fit.width - size.width) > 1 || abs(fit.height - size.height) > 1 else { continue }
            let group = widgets.widgets.filter { shows($0, on: screen) }
            guard !group.isEmpty else {
                settings.screenFits[key] = ScreenFit(scale: fit.scale, size: size)
                continue
            }
            let visible = screen.visibleFrame.size
            let refit = WidgetLayout.refit(group, from: fit, toScreen: size, visible: visible, range: AppSettings.widgetScaleRange)
            settings.screenFits[key] = ScreenFit(scale: refit.scale, size: size)
            let grid = widgetGrid(on: screen)
            var moved = grid.arranged(refit.widgets)
            // A desktop that filled the old screen fills the new one.
            if refit.fillsScreen { moved = grid.spread(moved) }
            for widget in moved where widgets.instance(widget.id)?.offset != widget.offset {
                widgets.update(widget.id) { $0.offset = widget.offset }
            }
        }
    }

    /// Lines every widget up on its screen's grid, with no overlaps. Changes
    /// nothing when they already are.
    func cleanUpWidgets(keeping kept: UUID? = nil) {
        for widget in gridArranged(widgets.widgets, keeping: kept) where widgets.instance(widget.id)?.offset != widget.offset {
            widgets.update(widget.id) { $0.offset = widget.offset }
        }
    }

    /// A new size for a widget, at the scale it has; the grid makes room for it.
    func resizeWidget(_ id: UUID, to size: WidgetSize) {
        guard let instance = widgets.instance(id) else { return }
        resizeWidget(id, to: WidgetResize.Result(size: size, scale: fittedScale(1, size: size, for: instance)))
    }

    /// A widget dragged to a new size by its corner: it stays where it is and
    /// the widgets around it make room.
    func resizeWidget(_ id: UUID, to result: WidgetResize.Result) {
        guard let instance = widgets.instance(id) else { return }
        guard instance.size != result.size || instance.scale != result.scale || instance.stretch != result.stretch else { return }
        widgets.update(id) {
            $0.size = result.size
            $0.scale = result.scale
            $0.stretch = result.stretch
        }
        cleanUpWidgets(keeping: id)
    }

    /// The grid's room for a widget on its screen, in layout points.
    func widgetRoom(for instance: WidgetInstance) -> CGSize? {
        screen(for: instance).map { widgetGrid(on: $0).capacity }
    }

    /// `scale` kept within what fits on the widget's screen at `size`.
    private func fittedScale(_ scale: Double, size: WidgetSize, for instance: WidgetInstance) -> Double {
        guard let room = widgetRoom(for: instance) else { return scale }
        let fits = min(Double(room.width / size.dimensions.width), Double(room.height / size.dimensions.height))
        return max(WidgetInstance.scaleRange.lowerBound, min(scale, fits))
    }
}

/// Calls `onChange` with the new value each time anything `value` reads changes.
@MainActor
func observe<Value>(_ value: @escaping @MainActor @Sendable () -> Value,
                    onChange: @escaping @MainActor @Sendable (Value) -> Void) {
    withObservationTracking {
        _ = value()
    } onChange: {
        Task { @MainActor in
            onChange(value())
            observe(value, onChange: onChange)
        }
    }
}

extension AppServices {
    /// Room enough that laying out a theme's grid never clamps it; fitting
    /// then places it on the real screen.
    static let unbounded = CGSize(width: 10_000, height: 10_000)

    /// A theme's arrangement sized and centered to fill the primary screen:
    /// sets the widget size and returns the widgets moved to match.
    func fittedToScreen(_ layout: [WidgetInstance], on screen: NSScreen? = NSScreen.screens.first) -> [WidgetInstance] {
        let bounds = screen?.visibleFrame.size ?? CGSize(width: 1440, height: 860)
        let fitted = WidgetLayout.fitted(layout, in: bounds, range: AppSettings.widgetScaleRange)
        if let screen {
            settings.screenFits[screen.stableID] = ScreenFit(scale: fitted.scale, size: screen.frame.size)
        } else {
            settings.widgetScale = fitted.scale
        }
        return fitted.widgets
    }

    /// Resizes and recenters the widgets on the primary screen so they fill it.
    func fitWidgetsToScreen() {
        guard let screen = NSScreen.screens.first else { return }
        let onScreen = widgets.widgets.filter { shows($0, on: screen) }
        guard !onScreen.isEmpty else { return }
        let moved = Dictionary(uniqueKeysWithValues: fittedToScreen(onScreen).map { ($0.id, $0.offset) })
        for (id, offset) in moved { widgets.update(id) { $0.offset = offset } }
    }
}

// MARK: Saving

extension AppServices {
    /// What couldn't be saved, and why: one list, shown in one place, whichever store failed.
    var saveProblems: [(what: String, why: String)] {
        [("your widget layout", widgets.saveError), ("your notes", notes.saveError),
         ("clipboard history", clipboard.saveError), ("the shelf", shelf.saveError),
         ("your workspaces", workspaces.saveError), ("wallpaper settings", wallpaper.saveError)]
            .compactMap { what, why in why.map { (what, $0) } }
    }

    /// Writes again every store whose last save failed.
    func retrySaves() {
        if widgets.saveError != nil { widgets.saveNow() }
        if notes.saveError != nil { notes.save() }
        if clipboard.saveError != nil { clipboard.save() }
        if shelf.saveError != nil { shelf.saveNow() }
        if workspaces.saveError != nil { workspaces.saveNow() }
        if wallpaper.saveError != nil { wallpaper.saveNow() }
    }
}
