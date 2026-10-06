// What looping a video as a wallpaper costs: this process, the system video
// decoder (VTDecoderXPCService) and WindowServer, over 15 s of playback in a
// screen-sized window. One line per file.
//
//     xcrun swift scripts/playcost.swift file.mp4 …
import AppKit
import AVFoundation

func cpuTime(_ pid: Int32) -> Double {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/ps")
    task.arguments = ["-o", "cputime=", "-p", String(pid)]
    let pipe = Pipe()
    task.standardOutput = pipe
    try? task.run()
    task.waitUntilExit()
    let text = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = text.split(separator: ":").compactMap { Double($0) }
    return parts.reduce(0) { $0 * 60 + $1 }
}

func pids(_ name: String) -> [Int32] {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    task.arguments = ["-x", name]
    let pipe = Pipe()
    task.standardOutput = pipe
    try? task.run()
    task.waitUntilExit()
    return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).split(separator: "\n").compactMap { Int32($0) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let paths = Array(CommandLine.arguments.dropFirst())
Task { @MainActor in
    let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1470, height: 956)
    let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView?.wantsLayer = true
    let layer = AVPlayerLayer()
    layer.frame = window.contentView!.bounds
    layer.videoGravity = .resizeAspectFill
    window.contentView!.layer!.addSublayer(layer)
    window.orderFrontRegardless()
    let me = ProcessInfo.processInfo.processIdentifier
    for path in paths {
        let item = AVPlayerItem(url: URL(fileURLWithPath: path))
        let player = AVQueuePlayer()
        let looper = AVPlayerLooper(player: player, templateItem: item)
        player.isMuted = true
        layer.player = player
        player.play()
        try? await Task.sleep(for: .seconds(4))
        let decoders = pids("VTDecoderXPCService"), server = pids("WindowServer")
        let m0 = cpuTime(me), d0 = decoders.map(cpuTime).reduce(0, +), w0 = server.map(cpuTime).reduce(0, +)
        try? await Task.sleep(for: .seconds(15))
        let m1 = cpuTime(me), d1 = pids("VTDecoderXPCService").map(cpuTime).reduce(0, +), w1 = server.map(cpuTime).reduce(0, +)
        print(String(format: "app %5.1f%%  decoder %5.1f%%  WindowServer %5.1f%%  %@", (m1 - m0) / 15 * 100, max(d1 - d0, 0) / 15 * 100,
                     (w1 - w0) / 15 * 100, (path as NSString).lastPathComponent))
        fflush(stdout)
        player.pause()
        layer.player = nil
        withExtendedLifetime(looper) {}
    }
    exit(0)
}
app.run()
