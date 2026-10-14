import CoreAudio
import Foundation
import Testing
@testable import AllSetCore

/// Audio buffers for a test, freed afterwards.
private final class Buffers {
    let list: UnsafeMutableAudioBufferListPointer
    private var memory: [UnsafeMutablePointer<Float>] = []

    /// Each buffer: its channel count and interleaved samples, or nil for a
    /// buffer with no data (a stream that's switched off).
    init(_ buffers: [(channels: Int, samples: [Float]?)]) {
        list = AudioBufferList.allocate(maximumBuffers: max(buffers.count, 1))
        list.count = buffers.count
        for (index, buffer) in buffers.enumerated() {
            var data: UnsafeMutableRawPointer?
            var bytes = 0
            if let samples = buffer.samples {
                let pointer = UnsafeMutablePointer<Float>.allocate(capacity: max(samples.count, 1))
                pointer.initialize(from: samples, count: samples.count)
                memory.append(pointer)
                data = UnsafeMutableRawPointer(pointer)
                bytes = samples.count * MemoryLayout<Float>.size
            }
            list[index] = AudioBuffer(mNumberChannels: UInt32(buffer.channels), mDataByteSize: UInt32(bytes), mData: data)
        }
    }

    /// Output buffers of the given channel counts, full of leftover noise
    /// that rendering must overwrite.
    convenience init(output channels: [Int], frames: Int) {
        self.init(channels.map { ($0, [Float](repeating: 0.7, count: $0 * frames)) })
    }

    func samples(_ index: Int) -> [Float] {
        let buffer = list[index]
        guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { return [] }
        return Array(UnsafeBufferPointer(start: data, count: Int(buffer.mDataByteSize) / MemoryLayout<Float>.size))
    }

    deinit {
        memory.forEach { $0.deallocate() }
        free(list.unsafeMutablePointer)
    }
}

/// Renders while both sets of buffers are certain to be alive.
private func render(_ input: Buffers, skipping: Int = 0, into output: Buffers, from: Float = 1, to: Float = 1) {
    withExtendedLifetime((input, output)) {
        AudioPassthrough.render(input: input.list, skippingBuffers: skipping, output: output.list, from: from, to: to)
    }
}

private func close(_ actual: [Float], _ expected: [Float]) -> Bool {
    actual.count == expected.count && zip(actual, expected).allSatisfy { abs($0 - $1) < 0.000_01 }
}

@Suite struct AudioPassthroughTests {
    @Test func scalesInterleavedStereo() {
        let input = Buffers([(2, [0.5, -0.5, 0.25, -0.25])])
        let output = Buffers(output: [2], frames: 2)
        render(input, into: output, from: 0.5, to: 0.5)
        #expect(close(output.samples(0), [0.25, -0.25, 0.125, -0.125]))
    }

    @Test func convertsBetweenLayouts() {
        let separate = Buffers([(1, [0.1, 0.2]), (1, [0.3, 0.4])])
        let interleaved = Buffers(output: [2], frames: 2)
        render(separate, into: interleaved)
        #expect(close(interleaved.samples(0), [0.1, 0.3, 0.2, 0.4]))

        let backToSeparate = Buffers(output: [1, 1], frames: 2)
        render(interleaved, into: backToSeparate)
        #expect(close(backToSeparate.samples(0), [0.1, 0.2]))
        #expect(close(backToSeparate.samples(1), [0.3, 0.4]))
    }

    @Test func fitsTheOutputsChannels() {
        // Stereo on a one-channel device is mixed down.
        let stereo = Buffers([(2, [0.2, 0.4, -1, 1])])
        let mono = Buffers(output: [1], frames: 2)
        render(stereo, into: mono)
        #expect(close(mono.samples(0), [0.3, 0]))

        // Mono goes to both sides.
        let monoInput = Buffers([(1, [0.2, 0.4])])
        let both = Buffers(output: [2], frames: 2)
        render(monoInput, into: both)
        #expect(close(both.samples(0), [0.2, 0.2, 0.4, 0.4]))

        // Channels past the sound's own stay silent.
        let surround = Buffers(output: [4], frames: 1)
        render(Buffers([(2, [0.1, 0.2])]), into: surround)
        #expect(close(surround.samples(0), [0.1, 0.2, 0, 0]))
    }

    @Test func skipsTheOutputDevicesOwnInputs() {
        // A headset: its microphone comes first, then the tap.
        let withMicrophone = Buffers([(1, [0.9, 0.9]), (2, [0.1, 0.2, 0.3, 0.4])])
        let output = Buffers(output: [2], frames: 2)
        render(withMicrophone, skipping: 1, into: output)
        #expect(close(output.samples(0), [0.1, 0.2, 0.3, 0.4]))

        // Switched off, the microphone has no data; still skipped.
        let switchedOff = Buffers([(1, nil), (2, [0.1, 0.2, 0.3, 0.4])])
        render(switchedOff, skipping: 1, into: output)
        #expect(close(output.samples(0), [0.1, 0.2, 0.3, 0.4]))
    }

    @Test func rampsGainAcrossTheBuffer() {
        let input = Buffers([(1, [1, 1, 1, 1])])
        let output = Buffers(output: [1], frames: 4)
        render(input, into: output, from: 0, to: 1)
        #expect(close(output.samples(0), [0, 0.25, 0.5, 0.75]))
    }

    @Test func keepsSamplesInRange() {
        let input = Buffers([(2, [0.8, -0.8])])
        let output = Buffers(output: [2], frames: 1)
        render(input, into: output, from: 2, to: 2)
        #expect(close(output.samples(0), [1, -1]))
    }

    @Test func silenceWithoutInput() {
        let output = Buffers(output: [2], frames: 3)
        render(Buffers([]), into: output)
        #expect(output.samples(0) == [Float](repeating: 0, count: 6))

        // Fewer input frames than output: the rest is silent.
        let short = Buffers([(1, [0.5])])
        let longer = Buffers(output: [1], frames: 3)
        render(short, into: longer)
        #expect(close(longer.samples(0), [0.5, 0, 0]))
    }
}

@Suite @MainActor struct AppVolumeTests {
    @Test func loudnessCurve() {
        #expect(AppVolume().isUnchanged)
        #expect(AppVolume().gain == 1)
        #expect(AppVolume(level: 0.5).gain == 0.25)
        #expect(!AppVolume(level: 0.5).isUnchanged)
        #expect(AppVolume(level: 1, isMuted: true).gain == 0)
        #expect(!AppVolume(level: 1, isMuted: true).isUnchanged)
        #expect(AppVolume(level: 3).gain == 1)
    }

    @Test func remembersLevelsAndForgetsFullVolume() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetMixer-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let store = AppVolumeStore(fileURL: file)
        store.set(AppVolume(level: 0.4), for: "com.spotify.client")
        store.set(AppVolume(level: 0.8, isMuted: true), for: "com.hnc.Discord")
        store.set(AppVolume(level: 0.5), for: "com.apple.Safari")
        store.set(AppVolume(), for: "com.apple.Safari")
        store.save()

        let reloaded = AppVolumeStore(fileURL: file)
        #expect(reloaded.volume(for: "com.spotify.client") == AppVolume(level: 0.4))
        #expect(reloaded.volume(for: "com.hnc.Discord") == AppVolume(level: 0.8, isMuted: true))
        #expect(reloaded.volumes["com.apple.Safari"] == nil)
        #expect(reloaded.volume(for: "com.example.new").isUnchanged)

        reloaded.resetAll()
        #expect(AppVolumeStore(fileURL: file).volumes.isEmpty)
    }

    @Test func gainBoxHandsOverNewLevels() {
        let box = GainBox(1)
        box.gain = 0.25
        #expect(box.gain == 0.25)
        #expect(box.current.pointee == 1)
    }

    @Test func errorsReadWell() {
        #expect(AudioRoutingError(step: "Starting playback", status: 0x7768_6F3F).description == "Starting playback failed ('who?')")
        #expect(AudioRoutingError(step: "Capturing Music", status: -50).description == "Capturing Music failed (-50)")
    }
}

@Suite @MainActor struct LiveAudioTests {
    @Test func listsAudioProcesses() {
        let processes = AudioProcesses.all()
        #expect(processes.allSatisfy { $0.pid > 0 && $0.objectID != kAudioObjectUnknown })
        #expect(Set(processes.map(\.objectID)).count == processes.count)
    }

    @Test func readsPermissionWithoutAsking() {
        let status = AudioCapturePermission.status
        #expect([.authorized, .denied, .unknown].contains(status))
    }

    @Test func listsOutputDevices() async throws {
        let monitor = VolumeMonitor()
        monitor.start()
        #expect(!monitor.outputDevices.isEmpty)
        #expect(monitor.outputDevices.allSatisfy { !$0.uid.isEmpty && !$0.uid.hasPrefix(AppAudioTap.uidPrefix) })
        #expect(monitor.outputDevices.contains { $0.id == monitor.deviceID })
    }
}
