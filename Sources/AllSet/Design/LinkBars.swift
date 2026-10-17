import AllSetCore
import SwiftUI

/// "A link asks to apply Floodlight Gold to your desktop" for a link that came
/// while All Set wasn't in front: nothing changes until Apply. Not modal; the
/// window works as usual meanwhile.
struct LinkConfirmationBar: View {
    let link: DeepLink
    let services: AppServices

    var body: some View {
        GlassPanel(cornerRadius: 22, padding: 0) {
            HStack(spacing: DS.Space.s) {
                Image(systemName: "link").foregroundStyle(DS.Ink.secondary)
                Text("A link asks to \(services.describe(link).lowercasedFirst)").dsText(.body)
                Button("Cancel") { withMotion(Motion.quick) { services.ui.pendingLink = nil } }
                    .buttonStyle(.pill)
                Button("Apply") {
                    withMotion(Motion.quick) { services.ui.pendingLink = nil }
                    services.perform(link)
                }
                .buttonStyle(.pillProminent)
            }
            .padding(.leading, DS.Space.m)
            .padding(.trailing, DS.Space.xxs + 1)
            .frame(height: 44)
        }
        .dsElevated()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("A link is waiting for your answer")
    }
}

/// Undo for what a link just did, for ten seconds.
struct LinkUndoBar: View {
    let undo: DesktopUndo
    let what: String
    let services: AppServices

    var body: some View {
        GlassPanel(cornerRadius: 22, padding: 0) {
            HStack(spacing: DS.Space.s) {
                Image(systemName: "link").foregroundStyle(DS.Ink.secondary)
                Text("\(what) from a link.").dsText(.body)
                Button("Undo") { withMotion(Motion.quick) { services.undoDesktopChange() } }
                    .buttonStyle(.pillProminent)
            }
            .padding(.leading, DS.Space.m)
            .padding(.trailing, DS.Space.xxs + 1)
            .frame(height: 44)
        }
        .dsElevated()
        .task(id: undo.id) {
            try? await Task.sleep(for: .seconds(10))
            if services.ui.desktopUndo?.id == undo.id {
                withMotion(Motion.standard) { services.ui.desktopUndo = nil }
            }
        }
    }
}

private extension String {
    var lowercasedFirst: String { prefix(1).lowercased() + dropFirst() }
}
