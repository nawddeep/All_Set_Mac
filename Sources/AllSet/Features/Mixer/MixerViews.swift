import AllSetCore
import AppKit
import SwiftUI

/// The notch's Sound tab: where sound plays, and each app's own volume.
struct MixerTab: View {
    let services: AppServices

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            OutputPane(volume: services.volume)
                .frame(width: 236)
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 4)
            AppsPane(mixer: services.mixer, openMixer: { services.openWindow(.mixer) })
                .frame(maxWidth: .infinity)
        }
    }
}

/// The system volume and the output devices, like Control Center's Sound.
private struct OutputPane: View {
    let volume: VolumeMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Output", systemImage: "hifispeaker.fill")
                .font(.system(size: 12, weight: .semibold))

            HStack(spacing: 8) {
                Button {
                    volume.setMuted(!volume.isMuted)
                } label: {
                    Image(systemName: CollapsedActivityView.volumeSymbol(level: volume.volume, muted: volume.isMuted))
                        .font(.system(size: 12, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 22, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(NotchIconButtonStyle())
                .help(volume.isMuted ? "Unmute" : "Mute")
                MixerSlider(value: Double(volume.volume), dimmed: volume.isMuted) { volume.setVolume(Float($0)) }
                Text(volume.isMuted ? "Off" : "\(Int((volume.volume * 100).rounded()))%")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }
            .disabled(!volume.hasVolumeControl)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(volume.outputDevices) { device in
                        DeviceRow(device: device, isCurrent: device.id == volume.deviceID) {
                            volume.selectOutput(device.id)
                        }
                    }
                }
            }
        }
    }
}

private struct DeviceRow: View {
    let device: AudioOutputDevice
    let isCurrent: Bool
    let select: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 8) {
                Image(systemName: device.kind.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isCurrent ? .black : .white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.white.opacity(isCurrent ? 0.92 : 0.12)))
                Text(device.name)
                    .font(.system(size: 11, weight: isCurrent ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(isHovering ? 0.08 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(isCurrent ? "Playing through \(device.name)" : "Play through \(device.name)")
    }
}

private struct AppsPane: View {
    let mixer: MixerController
    let openMixer: () -> Void

    var body: some View {
        let apps = mixer.activeApps
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Apps", systemImage: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if mixer.hasChanges {
                    Button("All to 100%") {
                        withMotion(Motion.standard) { mixer.resetAll() }
                    }
                    .help("Put every app back to full volume")
                }
                Button(action: openMixer) {
                    Image(systemName: "arrow.up.forward.app")
                }
                .help("Open the Sound Mixer")
            }
            .buttonStyle(NotchIconButtonStyle())
            .font(.system(size: 11, weight: .semibold))

            if mixer.needsPermission {
                PermissionNote(mixer: mixer)
            }

            if apps.isEmpty {
                Text("Play something, and each app gets its own volume here.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(apps) { app in
                            NotchAppRow(app: app, mixer: mixer)
                        }
                    }
                }
            }
        }
        .motion(Motion.quick, value: apps.map(\.id))
    }
}

/// One app: icon, name, a slider and a mute button.
private struct NotchAppRow: View {
    let app: AudioApp
    let mixer: MixerController

    var body: some View {
        let volume = mixer.volume(for: app.id)
        HStack(spacing: 8) {
            Image(nsImage: AppIconCache.icon(forPath: app.path))
                .resizable()
                .frame(width: 20, height: 20)
            HStack(spacing: 4) {
                Text(app.name)
                    .lineLimit(1)
                if let failure = mixer.failures[app.id] {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .help(failure)
                } else if app.isPlaying {
                    Image(systemName: "waveform")
                        .foregroundStyle(Theme.charging)
                        .symbolEffect(.variableColor.iterative, isActive: true)
                }
            }
            .font(.system(size: 11, weight: .medium))
            .frame(width: 118, alignment: .leading)

            MixerSlider(value: volume.level, dimmed: volume.isMuted) { mixer.setLevel($0, for: app.id) }
            Text(volume.isMuted ? "Off" : "\(Int((volume.level * 100).rounded()))%")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
            Button {
                mixer.toggleMute(app.id)
            } label: {
                Image(systemName: volume.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(volume.isMuted ? .orange : .white)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 22, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(NotchIconButtonStyle())
            .help(volume.isMuted ? "Unmute \(app.name)" : "Mute \(app.name)")
        }
        .frame(height: 26)
        .contextMenu {
            Button("Set to 100%") { mixer.reset(app.id) }
                .disabled(volume.isUnchanged)
        }
    }
}

/// Asks for the permission that per-app volume needs, in the notch.
private struct PermissionNote: View {
    let mixer: MixerController

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(mixer.permission == .denied
                 ? "Turn on All Set under System Audio Recording to change app volumes."
                 : "All Set needs permission to change app volumes.")
                .lineLimit(2)
            Spacer(minLength: 4)
            Button(mixer.permission == .denied ? "Open Settings" : "Allow") {
                if mixer.permission == .denied { mixer.openPermissionSettings() } else { mixer.askPermission() }
            }
            .buttonStyle(NotchIconButtonStyle())
            .font(.system(size: 11, weight: .semibold))
        }
        .font(.system(size: 10, weight: .medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.16)))
        .task {
            // macOS doesn't announce the change, so check while visible.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                mixer.checkPermission()
            }
        }
    }
}

/// A slim volume slider for the dark notch: click or drag anywhere on it, or
/// scroll over it. It follows the pointer at once, rather than waiting for
/// the device to report its new level, which arrives a moment later and
/// rounded to the device's own steps.
struct MixerSlider: View {
    let value: Double
    var dimmed = false
    let onChange: (Double) -> Void

    @State private var dragValue: Double?
    @State private var isHovering = false
    @State private var release: Task<Void, Never>?

    var body: some View {
        let shown = dragValue ?? value
        let isActive = dragValue != nil || isHovering
        let thickness: CGFloat = isActive ? 8 : 5
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.16))
                    .frame(height: thickness)
                Capsule()
                    .fill(.white.opacity(dimmed ? 0.3 : 1))
                    .frame(width: max(width * shown, thickness), height: thickness)
                    .opacity(shown > 0 ? 1 : 0)
                Circle()
                    .fill(.white)
                    .frame(width: 13, height: 13)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .scaleEffect(dragValue != nil ? 1.15 : 1)
                    .offset(x: min(max(width * shown - 6.5, 0), width - 13))
                    .opacity(isActive ? 1 : 0)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in set(drag.location.x / width) }
                    .onEnded { drag in
                        set(drag.location.x / width)
                        settle()
                    }
            )
            .overlay(ScrollWheelCatcher { delta in
                set(shown + delta)
                settle()
            })
        }
        .frame(height: 18)
        .onHover { isHovering = $0 }
        .motion(Motion.press, value: isActive)
    }

    private func set(_ raw: Double) {
        release?.cancel()
        let clamped = min(max(raw, 0), 1)
        dragValue = clamped
        onChange(clamped)
    }

    /// Hands back to the real value once the device has caught up.
    private func settle() {
        release?.cancel()
        release = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            dragValue = nil
        }
    }
}

/// Turns scrolling over a view into changes of a value: two-finger swipes up
/// or right raise it. Clicks and drags pass straight through.
struct ScrollWheelCatcher: NSViewRepresentable {
    let onScroll: (Double) -> Void

    final class CatcherView: NSView {
        var onScroll: ((Double) -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            NSApp.currentEvent?.type == .scrollWheel ? super.hitTest(point) : nil
        }

        override func scrollWheel(with event: NSEvent) {
            // Measured as the fingers move, whatever the scrolling direction setting.
            let sign: CGFloat = event.isDirectionInvertedFromDevice ? -1 : 1
            let vertical = event.scrollingDeltaY * sign
            let horizontal = -event.scrollingDeltaX * sign
            let delta = abs(vertical) >= abs(horizontal) ? vertical : horizontal
            // Trackpads report pixels; wheels report lines.
            let step = event.hasPreciseScrollingDeltas ? delta / 300 : delta / 16
            if step != 0 { onScroll?(Double(step)) }
        }
    }

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onScroll = onScroll
    }
}

// MARK: - Main window

/// Every app's volume, the output device, and remembered levels.
struct SoundMixerPage: View {
    let services: AppServices

    var body: some View {
        let mixer = services.mixer
        let volume = services.volume
        let running = Set(mixer.apps.map(\.id))
        let remembered = mixer.store.volumes.keys.filter { !running.contains($0) }.sorted()
        FormPage(eyebrow: "Tools", title: "Sound Mixer",
                 subtitle: "Where sound plays, and how loud each app is.") {
            if mixer.needsPermission {
                Section {
                    AudioPermissionBanner(mixer: mixer)
                }
            }

            Section("Output") {
                Picker("Play sound through", selection: Binding(get: { volume.deviceID },
                                                                set: { volume.selectOutput($0) })) {
                    ForEach(volume.outputDevices) { device in
                        Label(device.name, systemImage: device.kind.symbolName).tag(device.id)
                    }
                }
                LabeledContent("Volume") {
                    HStack(spacing: 10) {
                        Button {
                            volume.setMuted(!volume.isMuted)
                        } label: {
                            Image(systemName: CollapsedActivityView.volumeSymbol(level: volume.volume, muted: volume.isMuted))
                                .frame(width: 22)
                        }
                        .buttonStyle(.borderless)
                        .help(volume.isMuted ? "Unmute" : "Mute")
                        Slider(value: Binding(get: { Double(volume.volume) }, set: { volume.setVolume(Float($0)) }), in: 0...1)
                            .frame(width: 220)
                        Text(volume.isMuted ? "Muted" : "\(Int((volume.volume * 100).rounded()))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
                .disabled(!volume.hasVolumeControl)
            }

            Section {
                if mixer.listedApps.isEmpty {
                    Text("No app has set up sound yet. Play something and it appears here.")
                        .foregroundStyle(.secondary)
                }
                ForEach(mixer.listedApps) { app in
                    AppVolumeRow(app: app, mixer: mixer)
                }
            } header: {
                Text("Apps")
            } footer: {
                Text("An app you turn down plays through All Set, which needs permission to record its sound. The sound goes straight to your speakers; nothing is saved or sent anywhere. Apps at 100% play exactly as before.")
            }

            if !remembered.isEmpty {
                Section {
                    ForEach(remembered, id: \.self) { id in
                        RememberedRow(id: id, mixer: mixer)
                    }
                } header: {
                    Text("Not Running")
                } footer: {
                    Text("These levels apply as soon as the apps play again.")
                }
            }

            Section {
                Button("Set All Apps to 100%") { mixer.resetAll() }
                    .disabled(!mixer.hasChanges)
            }
        }
    }
}

private struct AppVolumeRow: View {
    let app: AudioApp
    let mixer: MixerController

    var body: some View {
        let volume = mixer.volume(for: app.id)
        HStack(spacing: 12) {
            Image(nsImage: AppIconCache.icon(forPath: app.path))
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                Group {
                    if let failure = mixer.failures[app.id] {
                        Label(failure, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else if app.isPlaying {
                        Label("Playing", systemImage: "waveform")
                            .foregroundStyle(.green)
                    } else {
                        Text("Not playing")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .lineLimit(1)
            }
            Spacer(minLength: 12)
            Button {
                mixer.toggleMute(app.id)
            } label: {
                Image(systemName: volume.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .foregroundStyle(volume.isMuted ? .orange : .secondary)
                    .frame(width: 22)
            }
            .buttonStyle(.borderless)
            .help(volume.isMuted ? "Unmute \(app.name)" : "Mute \(app.name)")
            Slider(value: Binding(get: { volume.level }, set: { mixer.setLevel($0, for: app.id) }), in: 0...1)
                .frame(width: 220)
            Text(volume.isMuted ? "Muted" : "\(Int((volume.level * 100).rounded()))%")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
        .contextMenu {
            Button("Set to 100%") { mixer.reset(app.id) }
                .disabled(volume.isUnchanged)
        }
    }
}

/// A saved level for an app that isn't running.
private struct RememberedRow: View {
    let id: String
    let mixer: MixerController

    var body: some View {
        let volume = mixer.volume(for: id)
        HStack(spacing: 12) {
            AppIcon(bundleIdentifier: id, size: 22)
            Text(AppIconCache.name(for: id) ?? id)
            Spacer()
            Text(volume.isMuted ? "Muted" : "\(Int((volume.level * 100).rounded()))%")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button {
                mixer.reset(id)
            } label: {
                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Forget this level")
        }
    }
}

/// Explains the permission per-app volume needs, with a way to give it.
struct AudioPermissionBanner: View {
    let mixer: MixerController

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "waveform.badge.exclamationmark")
                .font(.system(size: 22))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("Allow All Set to change app volumes").font(.headline)
                Text("To turn one app down, All Set takes its sound and plays it back quieter, which macOS counts as recording it. Turn on All Set in Privacy & Security › Screen & System Audio Recording, under System Audio Recording Only. This page updates as soon as you do.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    if mixer.permission == .unknown {
                        Button("Allow…") { mixer.askPermission() }
                            .buttonStyle(.borderedProminent)
                    }
                    Button("Open Settings") { mixer.openPermissionSettings() }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                mixer.checkPermission()
            }
        }
    }
}
