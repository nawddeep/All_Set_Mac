import AllSetCore
import AppKit
import SwiftUI

/// Where All Set keeps a person's data, and backing it up and restoring it
/// (`DataArchive`).
@MainActor
enum AppData {
    static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AllSet", isDirectory: true)
    }

    /// The preferences domain: the bundle's, or the process's when run unbundled.
    static var settingsDomain: String { Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName }

    static var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev" }

    enum LaunchRestore {
        case applied(DataArchive.Manifest, previous: URL)
        case failed(String)
    }

    /// What happened to a restore that was waiting when the app started.
    private(set) static var launchRestore: LaunchRestore?

    /// Swaps in a restore staged before the last quit. Must run before any
    /// store is created, so every store reads the restored files.
    static func applyStagedRestore() {
        do {
            guard let applied = try DataArchive.applyStaged(in: root) else { return }
            if var settings = applied.settings {
                // This Mac's own state isn't in a backup and isn't replaced by one.
                let current = UserDefaults.standard.persistentDomain(forName: settingsDomain) ?? [:]
                for key in DataArchive.machineStateKeys { settings[key] = current[key] }
                UserDefaults.standard.setPersistentDomain(settings, forName: settingsDomain)
            }
            launchRestore = .applied(applied.manifest, previous: applied.previous)
        } catch {
            launchRestore = .failed((error as? DataArchive.Failure)?.description ?? error.localizedDescription)
        }
    }

    /// Says, once, how a restore at launch went.
    static func presentLaunchRestoreOutcome() {
        guard let outcome = launchRestore else { return }
        launchRestore = nil
        let alert = NSAlert()
        switch outcome {
        case .applied(let manifest, let previous):
            alert.messageText = "Your All Set data was restored"
            alert.informativeText = "From the backup made \(manifest.created.formatted(date: .abbreviated, time: .shortened)). "
                + "What was here before is kept in \u{201C}\(previous.lastPathComponent)\u{201D} in All Set\u{2019}s data folder, "
                + "in case you want it back."
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Show in Finder")
            if alert.runModal() == .alertSecondButtonReturn { NSWorkspace.shared.activateFileViewerSelecting([previous]) }
        case .failed(let why):
            alert.alertStyle = .warning
            alert.messageText = "The restore wasn\u{2019}t applied"
            alert.informativeText = why
            alert.runModal()
        }
    }

    /// Asks where, then writes a backup there. Returns what to tell the person,
    /// or nil if they cancelled.
    static func export(options: DataArchive.Options) async -> String? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "All Set Backup \(Date.now.formatted(.iso8601.year().month().day()))"
        panel.prompt = "Export"
        panel.message = "A backup is a folder of ordinary files. Anyone who has it can read it."
        guard panel.runModal() == .OK, let destination = panel.url else { return nil }
        // The save panel has already asked about replacing what's there.
        if FileManager.default.fileExists(atPath: destination.path) {
            do {
                try FileManager.default.trashItem(at: destination, resultingItemURL: nil)
            } catch {
                return "Couldn\u{2019}t replace what was there: \(error.localizedDescription)"
            }
        }
        let root = root, version = version, domain = settingsDomain
        let result = await Task.detached(priority: .userInitiated) { () -> Result<DataArchive.Manifest, Error> in
            let settings = UserDefaults.standard.persistentDomain(forName: domain) ?? [:]
            return Result { try DataArchive.export(from: root, settings: settings, to: destination, options: options, appVersion: version) }
        }.value
        switch result {
        case .success(let manifest):
            NSWorkspace.shared.activateFileViewerSelecting([destination])
            let size = ByteCountFormatter.string(fromByteCount: Int64(manifest.totalBytes), countStyle: .file)
            return "Exported \(manifest.files.count) files (\(size))."
        case .failure(let error):
            return (error as? DataArchive.Failure)?.description ?? error.localizedDescription
        }
    }

    /// Asks which backup, checks all of it, asks to confirm, then stages it and
    /// restarts so it's applied before anything reads the old files. Returns
    /// what to tell the person if it didn't go ahead, or nil if they cancelled.
    static func restore() async -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Choose Backup"
        panel.message = "Choose an All Set backup folder."
        guard panel.runModal() == .OK, let archive = panel.url else { return nil }
        let checked = await Task.detached(priority: .userInitiated) { Result { try DataArchive.verify(archive) } }.value
        guard case .success(let manifest) = checked else {
            if case .failure(let error) = checked { return (error as? DataArchive.Failure)?.description ?? error.localizedDescription }
            return nil
        }

        let alert = NSAlert()
        alert.messageText = "Restore this backup?"
        var carries = "your widgets, notes, workspaces, pictures and settings"
        if manifest.includesClipboard { carries += ", clipboard history" }
        if manifest.includesWallpaperLibrary { carries += ", the wallpaper library" }
        alert.informativeText = "Made \(manifest.created.formatted(date: .abbreviated, time: .shortened)) by All Set \(manifest.appVersion): "
            + "\(carries). All Set will restart. What you have now is kept in its data folder, not deleted."
        alert.addButton(withTitle: "Restore and Restart")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        let root = root
        let staged = await Task.detached(priority: .userInitiated) { Result { try DataArchive.stage(archive, in: root) } }.value
        if case .failure(let error) = staged { return (error as? DataArchive.Failure)?.description ?? error.localizedDescription }
        restart()
        return nil
    }

    /// Quits, and opens the app again when it was started from its bundle.
    private static func restart() {
        let bundle = Bundle.main.bundlePath
        if bundle.hasSuffix(".app") {
            let reopen = Process()
            reopen.executableURL = URL(fileURLWithPath: "/bin/sh")
            reopen.arguments = ["-c", "sleep 1.5; /usr/bin/open \"$0\"", bundle]
            try? reopen.run()
        }
        NSApp.terminate(nil)
    }
}

/// What All Set keeps, where, and backing it up: on the General page.
struct DataPrivacySettings: View {
    let services: AppServices

    @State private var includesClipboard = false
    @State private var includesLibrary = false
    @State private var status: String?
    @State private var isWorking = false

    var body: some View {
        Section {
            LabeledContent {
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([AppData.root]) }
            } label: {
                Text("Where it\u{2019}s kept")
                Text("Widgets, notes, workspaces, imported pictures, clipboard history and wallpapers are files in one folder on this Mac. Nothing is sent anywhere unless you set up your own wallpaper server.")
            }
            LabeledContent {
                Text(services.clipboard.settings.isEnabled ? "On, \(services.clipboard.items.count) items" : "Off")
                    .foregroundStyle(.secondary)
            } label: {
                Text("Clipboard history")
                Text("Turn it on or off, set how long copies are kept, or erase everything on the Clipboard page.")
            }
        } header: {
            Text("Your data")
        }

        Section {
            SettingToggle("Include clipboard history", detail: "It can hold anything you have copied. Left out unless you turn this on.",
                          isOn: $includesClipboard)
            SettingToggle("Include the wallpaper library", detail: "Can be many gigabytes. It can be imported again from its source folders.",
                          isOn: $includesLibrary)
            HStack {
                Button("Export a Backup\u{2026}") {
                    run { await AppData.export(options: .init(includesClipboard: includesClipboard, includesWallpaperLibrary: includesLibrary)) }
                }
                Button("Restore from a Backup\u{2026}") { run { await AppData.restore() } }
                if isWorking { ProgressView().controlSize(.small) }
            }
            .disabled(isWorking)
            if let status {
                Text(status).foregroundStyle(.secondary)
            }
            if let previous = DataArchive.previousData(in: AppData.root).first {
                LabeledContent {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([previous]) }
                } label: {
                    Text("From before the last restore")
                    Text("Kept in case you want it back. Delete the folder once you\u{2019}re sure you don\u{2019}t.")
                }
            }
        } header: {
            Text("Back up and restore")
        } footer: {
            Text("A backup is a folder of ordinary files: anyone who has it can read it. API keys and tokens stay in your Keychain and are never in a backup. Restoring checks every file first, restarts All Set, and keeps what you had.")
        }
    }

    private func run(_ work: @escaping @MainActor () async -> String?) {
        isWorking = true
        status = nil
        Task {
            status = await work()
            isWorking = false
        }
    }
}
