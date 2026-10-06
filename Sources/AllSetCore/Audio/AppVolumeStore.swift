import CoreAudio
import Foundation
import Observation
import OSLog

/// One app's volume in the mixer.
public struct AppVolume: Codable, Equatable, Sendable {
    /// 0...1, where 1 leaves the app as it is.
    public var level: Double = 1
    public var isMuted = false

    public init(level: Double = 1, isMuted: Bool = false) {
        self.level = level
        self.isMuted = isMuted
    }

    /// Nothing to do: the app plays untouched, with no tap in its way.
    public var isUnchanged: Bool { level >= 0.999 && !isMuted }

    /// The multiplier for each sample. Squared, because loudness is heard
    /// roughly logarithmically: halfway on the slider sounds like half as loud.
    public var gain: Float {
        isMuted ? 0 : Float(pow(min(max(level, 0), 1), 2))
    }
}

/// Per-app volumes, remembered by bundle ID.
@Observable @MainActor
public final class AppVolumeStore {
    public private(set) var volumes: [String: AppVolume] = [:]

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "mixer")

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AllSet/mixer.json")
        volumes = StoreFile.load([String: AppVolume].self, from: self.fileURL) ?? [:]
    }

    public func volume(for bundleID: String) -> AppVolume {
        volumes[bundleID] ?? AppVolume()
    }

    public func set(_ volume: AppVolume, for bundleID: String) {
        volumes[bundleID] = volume.isUnchanged ? nil : volume
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    public func resetAll() {
        volumes.removeAll()
        save()
    }

    public func save() {
        pendingSave?.cancel()
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(volumes).write(to: fileURL, options: .atomic)
        } catch {
            log.error("Couldn't save app volumes: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// The work done on the audio thread for each buffer: copy an app's tapped
/// sound to the speakers, scaled. No allocation, locks or anything else that
/// could stall, since the audio thread must never wait.
public enum AudioPassthrough {
    /// Plays the tap's sound (the input buffers after the first
    /// `skippedBuffers`) into `output`: 32-bit float, interleaved or one
    /// buffer per channel on either side, scaled by a gain that moves from
    /// `startGain` to `endGain` across the buffer so slider moves don't
    /// click, and kept within -1...1.
    ///
    /// Stereo sound on a one-channel device is mixed down, mono sound goes to
    /// both sides of a stereo device, and channels beyond those stay silent,
    /// as they do for stereo sound anywhere.
    public static func render(input: UnsafeMutableAudioBufferListPointer, skippingBuffers skippedBuffers: Int = 0,
                              output: UnsafeMutableAudioBufferListPointer, from startGain: Float, to endGain: Float) {
        let firstBuffer = min(max(skippedBuffers, 0), input.count)
        var inputChannels = 0
        for index in firstBuffer..<input.count {
            inputChannels += Int(input[index].mNumberChannels)
        }
        let outputChannels = output.reduce(0) { $0 + Int($1.mNumberChannels) }

        var channel = 0
        for buffer in output {
            let stride = Int(buffer.mNumberChannels)
            defer { channel += stride }
            guard stride > 0, let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
            let frames = Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * stride)
            let step = frames > 0 ? (endGain - startGain) / Float(frames) : 0
            for offset in 0..<stride {
                let (first, second) = sources(forChannel: channel + offset, outputChannels: outputChannels,
                                              input: input, from: firstBuffer, inputChannels: inputChannels)
                for frame in 0..<frames {
                    var value: Float = 0
                    if let first, frame < first.frames {
                        value = first.data[frame * first.stride + first.offset]
                    }
                    if let second, frame < second.frames {
                        value = (value + second.data[frame * second.stride + second.offset]) * 0.5
                    }
                    let gain = startGain + step * Float(frame)
                    data[frame * stride + offset] = min(max(value * gain, -1), 1)
                }
            }
        }
    }

    private typealias Source = (data: UnsafeMutablePointer<Float>, stride: Int, offset: Int, frames: Int)

    /// The input channels an output channel plays: one, two to mix, or none.
    private static func sources(forChannel channel: Int, outputChannels: Int, input: UnsafeMutableAudioBufferListPointer,
                                from firstBuffer: Int, inputChannels: Int) -> (Source?, Source?) {
        if inputChannels == 0 { return (nil, nil) }
        if outputChannels == 1, inputChannels >= 2 {
            return (locate(0, in: input, from: firstBuffer), locate(1, in: input, from: firstBuffer))
        }
        if channel < inputChannels { return (locate(channel, in: input, from: firstBuffer), nil) }
        if inputChannels == 1, channel == 1 { return (locate(0, in: input, from: firstBuffer), nil) }
        return (nil, nil)
    }

    private static func locate(_ channel: Int, in list: UnsafeMutableAudioBufferListPointer, from firstBuffer: Int) -> Source? {
        var first = 0
        for index in firstBuffer..<list.count {
            let buffer = list[index]
            let count = Int(buffer.mNumberChannels)
            if channel < first + count {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { return nil }
                return (data, count, channel - first, Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * count))
            }
            first += count
        }
        return nil
    }
}
