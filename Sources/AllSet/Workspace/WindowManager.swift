import AllSetCore
import AppKit
import SwiftUI

/// Moves windows: keyboard shortcuts for layouts, drag-to-edge snapping with a
/// preview, and a memory of where windows were so Restore can put them back.
@MainActor
final class WindowManager {
    private let services: AppServices
    /// Where windows were before All Set moved them, newest last.
    private var history: [(window: AXWindow, frame: CGRect)] = []
    private var drag: DragState?
    private var mouseMonitor: Any?
    private let preview = SnapPreview()

    private struct DragState {
        let window: AXWindow
        let start: CGRect
        var checks = 0
        var isMoving = false
        var zone: WindowAction?
        /// The usable area of the display `zone` is on: the same zone on another
        /// display (or after the Dock moves) is a different target.
        var zoneArea: CGRect?
        var target: CGRect?
    }

    init(services: AppServices) {
        self.services = services
    }

    func start() {
        registerShortcuts()
        observe({ [services] in services.workspaces.settings }) { [weak self] _ in self?.registerShortcuts() }
        observe({ [services] in services.workspaces.workspaces.map(\.shortcut) }) { [weak self] _ in self?.registerShortcuts() }
        observe({ [services] in [services.clipboard.settings.pickerShortcut.map(\.display) ?? "", String(services.clipboard.settings.isEnabled)] }) { [weak self] _ in
            self?.registerShortcuts()
        }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            let type = event.type
            MainActor.assumeIsolated { self?.handleMouse(type) }
        }
    }

    // MARK: Shortcuts

    /// While a shortcut is being recorded, global shortcuts would swallow the
    /// keys being typed, so they're off until recording ends.
    func setRecordingShortcut(_ recording: Bool) {
        if recording {
            HotKeyCenter.shared.unregisterAll()
        } else {
            registerShortcuts()
        }
    }

    private func registerShortcuts() {
        HotKeyCenter.shared.unregisterAll()
        var conflicts = Set<String>()
        let settings = services.workspaces.settings
        if settings.shortcutsEnabled {
            for action in WindowAction.allCases {
                guard let shortcut = settings.shortcut(for: action) else { continue }
                if !HotKeyCenter.shared.register(shortcut, handler: { [weak self] in self?.perform(action) }) {
                    conflicts.insert(action.rawValue)
                }
            }
        }
        for workspace in services.workspaces.workspaces {
            guard let shortcut = workspace.shortcut else { continue }
            let id = workspace.id
            if !HotKeyCenter.shared.register(shortcut, handler: { [weak self] in
                guard let self, let workspace = services.workspaces.workspaces.first(where: { $0.id == id }) else { return }
                Task { await self.services.workspaceController.apply(workspace) }
            }) {
                conflicts.insert(id.uuidString)
            }
        }
        // The clipboard picker's shortcut lives here too, since the hot key
        // center is shared and re-registered as a whole.
        if services.clipboard.settings.isEnabled, let shortcut = services.clipboard.settings.pickerShortcut {
            if !HotKeyCenter.shared.register(shortcut, handler: { [weak self] in
                guard let self else { return }
                ClipboardPickerController.shared.toggle(services: services)
            }) {
                conflicts.insert("clipboard")
            }
        }
        if services.ui.shortcutConflicts != conflicts {
            services.ui.shortcutConflicts = conflicts
        }
    }

    // MARK: Actions

    func perform(_ action: WindowAction) {
        guard Accessibility.isTrusted else {
            Accessibility.requestAccess()
            return
        }
        guard let window = AXWindow.focused(), let current = window.frame.map(appKit) else {
            NSSound.beep()
            return
        }
        let screens = NSScreen.screens
        guard let screen = screen(for: current) else { return }
        let target: CGRect?
        switch action {
        case .restore:
            guard let index = history.lastIndex(where: { $0.window.isSame(as: window) }) else {
                NSSound.beep()
                return
            }
            target = history.remove(at: index).frame
        case .nextDisplay, .previousDisplay:
            guard screens.count > 1, let index = screens.firstIndex(of: screen) else {
                NSSound.beep()
                return
            }
            let step = action == .nextDisplay ? 1 : -1
            let destination = screens[(index + step + screens.count) % screens.count]
            target = WindowLayout.move(current, from: screen.visibleFrame, to: destination.visibleFrame)
        default:
            target = WindowLayout.frame(for: action, window: current, visible: screen.visibleFrame,
                                        gap: services.workspaces.settings.gap)
        }
        guard let target else { return }
        if action != .restore { remember(window, current) }
        window.setFrame(accessibility(target))
    }

    private func remember(_ window: AXWindow, _ frame: CGRect) {
        history.removeAll { $0.window.isSame(as: window) }
        history.append((window, frame))
        if history.count > 50 { history.removeFirst() }
    }

    // MARK: Drag to snap

    private var dragSnapActive: Bool {
        services.workspaces.settings.dragToSnap && !NativeTiling.isEnabled && Accessibility.isTrusted
    }

    private func handleMouse(_ type: NSEvent.EventType) {
        switch type {
        case .leftMouseDown:
            drag = nil
            guard dragSnapActive else { return }
            let point = accessibility(CGRect(origin: NSEvent.mouseLocation, size: .zero)).origin
            guard let window = AXWindow.at(point), window.pid != ProcessInfo.processInfo.processIdentifier,
                  let frame = window.frame else { return }
            drag = DragState(window: window, start: frame)

        case .leftMouseDragged:
            guard var state = drag else { return }
            if !state.isMoving {
                // A drag counts as a move once the window's origin changes but
                // not its size (resizing from an edge changes both).
                state.checks += 1
                if let frame = state.window.frame, frame.size == state.start.size, frame.origin != state.start.origin {
                    state.isMoving = true
                } else if state.checks > 30 {
                    drag = nil
                    return
                }
            }
            if state.isMoving {
                let pointer = NSEvent.mouseLocation
                if let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }),
                   let zone = WindowLayout.snapZone(at: pointer, screen: screen.frame) {
                    if zone != state.zone || screen.visibleFrame != state.zoneArea {
                        state.zone = zone
                        state.zoneArea = screen.visibleFrame
                        state.target = WindowLayout.frame(for: zone, window: appKit(state.start), visible: screen.visibleFrame,
                                                          gap: services.workspaces.settings.gap, cycle: false)
                        if let target = state.target { preview.show(target) }
                    }
                } else if state.zone != nil {
                    state.zone = nil
                    state.zoneArea = nil
                    state.target = nil
                    preview.hide()
                }
            }
            drag = state

        case .leftMouseUp:
            defer {
                drag = nil
                preview.hide()
            }
            guard let state = drag, state.isMoving, let target = state.target else { return }
            remember(state.window, appKit(state.start))
            state.window.setFrame(accessibility(target))

        default:
            break
        }
    }

    // MARK: Geometry

    private var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    private func appKit(_ rect: CGRect) -> CGRect { WindowLayout.flipped(rect, primaryHeight: primaryHeight) }
    private func accessibility(_ rect: CGRect) -> CGRect { WindowLayout.flipped(rect, primaryHeight: primaryHeight) }

    /// The screen showing most of a window.
    private func screen(for frame: CGRect) -> NSScreen? {
        NSScreen.screens.max { a, b in
            a.frame.intersection(frame).width * a.frame.intersection(frame).height
                < b.frame.intersection(frame).width * b.frame.intersection(frame).height
        } ?? NSScreen.main
    }
}

/// The translucent outline showing where a dragged window will snap.
@MainActor
private final class SnapPreview {
    private let panel: NSPanel = {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: SnapPreviewShape())
        host.sizingOptions = []
        panel.contentView = host
        return panel
    }()

    func show(_ frame: CGRect) {
        if panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame.insetBy(dx: frame.width * 0.04, dy: frame.height * 0.04), display: true)
            panel.alphaValue = 0
            panel.orderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                panel.animator().setFrame(frame, display: true)
                panel.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
    }
}

private struct SnapPreviewShape: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.accentColor.opacity(0.16))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.accentColor.opacity(0.75), lineWidth: 2))
            .padding(4)
    }
}
