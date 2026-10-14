import AllSetCore
import AppKit
import SwiftUI

/// Island animations the app can play on request ("Try it" buttons).
enum NotchDemo {
    case open
    case nowPlaying
    case volume
    case charging
    case lowBattery
    case audioDevice
}

/// Owns the notch panel: keeps it over the notch, opens and closes it as the
/// pointer comes and goes, and turns service events into live activities.
@MainActor
final class NotchController {
    private let services: AppServices
    private let model: NotchViewModel
    private let panel = NotchPanel()

    private var eventMonitors: [Any] = []
    private var screenObserver: NSObjectProtocol?
    private var pointerTimer: Timer?
    private var hoverTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?
    private var transientTask: Task<Void, Never>?
    private var nowPlayingHideTask: Task<Void, Never>?
    /// After closing from a button (e.g. Settings) the pointer is still on the
    /// notch; don't reopen until it has left.
    private var hoverSuppressed = false
    /// Stays open whatever the pointer does (see `applyPreviewArgument`).
    private var isPinnedOpen = false
    /// The drag pasteboard's change count when the mouse went down. If it
    /// changes during the drag, the drag carries content (files, pictures),
    /// not a window being moved.
    private var dragPasteboardCount = NSPasteboard(name: .drag).changeCount
    /// The button went down on the island (on a slider, say): it keeps the
    /// island open and taking the mouse until the button comes up, even if
    /// the pointer strays off it mid-drag.
    private var isDraggingInIsland = false

    init(services: AppServices) {
        self.services = services
        model = NotchViewModel(geometry: NotchGeometry(screenFrame: .zero, safeAreaTop: 0, topLeftArea: nil,
                                                       topRightArea: nil, menuBarHeight: 0))
        let root = NotchRootView(
            model: model,
            services: services,
            expand: { [weak self] in self?.expand() },
            openSettings: { [weak self] in self?.openSettings() }
        )
        panel.contentView = IslandView(model: model, root: root)
    }

    func start() {
        layout()
        panel.orderFrontRegardless()
        installPointerMonitors()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.layout() }
        }
        observe({ [services] in services.settings.notchDisplay }) { [weak self] _ in self?.layout() }
        observe({ [services] in services.settings.showNowPlaying }) { [weak self] _ in self?.updateNowPlaying() }
        observe({ [services] in services.settings.notchEnabled }) { [weak self] enabled in self?.setEnabled(enabled) }
        setEnabled(services.settings.notchEnabled)

        services.media.onChange = { [weak self] in self?.updateNowPlaying() }
        services.volume.onVolumeChange = { [weak self] level, muted in
            guard let self, services.settings.showVolume else { return }
            showTransient(.volume(level: level, muted: muted))
        }
        services.volume.onDeviceChange = { [weak self] name, kind in
            guard let self, services.settings.showAudioDevice else { return }
            showTransient(.audioDevice(name: name, kind: kind), for: .seconds(2.5))
        }
        services.power.onEvent = { [weak self] event in
            guard let self, services.settings.showBattery else { return }
            switch event {
            case .pluggedIn(let percent):
                showTransient(.power(percent: percent, pluggedIn: true), for: .seconds(2.5))
            case .unplugged(let percent):
                showTransient(.power(percent: percent, pluggedIn: false), for: .seconds(2))
            case .lowBattery(let percent):
                showTransient(.lowBattery(percent: percent), for: .seconds(4))
            }
        }
        updateNowPlaying()
        observe({ [model] in model.isExpanded && model.tab == .notes }) { [weak self] wantsKeyboard in
            self?.setAcceptsKeyboard(wantsKeyboard)
        }
        // Done typing: close if the pointer has already left.
        observe({ [model] in model.isEditing }) { [weak self] editing in
            if !editing { self?.pointerMoved() }
        }
        Task { [services, model] in
            try? await Task.sleep(for: .seconds(6))
            guard services.settings.notchEnabled else { return }
            await IslandView.warmUp(geometry: model.geometry, services: services)
        }

        #if DEBUG
        applyPreviewArgument()
        #endif
    }

    #if DEBUG
    /// `AllSet -previewNotch home|tray|mixer|system` opens the panel at launch and keeps it
    /// open, for working on its UI without hovering.
    private func applyPreviewArgument() {
        guard let tab = UserDefaults.standard.string(forKey: "previewNotch") else { return }
        model.tab = switch tab {
        case "system": .system
        case "tray": .tray
        case "mixer": .mixer
        case "notes": .notes
        default: .home
        }
        isPinnedOpen = true
        expand()
    }
    #endif

    // MARK: On and off, demos

    private func setEnabled(_ enabled: Bool) {
        if enabled {
            layout()
            panel.orderFrontRegardless()
        } else {
            collapse()
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
        }
    }

    /// For a knock: opens the island (on `tab`, if given) long enough to
    /// reach it with the pointer, or closes it if it's open on that tab already.
    func toggleIsland(tab: NotchViewModel.Tab? = nil) {
        guard services.settings.notchEnabled else { return }
        if model.isExpanded {
            if let tab, model.tab != tab {
                withAnimation(NotchAnimation.tab) { model.tab = tab }
            } else {
                isPinnedOpen = false
                collapse()
            }
            return
        }
        if let tab { model.tab = tab }
        isPinnedOpen = true
        expand(keepingTab: tab != nil)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, isPinnedOpen else { return }
            isPinnedOpen = false
            pointerMoved()
        }
    }

    /// Lets the panel take typing for the Notes tab, and gives the keyboard
    /// back to the app in front afterwards.
    private func setAcceptsKeyboard(_ accepts: Bool) {
        panel.acceptsKeyboard = accepts
        if !accepts, panel.isKeyWindow {
            model.isEditing = false
            // Leaving the screen for a moment hands key status back.
            panel.orderOut(nil)
            if services.settings.notchEnabled { panel.orderFrontRegardless() }
        }
    }

    /// Closes the island now, whatever the pointer is doing.
    func close() {
        isPinnedOpen = false
        model.isEditing = false
        collapse()
    }

    /// Shows a knock beside the notch: what it did, and how many knocks.
    func showKnock(count: KnockCount, symbol: String, failed: Bool) {
        showTransient(.knock(count: count, symbol: symbol, failed: failed), for: .seconds(failed ? 2.5 : 1.5))
    }

    func demo(_ demo: NotchDemo) {
        guard services.settings.notchEnabled else { return }
        switch demo {
        case .open:
            // Stay open long enough to look at, then close unless the pointer is on it.
            isPinnedOpen = true
            expand()
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3.5))
                guard let self else { return }
                isPinnedOpen = false
                pointerMoved()
            }
        case .nowPlaying:
            showTransient(.nowPlaying, for: .seconds(3))
        case .volume:
            showTransient(.volume(level: services.volume.volume, muted: services.volume.isMuted), for: .seconds(2))
        case .charging:
            let percent = services.monitor.snapshot.battery?.percent ?? services.power.state?.percent ?? 80
            showTransient(.power(percent: percent, pluggedIn: true), for: .seconds(2.5))
        case .lowBattery:
            showTransient(.lowBattery(percent: 10), for: .seconds(3))
        case .audioDevice:
            showTransient(.audioDevice(name: services.volume.deviceName, kind: services.volume.deviceKind), for: .seconds(2.5))
        }
    }

    // MARK: Placement

    private func layout() {
        guard let screen = targetScreen() else { return }
        model.geometry = NotchGeometry(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            topLeftArea: screen.auxiliaryTopLeftArea,
            topRightArea: screen.auxiliaryTopRightArea,
            menuBarHeight: max(screen.frame.maxY - screen.visibleFrame.maxY, NSStatusBar.system.thickness)
        )
        let size = NotchViewModel.windowSize
        panel.setFrame(CGRect(x: model.geometry.notchRect.midX - size.width / 2, y: screen.frame.maxY - size.height,
                              width: size.width, height: size.height),
                       display: true)
    }

    private func targetScreen() -> NSScreen? {
        switch services.settings.notchDisplay {
        case .builtIn: NSScreen.screens.first(where: \.isBuiltIn) ?? NSScreen.screens.first
        case .primary: NSScreen.screens.first
        }
    }

    // MARK: Pointer

    private func installPointerMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let type = event.type
            MainActor.assumeIsolated { self?.handlePointer(type, inIsland: false) }
        }) {
            eventMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let type = event.type
            let inIsland = event.window is NotchPanel
            MainActor.assumeIsolated { self?.handlePointer(type, inIsland: inIsland) }
            return event
        }) {
            eventMonitors.append(local)
        }
    }

    private func handlePointer(_ type: NSEvent.EventType, inIsland: Bool) {
        switch type {
        case .leftMouseDown:
            mouseWentDown()
            isDraggingInIsland = inIsland && model.isExpanded
        case .leftMouseUp:
            let wasDragging = isDraggingInIsland
            isDraggingInIsland = false
            if wasDragging { pointerMoved() }
        default:
            pointerMoved()
        }
    }

    private func pointerMoved() {
        guard services.settings.notchEnabled else { return }
        // Mid-drag on a control: stay open and keep the mouse.
        if isDraggingInIsland, NSEvent.pressedMouseButtons & 1 == 1 {
            collapseTask?.cancel()
            collapseTask = nil
            if panel.ignoresMouseEvents { panel.ignoresMouseEvents = false }
            return
        }
        isDraggingInIsland = false
        let point = NSEvent.mouseLocation
        let shape = model.geometry.hangingRect(size: model.shapeSize)

        // Take clicks only over the visible shape (plus the top edge, where a
        // flung pointer lands) so status items beside the notch keep working.
        let clickArea = CGRect(x: shape.minX, y: shape.minY, width: shape.width, height: shape.height + 2)
        let capturesClicks = clickArea.contains(point)
        if panel.ignoresMouseEvents == capturesClicks {
            panel.ignoresMouseEvents = !capturesClicks
        }

        let slack: CGFloat = model.isExpanded ? 8 : 5
        if shape.insetBy(dx: -slack, dy: -slack).contains(point) {
            pointerEntered()
        } else {
            pointerExited()
        }
    }

    private func mouseWentDown() {
        dragPasteboardCount = NSPasteboard(name: .drag).changeCount
    }

    /// Something (a file, a picture) is being dragged, rather than a window.
    private var isDraggingContent: Bool {
        NSEvent.pressedMouseButtons & 1 == 1 && NSPasteboard(name: .drag).changeCount != dragPasteboardCount
    }

    private func pointerEntered() {
        collapseTask?.cancel()
        collapseTask = nil
        if isDraggingContent {
            // Dragging something onto the notch: open the shelf right away.
            hoverTask?.cancel()
            hoverTask = nil
            if model.tab != .tray { withAnimation(NotchAnimation.tab) { model.tab = .tray } }
            if !model.isExpanded { expand(keepingTab: true) }
            return
        }
        guard !model.isExpanded, !hoverSuppressed else { return }
        setHovering(true)
        guard services.settings.expandOnHover, hoverTask == nil else { return }
        let delay = services.settings.hoverDelay
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.expand()
        }
    }

    private func pointerExited() {
        hoverSuppressed = false
        hoverTask?.cancel()
        hoverTask = nil
        setHovering(false)
        guard model.isExpanded, !isPinnedOpen, !model.isEditing, collapseTask == nil else { return }
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.collapse()
        }
    }

    private func setHovering(_ hovering: Bool) {
        guard model.isHovering != hovering else { return }
        withAnimation(NotchAnimation.hover) { model.isHovering = hovering }
    }

    /// Event monitors can miss a fast exit (say, onto another screen), so poll
    /// as a backstop while the panel is open.
    private func startPointerTimer() {
        pointerTimer?.invalidate()
        pointerTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
        // Lets macOS batch it with other wakeups.
        pointerTimer?.tolerance = 0.05
    }

    // MARK: Open and close

    private func expand(keepingTab: Bool = false) {
        hoverTask?.cancel()
        hoverTask = nil
        guard !model.isExpanded else { return }
        transientTask?.cancel()
        if !keepingTab {
            switch services.settings.notchStartTab {
            case .home: model.tab = .home
            case .system: model.tab = .system
            case .last: break
            }
        }
        withAnimation(NotchAnimation.open) {
            model.transientActivity = nil
            model.isHovering = false
            model.isExpanded = true
        }
        services.monitor.setViewer("notch", visible: true)
        if services.settings.hapticFeedback {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        startPointerTimer()
    }

    private func collapse() {
        collapseTask?.cancel()
        collapseTask = nil
        guard model.isExpanded else { return }
        withAnimation(NotchAnimation.close) { model.isExpanded = false }
        services.monitor.setViewer("notch", visible: false)
        pointerTimer?.invalidate()
        pointerTimer = nil
        pointerMoved()
    }

    private func openSettings() {
        hoverSuppressed = true
        collapse()
        services.openWindow(.island)
    }

    // MARK: Live activities

    private func updateNowPlaying() {
        nowPlayingHideTask?.cancel()
        guard services.settings.showNowPlaying, let info = services.media.info else {
            setShowsNowPlaying(false)
            return
        }
        if info.isPlaying {
            setShowsNowPlaying(true)
        } else if model.showsNowPlaying {
            // Linger a little after pausing, like the iPhone does.
            nowPlayingHideTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { return }
                self?.setShowsNowPlaying(false)
            }
        }
    }

    private func setShowsNowPlaying(_ shows: Bool) {
        guard model.showsNowPlaying != shows else { return }
        withAnimation(NotchAnimation.activity) { model.showsNowPlaying = shows }
    }

    private func showTransient(_ activity: LiveActivity, for duration: Duration = .seconds(1.6)) {
        guard !model.isExpanded, services.settings.notchEnabled else { return }
        withAnimation(NotchAnimation.activity) { model.transientActivity = activity }
        transientTask?.cancel()
        transientTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self else { return }
            withAnimation(NotchAnimation.activity) { self.model.transientActivity = nil }
        }
    }
}
