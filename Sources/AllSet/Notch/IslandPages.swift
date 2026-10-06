import AllSetCore
import SwiftUI

/// Everything about the Dynamic Island: a live miniature to play with, buttons
/// that run each animation on the real notch, and its settings.
struct IslandPage: View {
    let services: AppServices
    @State private var preview = NotchViewModel(geometry: IslandPage.previewGeometry)
    @State private var previewState: PreviewState = .home

    enum PreviewState: String, CaseIterable, Identifiable {
        case closed, nowPlaying, volume, home, system

        var id: String { rawValue }

        var title: String {
            switch self {
            case .closed: "Closed"
            case .nowPlaying: "Now Playing"
            case .volume: "Volume"
            case .home: "Open: Home"
            case .system: "Open: System"
            }
        }
    }

    /// A pretend 940-point-wide screen with a MacBook-sized notch.
    static let previewGeometry = NotchGeometry(
        screenFrame: CGRect(origin: .zero, size: NotchViewModel.windowSize),
        safeAreaTop: 32,
        topLeftArea: CGRect(x: 0, y: 0, width: (NotchViewModel.windowSize.width - 180) / 2, height: 32),
        topRightArea: CGRect(x: 0, y: 0, width: (NotchViewModel.windowSize.width - 180) / 2, height: 32),
        menuBarHeight: 32
    )

    var body: some View {
        @Bindable var settings = services.settings
        FormPage(eyebrow: settings.notchEnabled ? "On" : "Off", title: "Dynamic Island",
                 subtitle: "The notch becomes a live panel: music, timers, files and your Mac\u{2019}s vitals, a hover away.") {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                VStack(spacing: 0) {
                    IslandStage(model: preview, services: services)
                    HStack(spacing: DS.Space.xs) {
                        ForEach(PreviewState.allCases) { state in
                            FilterPill(title: state.title, isSelected: previewState == state) { previewState = state }
                        }
                    }
                    .padding(DS.Space.s)
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous))
                .background(RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous).fill(.black.opacity(0.35)))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous).strokeBorder(DS.Surface.hairline))

                VStack(alignment: .leading, spacing: DS.Space.s) {
                    SectionHeader(title: "Try it on your notch", subtitle: "Each one plays on your Mac\u{2019}s real notch.")
                    FlowLayout(spacing: DS.Space.xs) {
                        tryButton("Open the panel", symbol: "rectangle.expand.vertical", demo: .open)
                        tryButton("Now Playing", symbol: "music.note", demo: .nowPlaying)
                        tryButton("Volume", symbol: "speaker.wave.2.fill", demo: .volume)
                        tryButton("Charging", symbol: "bolt.fill", demo: .charging)
                        tryButton("Low battery", symbol: "battery.25percent", demo: .lowBattery)
                        tryButton("Audio device", symbol: "airpods", demo: .audioDevice)
                    }
                    .disabled(!settings.notchEnabled)
                }
            }
        } content: {
            Section {
                SettingToggle("Dynamic Island", detail: "Turn the notch into a live panel with activities around it.",
                              isOn: $settings.notchEnabled)
            }

            Section("Opening") {
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
                Picker("Open to", selection: $settings.notchStartTab) {
                    ForEach(NotchStartTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                Toggle("Haptic feedback when opening", isOn: $settings.hapticFeedback)
            }
            .disabled(!settings.notchEnabled)

            Section {
                Picker("Show on", selection: $settings.notchDisplay) {
                    ForEach(NotchDisplay.allCases) { display in
                        Text(display.title).tag(display)
                    }
                }
            } header: {
                Text("Placement")
            } footer: {
                Text("Screens without a notch get a virtual one in the middle of the menu bar. Clicking the notch always opens it.")
            }
            .disabled(!settings.notchEnabled)
        }
        .onChange(of: previewState, initial: true) { _, state in apply(state) }
        // A preview: numbers every couple of seconds are plenty.
        .onAppear { services.monitor.setViewer("window", visible: true, interval: 2) }
        .onDisappear { services.monitor.setViewer("window", visible: false) }
    }

    private func tryButton(_ title: String, symbol: String, demo: NotchDemo) -> some View {
        Button {
            services.notch?.demo(demo)
        } label: {
            Label(title, systemImage: symbol)
        }
        .buttonStyle(.pill)
    }

    private func apply(_ state: PreviewState) {
        let opening = state == .home || state == .system
        withAnimation(opening ? NotchAnimation.open : NotchAnimation.close) {
            preview.isExpanded = opening
            preview.tab = state == .system ? .system : .home
            preview.transientActivity = switch state {
            case .nowPlaying: .nowPlaying
            case .volume: .volume(level: max(services.volume.volume, 0.5), muted: false)
            default: nil
            }
        }
    }
}

/// The miniature: the notch hanging from the top of a pretend screen, scaled to fit.
private struct IslandStage: View {
    let model: NotchViewModel
    let services: AppServices

    var body: some View {
        GeometryReader { geometry in
            let size = NotchViewModel.windowSize
            let scale = min(1, geometry.size.width / size.width)
            ZStack(alignment: .top) {
                StudioBackdrop(piece: ArtPiece(style: .aurora, palette: .midnight))
                Rectangle()
                    .fill(.black.opacity(0.35))
                    .frame(height: 32 * scale)
                IslandRepresentable(model: model, services: services)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(scale, anchor: .top)
                    .frame(width: size.width * scale, height: size.height * scale, alignment: .top)
                    .allowsHitTesting(false)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        // Tall enough for whatever the island shows, plus some screen below it.
        .frame(height: max(model.shapeSize.height * 0.78 + 70, 150))
        .animation(model.isExpanded ? NotchAnimation.open : NotchAnimation.close, value: model.shapeSize)
        .clipped()
    }
}

/// The Mac at a glance: a tile per resource with its recent history, the
/// apps using the most, and how often to look.
struct MonitorPage: View {
    let services: AppServices

    var body: some View {
        @Bindable var settings = services.settings
        let monitor = services.monitor
        let snapshot = monitor.snapshot
        let unit = settings.temperatureUnit
        PageScaffold {
            PageHeader(eyebrow: "Live", title: "Monitor",
                       subtitle: "Your Mac right now. It reads \(snapshot.thermal.title.lowercased()), and once the window closes it keeps reading, just less often, for the menu bar and widgets.") {
                HStack(spacing: DS.Space.s) {
                    Picker("Update every", selection: $settings.refreshInterval) {
                        Text("½ s").tag(0.5)
                        Text("1 s").tag(1.0)
                        Text("2 s").tag(2.0)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .help("How often to update while stats are on screen")
                    Picker("Temperature", selection: $settings.temperatureUnit) {
                        ForEach(TemperatureUnit.allCases) { unit in
                            Text(unit == .celsius ? "°C" : "°F").tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .help("Temperature unit")
                }
                .labelsHidden()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: DS.Space.m)], spacing: DS.Space.m) {
                MetricTile(title: "CPU", symbol: "cpu", color: Theme.cpu, value: Format.percent(snapshot.cpu.total),
                           detail: [snapshot.cpu.perCore.isEmpty ? nil : "\(snapshot.cpu.perCore.count) cores",
                                    snapshot.temperatures.soc.map { Format.temperature($0, unit: unit) },
                                    snapshot.thermal.title].compactMap { $0 }.joined(separator: " · "),
                           history: monitor.cpuHistory, maxValue: 1)
                MetricTile(title: "GPU", symbol: "square.stack.3d.up.fill", color: Theme.gpu,
                           value: snapshot.gpu.map { Format.percent($0.utilization) } ?? "–",
                           detail: snapshot.gpu?.memoryInUse.map { "\(Format.memory($0)) in use" } ?? "Graphics",
                           history: monitor.gpuHistory, maxValue: 1)
                MetricTile(title: "Memory", symbol: "memorychip", color: Theme.memory, value: Format.percent(snapshot.memory.usedFraction),
                           detail: "\(Format.memory(snapshot.memory.used)) of \(Format.memory(snapshot.memory.total)) · \(snapshot.memory.pressure.title)",
                           history: monitor.memoryHistory, maxValue: 1)
                MetricTile(title: "Network", symbol: "arrow.up.arrow.down", color: Theme.download,
                           value: Format.rate(snapshot.network.downloadBytesPerSecond),
                           detail: "Down · up \(Format.rate(snapshot.network.uploadBytesPerSecond))",
                           history: monitor.downloadHistory, secondary: monitor.uploadHistory, secondaryColor: Theme.upload)
                MetricTile(title: "Disk", symbol: "internaldrive.fill", color: Theme.disk, value: Format.percent(snapshot.disk.usedFraction),
                           detail: "\(Format.bytes(Double(snapshot.disk.available))) free of \(Format.bytes(Double(snapshot.disk.total)))",
                           fraction: snapshot.disk.usedFraction)
                if let battery = snapshot.battery {
                    MetricTile(title: "Battery", symbol: battery.isCharging ? "battery.100percent.bolt" : "battery.75percent",
                               color: Theme.battery(percent: battery.percent, charging: battery.isCharging),
                               value: "\(battery.percent)%",
                               detail: [battery.isCharging ? "Charging" : battery.isPluggedIn ? "Plugged in" : "On battery",
                                        battery.minutesRemaining.map { Format.duration(minutes: $0) },
                                        battery.health.map { "Health \(Format.percent($0))" }].compactMap { $0 }.joined(separator: " · "),
                               fraction: Double(battery.percent) / 100)
                }
            }

            VStack(alignment: .leading, spacing: DS.Space.m) {
                SectionHeader(title: "What\u{2019}s using your Mac", subtitle: "Energy and memory by app, helpers included. macOS keeps its own services (WindowServer, kernel_task) private, so only apps you run are counted.")
                // The card draws its own box, as it does in the notch.
                TopAppsCard(services: services)
                    .frame(height: 300)
                    .frame(maxWidth: 640, alignment: .leading)
            }
        }
        .onAppear { services.monitor.setViewer("window", visible: true) }
        .onDisappear { services.monitor.setViewer("window", visible: false) }
    }
}

/// One resource: its reading large, a line of context, and its recent
/// history (or how full it is, for things that change slowly).
private struct MetricTile: View {
    let title: String
    let symbol: String
    let color: Color
    let value: String
    let detail: String
    var history: RollingSeries?
    var maxValue: Double?
    var secondary: RollingSeries?
    var secondaryColor: Color = .white
    var fraction: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
                Text(title).dsText(.eyebrow)
            }
            Text(value)
                .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(DS.Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail).dsText(.meta).lineLimit(1)
            Spacer(minLength: DS.Space.xs)
            if let history {
                // Both network lines share one scale so they compare honestly.
                let top = maxValue ?? max(history.maximum, secondary?.maximum ?? 0, 1)
                ZStack {
                    if let secondary {
                        Sparkline(values: secondary.values, capacity: secondary.capacity, color: secondaryColor, maxValue: top, filled: false)
                    }
                    Sparkline(values: history.values, capacity: history.capacity, color: color, maxValue: top)
                }
                .frame(height: 48)
            } else if let fraction {
                LevelBar(fraction: fraction, color: color, track: DS.Surface.hover)
                    .frame(height: 8)
                    .clipShape(Capsule())
            }
        }
        .padding(DS.Space.m)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Surface.raised))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).strokeBorder(DS.Surface.hairline))
        .accessibilityElement(children: .combine)
    }
}
