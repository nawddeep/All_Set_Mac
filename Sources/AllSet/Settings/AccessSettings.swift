import AllSetCore
import AppKit
import SwiftUI

/// Whose access key this Mac uses, and taking it off: on the General page,
/// only when the access gate is on.
struct AccessSettings: View {
    private let controller = AccessController.shared

    var body: some View {
        if let gate = controller.gate {
            Section {
                LabeledContent {
                    Button("Remove access key", role: .destructive, action: confirmRemoval)
                } label: {
                    Text("Access key")
                    Text(detail(gate))
                }
            } header: {
                Text("Access")
            }
        }
    }

    private func detail(_ gate: AccessGate) -> String {
        var lines: [String] = []
        if let session = gate.current {
            if !session.name.isEmpty { lines.append("Belongs to \(session.name).") }
            lines.append("Its token runs out on \(session.expiresAt.formatted(date: .abbreviated, time: .omitted)) and renews by itself.")
        }
        if case .offlineUnlocked = gate.state {
            lines.append("The server can\u{2019}t be reached right now, so only what\u{2019}s already on this Mac works.")
        }
        lines.append("Removing it takes the key and its token out of your Keychain, and All Set asks for a key again.")
        return lines.joined(separator: " ")
    }

    private func confirmRemoval() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Remove the access key?")
        alert.informativeText = String(localized: "All Set restarts at the key screen and nothing works until a key is entered again.")
        alert.addButton(withTitle: String(localized: "Remove and Restart"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        controller.removeKey()
    }
}
