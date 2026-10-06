import Foundation
import Testing
@testable import AllSetCore

/// These run against the real machine, so they check shape and sanity rather
/// than exact values.
@Suite @MainActor struct LiveSystemTests {
    @Test func samplesThisMac() async throws {
        let monitor = SystemMonitor()
        monitor.setViewer("test", visible: true)
        monitor.activeInterval = 0.2
        monitor.start()
        defer { monitor.stop() }
        // CPU usage needs two samples to diff. Waited for, not assumed after a
        // fixed pause: with other suites busy on the main actor, half a second
        // was sometimes too short (4 runs in 20), which failed this test for
        // no fault of the monitor's.
        for _ in 0..<100 where monitor.cpuHistory.values.count < 2 || monitor.snapshot.topApps.isEmpty {
            try await Task.sleep(for: .milliseconds(100))
        }

        let snapshot = monitor.snapshot
        #expect(snapshot.cpu.perCore.count == ProcessInfo.processInfo.processorCount)
        #expect(snapshot.cpu.perCore.allSatisfy { (0...1).contains($0) })
        #expect(snapshot.memory.total == ProcessInfo.processInfo.physicalMemory)
        #expect(snapshot.memory.used > 0 && snapshot.memory.used <= snapshot.memory.total)
        #expect(snapshot.disk.total > 0)
        #expect(monitor.cpuHistory.values.count >= 2)
        // At least this test process is busy enough to register.
        #expect(!snapshot.topApps.isEmpty)
        #expect(snapshot.topApps.count <= 5)

        #if arch(arm64)
        // A CI virtual machine has no temperature sensors, GPU readings or core kinds.
        guard !TestEnvironment.isCI else { return }
        #expect(snapshot.cpu.coreKinds.contains(.efficiency))
        #expect(snapshot.cpu.coreKinds.contains(.performance))
        #expect(snapshot.gpu != nil)
        let soc = try #require(snapshot.temperatures.soc)
        #expect((10...110).contains(soc))
        #endif
    }
}

/// Runs the real media helper through /usr/bin/perl, exactly as the app does.
@Suite struct MediaHelperTests {
    /// `swift build` puts the helper next to the other build products.
    static let helperURL: URL? = {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(".build/debug/\(MediaController.helperLibraryName)")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }()

    @Test(.enabled(if: helperURL != nil, "Run `swift build` first to build the helper"),
          .disabled(if: TestEnvironment.isCI, "Needs a logged-in Mac with Now Playing, not a CI virtual machine"))
    func helperLoadsInPerlAndReportsState() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = ["-e", MediaController.loaderScript, try #require(Self.helperURL).path]
        let stdin = Pipe()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout

        let lines = Collected()
        let reader = LineReader { lines.append(String(decoding: $0, as: UTF8.self)) }
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil } else { reader.append(data) }
        }
        try process.run()
        defer { if process.isRunning { process.terminate() } }

        for _ in 0..<50 where lines.values.count < 2 {
            try await Task.sleep(for: .milliseconds(100))
        }
        let messages = lines.values.compactMap {
            try? JSONDecoder().decode(MediaHelperMessage.self, from: Data($0.utf8))
        }
        #expect(messages.first?.type == "ready")
        #expect(messages.dropFirst().first?.type == "nowPlaying")

        // Closing stdin is how the app tells the helper to quit.
        try stdin.fileHandleForWriting.close()
        for _ in 0..<30 where process.isRunning {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(!process.isRunning)
        #expect(process.terminationStatus == 0)
    }
}
