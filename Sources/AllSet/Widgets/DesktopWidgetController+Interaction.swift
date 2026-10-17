import AllSetCore
import AppKit
import SwiftUI

/// Arranging, corner resizing and dropping widgets from the gallery.
extension DesktopWidgetController {
    // MARK: Arranging

    func handleDrag(_ id: UUID, _ phase: WidgetDragPhase) {
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
    func slot(for instance: WidgetInstance, in window: NSWindow) -> (screen: NSScreen, offset: CGPoint, grid: WidgetGrid, swap: UUID?)? {
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

    func showSlot(for instance: WidgetInstance, in window: NSWindow) {
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
    func handleResize(_ id: UUID, _ phase: WidgetDragPhase, pointer: CGPoint = NSEvent.mouseLocation) {
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
    func showResizeSlot(for instance: WidgetInstance, footprint: CGSize, in screen: NSScreen, window: NSWindow) {
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
    func updateDropping() {
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
        watch.tolerance = 0.01
        // Runs during the drag's own event loop too.
        RunLoop.main.add(watch, forMode: .common)
        dropWatch = watch
    }

    /// Follows the pointer to other screens, and ends the drag once the
    /// button is up (the drop itself, if any, arrives first).
    func watchDrop(_ instance: WidgetInstance) {
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

    func showDropGrid(at point: CGPoint, for instance: WidgetInstance) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.screens.first else { return }
        gridOverlay.show(on: screen, grid: services.widgetGrid(on: screen), scale: services.widgetScale(on: screen),
                         occupied: services.occupiedRects(on: screen),
                         level: NSWindow.Level(rawValue: WidgetWindow.arrangingLevel.rawValue - 1), acceptsDrops: true)
    }

    /// The slot for a widget centered on `point`.
    func dropSlot(at point: CGPoint, for instance: WidgetInstance) -> (screen: NSScreen, offset: CGPoint)? {
        guard let screen = gridOverlay.screen, let layout = gridOverlay.layoutPoint(point) else { return nil }
        let size = instance.footprint
        let wanted = CGPoint(x: layout.x - size.width / 2, y: layout.y - size.height / 2)
        guard let spot = services.widgetGrid(on: screen).place(size, near: wanted,
                                                               avoiding: services.occupiedRects(on: screen)) else { return nil }
        return (screen, spot)
    }

    func dropMoved(to point: CGPoint, instance: WidgetInstance) {
        gridOverlay.highlight(dropSlot(at: point, for: instance).map { CGRect(origin: $0.offset, size: instance.footprint) })
    }

    func drop(_ instance: WidgetInstance, at point: CGPoint) -> Bool {
        guard let slot = dropSlot(at: point, for: instance) else { return false }
        services.addWidget(instance, at: slot)
        services.ui.widgetDrop = nil
        return true
    }

    func endDropping() {
        dropWatch?.invalidate()
        dropWatch = nil
        gridOverlay.onDragUpdate = nil
        gridOverlay.onDrop = nil
        gridOverlay.hide()
        let level = services.ui.isArrangingWidgets ? WidgetWindow.arrangingLevel : WidgetWindow.desktopLevel
        for window in windows.values { window.level = level }
    }

    func setArranging(_ arranging: Bool) {
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

    func showToolbar() {
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
