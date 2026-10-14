import CoreAudio
import CPrivateAPIs
import Foundation
import OSLog

/// A Core Audio call that failed.
public struct AudioRoutingError: Error, CustomStringConvertible {
    public let step: String
    public let status: OSStatus

    public var description: String {
        // Most Core Audio errors are four letters, like 'who?'.
        let bytes = withUnsafeBytes(of: UInt32(bitPattern: status).bigEndian) { Array($0) }
        let code = bytes.allSatisfy { (32...126).contains($0) } ? "'\(String(decoding: bytes, as: UTF8.self))'" : "\(status)"
        return "\(step) failed (\(code))"
    }

    static func check(_ status: OSStatus, _ step: String) throws {
        guard status == noErr else { throw AudioRoutingError(step: step, status: status) }
    }
}

/// One app's gain, shared with the audio thread.
public final class GainBox: @unchecked Sendable {
    /// Written by the app, read by the audio thread once per buffer: the Float's
    /// bits, through atomic load/store (lock-free, so the audio thread never waits).
    /// A plain load/store of the same size isn't synchronisation (review R3).
    private let target = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
    /// The audio thread's own: where the last buffer ended, for the next to ramp from.
    let current = UnsafeMutablePointer<Float>.allocate(capacity: 1)

    public init(_ gain: Float) {
        target.initialize(to: gain.bitPattern)
        current.initialize(to: gain)
    }

    /// Takes effect over the next buffer.
    public var gain: Float {
        get { loadTarget() }
        set { allset_atomic_store_u32(target, newValue.bitPattern) }
    }

    /// The gain the app last set, as the audio thread reads it.
    func loadTarget() -> Float {
        Float(bitPattern: allset_atomic_load_u32(target))
    }

    deinit {
        target.deallocate()
        current.deallocate()
    }
}

/// Plays one app's sound through All Set so its volume can change: a process
/// tap takes the app's sound (and silences it at the source), and a private
/// aggregate device plays it on the output device at the chosen gain.
///
/// Not thread-safe; `AppAudioRouter` uses it from its queue only.
final class AppAudioTap {
    /// Start of the UIDs of the mixer's own devices, so they can be told apart.
    static let uidPrefix = "com.pratik.allset.mixer."

    let name: String
    private(set) var processes: [AudioObjectID]
    private(set) var outputUID: String
    private(set) var isRunning = false

    private let gain: GainBox
    private let tapUUID = UUID()
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let log = Logger(subsystem: "com.pratik.allset", category: "mixer")

    init(name: String, processes: [AudioObjectID], outputUID: String, gain: GainBox) throws {
        self.name = name
        self.processes = processes
        self.outputUID = outputUID
        self.gain = gain
        try makeTap()
        do {
            try makeDevice()
        } catch {
            destroyTap()
            throw error
        }
    }

    deinit {
        invalidate()
    }

    /// Follows the app as its helper processes come and go.
    func setProcesses(_ processes: [AudioObjectID]) throws {
        guard processes != self.processes else { return }
        var address = AudioProperty.address(kAudioTapPropertyDescription)
        let description = Self.description(of: processes, uuid: tapUUID, name: name)
        let status = withUnsafePointer(to: description) {
            AudioObjectSetPropertyData(tapID, &address, 0, nil, UInt32(MemoryLayout<CATapDescription>.size), $0)
        }
        self.processes = processes
        guard status != noErr else { return }

        // The tap can't be changed in place; build it again.
        log.info("Rebuilding the tap for \(self.name, privacy: .public): \(AudioRoutingError(step: "Updating", status: status).description, privacy: .public)")
        let wasRunning = isRunning
        destroyDevice()
        destroyTap()
        try makeTap()
        try makeDevice()
        if wasRunning { try start() }
    }

    /// Moves playback to another output device.
    func setOutput(_ uid: String) throws {
        guard uid != outputUID else { return }
        let wasRunning = isRunning
        destroyDevice()
        outputUID = uid
        try makeDevice()
        if wasRunning { try start() }
    }

    func start() throws {
        guard !isRunning, let procID else { return }
        try AudioRoutingError.check(AudioDeviceStart(deviceID, procID), "Starting playback")
        isRunning = true
    }

    func stop() {
        guard isRunning, let procID else { return }
        AudioDeviceStop(deviceID, procID)
        isRunning = false
    }

    /// Hands the app its sound back.
    func invalidate() {
        destroyDevice()
        destroyTap()
    }

    private static func description(of processes: [AudioObjectID], uuid: UUID, name: String) -> CATapDescription {
        let description = CATapDescription(stereoMixdownOfProcesses: processes)
        description.uuid = uuid
        description.name = "All Set: \(name)"
        description.isPrivate = true
        // Silent at the source whether or not playback here is running, so a
        // turned-down app never blares for a moment when it starts to play.
        description.muteBehavior = .muted
        return description
    }

    private func makeTap() throws {
        var id = AudioObjectID(kAudioObjectUnknown)
        try AudioRoutingError.check(
            AudioHardwareCreateProcessTap(Self.description(of: processes, uuid: tapUUID, name: name), &id),
            "Capturing \(name)")
        tapID = id
    }

    private func makeDevice() throws {
        let composition: [String: Any] = [
            kAudioAggregateDeviceNameKey: "All Set: \(name)",
            kAudioAggregateDeviceUIDKey: Self.uidPrefix + UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: false,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: tapUUID.uuidString,
                                               kAudioSubTapDriftCompensationKey: true]],
        ]
        var id = AudioObjectID(kAudioObjectUnknown)
        try AudioRoutingError.check(AudioHardwareCreateAggregateDevice(composition as CFDictionary, &id),
                                    "Setting up playback")
        deviceID = id

        // The aggregate's input starts with the output device's own inputs
        // (a headset's microphone), then the tap. Those are skipped, and
        // switched off below.
        let skipped = AudioProperty.device(forUID: outputUID).map { AudioProperty.streamCount($0, kAudioObjectPropertyScopeInput) } ?? 0
        let gain = self.gain
        var procID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, id, nil) { _, input, _, output, _ in
            let target = gain.loadTarget()
            AudioPassthrough.render(input: UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input)),
                                    skippingBuffers: skipped,
                                    output: UnsafeMutableAudioBufferListPointer(output),
                                    from: gain.current.pointee, to: target)
            gain.current.pointee = target
        }
        guard status == noErr, let procID else {
            destroyDevice()
            throw AudioRoutingError(step: "Setting up playback", status: status)
        }
        self.procID = procID
        if skipped > 0 { turnOffInputs(skipped, procID: procID) }
    }

    /// Keeps the output device's microphone off. Using it would light up
    /// the microphone indicator and switch AirPods to their low-quality
    /// headset mode.
    private func turnOffInputs(_ count: Int, procID: AudioDeviceIOProcID) {
        let streams = AudioProperty.streamCount(deviceID, kAudioObjectPropertyScopeInput)
        guard streams > count,
              let flags = MemoryLayout<AudioHardwareIOProcStreamUsage>.offset(of: \.mStreamIsOn),
              let number = MemoryLayout<AudioHardwareIOProcStreamUsage>.offset(of: \.mNumberStreams) else { return }
        let size = flags + MemoryLayout<UInt32>.stride * streams
        let usage = UnsafeMutableRawPointer.allocate(byteCount: size,
                                                     alignment: MemoryLayout<AudioHardwareIOProcStreamUsage>.alignment)
        defer { usage.deallocate() }
        usage.storeBytes(of: unsafeBitCast(procID, to: UnsafeMutableRawPointer.self), as: UnsafeMutableRawPointer.self)
        usage.storeBytes(of: UInt32(streams), toByteOffset: number, as: UInt32.self)
        for stream in 0..<streams {
            usage.storeBytes(of: stream < count ? 0 : 1, toByteOffset: flags + MemoryLayout<UInt32>.stride * stream, as: UInt32.self)
        }
        var address = AudioProperty.address(kAudioDevicePropertyIOProcStreamUsage, kAudioObjectPropertyScopeInput)
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(size), usage)
        if status != noErr {
            log.error("Couldn't turn off the output device's inputs: \(status)")
        }
    }

    private func destroyDevice() {
        guard deviceID != kAudioObjectUnknown else { return }
        stop()
        if let procID {
            AudioDeviceDestroyIOProcID(deviceID, procID)
        }
        procID = nil
        AudioHardwareDestroyAggregateDevice(deviceID)
        deviceID = AudioObjectID(kAudioObjectUnknown)
    }

    private func destroyTap() {
        guard tapID != kAudioObjectUnknown else { return }
        AudioHardwareDestroyProcessTap(tapID)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }
}

/// Keeps one `AppAudioTap` for each app whose volume isn't 100%. Core Audio
/// takes a moment to build and tear down devices, so that happens on a queue
/// of its own and the interface never waits for it.
public final class AppAudioRouter: @unchecked Sendable {
    public struct Request: Equatable, Sendable {
        /// The app's bundle ID.
        public let id: String
        public let name: String
        public let processes: [AudioObjectID]
        /// Playback runs only while the app makes sound, so the output device
        /// can rest and the Mac can sleep.
        public let isPlaying: Bool
        public let gain: GainBox

        public init(id: String, name: String, processes: [AudioObjectID], isPlaying: Bool, gain: GainBox) {
            self.id = id
            self.name = name
            self.processes = processes
            self.isPlaying = isPlaying
            self.gain = gain
        }

        public static func == (lhs: Request, rhs: Request) -> Bool {
            lhs.id == rhs.id && lhs.name == rhs.name && lhs.processes == rhs.processes
                && lhs.isPlaying == rhs.isPlaying && lhs.gain === rhs.gain
        }
    }

    private struct Failure {
        let processes: [AudioObjectID]
        let outputUID: String
        let message: String
    }

    /// Stopping and removing wait a little, so a pause between songs or a
    /// slider dragged through 100% doesn't tear everything down.
    private struct Pending: Hashable {
        enum Kind { case stop, removal }
        let kind: Kind
        let id: String
    }

    private let queue = DispatchQueue(label: "com.pratik.allset.mixer", qos: .userInitiated)
    // The rest is only touched on `queue`.
    private var taps: [String: AppAudioTap] = [:]
    private var pending: [Pending: DispatchWorkItem] = [:]
    /// Not retried until something about the app or output changes.
    private var failures: [String: Failure] = [:]
    private let log = Logger(subsystem: "com.pratik.allset", category: "mixer")

    public init() {}

    /// Brings the taps in line with `requests`, then reports the apps whose
    /// sound couldn't be routed, and why.
    public func apply(_ requests: [Request], outputUID: String,
                      completion: @escaping @MainActor @Sendable ([String: String]) -> Void) {
        queue.async { [self] in
            let wanted = Set(requests.map(\.id))
            for id in taps.keys where !wanted.contains(id) {
                cancel(.stop, id)
                schedule(.removal, id, after: 1.5) { router in
                    router.taps.removeValue(forKey: id)?.invalidate()
                }
            }
            failures = failures.filter { wanted.contains($0.key) }

            for request in requests {
                cancel(.removal, request.id)
                if taps[request.id] == nil, let failure = failures[request.id],
                   failure.processes == request.processes, failure.outputUID == outputUID {
                    continue
                }
                do {
                    let tap: AppAudioTap
                    if let existing = taps[request.id] {
                        try existing.setProcesses(request.processes)
                        try existing.setOutput(outputUID)
                        tap = existing
                    } else {
                        tap = try AppAudioTap(name: request.name, processes: request.processes,
                                              outputUID: outputUID, gain: request.gain)
                        taps[request.id] = tap
                    }
                    failures[request.id] = nil
                    if request.isPlaying {
                        cancel(.stop, request.id)
                        try tap.start()
                    } else if tap.isRunning {
                        schedule(.stop, request.id, after: 2) { router in
                            router.taps[request.id]?.stop()
                        }
                    }
                } catch {
                    log.error("\(request.name, privacy: .public): \(String(describing: error), privacy: .public)")
                    cancel(.stop, request.id)
                    taps.removeValue(forKey: request.id)?.invalidate()
                    failures[request.id] = Failure(processes: request.processes, outputUID: outputUID,
                                                   message: String(describing: error))
                }
            }
            let report = failures.mapValues(\.message)
            Task { @MainActor in completion(report) }
        }
    }

    /// Hands every app its sound back, before quitting.
    public func removeAll() {
        queue.sync {
            for work in pending.values {
                work.cancel()
            }
            pending.removeAll()
            for tap in taps.values {
                tap.invalidate()
            }
            taps.removeAll()
        }
    }

    private func schedule(_ kind: Pending.Kind, _ id: String, after delay: TimeInterval,
                          _ action: @escaping @Sendable (AppAudioRouter) -> Void) {
        let key = Pending(kind: kind, id: id)
        guard pending[key] == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            pending[key] = nil
            action(self)
        }
        pending[key] = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancel(_ kind: Pending.Kind, _ id: String) {
        pending.removeValue(forKey: Pending(kind: kind, id: id))?.cancel()
    }
}
