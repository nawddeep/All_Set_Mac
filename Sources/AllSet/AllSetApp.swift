import AllSetCore
import SwiftUI

@main
struct AllSetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        let services = appDelegate.services
        @Bindable var settings = services.settings

        MenuBarExtra(isInserted: $settings.showMenuBarIcon) {
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
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { services.openWindow(.general) }
                .keyboardShortcut(",")
        }
        CommandMenu("Widgets") {
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
        CommandGroup(before: .windowList) {
            Button("All Set Window") { services.openWindow() }
                .keyboardShortcut("0")
            Divider()
        }
    }
}
