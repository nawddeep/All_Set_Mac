// Whether AVFoundation (what the live wallpaper plays with) can play each
// file: the asset loads as playable, an AVPlayerItem reaches readyToPlay, and
// a frame decodes. Prints one JSON line per file.
//
//     xcrun swift scripts/playcheck.swift file1.mp4 file2.webm …
import AVFoundation
import Foundation

@MainActor
func check(_ path: String) async -> [String: Any] {
    let url = URL(fileURLWithPath: path)
    let asset = AVURLAsset(url: url)
    var result: [String: Any] = ["path": path]
    let playable = (try? await asset.load(.isPlayable)) ?? false
    result["isPlayable"] = playable
    let item = AVPlayerItem(asset: asset)
    let player = AVPlayer(playerItem: item)
    player.isMuted = true
    let start = Date()
    while item.status == .unknown, Date().timeIntervalSince(start) < 8 {
        try? await Task.sleep(for: .milliseconds(50))
    }
    result["ready"] = item.status == .readyToPlay
    if let error = item.error { result["error"] = error.localizedDescription }
    let generator = AVAssetImageGenerator(asset: asset)
    generator.maximumSize = CGSize(width: 320, height: 320)
    result["frame"] = (try? await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600))) != nil
    result["plays"] = playable && item.status == .readyToPlay && (result["frame"] as? Bool ?? false)
    return result
}

let paths = Array(CommandLine.arguments.dropFirst())
Task { @MainActor in
    for path in paths {
        let result = await check(path)
        if let data = try? JSONSerialization.data(withJSONObject: result), let line = String(data: data, encoding: .utf8) {
            print(line)
            fflush(stdout)
        }
    }
    exit(0)
}
RunLoop.main.run()
