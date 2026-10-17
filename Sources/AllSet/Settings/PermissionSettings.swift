import AllSetCore
import AppKit
import SwiftUI

/// Reading where each permission stands. Nothing here asks: asking happens
/// only from the feature that needs it.
@MainActor
enum PermissionCenter {
    static func status(of permission: Permission, services: AppServices) -> PermissionStatus {
        switch permission {
        case .accessibility:
            // macOS can't tell "never asked" from "said no" here.
            return Accessibility.isTrusted ? .granted : .denied
        case .calendars:
            switch services.calendar.access {
            case .granted: return .granted
            case .denied: return .denied
            case .notDetermined: return .notAsked
            case .unavailable: return .unknown
            }
        case .audioCapture:
            switch AudioCapturePermission.status {
            case .authorized: return .granted
            case .denied: return .denied
            case .unknown: return .notAsked
            case .unverifiable: return .unknown
            }
        }
    }

    /// Asks for what switching `extra` on needs, if it isn't granted: macOS
    /// shows its own prompt. Called when the switch goes on, never at launch.
    static func requestIfNeeded(for extra: Extra, services: AppServices) {
        guard let permission = Permission.needed(toTurnOn: extra),
              status(of: permission, services: services) != .granted else { return }
        switch permission {
        case .accessibility: Accessibility.requestAccess()
        // The mixer asks the first time it routes an app's sound, which needs a running app to explain itself.
        case .audioCapture, .calendars: break
        }
    }
}

/// General › Permissions: each permission that matters for what's on, where it
/// stands, what it's for, what breaks without it, and the way to System Settings.
struct PermissionSettings: View {
    let services: AppServices
    /// Re-read when the app comes back to the front: the answer may have changed in System Settings.
    @State private var refresh = 0

    var body: some View {
        let relevant = Permission.relevant(extras: services.extras.enabled,
                                           widgetKinds: Set(services.widgets.widgets.map(\.kind)))
        Section {
            if relevant.isEmpty {
                Text("Nothing you use needs a permission right now.").foregroundStyle(.secondary)
            }
            ForEach(relevant) { permission in
                let status = PermissionCenter.status(of: permission, services: services)
                LabeledContent {
                    HStack(spacing: DS.Space.xs) {
                        Label(status.label, systemImage: status == .granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(status == .granted ? Color.green : Color.orange)
                        if status != .granted {
                            Button("Open System Settings") { NSWorkspace.shared.open(permission.settingsURL) }
                        }
                    }
                } label: {
                    Text(permission.title)
                    Text(status == .granted ? permission.purpose : "\(permission.purpose) Without it: \(permission.withoutIt)")
                }
                .id("\(permission.id)-\(refresh)")
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("All Set asks for a permission only when you turn on something that needs it. You can change any of them in System Settings › Privacy & Security.")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh += 1 }
    }
}
