import AllSetCore
import SwiftUI

/// Every extra with its switch. Off, an extra starts nothing and asks for
/// nothing; on, its page joins the Extras pills.
struct ExtrasPage: View {
    let extras: ExtrasSettings

    var body: some View {
        FormPage(eyebrow: "Extras", title: "Extras",
                 subtitle: "All Set is the Dynamic Island, widgets, themes and wallpaper. These are optional: each runs only while it's on.") {
            Section {
                ForEach(Extra.allCases) { extra in
                    ExtraToggle(extra: extra, extras: extras)
                }
            } footer: {
                Text("An extra that's off keeps no timer, holds no keyboard shortcut and never asks for a permission. Its settings stay, for when you turn it back on.")
            }
        }
    }
}

/// One extra: what it is, and its switch.
private struct ExtraToggle: View {
    let extra: Extra
    let extras: ExtrasSettings

    var body: some View {
        Toggle(isOn: Binding(get: { extras.isOn(extra) }, set: { extras.set(extra, on: $0) })) {
            HStack(spacing: DS.Space.s) {
                Image(systemName: extra.symbol)
                    .frame(width: 22)
                    .foregroundStyle(DS.Ink.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(extra.title)
                    Text(extra.summary).dsText(.meta).foregroundStyle(DS.Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityHint(extra.summary)
    }
}

/// An extra's page while the extra is off: what it is and a switch.
struct ExtraOffPage: View {
    let extra: Extra
    let extras: ExtrasSettings

    var body: some View {
        FormPage(eyebrow: "Extras", title: extra.title, subtitle: extra.summary) {
            Section {
                ExtraToggle(extra: extra, extras: extras)
            } footer: {
                Text("\(extra.title) is off. Turn it on to use it; nothing runs until you do.")
            }
        }
    }
}
