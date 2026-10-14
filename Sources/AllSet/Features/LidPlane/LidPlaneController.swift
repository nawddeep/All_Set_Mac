// Adapted from Lid Plane, Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import AllSetCore
import AppKit
import MetalKit
import Observation
import OSLog
import ScreenCaptureKit

final class LidPlaneOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// A display link keeps its target alive; this one only holds the work weakly.
private final class DisplayLinkTarget: NSObject {
    var onFrame: (() -> Void)?
    @objc func frame(_ link: CADisplayLink) { onFrame?() }
}

/// Holds the desktop at an apparent fixed angle and blurs it as the lid closes.
///
/// Sensing, capture and drawing only run while the effect is on: with it off
/// there is no timer, no stream and no Metal device.
@Observable @MainActor
final class LidPlaneController {
    let settings: LidPlaneSettings

    // What the settings page shows.
    private(set) var status = "Off"
    /// The lid angle in degrees; nil without a fresh sensor reading.
    private(set) var angle: Double?
    private(set) var isSimulating = false
    private(set) var hasSensor = false
    private(set) var shortcutAvailable = true
    private(set) var hasScreenAccess = CGPreflightScreenCaptureAccess()
    private(set) var lastProblem: String?

    @ObservationIgnored private var sensor: LidSensor?
    @ObservationIgnored private let environment = LidPlaneDisplay()
    @ObservationIgnored private var safety = DisplaySafetyGate()
    @ObservationIgnored private var motion = LidMotionFilter()
    @ObservationIgnored private var anchor = AutoAnchor(angle: 110, now: 0)
    @ObservationIgnored private var tracker = LidTracker()
    @ObservationIgnored private var intro = FoldIntro()
    @ObservationIgnored private var warmup = CaptureWarmup()
    /// A frame has rendered since the overlay was last hidden.
    @ObservationIgnored private var overlayDrawn = false
    @ObservationIgnored private var renderer: LidPlaneRenderer?
    @ObservationIgnored private var previewRenderer: LidPlaneRenderer?
    @ObservationIgnored private var window: LidPlaneOverlayPanel?
    @ObservationIgnored private var view: MTKView?
    @ObservationIgnored private var capture: LidPlaneCapture?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var timerInterval: TimeInterval = 0
    /// Drives every frame while the fold is moving, at the display's own rate.
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private var displayLinkScreen: CGDirectDisplayID?
    @ObservationIgnored private var builtInScreen: NSScreen?
    @ObservationIgnored private var lastScreenCheck: TimeInterval = -.infinity
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private let logger = Logger(subsystem: "com.pratik.allset", category: "LidPlane")

    @ObservationIgnored private var wantsOverlay = false
    @ObservationIgnored private var starting = false
    @ObservationIgnored private var stoppingCapture = false
    @ObservationIgnored private var suspended = false
    @ObservationIgnored private var hasFrame = false
    @ObservationIgnored private var current = 110.0
    @ObservationIgnored private var lastReading: TimeInterval = 0
    @ObservationIgnored private var previousTick: TimeInterval = 0
    @ObservationIgnored private var lastAnglePoll: TimeInterval = 0
    @ObservationIgnored private var lastSensorReconnect: TimeInterval = 0
    @ObservationIgnored private var demoAngle = 75.0
    @ObservationIgnored private var capturedDisplay: CGDirectDisplayID?
    @ObservationIgnored private var motionSettings: (Bool, Double, Double)?
    /// How many views want a live angle readout (the settings page).
    @ObservationIgnored private var readoutViewers = 0
    @ObservationIgnored private var hotKeyRegistered = false

    init(settings: LidPlaneSettings) {
        self.settings = settings
    }

    /// Observation treats every write as a change, so equal values are skipped.
    private func setStatus(_ text: String) {
        if status != text { status = text }
    }

    // MARK: Lifecycle

    func start() {
        applyShortcut()
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.willSleep() }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.didWake() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.displaysChanged() } })
        if settings.isEnabled { begin() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        stopDisplayLink()
        stopCapture()
        window?.orderOut(nil)
        HotKeyCenter.shared.unregisterAll(group: Self.hotKeyGroup)
    }

    func setEnabled(_ on: Bool) {
        guard on != settings.isEnabled else { return }
        settings.isEnabled = on
        if on { begin() } else { end() }
    }

    func toggleEnabled() {
        setEnabled(!settings.isEnabled)
    }

    private func begin() {
        lastProblem = nil
        hasScreenAccess = CGPreflightScreenCaptureAccess()
        safety.reset()
        _ = prepare()
        anchorHere()
        scheduleTimer()
        update()
    }

    private func end() {
        stopCapture()
        setStatus("Off")
        isSimulating = false
        scheduleTimer()
    }

    // MARK: The settings page

    /// A page that shows the angle live registers itself while on screen.
    func readoutAppeared() {
        readoutViewers += 1
        hasScreenAccess = CGPreflightScreenCaptureAccess()
        scheduleTimer()
    }

    func readoutDisappeared() {
        readoutViewers = max(0, readoutViewers - 1)
        scheduleTimer()
    }

    func anchorHere() {
        if !isSimulating, let angle = sensor?.read() {
            current = angle
            lastReading = CACurrentMediaTime()
            tracker.reset(to: angle, at: lastReading)
        }
        anchor.anchor(at: current, now: CACurrentMediaTime())
        motion.reset(to: settings.angleMode ? min(current, settings.activationAngle) : current)
    }

    func toggleSimulation() {
        guard settings.isEnabled else { return }
        isSimulating.toggle()
        if isSimulating {
            demoAngle = max(10, (settings.angleMode ? settings.activationAngle : anchor.reference) - 35)
        } else {
            resetMotion()
        }
    }

    func requestScreenAccess() {
        if !CGRequestScreenCaptureAccess() {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
        hasScreenAccess = CGPreflightScreenCaptureAccess()
    }

    func applyShortcut() {
        HotKeyCenter.shared.unregisterAll(group: Self.hotKeyGroup)
        hotKeyRegistered = false
        guard settings.shortcutEnabled else { shortcutAvailable = true; return }
        let chord = Shortcut(keyCode: 0x25, modifiers: [.control, .command], key: "L")
        hotKeyRegistered = HotKeyCenter.shared.register(chord, group: Self.hotKeyGroup) { [weak self] in self?.toggleEnabled() }
        shortcutAvailable = hotKeyRegistered
    }

    private static let hotKeyGroup = "lidplane"

    /// A picture of the effect on generated artwork, for the settings page.
    /// Uses its own renderer so a running effect is never disturbed.
    func previewImage(degrees: Double) -> CGImage? {
        if previewRenderer == nil, let gpu = renderer?.gpu ?? MTLCreateSystemDefaultDevice() {
            previewRenderer = try? LidPlaneRenderer(gpu: gpu)
        }
        guard let previewRenderer else { return nil }
        previewRenderer.blur = settings.blur
        previewRenderer.warp = settings.holdAngle
        previewRenderer.perspective = settings.perspective
        return try? previewRenderer.preview(to: nil, angle: Float(degrees * .pi / 180))
    }

    func releasePreview() {
        previewRenderer = nil
    }

    // MARK: Timer

    /// While the fold is live, ticks come from a display link at the screen's
    /// refresh (120 Hz on ProMotion, 60 Hz otherwise). At rest a slow timer
    /// only watches the angle.
    private func scheduleTimer() {
        let live = settings.isEnabled && (capture != nil || wantsOverlay || isSimulating)
        if live, startDisplayLink() {
            timer?.invalidate(); timer = nil; timerInterval = 0
            return
        }
        stopDisplayLink()
        let interval: TimeInterval?
        if settings.isEnabled {
            interval = live ? 1.0 / 60 : 1.0 / 10
        } else if readoutViewers > 0 {
            interval = 0.2
        } else {
            interval = nil
        }
        guard let interval else {
            timer?.invalidate(); timer = nil; timerInterval = 0
            return
        }
        guard interval != timerInterval || timer == nil else { return }
        timer?.invalidate()
        timerInterval = interval
        let next = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    /// False when there is no built-in screen to sync to; the timer covers that.
    private func startDisplayLink() -> Bool {
        guard let screen = usableBuiltInScreen(now: CACurrentMediaTime()),
              let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
        if displayLink != nil, displayLinkScreen == id { return true }
        stopDisplayLink()
        let target = DisplayLinkTarget()
        target.onFrame = { [weak self] in self?.update() }
        let link = screen.displayLink(target: target, selector: #selector(DisplayLinkTarget.frame(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
        displayLinkScreen = id
        return true
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkScreen = nil
    }

    /// `NSScreen.screens` is too slow to walk every frame; a tenth of a second
    /// matches how often the clamshell state is read, and a display change
    /// clears it straight away.
    private func usableBuiltInScreen(now: TimeInterval) -> NSScreen? {
        if now - lastScreenCheck >= 0.1 {
            lastScreenCheck = now
            builtInScreen = LidPlaneDisplay.usableBuiltInScreen()
        }
        return builtInScreen
    }

    // MARK: Overlay

    private func prepare() -> Bool {
        if renderer != nil, window != nil { return true }
        guard let gpu = MTLCreateSystemDefaultDevice() else { fail("Metal is unavailable on this Mac."); return false }
        let made: LidPlaneRenderer
        do { made = try LidPlaneRenderer(gpu: gpu) } catch { fail(error.localizedDescription); return false }
        let panel = LidPlaneOverlayPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Lid Plane Overlay"
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.hasShadow = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isReleasedWhenClosed = false
        // One transformed desktop above ordinary system UI, including the Dock,
        // menu bar and open menus. This does not bypass secure surfaces.
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let mtk = MTKView(frame: .zero, device: gpu)
        mtk.colorPixelFormat = .bgra8Unorm
        // Untagged, captured pixels would be shown as the panel's own colours.
        mtk.colorspace = CGColorSpace(name: LidPlaneCapture.colorSpaceName)
        mtk.isPaused = true
        mtk.enableSetNeedsDisplay = false
        mtk.delegate = made
        mtk.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtk.layer?.isOpaque = false
        mtk.autoresizingMask = [.width, .height]
        panel.contentView = mtk
        made.onRenderComplete = { [weak self] success in
            guard let self, self.wantsOverlay, let window = self.window else { return }
            if success {
                // Shown from the next tick, fading in (see `update`).
                self.overlayDrawn = true
            } else {
                window.orderOut(nil)
                self.logger.error("Overlay render failed; hiding panel")
            }
        }
        renderer = made
        window = panel
        view = mtk
        return true
    }

    private func fitOverlay(to screen: NSScreen) {
        guard let window, let view else { return }
        window.setFrame(screen.frame, display: false)
        view.frame = NSRect(origin: .zero, size: screen.frame.size)
        // A zero-sized MTKView can retain contentsScale == 0 after resizing: a valid
        // drawableSize still renders, but presents no pixels.
        view.layer?.contentsScale = screen.backingScaleFactor
        view.drawableSize = CGSize(width: screen.frame.width * screen.backingScaleFactor,
                                   height: screen.frame.height * screen.backingScaleFactor)
    }

    // MARK: Capture

    private func startCapture() {
        guard settings.isEnabled, !suspended, safety.state == .ready, capture == nil, !stoppingCapture,
              let screen = LidPlaneDisplay.usableBuiltInScreen(),
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              prepare(), let window, let renderer else { return }
        fitOverlay(to: screen)
        // The overlay must exist in the window server for the stream to leave it
        // out, so it's ordered in, fully transparent, before capture starts.
        window.alphaValue = 0
        window.orderFrontRegardless()
        let overlayID = CGWindowID(window.windowNumber)
        capturedDisplay = displayID
        starting = true
        setStatus("Starting…")
        let session = LidPlaneCapture()
        capture = session
        session.onFrame = { [weak self, weak session] buffer in
            guard let self, let session, self.capture === session, self.settings.isEnabled else { return }
            self.hasFrame = renderer.setDesktopFrame(buffer)
        }
        session.onError = { [weak self, weak session] error in
            guard let self, let session, self.capture === session else { return }
            self.captureFailed(error)
        }
        Task { @MainActor in
            do {
                try await session.start(displayID: displayID, excludingWindowID: overlayID)
                guard capture === session, settings.isEnabled else { await session.stop(); return }
                // The next tick names the state: a warmed-up stream may still be armed.
                starting = false
            } catch {
                guard capture === session else { return }
                captureFailed(error)
            }
        }
        scheduleTimer()
    }

    private func stopCapture(resetSimulation: Bool = true) {
        let previous = capture
        capture = nil
        starting = false
        hasFrame = false
        if resetSimulation { isSimulating = false }
        capturedDisplay = nil
        hideOverlay()
        window?.orderOut(nil)
        resetFold()
        renderer?.useArtwork()
        if let previous {
            stoppingCapture = true
            Task { @MainActor in
                await previous.stop()
                stoppingCapture = false
            }
        }
        scheduleTimer()
    }

    private func captureFailed(_ error: Error) {
        let now = CACurrentMediaTime()
        if suspended || environment.lidClosed(now: now) == true || LidPlaneDisplay.usableBuiltInScreen() == nil
            || (now - lastReading <= 1 && current <= 5) {
            stopCapture()
            safety.reset()
            setStatus("Paused · display changing")
            return
        }
        let failure = error as NSError
        stopCapture()
        settings.isEnabled = false
        setStatus("Capture unavailable")
        scheduleTimer()
        hasScreenAccess = CGPreflightScreenCaptureAccess()
        let denied = failure.domain == SCStreamErrorDomain && failure.code == -3801
        lastProblem = denied
            ? "All Set needs Screen & System Audio Recording access to hold the desktop still. Allow it in System Settings → Privacy & Security, then turn the effect on again. After a rebuild, remove the old All Set entry first."
            : "\(failure.localizedDescription) (\(failure.domain) \(failure.code))"
    }

    private func fail(_ message: String) {
        settings.isEnabled = false
        setStatus("Unavailable")
        lastProblem = message
        scheduleTimer()
    }

    // MARK: Each tick

    private func update() {
        guard !suspended else { return }
        let now = CACurrentMediaTime()
        // The angle readout also works while the effect is off. A read costs
        // about 0.3 ms, so even at 120 Hz the hinge is read at most ~80 times a
        // second (every frame at 60 Hz); the easing below fills in between.
        let pollInterval = settings.isEnabled ? 0.012 : 0.2
        if (settings.isEnabled || readoutViewers > 0), now - lastAnglePoll >= pollInterval {
            lastAnglePoll = now
            if sensor == nil { sensor = LidSensor() }
            if let reading = sensor?.read() {
                current = reading
                tracker.reading(reading, at: now)
                lastReading = now
                if abs((angle ?? -1000) - reading) >= 0.5 { angle = reading }
                if !hasSensor { hasSensor = true }
            } else {
                if now - lastReading > 1, angle != nil { angle = nil }
                if hasSensor, now - lastReading > 1 { hasSensor = false }
                if settings.isEnabled, now - lastSensorReconnect > 2 {
                    lastSensorReconnect = now
                    sensor = LidSensor()
                }
            }
        }
        guard settings.isEnabled else { return }
        if renderer == nil, !prepare() { return }
        guard let renderer else { return }
        let motionKey = (settings.angleMode, settings.activationAngle, settings.jitterTolerance)
        if motionSettings.map({ $0 != motionKey }) ?? true {
            motionSettings = motionKey
            resetMotion()
        }
        renderer.blur = settings.blur
        renderer.warp = settings.holdAngle
        renderer.perspective = settings.perspective

        let dt = min(0.1, max(0, now - previousTick))
        previousTick = now
        let freshSensor = now - lastReading <= 1
        let screen = usableBuiltInScreen(now: now)
        let closed = environment.lidClosed(now: now) == true || (freshSensor && current <= 5)
        guard safety.update(lidClosed: closed, builtInAvailable: screen != nil,
                            sensorAvailable: freshSensor || isSimulating, now: now) else {
            if capture != nil || wantsOverlay { stopCapture() }
            setStatus(safety.state.rawValue)
            return
        }
        if let capturedDisplay, let screen,
           screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID != capturedDisplay {
            stopCapture()
            safety.reset()
            return
        }
        // The raw reading decides whether the effect may show at all (the
        // safety rule); the tracked angle is what gets drawn.
        let input = isSimulating ? demoAngle : current
        let tracked = isSimulating ? demoAngle : (tracker.advance(to: now) ?? current)
        let limit = settings.activationAngle
        warmup.update(angle: input, now: now)
        // The simulated fold holds still, so only the real lid has a speed.
        let closingSpeed = isSimulating ? 0 : -tracker.velocity
        let warm = isSimulating || warmup.isWarm(angle: input, limit: limit, angleMode: settings.angleMode,
                                                 closingSpeed: closingSpeed, now: now)
        guard AngleActivation.allows(angle: input, limit: limit, enabled: settings.angleMode) else {
            motion.reset(to: limit)
            resetFold()
            hideOverlay()
            // Heading for the angle: have frames ready before the fold begins.
            if warm { if capture == nil { startCapture() } } else if capture != nil { stopCapture(resetSimulation: false) }
            setStatus("Armed · above \(Int(limit))°")
            return
        }
        let stableAngle = motion.update(tracked, tolerance: isSimulating ? 0 : settings.jitterTolerance)
        anchor.delay = settings.anchorDelay
        anchor.movementThreshold = max(0.1, settings.jitterTolerance)
        anchor.update(angle: stableAngle, now: now, enabled: settings.autoAnchor && !settings.angleMode && !isSimulating)
        let reference = settings.angleMode ? limit : anchor.reference
        // In angle mode the fold never tilts the other way, even when the
        // tracked angle runs a fraction ahead of the raw one near the limit.
        let fold = settings.angleMode ? max(0, reference - stableAngle) : reference - stableAngle
        let target = Float(fold * .pi / 180)
        // Nothing can be drawn before the first desktop frame, so the fold waits
        // at flat rather than running ahead and appearing part-way in. A fold
        // that starts level with the lid then tracks it 1:1; only one that
        // starts behind is eased in.
        if hasFrame {
            renderer.delta = Float(intro.step(toward: Double(target), dt: dt))
        } else {
            resetFold()
        }
        // No stream discovery, desktop frames or GPU draws while visually idle.
        // The motion anchor is independent of stream restarts.
        let demand = abs(target) > abs(renderer.delta) ? target : renderer.delta
        guard CaptureDemand.needsCapture(delta: demand, blur: renderer.blur, warp: renderer.warp) else {
            resetFold()
            hideOverlay()
            if warm { if capture == nil { startCapture() } } else if capture != nil { stopCapture(resetSimulation: false) }
            setStatus("Armed · idle")
            scheduleTimer()
            return
        }
        if capture == nil { startCapture() }
        setStatus(starting ? "Starting…" : (isSimulating ? "Demo" : "On"))
        // The real desktop shows when aligned, avoiding capture latency.
        wantsOverlay = hasFrame && abs(renderer.delta) > 0.002 && (renderer.blur || renderer.warp)
        if wantsOverlay, let window {
            if !window.isVisible {
                window.alphaValue = 0
                window.orderFrontRegardless()
            }
            view?.draw()
            // Dissolve between the real desktop and the overlay over the first
            // 1.5° of fold, both ways, once a frame is on screen.
            if overlayDrawn {
                let alpha = CGFloat(OverlayVisibility.alpha(delta: Double(renderer.delta)))
                if window.alphaValue != alpha { window.alphaValue = alpha }
            }
        } else {
            hideOverlay()
        }
    }

    private func resetFold() {
        intro.reset()
        renderer?.delta = 0
    }

    /// While a stream runs the overlay stays ordered in, fully transparent and
    /// click-through, so the stream can keep leaving it out.
    private func hideOverlay() {
        wantsOverlay = false
        overlayDrawn = false
        guard let window else { return }
        if capture == nil {
            window.orderOut(nil)
        } else if window.alphaValue != 0 {
            window.alphaValue = 0
        }
    }

    private func resetMotion() {
        resetFold()
        hideOverlay()
        anchorHere()
    }

    // MARK: System events

    private func willSleep() {
        suspended = true
        lastScreenCheck = -.infinity
        safety.reset()
        stopCapture()
        if settings.isEnabled { setStatus("Paused · sleeping") }
    }

    private func didWake() {
        suspended = false
        safety.reset()
        lastReading = 0
        tracker.reset()
        sensor = LidSensor()
        if settings.isEnabled { update() }
    }

    private func displaysChanged() {
        lastScreenCheck = -.infinity
        builtInScreen = nil
        stopDisplayLink()
        guard settings.isEnabled else { return }
        // Stop before AppKit can relocate a full-screen panel onto an external screen.
        stopCapture()
        safety.reset()
        setStatus("Waiting for built-in display…")
    }
}
