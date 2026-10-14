import CoreAudio
import Foundation

/// A process that has set up Core Audio, whether or not it's making sound.
public struct AudioProcess: Equatable, Sendable {
    public let objectID: AudioObjectID
    public let pid: pid_t
    public let bundleID: String?
    /// Sending sound to an output device right now.
    public let isPlaying: Bool
}

public enum AudioProcesses {
    /// Every process Core Audio knows about.
    public static func all() -> [AudioProcess] {
        AudioProperty.objectIDs(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList)
            .compactMap { id in
                guard let pid = AudioProperty.value(id, kAudioProcessPropertyPID, initial: pid_t(-1)), pid > 0 else {
                    return nil
                }
                return AudioProcess(objectID: id, pid: pid,
                                    bundleID: AudioProperty.string(id, kAudioProcessPropertyBundleID),
                                    isPlaying: (AudioProperty.value(id, kAudioProcessPropertyIsRunningOutput, initial: UInt32(0)) ?? 0) != 0)
            }
    }
}

/// Calls back on the main thread each time a Core Audio property changes,
/// until invalidated or released.
public final class AudioPropertyListener {
    private let objectID: AudioObjectID
    private var address: AudioObjectPropertyAddress
    private var block: AudioObjectPropertyListenerBlock?

    public init(_ objectID: AudioObjectID, _ selector: AudioObjectPropertySelector,
                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
                onChange: @escaping @MainActor () -> Void) {
        self.objectID = objectID
        address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
        let block: AudioObjectPropertyListenerBlock = { _, _ in
            MainActor.assumeIsolated { onChange() }
        }
        if AudioObjectAddPropertyListenerBlock(objectID, &address, .main, block) == noErr {
            self.block = block
        }
    }

    public func invalidate() {
        guard let block else { return }
        self.block = nil
        // A process or device that has gone took its listeners with it.
        guard AudioObjectExists(objectID) else { return }
        AudioObjectRemovePropertyListenerBlock(objectID, &address, .main, block)
    }

    deinit {
        invalidate()
    }
}

/// Reading Core Audio properties.
enum AudioProperty {
    static func address(_ selector: AudioObjectPropertySelector,
                        _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func value<Value>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                             scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, initial: Value) -> Value? {
        var address = address(selector, scope)
        var value = initial
        var size = UInt32(MemoryLayout<Value>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0)
        }
        return status == noErr ? value : nil
    }

    static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = address(selector)
        var string: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &string) {
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0)
        }
        guard status == noErr else { return nil }
        return string?.takeRetainedValue() as String?
    }

    static func objectIDs(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                          scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> [AudioObjectID] {
        var address = address(selector, scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return Array(ids.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }

    static func device(forUID uid: String) -> AudioObjectID? {
        var address = address(kAudioHardwarePropertyTranslateUIDToDevice)
        var qualifier = uid as CFString
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = withUnsafeMutablePointer(to: &qualifier) {
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address,
                                       UInt32(MemoryLayout<CFString>.size), $0, &size, &id)
        }
        return status == noErr && id != kAudioObjectUnknown ? id : nil
    }

    static func streamCount(_ device: AudioObjectID, _ scope: AudioObjectPropertyScope) -> Int {
        objectIDs(device, kAudioDevicePropertyStreams, scope: scope).count
    }
}

/// Whether a Core Audio object (a device, a process) still exists.
func AudioObjectExists(_ id: AudioObjectID) -> Bool {
    var address = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyClass, mScope: kAudioObjectPropertyScopeGlobal,
                                             mElement: kAudioObjectPropertyElementMain)
    return AudioObjectHasProperty(id, &address)
}
