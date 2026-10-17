import AllSetCore
import AppKit
import SwiftUI

/// What All Set changes outside itself, and putting it all back: macOS's
/// ⌘⇧5 screenshot shortcut, the system wallpaper under the live one, and the
/// login item. Also what "Uninstall All Set…" runs first.
@MainActor
enum SystemRestore {
    /// Puts back every macOS setting All Set changed. Safe to run anytime.
    static func restoreMacOSSettings(services: AppServices) {
        services.screenshotShortcut.giveBackSystemShortcut()
        // Turning the live wallpaper off puts the original system wallpapers back.
        services.wallpaper.config.isEnabled = false
    }

    /// Restores macOS, removes the login item, optionally moves All Set's data
    /// to the Trash, then moves the app to the Trash and quits.
    static func uninstall(services: AppServices) {
        let alert = NSAlert()
        alert.messageText = "Uninstall All Set?"
        alert.informativeText = "macOS's screenshot shortcut and your system wallpaper are put back, All Set stops opening at login, and the app moves to the Trash. You can drag it back out of the Trash until you empty it."
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Also move my All Set data (widgets, notes, wallpapers, clipboard history) to the Trash"
        alert.suppressionButton?.state = .off
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let removesData = alert.suppressionButton?.state == .on

        restoreMacOSSettings(services: services)
        if LaunchAtLogin.isAvailable, LaunchAtLogin.isEnabled { try? LaunchAtLogin.setEnabled(false) }
        // The wallpaper controller puts the system wallpapers back when it sees
        // the live one turned off: give it a moment before anything goes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            finishUninstall(services: services, removesData: removesData)
        }
    }

    private static func finishUninstall(services: AppServices, removesData: Bool) {
        services.stop()
        var leftovers: [String] = []
        if removesData {
            if (try? FileManager.default.trashItem(at: AppData.root, resultingItemURL: nil)) == nil {
                leftovers.append(AppData.root.path)
            }
            if let domain = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: domain) }
        }
        if Bundle.main.bundleURL.pathExtension == "app",
           (try? FileManager.default.trashItem(at: Bundle.main.bundleURL, resultingItemURL: nil)) == nil {
            leftovers.append(Bundle.main.bundleURL.path)
        }
        if !leftovers.isEmpty {
            let note = NSAlert()
            note.messageText = "Almost done"
            note.informativeText = "Couldn't move these to the Trash; drag them there yourself:\n" + leftovers.joined(separator: "\n")
            note.runModal()
        }
        exit(0)
    }
}

/// General › macOS: put back what All Set changed, or uninstall it.
struct SystemRestoreSettings: View {
    let services: AppServices
    @State private var restored = false

    var body: some View {
        Section {
            LabeledContent {
                Button(restored ? "Restored" : "Restore") {
                    SystemRestore.restoreMacOSSettings(services: services)
                    restored = true
                }
                .disabled(restored)
            } label: {
                Text("Restore macOS settings All Set changed")
                Text("Gives macOS back its ⌘⇧5 screenshot shortcut and turns the live wallpaper off, which puts your own system wallpaper back.")
            }
            LabeledContent {
                Button("Uninstall All Set\u{2026}", role: .destructive) { SystemRestore.uninstall(services: services) }
            } label: {
                Text("Uninstall")
                Text("Restores macOS, removes the login item and moves the app (and, if you choose, your data) to the Trash. Already deleted the app? Run scripts/uninstall.sh from the download.")
            }
        } header: {
            Text("macOS")
        }
    }
}
