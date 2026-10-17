import AppKit
import Observation
import OSLog

/// Now Playing state and playback control for whatever app is playing: Music,
/// Spotify, browsers and anything else that reports to Control Center.
///
/// macOS 15.4+ only shares this with Apple-signed processes, so the work happens
/// in a helper library that `/usr/bin/perl` loads (see MediaHelper.m). This
/// class runs that process, parses its JSON lines, and sends it commands.
@Observable @MainActor
public final class MediaController {
    public private(set) var info: NowPlayingInfo?
    public private(set) var artwork: NSImage?
    /// A vivid color from the artwork, for tinting controls.
    public private(set) var accentColor: NSColor?
    public private(set) var isAvailable = true
    public private(set) var unavailableReason: String?

    @ObservationIgnored public var onChange: (@MainActor () -> Void)?

    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var input: FileHandle?
    @ObservationIgnored private var artworkID: String?
    @ObservationIgnored private var isStopping = false
    /// Restarts after a failure, this launch: at most `maximumRetries`, each
    /// after a longer wait (2, 4, 8 s), then Now Playing is marked unavailable.
    @ObservationIgnored private var retries = 0
    @ObservationIgnored private var readyTimeout: Task<Void, Never>?
    nonisolated static let maximumRetries = 3
    nonisolated static let readyDeadline: Duration = .seconds(3)
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "media")

    nonisolated static let helperLibraryName = "libAllSetMediaHelper.dylib"
    /// Must match the fatal exit status in MediaHelper.m.
    nonisolated static let unavailableExitStatus: Int32 = 2

    nonisolated static let loaderScript = """
        use strict; use warnings; use DynaLoader;
        my $path = shift @ARGV or die "missing helper path\\n";
        my $lib = DynaLoader::dl_load_file($path, 0) or die "cannot load helper: " . DynaLoader::dl_error() . "\\n";
        my $run = DynaLoader::dl_find_symbol($lib, "allset_media_run") or die "helper has no entry point\\n";
        DynaLoader::dl_install_xsub("main::allset_media_run", $run);
        main::allset_media_run();
        """

    public init() {}

    public func start() {
        guard process == nil else { return }
        guard Capabilities.shared.isEnabled(.nowPlaying) else {
            markUnavailable("Now Playing is switched off on this Mac (capability.nowPlaying.disabled).")
            return
        }
        guard let library = Self.helperLibraryURL() else {
            markUnavailable("The media helper library is missing from the app.")
            Capabilities.shared.report(.nowPlaying, .unavailable("the helper library is missing"))
            return
        }
        isStopping = false

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = ["-e", Self.loaderScript, library.path]
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        let reader = LineReader { [weak self] line in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.handle(line) }
            }
        }
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                reader.append(data)
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { [log] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                log.error("helper: \(String(decoding: data, as: UTF8.self), privacy: .public)")
            }
        }
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            let pid = process.processIdentifier
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.helperExited(pid: pid, status: status) }
            }
        }

        do {
            try process.run()
        } catch {
            markUnavailable("Couldn't start /usr/bin/perl: \(error.localizedDescription)")
            Capabilities.shared.report(.nowPlaying, .unavailable("/usr/bin/perl couldn't start"))
            return
        }
        self.process = process
        input = stdin.fileHandleForWriting
        isAvailable = true
        // The helper says "ready" once MediaRemote is loaded; silence means it's stuck.
        readyTimeout?.cancel()
        readyTimeout = Task { [weak self] in
            try? await Task.sleep(for: Self.readyDeadline)
            guard !Task.isCancelled, let self, self.process === process else { return }
            log.error("Media helper didn't answer within 3 s")
            Capabilities.shared.report(.nowPlaying, .failed("the helper didn't answer within 3 seconds"))
            process.terminate()  // helperExited decides whether to try again
        }
    }

    public func stop() {
        isStopping = true
        readyTimeout?.cancel()
        try? input?.close()
        process?.terminate()
        process = nil
        input = nil
    }

    // MARK: Commands

    public func togglePlayPause() {
        send("toggle")
        guard var updated = info else { return }
        updated.elapsedTime = updated.elapsed()
        updated.timestamp = .now
        updated.isPlaying.toggle()
        setInfo(updated)
    }

    public func nextTrack() { send("next") }

    public func previousTrack() { send("previous") }

    public func seek(to seconds: TimeInterval) {
        send("seek \(seconds)")
        guard var updated = info else { return }
        updated.elapsedTime = seconds
        updated.timestamp = .now
        setInfo(updated)
    }

    public func openSourceApp() {
        guard let id = info?.bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func send(_ command: String) {
        guard let input else { return }
        do {
            try input.write(contentsOf: Data((command + "\n").utf8))
        } catch {
            log.error("Couldn't send \(command, privacy: .public) to helper: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Helper output

    private func handle(_ line: Data) {
        guard let message = try? JSONDecoder().decode(MediaHelperMessage.self, from: line) else { return }
        switch message.type {
        case "nowPlaying":
            apply(message)
        case "ready":
            readyTimeout?.cancel()
            retries = 0
            Capabilities.shared.report(.nowPlaying, .available)
        case "error":
            markUnavailable(message.message ?? "Now Playing isn't available.")
            Capabilities.shared.report(.nowPlaying, .unavailable(message.message ?? "MediaRemote refused"))
        default:
            break
        }
    }

    private func apply(_ message: MediaHelperMessage) {
        let newInfo = NowPlayingInfo(message: message)

        if let base64 = message.artwork, let data = Data(base64Encoded: base64), let image = NSImage(data: data) {
            setArtwork(image, id: message.artworkID)
        } else if newInfo == nil {
            setArtwork(nil, id: nil)
        } else if let id = message.artworkID, id != artworkID {
            // Artwork we never received; show none rather than the old one.
            setArtwork(nil, id: nil)
        } else if message.artworkID == nil, newInfo?.trackKey != info?.trackKey {
            setArtwork(nil, id: nil)
        }
        setInfo(newInfo)
    }

    private func setInfo(_ newInfo: NowPlayingInfo?) {
        guard newInfo != info else { return }
        info = newInfo
        onChange?()
    }

    private func setArtwork(_ image: NSImage?, id: String?) {
        artworkID = id
        artwork = image
        accentColor = image.flatMap(ArtworkPalette.accentColor(for:))
    }

    private func helperExited(pid: Int32, status: Int32) {
        // A helper stopped earlier can finish exiting after its replacement started.
        guard process == nil || process?.processIdentifier == pid else { return }
        process = nil
        input = nil
        guard !isStopping else { return }
        readyTimeout?.cancel()
        if status == Self.unavailableExitStatus {
            markUnavailable(unavailableReason ?? "Now Playing isn't available on this Mac.")
            Capabilities.shared.report(.nowPlaying, .unavailable(unavailableReason ?? "MediaRemote isn't available"))
            return
        }
        log.error("Media helper exited with status \(status)")
        guard retries < Self.maximumRetries else {
            markUnavailable("The media helper keeps stopping (exit status \(status)).")
            Capabilities.shared.report(.nowPlaying, .failed("the helper stopped \(retries + 1) times"))
            return
        }
        retries += 1
        let wait = Self.retryDelay(attempt: retries)
        Task { [weak self] in
            try? await Task.sleep(for: wait)
            self?.start()
        }
    }

    private func markUnavailable(_ reason: String) {
        log.error("Now Playing unavailable: \(reason, privacy: .public)")
        isAvailable = false
        unavailableReason = reason
        setArtwork(nil, id: nil)
        setInfo(nil)
    }

    /// 2, 4, 8 seconds: never a tight loop.
    nonisolated static func retryDelay(attempt: Int) -> Duration {
        .seconds(2 << max(0, min(attempt - 1, 4)))
    }

    /// Next to the executable when run from `.build`, or in Contents/Frameworks
    /// inside the app bundle.
    nonisolated static func helperLibraryURL() -> URL? {
        [Bundle.main.privateFrameworksURL, Bundle.main.executableURL?.deletingLastPathComponent()]
            .compactMap { $0?.appendingPathComponent(helperLibraryName) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
