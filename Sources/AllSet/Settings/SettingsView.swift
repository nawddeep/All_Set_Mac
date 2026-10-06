import AllSetCore
import SwiftUI

struct SettingsIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color.gradient))
    }
}

struct GeneralSettings: View {
    @Bindable var settings: AppSettings
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    var body: some View {
        Section {
            Toggle("Open at login", isOn: Binding(
                get: { launchAtLogin },
                set: { enabled in
                    do {
                        try LaunchAtLogin.setEnabled(enabled)
                        launchError = nil
                    } catch {
                        launchError = error.localizedDescription
                    }
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            ))
            .disabled(!LaunchAtLogin.isAvailable)
        } footer: {
            if !LaunchAtLogin.isAvailable {
                Text("Available when running the packaged app (`make open`).")
            } else if let launchError {
                Text(launchError).foregroundStyle(.red)
            }
        }

        Section {
            SettingToggle("Show All Set in the Dock",
                          detail: "Click the Dock icon to open this window. Turn off to live only in the menu bar.",
                          isOn: $settings.showInDock)
        }

        Section {
            Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
            Toggle("Show CPU usage next to the icon", isOn: $settings.showCPUInMenuBar)
                .disabled(!settings.showMenuBarIcon)
        } header: {
            Text("Menu bar")
        } footer: {
            Text("With both the Dock and menu bar icons hidden, open this window from the gear in the notch.")
        }
    }
}

struct NotchSettings: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Section {
            Picker("Show on", selection: $settings.notchDisplay) {
                ForEach(NotchDisplay.allCases) { display in
                    Text(display.title).tag(display)
                }
            }
        } header: {
            Text("Placement")
        } footer: {
            Text("Screens without a notch get a virtual one in the middle of the menu bar.")
        }

        Section {
            Toggle("Open when the pointer rests on the notch", isOn: $settings.expandOnHover)
            LabeledContent("Delay") {
                HStack {
                    Slider(value: $settings.hoverDelay, in: 0...0.6, step: 0.05)
                        .frame(width: 180)
                    Text("\(Int((settings.hoverDelay * 1000).rounded())) ms")
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }
            }
            .disabled(!settings.expandOnHover)
            Toggle("Haptic feedback when opening", isOn: $settings.hapticFeedback)
        } header: {
            Text("Behavior")
        } footer: {
            Text("Clicking the notch always opens it.")
        }
    }
}

struct ActivitySettings: View {
    @Bindable var settings: AppSettings
    let media: MediaController

    var body: some View {
        Section {
            toggle("Now Playing", detail: "Artwork and a visualizer while music or video plays", isOn: $settings.showNowPlaying)
            toggle("Volume", detail: "Level indicator when the volume changes", isOn: $settings.showVolume)
            toggle("Battery", detail: "Charging, unplugged and low battery alerts", isOn: $settings.showBattery)
            toggle("Audio output", detail: "When AirPods or other devices connect", isOn: $settings.showAudioDevice)
        } header: {
            Text("Show beside the closed notch")
        }

        Section("Now Playing") {
            LabeledContent("Status") {
                if media.isAvailable {
                    Label("Working", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Label("Unavailable", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
            if let reason = media.unavailableReason {
                Text(reason).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func toggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        SettingToggle(title, detail: detail, isOn: isOn)
    }
}

struct AboutSettings: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development build"
    }

    var body: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(alignment: .leading, spacing: 4) {
                    Text("All Set").font(.title2.bold())
                    Text("Version \(version)").foregroundStyle(.secondary)
                    Text("Desktop widgets, themes and wallpapers, a Dynamic Island, and a system monitor for your Mac.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }
}
