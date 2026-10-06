import AppKit
import Foundation
import Observation
import OSLog

/// The detector, fed about 794 times a second from the sensor's thread and
/// told about typing and clicks from the main thread, behind one lock.
final class KnockEngine: @unchecked Sendable {
    struct Output: Sendable {
        var tap: TapObservation?
        var events: [KnockEvent] = []
        /// The strongest movement since the last meter reading.
        var meter: Double?
    }

    /// Meter readings per second.
    static let meterRate = 30.0

    private let lock = NSLock()
    private var detector = KnockDetector()
    private var lastSampleTime: TimeInterval = 0
    private var metering = false
    private var meterPeak = 0.0
    private var meterPublishedAt: TimeInterval = -.infinity
    private let deliver: @Sendable (Output) -> Void

    init(deliver: @escaping @Sendable (Output) -> Void) {
        self.deliver = deliver
    }

    /// Called on the sensor's thread for every sample.
    func process(_ sample: AccelerometerSample) {
        let output: Output? = lock.withLock {
            lastSampleTime = sample.timestamp
            let outcome = detector.process(sample)
            var output = Output(tap: outcome.tap, events: outcome.events)
            // The meter shows the peak of each interval, not a sample picked
            // at random, or a 10 ms knock would usually fall between readings.
            if metering, let magnitude = outcome.magnitude {
                meterPeak = max(meterPeak, magnitude)
                if sample.timestamp - meterPublishedAt >= 1 / Self.meterRate {
                    output.meter = meterPeak
                    meterPeak = 0
                    meterPublishedAt = sample.timestamp
                }
            }
            return output.tap != nil || !output.events.isEmpty || output.meter != nil ? output : nil
        }
        if let output { deliver(output) }
    }

    var configuration: DetectorConfiguration {
        get { lock.withLock { detector.configuration } }
        set { lock.withLock { detector.configuration = newValue } }
    }

    var isMetering: Bool {
        get { lock.withLock { metering } }
        set { lock.withLock { metering = newValue } }
    }

    /// When the last sample arrived, on the sensor's clock.
    var lastSample: TimeInterval { lock.withLock { lastSampleTime } }

    func noteKeyDown(at time: TimeInterval) { lock.withLock { detector.noteKeyDown(at: time) } }
    func notePointerEvent(at time: TimeInterval) { lock.withLock { detector.notePointerEvent(at: time) } }
    func noteWake(at time: TimeInterval) { lock.withLock { detector.noteWake(at: time) } }

    /// Starts fresh: the Mac may have moved since the last sample.
    func reset(at time: TimeInterval) {
        lock.withLock {
            detector.reset()
            lastSampleTime = time
        }
    }
}

/// Listens for knocks on the Mac's case, from the motion sensor.
///
/// The sensor runs only while it's any use: not while the display is off or
/// the Mac is asleep or locked, and (by choice) not in Low Power Mode. Typing
/// and clicking hold knocks off briefly, since both shake the case; watching
/// keys needs Accessibility permission.
@Observable @MainActor
public final class KnockListener {
    public enum Status: Equatable, Sendable {
        case off
        case listening
        /// Enabled, but the sensor is off while the display sleeps, the Mac
        /// is locked or Low Power Mode is on.
        case resting
        case noSensor
        /// The sensor stopped reporting; trying again.
        case retrying
    }

    public private(set) var status = Status.off
    /// Recent movement in g, oldest first, for a live meter. Filled only
    /// while something is metering. Not observed: at 30 readings a second,
    /// redrawing through SwiftUI would cost more than the sensor itself, so
    /// meters draw directly when `onMeter` calls.
    @ObservationIgnored public private(set) var meter: [Double] = []
    @ObservationIgnored public var onMeter: (@MainActor ([Double]) -> Void)?
    /// Goes up by one with every knock felt, whether or not it completes a
    /// sequence: what a meter flashes on.
    public private(set) var tapPulse = 0
    public private(set) var lastTap: TapObservation?

    /// Called with each finished knock sequence.
    @ObservationIgnored public var onKnock: (@MainActor (KnockEvent) -> Void)?

    public var isEnabled = false {
        didSet { if isEnabled != oldValue { update() } }
    }
    public var restsInLowPowerMode = true {
        didSet { if restsInLowPowerMode != oldValue { update() } }
    }
    /// Rests while the Mac runs on its battery. `isOnBattery` is told by the
    /// app, which already watches the power source.
    public var restsOnBattery = true {
        didSet { if restsOnBattery != oldValue { update() } }
    }
    public var isOnBattery = false {
        didSet { if isOnBattery != oldValue { update() } }
    }
    public var configuration = DetectorConfiguration() {
        didSet { engine.configuration = configuration }
    }

    public static let meterLength = 150

    @ObservationIgnored private lazy var engine = KnockEngine { [weak self] output in
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self?.receive(output) }
        }
    }
    @ObservationIgnored private var sensor: MotionSensor?
    @ObservationIgnored private var monitors: [Any] = []
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var watchdog: Timer?
    @ObservationIgnored private var retry: Task<Void, Never>?
    @ObservationIgnored private var retryDelay: TimeInterval = 0.5
    @ObservationIgnored private var meterViewers = 0
    @ObservationIgnored private var isAsleep = false
    @ObservationIgnored private var isDisplayAsleep = false
    @ObservationIgnored private var isLocked = false
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "knock")

    public init() {}

    /// Whether this Mac has a motion sensor to listen with.
    public static var isSupported: Bool { MotionSensor.isAvailable }

    /// Turns the sensor off for good, before quitting.
    public func shutDown() {
        isEnabled = false
        for (center, observer) in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
    }

    // MARK: Meter

    /// Starts filling `meter`; pair with `stopMetering()`.
    public func startMetering() {
        meterViewers += 1
        if meterViewers == 1 {
            meter.removeAll()
            engine.isMetering = true
        }
    }

    public func stopMetering() {
        meterViewers = max(meterViewers - 1, 0)
        if meterViewers == 0 { engine.isMetering = false }
    }

    // MARK: Listening or not

    private var shouldListen: Bool {
        isEnabled && !isAsleep && !isDisplayAsleep && !isLocked
            && !(restsInLowPowerMode && ProcessInfo.processInfo.isLowPowerModeEnabled)
            && !(restsOnBattery && isOnBattery)
    }

    private func update() {
        if isEnabled { watchSystem() }
        if shouldListen {
            open()
        } else {
            close(as: isEnabled ? .resting : .off)
        }
    }

    private func open() {
        guard sensor == nil, retry == nil else { return }
        guard MotionSensor.isAvailable else {
            status = .noSensor
            return
        }
        MotionSensor.setReporting(true)
        engine.configuration = configuration
        // Fresh resting vector, and a moment's grace: the sensor usually
        // starts as the lid opens or the Mac wakes.
        let now = MotionSensor.now()
        engine.reset(at: now)
        engine.noteWake(at: now)
        let sensor = MotionSensor { [engine] sample in engine.process(sample) }
        do {
            try sensor.start()
        } catch {
            log.error("\(String(describing: error), privacy: .public)")
            if case .notFound = error as? MotionSensor.Failure {
                status = .noSensor
            } else {
                scheduleRetry()
            }
            return
        }
        self.sensor = sensor
        status = .listening
        startMonitoringInput()
        startWatchdog()
    }

    private func close(as status: Status) {
        retry?.cancel()
        retry = nil
        watchdog?.invalidate()
        watchdog = nil
        stopMonitoringInput()
        if let sensor {
            sensor.stop()
            self.sensor = nil
            MotionSensor.setReporting(false)
        }
        self.status = status
    }

    /// Reopens after the sensor fell silent or wouldn't open, waiting longer
    /// each time up to 8 seconds.
    private func scheduleRetry() {
        sensor?.stop()
        sensor = nil
        status = .retrying
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, 8)
        retry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            retry = nil
            if shouldListen { open() }
        }
    }

    /// The sensor reports every 1.3 ms, so two quiet seconds mean it has stopped.
    private func startWatchdog() {
        watchdog?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkForSilence() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
    }

    private func checkForSilence() {
        guard sensor != nil else { return }
        if MotionSensor.now() - engine.lastSample > 2 {
            log.error("The motion sensor went quiet; reopening")
            watchdog?.invalidate()
            watchdog = nil
            scheduleRetry()
        } else {
            retryDelay = 0.5
        }
    }

    private func receive(_ output: KnockEngine.Output) {
        if let value = output.meter, meterViewers > 0 {
            meter.append(value)
            if meter.count > Self.meterLength {
                meter.removeFirst(meter.count - Self.meterLength)
            }
            onMeter?(meter)
        }
        if let tap = output.tap {
            lastTap = tap
            tapPulse &+= 1
        }
        for event in output.events {
            log.info("\(event.count.title, privacy: .public) knock")
            onKnock?(event)
        }
    }

    // MARK: Typing, clicking, sleep, locking

    private static let pointerEvents: NSEvent.EventTypeMask = [
        .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
    ]

    /// Keys pressed in other apps reach the global monitor only with
    /// Accessibility permission; the local one covers All Set's own windows.
    private func startMonitoringInput() {
        guard monitors.isEmpty else { return }
        let engine = engine
        let key: (NSEvent) -> Void = { engine.noteKeyDown(at: $0.timestamp) }
        let pointer: (NSEvent) -> Void = { engine.notePointerEvent(at: $0.timestamp) }
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: key),
            NSEvent.addGlobalMonitorForEvents(matching: Self.pointerEvents, handler: pointer),
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { key($0); return $0 },
            NSEvent.addLocalMonitorForEvents(matching: Self.pointerEvents) { pointer($0); return $0 },
        ].compactMap { $0 }
    }

    private func stopMonitoringInput() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    private func watchSystem() {
        guard observers.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        func watch(_ center: NotificationCenter, _ name: Notification.Name, _ handle: @escaping @MainActor (KnockListener) -> Void) {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    handle(self)
                    self.update()
                }
            }
            observers.append((center, observer))
        }
        watch(workspace, NSWorkspace.willSleepNotification) { $0.isAsleep = true }
        watch(workspace, NSWorkspace.didWakeNotification) { $0.isAsleep = false; $0.moved() }
        watch(workspace, NSWorkspace.screensDidSleepNotification) { $0.isDisplayAsleep = true }
        watch(workspace, NSWorkspace.screensDidWakeNotification) { $0.isDisplayAsleep = false; $0.moved() }
        watch(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.isLocked = true }
        watch(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.isLocked = false; $0.moved() }
        watch(.default, .NSProcessInfoPowerStateDidChange) { _ in }
    }

    /// Waking or opening the lid moves the case; ignore it for a moment.
    private func moved() {
        engine.noteWake(at: MotionSensor.now())
    }
}
