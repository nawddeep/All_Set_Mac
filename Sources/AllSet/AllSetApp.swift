import AllSetCore
import SwiftUI

/// Where the process starts: a command typed in Terminal (`AllSet library <key>`)
/// runs and ends without the app ever appearing; anything else is the app.
@main
enum Launcher {
    @MainActor static func main() {
        if let command = LibraryCommand(arguments: CommandLine.arguments) {
            Task.detached { exit(await command.run()) }
            dispatchMain()
        }
        AllSetApp.main()
    }
}

struct AllSetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        let services = appDelegate.services
        let settings = services.settings
        let access = AccessController.shared
        // No menu bar item until the access key is accepted.
        let showsMenuBarItem = Binding(get: { access.isUnlocked && settings.showMenuBarIcon },
                                       set: { settings.showMenuBarIcon = $0 })

        MenuBarExtra(isInserted: showsMenuBarItem) {
            MenuBarContentView(services: services)
        } label: {
            MenuBarLabel(monitor: services.monitor, settings: services.settings)
        }
        .menuBarExtraStyle(.window)
        .commands { AppCommands(services: services) }
    }
}

/// The menu bar's commands while All Set is in front: Settings where every Mac
/// app has it, and the main places to go, each with a shortcut.
private struct AppCommands: Commands {
    let services: AppServices

    var body: some Commands {
        let isLocked = !AccessController.shared.isUnlocked
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { services.openWindow(.general) }
                .keyboardShortcut(",")
                .disabled(isLocked)
        }
        CommandMenu("Widgets") {
            Group {
                Button("Widget Gallery") { services.openWindow(.gallery(nil)) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Themes") { services.openWindow(.themes) }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Divider()
                Button(services.ui.isArrangingWidgets ? "Done Arranging" : "Arrange Widgets") {
                    services.ui.isArrangingWidgets.toggle()
                }
                .keyboardShortcut("a", modifiers: [.command, .option])
                Button(services.settings.showWidgets ? "Hide Widgets" : "Show Widgets") {
                    services.settings.showWidgets.toggle()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                Divider()
                // The desktop from before the last theme, wallpaper or Turn Off, kept on
                // disk: works after the Undo offer has gone and after a relaunch.
                Button("Restore Previous Desktop") { services.restorePreviousDesktop() }
                    .disabled(services.previousDesktop == nil)
            }
            .disabled(isLocked)
        }
        CommandGroup(before: .windowList) {
            Button("All Set Window") { services.openWindow() }
                .keyboardShortcut("0")
                .disabled(isLocked)
            Divider()
        }
    }
}
