import AppKit
import ServiceManagement
import SwiftUI

@MainActor
enum LaunchAtLogin {
    /// Login items need a real app bundle, not the bare `.build` executable.
    static var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
