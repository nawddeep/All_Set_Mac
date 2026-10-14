import AudioToolbox
import CoreAudio
import Foundation
import Observation

public enum AudioDeviceKind: Sendable {
    case builtIn
    case headphones
    case airPods
    case bluetooth
    case display
    case airPlay
    case other

    public var symbolName: String {
        switch self {
        case .builtIn: "laptopcomputer"
        case .headphones: "headphones"
        case .airPods: "airpods"
        case .bluetooth: "hifispeaker.fill"
        case .display: "tv"
        case .airPlay: "airplayaudio"
        case .other: "speaker.wave.2.fill"
        }
    }
}

public struct AudioOutputDevice: Identifiable, Equatable, Sendable {
    public let id: AudioObjectID
    public let uid: String
    public let name: String
    public let kind: AudioDeviceKind
}

/// Watches the default output device's volume and mute state, and which device
/// is the default, through Core Audio property listeners.
@Observable @MainActor
public final class VolumeMonitor {
    public private(set) var volume: Float = 0
    public private(set) var isMuted = false
    public private(set) var hasVolumeControl = false
    public private(set) var deviceName = ""
    public private(set) var deviceKind: AudioDeviceKind = .other
    public private(set) var deviceID = AudioObjectID(kAudioObjectUnknown)
    /// Every device that can play sound, for choosing where audio goes.
    public private(set) var outputDevices: [AudioOutputDevice] = []

    @ObservationIgnored public var onVolumeChange: (@MainActor (Float, Bool) -> Void)?
    @ObservationIgnored public var onDeviceChange: (@MainActor (String, AudioDeviceKind) -> Void)?
    /// Also told when the output device changes, so the mixer can follow it.
    @ObservationIgnored public var onOutputChange: (@MainActor () -> Void)?

    @ObservationIgnored private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    @ObservationIgnored private var deviceListListener: AudioObjectPropertyListenerBlock?
    @ObservationIgnored private var deviceListener: AudioObjectPropertyListenerBlock?
    /// Changes made from inside the app (its sliders) don't pop up the volume
    /// indicator until this passes; it would just repeat what the slider shows.
    @ObservationIgnored private var quietUntil = ContinuousClock.now

    private static var defaultOutputAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                   mScope: kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain)
    }
    private static var volumeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                                   mScope: kAudioDevicePropertyScopeOutput,
                                   mElement: kAudioObjectPropertyElementMain)
    }
    private static var muteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
                                   mScope: kAudioDevicePropertyScopeOutput,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    public init() {}

    public func start() {
        guard defaultDeviceListener == nil else { return }
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.defaultDeviceChanged() }
        }
        var address = Self.defaultOutputAddress
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        defaultDeviceListener = listener
        bind(to: Self.defaultOutputDevice())

        let devicesChanged: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.reloadDevices() }
        }
        var devicesAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                        mScope: kAudioObjectPropertyScopeGlobal,
                                                        mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddress, .main, devicesChanged)
        deviceListListener = devicesChanged
        reloadDevices()
    }

    /// Makes a device the one all sound plays through.
    public func selectOutput(_ id: AudioObjectID) {
        var address = Self.defaultOutputAddress
        var device = id
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
                                   UInt32(MemoryLayout<AudioObjectID>.size), &device)
    }

    public static func uid(of id: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &uid) { AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0) }
        guard status == noErr else { return nil }
        return uid?.takeRetainedValue() as String?
    }

    private func reloadDevices() {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids)
        let devices = ids.compactMap { id -> AudioOutputDevice? in
            var canBeDefault = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceCanBeDefaultDevice,
                                                          mScope: kAudioDevicePropertyScopeOutput,
                                                          mElement: kAudioObjectPropertyElementMain)
            var value: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            // Microphones and hidden devices can't be chosen for output; nor
            // can the mixer's own private devices.
            guard AudioObjectGetPropertyData(id, &canBeDefault, 0, nil, &size, &value) == noErr, value != 0,
                  let uid = Self.uid(of: id), !uid.hasPrefix(AppAudioTap.uidPrefix),
                  let name = Self.name(of: id) else { return nil }
            return AudioOutputDevice(id: id, uid: uid, name: name, kind: Self.kind(of: id, name: name))
        }
        if devices != outputDevices { outputDevices = devices }
    }

    /// Sets the output volume. `announce` pops up the volume indicator, as the
    /// volume keys do; leave it off for sliders, which show the level themselves.
    public func setVolume(_ value: Float, announce: Bool = false) {
        guard hasVolumeControl else { return }
        if !announce { quietUntil = .now + .milliseconds(600) }
        var address = Self.volumeAddress
        var level = Float32(min(max(value, 0), 1))
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &level)
        if isMuted, level > 0 { setMuted(false, announce: announce) }
    }

    public func setMuted(_ muted: Bool, announce: Bool = false) {
        if !announce { quietUntil = .now + .milliseconds(600) }
        var address = Self.muteAddress
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }

    private func defaultDeviceChanged() {
        let newID = Self.defaultOutputDevice()
        guard newID != deviceID else { return }
        bind(to: newID)
        onDeviceChange?(deviceName, deviceKind)
        onOutputChange?()
    }

    private func bind(to id: AudioObjectID) {
        // A device that has gone (headphones unplugged) has no listeners left to remove.
        if let deviceListener, deviceID != kAudioObjectUnknown, AudioObjectExists(deviceID) {
            var volume = Self.volumeAddress
            var mute = Self.muteAddress
            AudioObjectRemovePropertyListenerBlock(deviceID, &volume, .main, deviceListener)
            AudioObjectRemovePropertyListenerBlock(deviceID, &mute, .main, deviceListener)
        }

        deviceID = id
        deviceName = Self.name(of: id) ?? "Speakers"
        deviceKind = Self.kind(of: id, name: deviceName)

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.volumeChanged() }
        }
        var volumeAddress = Self.volumeAddress
        var muteAddress = Self.muteAddress
        // Some outputs (many displays) report a volume they won't let anyone change.
        var settable: DarwinBoolean = false
        hasVolumeControl = AudioObjectHasProperty(id, &volumeAddress)
            && AudioObjectIsPropertySettable(id, &volumeAddress, &settable) == noErr && settable.boolValue
        if AudioObjectHasProperty(id, &volumeAddress) {
            AudioObjectAddPropertyListenerBlock(id, &volumeAddress, .main, listener)
        }
        if AudioObjectHasProperty(id, &muteAddress) {
            AudioObjectAddPropertyListenerBlock(id, &muteAddress, .main, listener)
        }
        deviceListener = listener
        volume = Self.readVolume(id) ?? 0
        isMuted = Self.readMute(id) ?? false
    }

    private func volumeChanged() {
        let newVolume = Self.readVolume(deviceID) ?? volume
        let newMuted = Self.readMute(deviceID) ?? isMuted
        // Devices often notify once per channel for a single key press.
        guard abs(newVolume - volume) > 0.001 || newMuted != isMuted else { return }
        volume = newVolume
        isMuted = newMuted
        if ContinuousClock.now >= quietUntil { onVolumeChange?(newVolume, newMuted) }
    }

    private static func defaultOutputDevice() -> AudioObjectID {
        var address = defaultOutputAddress
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return id
    }

    private static func readVolume(_ id: AudioObjectID) -> Float? {
        var address = volumeAddress
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func readMute(_ id: AudioObjectID) -> Bool? {
        var address = muteAddress
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr ? value != 0 : nil
    }

    private static func name(of id: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &name) {
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0)
        }
        guard status == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }

    private static func kind(of id: AudioObjectID, name: String) -> AudioDeviceKind {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(id, &address, 0, nil, &size, &transport)

        let lowercased = name.lowercased()
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn:
            return lowercased.contains("headphone") ? .headphones : .builtIn
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            if lowercased.contains("airpods") { return .airPods }
            if ["headphone", "buds", "beats"].contains(where: lowercased.contains) { return .headphones }
            return .bluetooth
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return .display
        case kAudioDeviceTransportTypeAirPlay:
            return .airPlay
        default:
            return .other
        }
    }
}
