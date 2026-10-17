import AllSetCore
import Foundation

/// `AllSet library <key>`, typed in Terminal on a Mac the wallpaper library is
/// shared with: saves the library's API key, fetches the list of wallpapers and
/// downloads them. The app shows each one as it lands; nothing here opens it.
///
///     /Applications/AllSet.app/Contents/MacOS/AllSet library <key>
///
/// `--list-only` stops after the list and its pictures (each wallpaper then
/// downloads when it's picked in the app); `--server <address>` names a library
/// other than the one this copy of the app was built for.
struct LibraryCommand {
    private static let usage = """
    Usage: AllSet library <key> [--list-only] [--server <address>]

      <key>          the wallpaper library's API key you were sent
      --list-only    get the list and its pictures; each wallpaper downloads when you pick it
      --server       the library's address, if it isn't the one built into this copy
    """

    private var key: String?
    private var server: String?
    private var listOnly = false
    private var wantsHelp = false

    /// Nil unless the arguments are this command's.
    init?(arguments: [String]) {
        guard arguments.count > 1, arguments[1] == "library" else { return nil }
        var rest = arguments.dropFirst(2).makeIterator()
        while let argument = rest.next() {
            switch argument {
            case "--list-only": listOnly = true
            case "--server": server = rest.next()
            case "-h", "--help": wantsHelp = true
            default:
                if argument.hasPrefix("-") || key != nil { wantsHelp = true } else { key = argument }
            }
        }
    }

    /// The process's exit status: 0 when the library is set up on this Mac.
    func run() async -> Int32 {
        if wantsHelp {
            print(Self.usage)
            return 0
        }
        var key = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if key.isEmpty {
            print("Wallpaper library key: ", terminator: "")
            key = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        guard !key.isEmpty else { return fail("No key given.\n\n\(Self.usage)") }
        let address = server ?? Bundle.main.object(forInfoDictionaryKey: "AllSetLibraryServerURL") as? String
        guard let address, let url = URL(string: address), url.scheme != nil, url.host != nil else {
            return fail("This copy of All Set has no wallpaper library built in. Give its address with --server.")
        }
        let directory = WallpaperStore.defaultDirectory.appendingPathComponent("Library", isDirectory: true)
        let sync = LibrarySync(server: url, key: key, directory: directory)

        print("Checking the key with the wallpaper library…")
        let catalog: WallpaperLibraryCatalog
        do {
            catalog = try await sync.fetchCatalog()
        } catch {
            return fail(error.localizedDescription)
        }
        guard LibraryKey.store(key) else { return fail("Couldn't save the key in this Mac's Keychain.") }
        if sync.hasOwnLibrary {
            LibraryKey.announceChange()
            print("Key saved. This Mac keeps its own wallpaper library, so there is nothing to download: "
                  + "All Set now fetches from the library anything this Mac has freed.")
            return 0
        }
        do {
            try sync.save(catalog)
        } catch {
            return fail("Couldn't save the list of wallpapers: \(error.localizedDescription)")
        }
        LibraryKey.announceChange()

        let (pictures, videos) = sync.missing(in: catalog)
        let total = videos.reduce(0) { $0 + $1.size }
        print("Key saved. \(catalog.items.count) wallpapers are now in All Set, under Wallpaper.")
        if !pictures.isEmpty { print("Getting their pictures (\(pictures.count))…") }
        if listOnly {
            let summary = await sync.download(catalog, options: .init(catalogOnly: true), changed: LibraryKey.announceChange)
            print(summary.failed == 0 ? "Done. Each wallpaper downloads when you pick it in All Set."
                  : "Done, but \(summary.failed) pictures couldn't be fetched. Run the same command again to get them.")
            return 0
        }
        if !videos.isEmpty {
            print("Then downloading \(videos.count) wallpapers (\(size(total))), smallest first. "
                  + "They appear in All Set as they arrive.\nStop any time with Control-C; run the same command again to carry on.")
        }
        let ticker = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if !Task.isCancelled { print("  … \(size(sync.progress.received)) downloaded so far") }
            }
        }
        let summary = await sync.download(catalog, freeSpace: {
            (try? directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
                .volumeAvailableCapacityForImportantUsage
        }, finished: { video, done, total, error in
            let count = "\(done)/\(total)"
            if let error {
                print("  \(count)  couldn't get \(video.title): \(error.localizedDescription)")
            } else {
                print("  \(count)  \(video.title)  (\(size(video.size)))")
            }
        }, changed: LibraryKey.announceChange)
        ticker.cancel()

        print("\nDone: \(summary.downloaded) wallpapers downloaded.")
        if summary.leftForLater > 0 {
            print("\(summary.leftForLater) more were left on the library to keep 10 GB free on this Mac. "
                  + "Each one downloads when you pick it in All Set.")
        }
        if summary.failed > 0 {
            print("\(summary.failed) files couldn't be downloaded. Run the same command again to get them.")
        }
        return summary.failed == 0 ? 0 : 1
    }

    private func fail(_ message: String) -> Int32 {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        return 1
    }
}

private func size(_ bytes: Int64) -> String {
    bytes.formatted(.byteCount(style: .file))
}
