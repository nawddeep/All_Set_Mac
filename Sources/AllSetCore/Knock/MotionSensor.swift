import Foundation
import IOKit
import IOKit.hid
import OSLog

/// The accelerometer inside Apple Silicon MacBooks, which sits behind the
/// sensor coprocessor (SPU) and has no public API.
///
/// - It's the `AppleSPUHIDDevice` on vendor usage page 0xFF00, usage 3.
/// - Its driver stays silent until asked to report, which an ordinary process
///   may do: reporting state, power state and interval are written to the
///   `AppleSPUHIDDriver` beneath it. The interval sets the rate; 1 ms gives
///   the fastest the sensor manages, about 794 reports a second.
/// - Each report is 22 bytes: x, y and z are little-endian Int32 at bytes
///   6, 10 and 14, in 16.16 fixed point g.
///
/// Reports arrive on a thread of the sensor's own, so the main thread never
/// sees the firehose; `onSample` is called there.
public final class MotionSensor: @unchecked Sendable {
    public enum Failure: Error, CustomStringConvertible {
        case notFound
        case cannotOpen(IOReturn)

        public var description: String {
            switch self {
            case .notFound: "This Mac has no motion sensor"
            case .cannotOpen(let code): String(format: "The motion sensor couldn't be opened (0x%08x)", code)
            }
        }
    }

    /// Microseconds between reports; the sensor's fastest.
    public static let reportInterval = 1000

    private static let usagePage = 0xFF00
    private static let usage = 3
    private static let log = Logger(subsystem: "com.pratik.allset", category: "knock")

    private let onSample: @Sendable (AccelerometerSample) -> Void
    private let lock = NSLock()
    private var isStopping = false
    private var runLoop: CFRunLoop?
    private var thread: Thread?

    /// `onSample` is called on the sensor's thread, about 794 times a second: keep it quick.
    public init(onSample: @escaping @Sendable (AccelerometerSample) -> Void) {
        self.onSample = onSample
    }

    deinit {
        stop()
    }

    /// Whether this Mac has the sensor at all.
    public static var isAvailable: Bool {
        guard let device = service(class: "AppleSPUHIDDevice") else { return false }
        IOObjectRelease(device)
        return true
    }

    /// Turns the driver's reporting on or off. It stays as set until changed
    /// or the Mac restarts, so switch it off when done listening.
    public static func setReporting(_ on: Bool) {
        guard let driver = service(class: "AppleSPUHIDDriver") else { return }
        defer { IOObjectRelease(driver) }
        let values = [
            ("SensorPropertyReportingState", on ? 1 : 0),
            ("SensorPropertyPowerState", on ? 1 : 0),
            ("ReportInterval", on ? reportInterval : 0),
        ]
        for (key, value) in values {
            let result = IORegistryEntrySetCFProperty(driver, key as CFString, value as CFNumber)
            if result != KERN_SUCCESS {
                log.error("Couldn't set \(key, privacy: .public): \(result)")
            }
        }
    }

    /// Opens the sensor on a new thread, returning once it's open or has failed.
    public func start() throws {
        guard thread == nil else { return }
        let opened = DispatchSemaphore(value: 0)
        let outcome = OpenOutcome()
        lock.withLock { isStopping = false }
        let thread = Thread { [self] in run(opened: opened, outcome: outcome) }
        thread.name = "All Set motion sensor"
        // Reports are time-sensitive; don't queue them behind background work.
        thread.qualityOfService = .userInitiated
        self.thread = thread
        thread.start()
        opened.wait()
        if let failure = outcome.failure {
            self.thread = nil
            throw failure
        }
    }

    /// Closes the sensor. Returns straight away; the thread finishes shortly after.
    public func stop() {
        lock.withLock {
            isStopping = true
            if let runLoop { CFRunLoopStop(runLoop) }
        }
        thread = nil
    }

    /// Decodes one report, or nil if it's too short.
    public static func decode(_ report: UnsafeRawBufferPointer, timestamp: TimeInterval) -> AccelerometerSample? {
        guard report.count >= 18 else { return nil }
        func axis(_ offset: Int) -> Double {
            Double(Int32(littleEndian: report.loadUnaligned(fromByteOffset: offset, as: Int32.self))) / 65536
        }
        return AccelerometerSample(timestamp: timestamp, x: axis(6), y: axis(10), z: axis(14))
    }

    /// Seconds since boot, not counting sleep: the clock `NSEvent.timestamp` uses.
    public static func now() -> TimeInterval {
        Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1_000_000_000
    }

    // MARK: The sensor thread

    private func run(opened: DispatchSemaphore, outcome: OpenOutcome) {
        guard let service = Self.service(class: "AppleSPUHIDDevice") else {
            outcome.failure = .notFound
            opened.signal()
            return
        }
        defer { IOObjectRelease(service) }
        guard let device = IOHIDDeviceCreate(kCFAllocatorDefault, service) else {
            outcome.failure = .notFound
            opened.signal()
            return
        }
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            outcome.failure = .cannotOpen(result)
            opened.signal()
            return
        }

        let sink = ReportSink(onSample: onSample)
        let size = 64
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        buffer.initialize(repeating: 0, count: size)
        IOHIDDeviceRegisterInputReportCallback(device, buffer, size, { context, result, _, _, _, report, length in
            guard let context, result == kIOReturnSuccess else { return }
            Unmanaged<ReportSink>.fromOpaque(context).takeUnretainedValue()
                .deliver(UnsafeRawBufferPointer(start: report, count: length))
        }, Unmanaged.passUnretained(sink).toOpaque())
        let loop = RunLoop.current.getCFRunLoop()
        IOHIDDeviceScheduleWithRunLoop(device, loop, CFRunLoopMode.defaultMode.rawValue)
        let stopping = lock.withLock {
            runLoop = loop
            return isStopping
        }
        opened.signal()
        Self.log.info("Motion sensor open")

        if !stopping {
            // Wakes at least once a second to check for a stop that arrived
            // before the loop was running.
            while !lock.withLock({ isStopping }) {
                if CFRunLoopRunInMode(.defaultMode, 1, false) == .finished {
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
        }

        IOHIDDeviceUnscheduleFromRunLoop(device, loop, CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceRegisterInputReportCallback(device, buffer, size, nil, nil)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        buffer.deallocate()
        lock.withLock { runLoop = nil }
        withExtendedLifetime(sink) {}
        Self.log.info("Motion sensor closed")
    }

    /// The first registered service of `className` on the sensor's usage.
    private static func service(class className: String) -> io_service_t? {
        var iterator: io_iterator_t = IO_OBJECT_NULL
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != IO_OBJECT_NULL {
            if intProperty(service, kIOHIDPrimaryUsagePageKey) == usagePage, intProperty(service, kIOHIDPrimaryUsageKey) == usage {
                return service
            }
            IOObjectRelease(service)
        }
        return nil
    }

    private static func intProperty(_ service: io_service_t, _ key: String) -> Int? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int
    }
}

/// Hands reports from the C callback to Swift, timestamped on arrival.
private final class ReportSink {
    let onSample: @Sendable (AccelerometerSample) -> Void

    init(onSample: @escaping @Sendable (AccelerometerSample) -> Void) {
        self.onSample = onSample
    }

    func deliver(_ report: UnsafeRawBufferPointer) {
        if let sample = MotionSensor.decode(report, timestamp: MotionSensor.now()) {
            onSample(sample)
        }
    }
}

private final class OpenOutcome: @unchecked Sendable {
    var failure: MotionSensor.Failure?
}
