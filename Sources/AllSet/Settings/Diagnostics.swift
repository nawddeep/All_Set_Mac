import AppKit
import MetricKit
import OSLog
import SwiftUI

/// Crash and hang reports from MetricKit, kept on this Mac only, in
/// `<data folder>/Diagnostics`. Nothing is sent anywhere: "Export Diagnostics…"
/// zips them with the last day of All Set's own log for the person to email.
@MainActor
final class Diagnostics: NSObject, MXMetricManagerSubscriber {
    static let shared = Diagnostics()
    private let log = Logger(subsystem: "com.pratik.allset", category: "diagnostics")

    static var folder: URL { AppData.root.appendingPathComponent("Diagnostics", isDirectory: true) }

    func start() {
        MXMetricManager.shared.add(self)
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let folder = MainActor.assumeIsolated { Self.folder }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for payload in payloads {
            let name = "diagnostic-\(ISO8601DateFormatter().string(from: payload.timeStampEnd)).json"
                .replacingOccurrences(of: ":", with: "-")
            do {
                try payload.jsonRepresentation().write(to: folder.appendingPathComponent(name), options: .atomic)
            } catch {
                Logger(subsystem: "com.pratik.allset", category: "diagnostics")
                    .error("Couldn't keep a diagnostic report: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Reports kept so far, for the About page.
    static var reportCount: Int {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(".json") }.count
    }

    /// Asks where to save, then writes a zip of the reports, the last 24 hours
    /// of All Set's log, and the app and macOS versions.
    func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "AllSet-diagnostics-\(Date.now.formatted(.iso8601.year().month().day())).zip"
        panel.allowedContentTypes = [.zip]
        panel.message = "A zip of All Set's crash reports and its own log from the last day. Nothing is sent; attach it to an email if you want help."
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        Task.detached(priority: .userInitiated) {
            let ok = Self.writeArchive(to: destination)
            await MainActor.run {
                if ok {
                    NSWorkspace.shared.activateFileViewerSelecting([destination])
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Couldn't export diagnostics"
                    alert.informativeText = "The zip couldn't be written to \(destination.path)."
                    alert.runModal()
                }
            }
        }
    }

    nonisolated private static func writeArchive(to destination: URL) -> Bool {
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("AllSet-diagnostics-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: work) }
        do {
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let reports = MainActor.assumeIsolated { folder }
            if FileManager.default.fileExists(atPath: reports.path) {
                try FileManager.default.copyItem(at: reports, to: work.appendingPathComponent("Reports"))
            }
            let info = Bundle.main.infoDictionary ?? [:]
            let about = """
                All Set \(info["CFBundleShortVersionString"] as? String ?? "dev") (\(info["CFBundleVersion"] as? String ?? "-"))
                macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
                Exported \(Date.now.formatted(.iso8601))
                """
            try about.write(to: work.appendingPathComponent("about.txt"), atomically: true, encoding: .utf8)
            // All Set's own log only, from the last day.
            run("/usr/bin/log", ["show", "--last", "24h", "--style", "compact", "--predicate", "subsystem == \"com.pratik.allset\""],
                output: work.appendingPathComponent("log.txt"))
            try? FileManager.default.removeItem(at: destination)
            return run("/usr/bin/ditto", ["-c", "-k", "--keepParent", work.path, destination.path], output: nil)
        } catch {
            return false
        }
    }

    @discardableResult
    nonisolated private static func run(_ path: String, _ arguments: [String], output: URL?) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        if let output {
            FileManager.default.createFile(atPath: output.path, contents: nil)
            process.standardOutput = try? FileHandle(forWritingTo: output)
        }
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
