import AllSetCore
import AppKit
import SwiftUI

enum WidgetDragPhase {
    case changed
    case ended
}

/// Keeps one window per widget in `WidgetStore`, placed where the store says,
/// and runs arrange mode: dragging, snapping and the floating toolbar.
@MainActor
final class DesktopWidgetController {
    private let services: AppServices
    private var windows: [UUID: WidgetWindow] = [:]
    /// Windows from removed widgets, kept for the next ones: making a window
    /// and tearing one down both cost the window server work.
    private var spares: [WidgetWindow] = []
    /// New widgets waiting for their turn to appear.
    private var pendingArrivals: [UUID] = []
    private var arrivals: Task<Void, Never>?
    private var occlusionObservers: [UUID: NSObjectProtocol] = [:]
    private var screenObserver: NSObjectProtocol?
    /// Reads the pointer for the corner resize handles: macOS sends no
    /// mouse-moved events to an app that isn't in front, so it's read directly,
    /// two dozen cheap checks a second, and only while some widget is shown
    /// uncovered. No widgets, or all of them covered, means no wakeups.
    private lazy var pointerWatch = NeededTimer(interval: 0.05, tolerance: 0.02) { [weak self] in self?.pointerMoved() }
    private var lastPointer: CGPoint?
    private var toolbar: NSPanel?
    /// "Keep / Go Back" while a theme is being tried on the desktop.
    private var previewBar: NSPanel?
    /// False during the first layout, so widgets don't fade in at launch.
    private var hasStarted = false
    /// The widget being dragged, where the pointer started and where its window was.
    private var drag: (id: UUID, startPointer: CGPoint, startOrigin: CGPoint)?
    /// The widget being resized by its corner: where the pointer started, its
    /// content's top-left on screen (which stays put) and its footprint then.
    private var resize: (id: UUID, startPointer: CGPoint, topLeft: CGPoint, startFootprint: CGSize)?
    /// What the resize last showed, saved when the corner is let go.
    private var resizeResult: WidgetResize.Result?
    /// The slots, shown while a widget is dragged or dropped from the gallery.
    private let gridOverlay = WidgetGridOverlay()
    /// What the grid layout last depended on; a change tidies the widgets.
    private var gridShape: GridShape?
    /// Watches for a gallery drag ending without a drop.
    private var dropWatch: Timer?
    private var dropReleasedAt: Date?

    private struct GridShape: Equatable {
        var footprints: [UUID: CGSize]
        var screens: [CGRect]
        var scale: Double
        var fits: [String: ScreenFit]
    }

    init(services: AppServices) {
        self.services = services
    }

    func start() {
        if !services.widgets.hasSavedLayout, let screen = NSScreen.screens.first {
            services.widgets.add(contentsOf: WidgetLayout.starterSet(screenName: screen.localizedName).map { $0.placed(on: screen) })
        }
        sync(animated: false)

        observe({ [services] in services.widgets.widgets }) { [weak self] _ in self?.sync() }
        observe({ [services] in services.settings.showWidgets }) { [weak self] _ in self?.sync() }
        observe({ [services] in services.settings.widgetScale }) { [weak self] _ in self?.sync() }
        observe({ [services] in services.settings.screenFits }) { [weak self] _ in self?.sync() }
        observe({ [services] in services.ui.isArrangingWidgets }) { [weak self] arranging in
            self?.setArranging(arranging)
        }
        observe({ [services] in services.ui.themePreview?.setID }) { [weak self] setID in
            self?.showPreviewBar(for: setID)
        }
        observe({ [services] in services.ui.widgetDrop?.id }) { [weak self] _ in
            self?.updateDropping()
        }
        hasStarted = true
        updatePointerWatch()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync(animated: false) }
        }
    }

    private func updatePointerWatch() {
        let needed = services.settings.showWidgets && windows.values.contains { !$0.state.isOccluded }
        guard pointerWatch.setNeeded(needed), !needed else { return }
        // Stopped: nothing can stay hovered.
        lastPointer = nil
        for window in windows.values where window.state.cornerHovered { window.state.cornerHovered = false }
    }

    private func pointerMoved() {
        guard resize == nil, services.settings.showWidgets else { return }
        let pointer = NSEvent.mouseLocation
        guard pointer != lastPointer else { return }
        lastPointer = pointer
        for window in windows.values { window.pointerMoved(to: pointer) }
    }

    // MARK: Windows

    private func sync(animated: Bool = true) {
        tidyIfShapeChanged()
        let wanted = services.settings.showWidgets ? services.widgets.widgets : []
        let wantedIDs = Set(wanted.map(\.id))
        for id in windows.keys where !wantedIDs.contains(id) {
            closeWindow(id)
        }
        pendingArrivals.removeAll { !wantedIDs.contains($0) }

        // A whole new set (a theme) arrives a couple of widgets a frame instead
        // of all in one: no stall, and the desktop fills in like a cascade.
        let newCount = wanted.count { windows[$0.id] == nil }
        let staggers = hasStarted && newCount > Self.arrivalBatch
        for instance in wanted {
            if windows[instance.id] == nil {
                if staggers || pendingArrivals.contains(instance.id) {
                    if !pendingArrivals.contains(instance.id) { pendingArrivals.append(instance.id) }
                    continue
                }
                show(instance)
            } else {
                place(instance, animated: animated)
            }
        }
        startArrivals()
        updateStatsViewer()
    }

    /// Lines the widgets up on the grid whenever what the layout depends on
    /// changed: a widget came, went or changed size, or the widget size or the
    /// screens did (another Mac, a new display). Moves nothing that's already
    /// in place, so it's free the rest of the time.
    private func tidyIfShapeChanged() {
        let shape = GridShape(
            footprints: Dictionary(services.widgets.widgets.map { ($0.id, $0.footprint) }, uniquingKeysWith: { first, _ in first }),
            screens: NSScreen.screens.map(\.visibleFrame),
            scale: services.settings.widgetScale,
            fits: services.settings.screenFits
        )
        guard shape != gridShape, drag == nil, resize == nil else { return }
        // A new resolution or display refits first, then everything is tidied.
        services.refitWidgetsToScreens()
        gridShape = GridShape(
            footprints: shape.footprints, screens: shape.screens, scale: services.settings.widgetScale,
            fits: services.settings.screenFits
        )
        services.cleanUpWidgets()
    }

    /// How many new widgets appear per frame.
    private static var arrivalBatch: Int {
        #if DEBUG
        // `-arrivalBatch 100`: everything at once, as before, for comparing.
        let value = UserDefaults.standard.integer(forKey: "arrivalBatch")
        if value > 0 { return value }
        #endif
        return 3
    }

    private func startArrivals() {
        guard arrivals == nil, !pendingArrivals.isEmpty else { return }
        arrivals = Task { [weak self] in
            while let self, !self.pendingArrivals.isEmpty {
                let batch = self.pendingArrivals.prefix(Self.arrivalBatch)
                self.pendingArrivals.removeFirst(batch.count)
                for id in batch where self.windows[id] == nil {
                    guard self.services.settings.showWidgets, let instance = self.services.widgets.instance(id) else { continue }
                    self.show(instance)
                }
                self.updateStatsViewer()
                try? await Task.sleep(for: .milliseconds(34))
            }
            self?.arrivals = nil
        }
    }

    /// Puts a widget on the desktop in a fresh (or recycled) window.
    private func show(_ instance: WidgetInstance) {
        let window = makeWindow(for: instance)
        window.allowsKey = instance.kind == .note || instance.kind == .todo
        window.state.contentScale = contentScale(for: instance)
        if let frame = frame(for: instance) { window.setFrame(frame, display: false) }
        if hasStarted { arrive(window, motion: instance.designTheme?.motion ?? .calm) }
        window.orderFront(nil)
    }

    /// Moves an existing widget's window to where the store says.
    private func place(_ instance: WidgetInstance, animated: Bool) {
        guard let window = windows[instance.id] else { return }
        window.allowsKey = instance.kind == .note || instance.kind == .todo
        guard drag?.id != instance.id, resize?.id != instance.id, let frame = frame(for: instance) else { return }
        window.state.contentScale = contentScale(for: instance)
        if window.frame != frame {
            if animated, window.isVisible {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.25
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    window.animator().setFrame(frame, display: true)
                }
            } else {
                window.setFrame(frame, display: true)
            }
        }
        if !window.isVisible { window.orderFront(nil) }
    }

    /// A new widget fades in the way its theme moves: quickly for energetic
    /// themes, slowly for calm ones, at once for still ones (or with Reduce Motion, briefly).
    private func arrive(_ window: WidgetWindow, motion: MotionLanguage) {
        let duration = Motion.reducesMotion ? 0.15 : motion.appearDuration
        guard duration > 0 else { return }
        window.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    private func showPreviewBar(for setID: String?) {
        previewBar?.orderOut(nil)
        previewBar = nil
        guard let setID, let set = ThemeLibrary.set(setID), let screen = NSScreen.screens.first else { return }
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        let hostingView = FirstClickHostingView(rootView: ThemePreviewBar(
            name: set.name,
            onKeep: { [weak self] in self?.services.endThemePreview(keep: true) },
            onRevert: { [weak self] in self?.services.endThemePreview(keep: false) }
        ))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        let size = CGSize(width: 520, height: 84)
        let visible = screen.visibleFrame
        panel.setFrame(CGRect(x: visible.midX - size.width / 2, y: visible.minY + 20, width: size.width, height: size.height), display: true)
        panel.orderFront(nil)
        previewBar = panel
    }

    private func makeWindow(for instance: WidgetInstance) -> WidgetWindow {
        let id = instance.id
        let window = spares.popLast() ?? WidgetWindow()
        window.state.isOccluded = false
        window.state.cornerHovered = false
        window.state.isResizing = false
        window.state.liveSize = nil
        window.state.liveScale = nil
        let root = WidgetRoot(
            id: id,
            services: services,
            window: window.state,
            onDrag: { [weak self] phase in self?.handleDrag(id, phase) },
            onResize: { [weak self] phase in self?.handleResize(id, phase) },
            onRemove: { [weak self] in self?.services.removeWidget(id) },
            onConfigure: { [weak self] in self?.services.openWindow(.widget(id)) }
        )
        if let hostingView = window.contentView as? FirstClickHostingView<WidgetRoot> {
            hostingView.rootView = root
        } else {
            let hostingView = FirstClickHostingView(rootView: root)
            hostingView.sizingOptions = []
            window.contentView = hostingView
        }
        window.level = services.ui.isArrangingWidgets ? WidgetWindow.arrangingLevel : WidgetWindow.desktopLevel

        occlusionObservers[id] = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.visibilityChanged() }
        }
        windows[id] = window
        updatePointerWatch()
        return window
    }

    private func closeWindow(_ id: UUID) {
        if let observer = occlusionObservers.removeValue(forKey: id) {
            NotificationCenter.default.removeObserver(observer)
        }
        guard let window = windows.removeValue(forKey: id) else { return }
        defer { updatePointerWatch() }
        window.orderOut(nil)
        if spares.count < Self.spareLimit {
            (window.contentView as? FirstClickHostingView<WidgetRoot>)?.rootView = WidgetRoot.empty(services: services)
            window.alphaValue = 1
            spares.append(window)
        } else {
            window.close()
        }
    }

    private static let spareLimit = 16

    private func visibilityChanged() {
        for window in windows.values {
            let occluded = !window.occlusionState.contains(.visible)
            if window.state.isOccluded != occluded { window.state.isOccluded = occluded }
        }
        updatePointerWatch()
        updateStatsViewer()
    }

    /// The window frame for a widget: its saved spot, kept on screen, plus the
    /// margin around it.
    private func frame(for instance: WidgetInstance) -> CGRect? {
        guard let screen = services.screen(for: instance) else { return nil }
        let visible = screen.visibleFrame
        // Offsets are layout points: position and size both grow with the widget size.
        let scale = services.widgetScale(on: screen)
        let size = CGSize(width: instance.footprint.width * scale, height: instance.footprint.height * scale)
        let offset = WidgetLayout.clamp(CGPoint(x: instance.offset.x * scale, y: instance.offset.y * scale),
                                        size: size, within: visible.size)
        return windowFrame(topLeft: CGPoint(x: visible.minX + offset.x, y: visible.maxY - offset.y),
                           size: size, contentScale: scale * instance.scale)
    }

    /// A window around content of `size` (screen points) hanging from
    /// `topLeft`. The margin grows with the widget, so its shadow and badges
    /// keep the same room at any size.
    private func windowFrame(topLeft: CGPoint, size: CGSize, contentScale: Double) -> CGRect {
        let content = CGRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height)
        return content.insetBy(dx: -WidgetWindow.margin * contentScale, dy: -WidgetWindow.margin * contentScale)
    }

    /// How much larger than layout points a widget's window draws it.
    private func contentScale(for instance: WidgetInstance) -> Double {
        services.widgetScale(on: services.screen(for: instance)) * instance.scale
    }


    /// Stats widgets only need fresh numbers while someone can see them, and
    /// only as often as the most eager visible one asks.
    private func updateStatsViewer() {
        let intervals = windows.compactMap { id, window -> TimeInterval? in
            guard window.occlusionState.contains(.visible), let instance = services.widgets.instance(id) else { return nil }
            switch instance.kind {
            case .system, .battery, .terminal:
                return instance.options.refresh.interval(for: .systemStats) ?? 5
            case .metric where ![.wifi, .uptime].contains(instance.options.metric):
                return instance.options.refresh.interval(for: .systemStats) ?? 5
            default:
                return nil
            }
        }
        services.monitor.setViewer("widgets", visible: !intervals.isEmpty, interval: intervals.min())
    }

    // MARK: Arranging

    private func handleDrag(_ id: UUID, _ phase: WidgetDragPhase) {
        guard let window = windows[id], let instance = services.widgets.instance(id) else { return }
        // Global pointer position, since the view under the pointer moves with the window.
        let pointer = NSEvent.mouseLocation
        switch phase {
        case .changed:
            if drag?.id != id {
                drag = (id, pointer, window.frame.origin)
            }
            guard let drag else { return }
            window.setFrameOrigin(CGPoint(x: drag.startOrigin.x + pointer.x - drag.startPointer.x,
                                          y: drag.startOrigin.y + pointer.y - drag.startPointer.y))
            showSlot(for: instance, in: window)
        case .ended:
            guard drag?.id == id else { return }
            drag = nil
            gridOverlay.hide()
            // No free slot: it goes back where it was.
            if let slot = slot(for: instance, in: window) {
                if let other = slot.swap {
                    services.widgets.update(other) {
                        $0.offset = instance.offset
                        $0.screenID = instance.screenID
                        $0.screenName = instance.screenName
                    }
                }
                services.widgets.update(id) {
                    $0.offset = slot.offset
                    $0.place(on: slot.screen)
                }
            }
            // Settle into the slot even if the saved spot didn't change.
            sync()
        }
    }

    /// Where a dragged widget would land: the free slot nearest it, on the
    /// screen under its middle.
    private func slot(for instance: WidgetInstance, in window: NSWindow) -> (screen: NSScreen, offset: CGPoint, grid: WidgetGrid, swap: UUID?)? {
        let margin = WidgetWindow.margin * contentScale(for: instance)
        let content = window.frame.insetBy(dx: margin, dy: margin)
        let center = CGPoint(x: content.midX, y: content.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.screens.first else { return nil }
        let scale = services.widgetScale(on: screen)
        let visible = screen.visibleFrame
        let offset = CGPoint(x: (content.minX - visible.minX) / scale, y: (visible.maxY - content.maxY) / scale)
        let grid = services.widgetGrid(on: screen)
        // Dropped on a widget of the same size: they trade places, so a packed
        // desktop (a theme) can still be rearranged.
        if let cell = grid.nearestCell(to: offset, footprint: instance.footprint) {
            let target = grid.offset(of: cell)
            let box = CGRect(origin: target, size: instance.footprint).insetBy(dx: 1, dy: 1)
            let covered = services.widgets.widgets.filter {
                $0.id != instance.id && services.shows($0, on: screen) && CGRect(origin: $0.offset, size: $0.footprint).intersects(box)
            }
            if covered.count == 1, let other = covered.first, other.footprint == instance.footprint,
               abs(other.offset.x - target.x) < 1, abs(other.offset.y - target.y) < 1 {
                return (screen, target, grid, other.id)
            }
        }
        guard let spot = grid.place(instance.footprint, near: offset, avoiding: services.occupiedRects(on: screen, except: instance.id)) else {
            return nil
        }
        return (screen, spot, grid, nil)
    }

    private func showSlot(for instance: WidgetInstance, in window: NSWindow) {
        guard let slot = slot(for: instance, in: window) else {
            gridOverlay.highlight(nil)
            return
        }
        if !gridOverlay.isShowing || gridOverlay.screen?.displayID != slot.screen.displayID {
            gridOverlay.show(on: slot.screen, grid: slot.grid, scale: services.widgetScale(on: slot.screen),
                             occupied: services.occupiedRects(on: slot.screen, except: instance.id),
                             level: window.level, below: window)
        }
        gridOverlay.highlight(CGRect(origin: slot.offset, size: instance.footprint))
    }

    // MARK: Resizing

    /// The corner handle being dragged: the widget grows or shrinks live from
    /// its top-left, taking whichever of its layouts fits the drag best
    /// (`WidgetResize`), and is saved when let go, the others making room.
    private func handleResize(_ id: UUID, _ phase: WidgetDragPhase, pointer: CGPoint = NSEvent.mouseLocation) {
        guard let window = windows[id], let instance = services.widgets.instance(id),
              let screen = services.screen(for: instance) else { return }
        let scale = services.widgetScale(on: screen)
        switch phase {
        case .changed:
            if resize?.id != id {
                let margin = WidgetWindow.margin * contentScale(for: instance)
                resize = (id, pointer, CGPoint(x: window.frame.minX + margin, y: window.frame.maxY - margin), instance.footprint)
                resizeResult = WidgetResize.Result(size: instance.size, scale: instance.scale, stretch: instance.stretch)
            }
            guard let resize else { return }
            // Layout points; dragging down (smaller y on screen) makes it taller.
            let dragged = CGSize(width: resize.startFootprint.width + (pointer.x - resize.startPointer.x) / scale,
                                 height: resize.startFootprint.height + (resize.startPointer.y - pointer.y) / scale)
            // No further than the grid holds, or than the screen reaches from here.
            let visible = screen.visibleFrame
            let edgeRoom = CGSize(width: (visible.maxX - resize.topLeft.x) / scale - WidgetLayout.margin / scale,
                                  height: (resize.topLeft.y - visible.minY) / scale - WidgetLayout.margin / scale)
            let capacity = services.widgetRoom(for: instance) ?? edgeRoom
            let room = CGSize(width: min(capacity.width, edgeRoom.width), height: min(capacity.height, edgeRoom.height))
            let result = WidgetResize.resolve(dragged, current: resizeResult?.size ?? instance.size,
                                              sizes: instance.kind.supportedSizes, room: room)
            guard result != resizeResult || window.state.liveSize == nil else { return }
            resizeResult = result
            window.state.liveSize = result.size
            window.state.liveScale = result.scale
            window.state.liveStretch = result.stretch
            window.state.contentScale = scale * result.scale
            let size = CGSize(width: result.footprint.width * scale, height: result.footprint.height * scale)
            window.setFrame(windowFrame(topLeft: resize.topLeft, size: size, contentScale: scale * result.scale), display: true)
            showResizeSlot(for: instance, footprint: result.footprint, in: screen, window: window)
        case .ended:
            guard resize?.id == id else { return }
            let result = resizeResult
            resize = nil
            resizeResult = nil
            gridOverlay.hide()
            // Saved first, so the window's size and content agree throughout.
            if let result { services.resizeWidget(id, to: result) }
            window.state.liveSize = nil
            window.state.liveScale = nil
            window.state.liveStretch = nil
            sync()
        }
    }

    /// The cells a widget being resized will take, from where it stands.
    private func showResizeSlot(for instance: WidgetInstance, footprint: CGSize, in screen: NSScreen, window: NSWindow) {
        let grid = services.widgetGrid(on: screen)
        if !gridOverlay.isShowing || gridOverlay.screen?.displayID != screen.displayID {
            gridOverlay.show(on: screen, grid: grid, scale: services.widgetScale(on: screen),
                             occupied: services.occupiedRects(on: screen, except: instance.id),
                             level: window.level, below: window)
        }
        let cell = grid.nearestCell(to: instance.offset, footprint: footprint).map(grid.offset(of:)) ?? instance.offset
        gridOverlay.highlight(CGRect(origin: cell, size: footprint))
    }

    // MARK: Dropping from the gallery

    /// While a gallery widget is dragged, the grid covers the screen and the
    /// widgets rise above the windows, so it can be dropped into any free slot.
    private func updateDropping() {
        guard let instance = services.ui.widgetDrop else {
            endDropping()
            return
        }
        for window in windows.values { window.level = WidgetWindow.arrangingLevel }
        gridOverlay.onDragUpdate = { [weak self] point in self?.dropMoved(to: point, instance: instance) }
        gridOverlay.onDrop = { [weak self] point in self?.drop(instance, at: point) ?? false }
        showDropGrid(at: NSEvent.mouseLocation, for: instance)
        dropReleasedAt = nil
        dropWatch?.invalidate()
        let watch = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.watchDrop(instance) }
        }
        // Runs during the drag's own event loop too.
        RunLoop.main.add(watch, forMode: .common)
        dropWatch = watch
    }

    /// Follows the pointer to other screens, and ends the drag once the
    /// button is up (the drop itself, if any, arrives first).
    private func watchDrop(_ instance: WidgetInstance) {
        let pointer = NSEvent.mouseLocation
        if NSEvent.pressedMouseButtons & 1 == 0 {
            let released = dropReleasedAt ?? .now
            dropReleasedAt = released
            if Date.now.timeIntervalSince(released) > 0.4 { services.ui.widgetDrop = nil }
            return
        }
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }), screen.displayID != gridOverlay.screen?.displayID {
            showDropGrid(at: pointer, for: instance)
        }
    }

    private func showDropGrid(at point: CGPoint, for instance: WidgetInstance) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.screens.first else { return }
        gridOverlay.show(on: screen, grid: services.widgetGrid(on: screen), scale: services.widgetScale(on: screen),
                         occupied: services.occupiedRects(on: screen),
                         level: NSWindow.Level(rawValue: WidgetWindow.arrangingLevel.rawValue - 1), acceptsDrops: true)
    }

    /// The slot for a widget centered on `point`.
    private func dropSlot(at point: CGPoint, for instance: WidgetInstance) -> (screen: NSScreen, offset: CGPoint)? {
        guard let screen = gridOverlay.screen, let layout = gridOverlay.layoutPoint(point) else { return nil }
        let size = instance.footprint
        let wanted = CGPoint(x: layout.x - size.width / 2, y: layout.y - size.height / 2)
        guard let spot = services.widgetGrid(on: screen).place(size, near: wanted,
                                                               avoiding: services.occupiedRects(on: screen)) else { return nil }
        return (screen, spot)
    }

    private func dropMoved(to point: CGPoint, instance: WidgetInstance) {
        gridOverlay.highlight(dropSlot(at: point, for: instance).map { CGRect(origin: $0.offset, size: instance.footprint) })
    }

    private func drop(_ instance: WidgetInstance, at point: CGPoint) -> Bool {
        guard let slot = dropSlot(at: point, for: instance) else { return false }
        services.addWidget(instance, at: slot)
        services.ui.widgetDrop = nil
        return true
    }

    private func endDropping() {
        dropWatch?.invalidate()
        dropWatch = nil
        gridOverlay.onDragUpdate = nil
        gridOverlay.onDrop = nil
        gridOverlay.hide()
        let level = services.ui.isArrangingWidgets ? WidgetWindow.arrangingLevel : WidgetWindow.desktopLevel
        for window in windows.values { window.level = level }
    }

    private func setArranging(_ arranging: Bool) {
        for window in windows.values {
            window.level = arranging ? WidgetWindow.arrangingLevel : WidgetWindow.desktopLevel
        }
        if arranging {
            showToolbar()
        } else {
            toolbar?.orderOut(nil)
            toolbar = nil
        }
    }

    private func showToolbar() {
        guard toolbar == nil, let screen = NSScreen.screens.first else { return }
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: WidgetWindow.arrangingLevel.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        let hostingView = FirstClickHostingView(rootView: ArrangeToolbar(
            onAdd: { [weak self] in self?.services.openWindow(.gallery(nil)) },
            onDone: { [weak self] in self?.services.ui.isArrangingWidgets = false }
        ))
        hostingView.sizingOptions = []
        panel.contentView = hostingView

        let size = CGSize(width: 480, height: 84)
        let visible = screen.visibleFrame
        panel.setFrame(CGRect(x: visible.midX - size.width / 2, y: visible.minY + 20, width: size.width, height: size.height),
                       display: true)
        panel.orderFront(nil)
        toolbar = panel
    }
}

/// A widget window's content: the widget, with a fresh identity whenever a
/// recycled window takes on a different widget.
private struct WidgetRoot: View {
    let id: UUID
    let services: AppServices
    let window: WidgetWindowState
    let onDrag: @MainActor (WidgetDragPhase) -> Void
    let onResize: @MainActor (WidgetDragPhase) -> Void
    let onRemove: @MainActor () -> Void
    let onConfigure: @MainActor () -> Void

    var body: some View {
        // Laid out at natural size, then drawn larger or smaller as a whole;
        // SwiftUI redraws at the new size, so text and shapes stay sharp. The
        // widget's own scale (from its corner) multiplies the desktop-wide one.
        let instance = services.widgets.instance(id)
        let own = window.liveScale ?? instance?.scale ?? 1
        let stretch = window.liveStretch ?? instance?.stretch ?? 1
        let scale = services.widgetScale(on: instance.flatMap { services.screen(for: $0) }) * own
        // Cinematic faces lay out at the stretched dimensions so their dials and
        // fonts stay proportional to the gallery, instead of stretching pixels.
        let cinematic = instance?.options.cinematicClock == true || instance?.options.cinematicStyle == true
        let scaleY = scale * (cinematic ? 1 : stretch)
        GeometryReader { geometry in
            WidgetHostView(id: id, services: services, window: window, onDrag: onDrag, onResize: onResize,
                           onRemove: onRemove, onConfigure: onConfigure)
                .id(id)
                .frame(width: geometry.size.width / scale, height: geometry.size.height / scaleY)
                .scaleEffect(x: scale, y: scaleY, anchor: .topLeading)
                .environment(\.widgetRenderScale, scale)
        }
    }

    /// What a spare window holds: nothing (no widget has this id).
    static func empty(services: AppServices) -> WidgetRoot {
        WidgetRoot(id: UUID(), services: services, window: WidgetWindowState(), onDrag: { _ in }, onResize: { _ in },
                   onRemove: {}, onConfigure: {})
    }
}

#if DEBUG
extension DesktopWidgetController {
    /// For `-probe resize`: a widget's window, and its corner dragged to `pointer`.
    func debugWindow(_ id: UUID) -> WidgetWindow? { windows[id] }

    func debugResize(_ id: UUID, _ phase: WidgetDragPhase, pointer: CGPoint) {
        windows[id]?.state.isResizing = phase == .changed
        handleResize(id, phase, pointer: pointer)
    }
}
#endif
