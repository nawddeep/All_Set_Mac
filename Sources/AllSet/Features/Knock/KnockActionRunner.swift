import AllSetCore
import AppKit
import QuartzCore

/// Carries out knock actions. Each returns why it failed, if it did, in
/// words fit to show.
@MainActor
enum KnockActionRunner {
    static func run(_ action: KnockAction, services: AppServices) async -> String? {
        if action.needsAccessibility, !Accessibility.isTrusted {
            Accessibility.requestAccess()
            return "Needs Accessibility permission"
        }
        switch action {
        case .toggleIsland:
            return toggleIsland(nil, services: services)
        case .openIsland(let tab):
            return toggleIsland(tab, services: services)
        case .clipboardHistory:
            ClipboardPickerController.shared.toggle(services: services)
        case .toggleWidgets:
            services.settings.showWidgets.toggle()
        case .toggleWallpaper:
            services.wallpaper.config.isEnabled.toggle()
        case .applyWorkspace(let id, _):
            guard let workspace = services.workspaces.workspaces.first(where: { $0.id == id }) else {
                return "That workspace was deleted"
            }
            await services.workspaceController.apply(workspace)
        case .moveWindow(let windowAction):
            services.windowManager?.perform(windowAction)
        case .openAllSet:
            services.openWindow()

        case .playPause: postMediaKey(16)
        case .nextTrack: postMediaKey(17)
        case .previousTrack: postMediaKey(18)

        case .volumeUp, .volumeDown:
            let volume = services.volume
            guard volume.hasVolumeControl else { return "\(volume.deviceName) has no volume control" }
            // A sixteenth, like the volume keys.
            volume.setVolume(volume.volume + (action == .volumeUp ? 1 : -1) / 16, announce: true)
        case .toggleMute:
            services.volume.setMuted(!services.volume.isMuted, announce: true)

        case .lockScreen: postKey(0x0C, [.maskControl, .maskCommand])
        case .screenshot:
            // Interactive, to the clipboard; waits for the selection.
            return await CommandRunner.run("/usr/sbin/screencapture", ["-i", "-c"], timeout: nil)
        case .aiScreenshot:
            await ScreenshotStudioController.shared.capture(services: services)
        case .missionControl:
            return await CommandRunner.run("/usr/bin/open", ["-a", "Mission Control"], timeout: 10)
        case .nextDesktop: postKey(0x7C, .maskControl)
        case .previousDesktop: postKey(0x7B, .maskControl)
        case .showDesktop: postKey(0x67, [])

        case .copy: postKey(0x08, .maskCommand)
        case .paste: postKey(0x09, .maskCommand)
        case .undo: postKey(0x06, .maskCommand)
        case .closeWindow: postKey(0x0D, .maskCommand)
        case .nextTab: postKey(0x1E, [.maskCommand, .maskShift])
        case .previousTab: postKey(0x21, [.maskCommand, .maskShift])

        case .openApp(let bundleID, let name):
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                return "\(name) isn't installed"
            }
            do {
                _ = try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            } catch {
                return error.localizedDescription
            }
        case .runShortcut(let name):
            return await CommandRunner.run("/usr/bin/shortcuts", ["run", name], timeout: 60)
        case .shellCommand(let command):
            guard !command.trimmingCharacters(in: .whitespaces).isEmpty else { return "No command set" }
            // The login shell, so the command sees the usual PATH.
            return await CommandRunner.run("/bin/zsh", ["-lc", command], timeout: 30)

        case .screenFlash: ScreenOverlay.flash()
        case .ripple: ScreenOverlay.ripple()
        case .playSound(let name):
            guard let sound = NSSound(named: name) else { return "No sound called \(name)" }
            sound.play()
        }
        return nil
    }

    private static func toggleIsland(_ tab: IslandTab?, services: AppServices) -> String? {
        guard services.settings.notchEnabled, let notch = services.notch else { return "The Dynamic Island is off" }
        let islandTab: NotchViewModel.Tab? = switch tab {
        case .home: .home
        case .tray: .tray
        case .sound: .mixer
        case .notes: .notes
        case .system: .system
        case nil: nil
        }
        notch.toggleIsland(tab: islandTab)
        return nil
    }

    /// A shortcut, as if typed, to the app in front.
    private static func postKey(_ key: CGKeyCode, _ flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }

    /// A hardware media key (play 16, next 17, previous 18): it reaches
    /// whichever app is playing, and needs no permission.
    private static func postMediaKey(_ key: Int) {
        for isDown in [true, false] {
            let state = isDown ? 0xA : 0xB
            let event = NSEvent.otherEvent(with: .systemDefined, location: .zero,
                                           modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
                                           timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0,
                                           context: nil, subtype: 8, data1: (key << 16) | (state << 8), data2: -1)
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}

/// Runs a command without blocking, stopping it if it takes too long.
// `CommandRunner` is in AllSetCore (Support/CommandRunner.swift).

/// Brief effects drawn over everything, passing clicks through.
@MainActor
enum ScreenOverlay {
    /// Kept until their animation ends; nothing else holds them.
    private static var windows: [NSWindow] = []

    /// A white flash across every screen.
    static func flash() {
        for screen in NSScreen.screens {
            present(on: screen, for: 0.3) { layer, _ in
                let fade = CABasicAnimation(keyPath: "backgroundColor")
                fade.fromValue = NSColor.white.withAlphaComponent(0.55).cgColor
                fade.toValue = NSColor.white.withAlphaComponent(0).cgColor
                fade.duration = 0.3
                fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
                layer.backgroundColor = NSColor.clear.cgColor
                layer.add(fade, forKey: "flash")
            }
        }
    }

    /// A ring spreading out from the pointer.
    static func ripple() {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(location, $0.frame, false) }) ?? NSScreen.main else {
            return
        }
        present(on: screen, for: 0.6) { layer, frame in
            let center = CGPoint(x: location.x - frame.minX, y: location.y - frame.minY)
            func circle(_ diameter: CGFloat) -> CGPath {
                CGPath(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter),
                       transform: nil)
            }
            let ring = CAShapeLayer()
            ring.path = circle(340)
            ring.fillColor = nil
            ring.strokeColor = NSColor.white.cgColor
            ring.lineWidth = 3
            ring.opacity = 0
            layer.addSublayer(ring)
            let grow = CABasicAnimation(keyPath: "path")
            grow.fromValue = circle(24)
            grow.toValue = circle(340)
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.9
            fade.toValue = 0
            let group = CAAnimationGroup()
            group.animations = [grow, fade]
            group.duration = 0.6
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ring.add(group, forKey: "ripple")
        }
    }

    private static func present(on screen: NSScreen, for duration: TimeInterval, draw: (CALayer, CGRect) -> Void) {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        window.contentView = view
        window.setFrame(screen.frame, display: false)
        if let layer = view.layer { draw(layer, screen.frame) }
        windows.append(window)
        window.orderFrontRegardless()
        Task {
            try? await Task.sleep(for: .seconds(duration))
            window.orderOut(nil)
            windows.removeAll { $0 === window }
        }
    }
}
