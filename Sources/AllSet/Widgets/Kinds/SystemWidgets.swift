import AllSetCore
import SwiftUI

struct SystemWidget: View {
    let size: WidgetSize
    let monitor: any SystemReadings
    let unit: TemperatureUnit

    var body: some View {
        let snapshot = monitor.snapshot
        switch size {
        case .small:
            Grid(horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    ring(0, snapshot, diameter: 46)
                    ring(1, snapshot, diameter: 46)
                }
                GridRow {
                    ring(2, snapshot, diameter: 46)
                    ring(3, snapshot, diameter: 46)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .medium:
            VStack(spacing: 14) {
                rings(snapshot, diameter: 56)
                chips(snapshot)
            }
            .padding(16)
        case .large:
            overview(snapshot)
                .padding(18)
        case .extraLarge:
            HStack(spacing: 22) {
                overview(snapshot)
                    .frame(width: 318)
                VStack(spacing: 12) {
                    history("CPU", Format.percent(snapshot.cpu.total), monitor.cpuHistory.values, color: Theme.cpu)
                    history("GPU", snapshot.gpu.map { Format.percent($0.utilization) } ?? "—", monitor.gpuHistory.values, color: Theme.gpu)
                    history("Memory", Format.percent(snapshot.memory.usedFraction), monitor.memoryHistory.values, color: Theme.memory)
                    history("Network ↓", Format.rate(snapshot.network.downloadBytesPerSecond), monitor.downloadHistory.values,
                            color: Theme.download, top: max(monitor.downloadHistory.values.max() ?? 0, 100_000))
                }
            }
            .padding(18)
        }
    }

    private func overview(_ snapshot: SystemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            rings(snapshot, diameter: 58)
            chips(snapshot)
                .frame(maxWidth: .infinity)
            Divider().opacity(0.5)
            WidgetWord("Using the most energy")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            TopAppsList(apps: snapshot.topApps, spacing: 8, track: .primary.opacity(0.12))
            Spacer(minLength: 0)
        }
    }

    /// The last minute of one reading.
    private func history(_ title: String, _ value: String, _ values: [Double], color: Color, top: Double = 1) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                WidgetWord(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.system(size: 12, weight: .semibold)).monospacedDigit()
            }
            Sparkline(values: values, capacity: SystemMonitor.historyLength, color: color, maxValue: top)
        }
        .accessibilityElement(children: .combine)
    }

    private func rings(_ snapshot: SystemSnapshot, diameter: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                ring(index, snapshot, diameter: diameter)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// CPU, GPU, memory, then battery (or disk on Macs without one).
    @ViewBuilder
    private func ring(_ index: Int, _ snapshot: SystemSnapshot, diameter: CGFloat) -> some View {
        switch index {
        case 0:
            StatRing(title: "CPU", fraction: snapshot.cpu.total, color: Theme.cpu, diameter: diameter)
        case 1:
            StatRing(title: "GPU", fraction: snapshot.gpu?.utilization, color: Theme.gpu, diameter: diameter)
        case 2:
            StatRing(title: "RAM", fraction: snapshot.memory.usedFraction,
                     color: Theme.pressure(snapshot.memory.pressure), diameter: diameter)
        default:
            if let battery = snapshot.battery {
                StatRing(title: "BAT", fraction: Double(battery.percent) / 100,
                         color: Theme.battery(percent: battery.percent, charging: battery.isCharging),
                         symbol: battery.isCharging ? "bolt.fill" : nil, diameter: diameter)
            } else {
                StatRing(title: "DISK", fraction: snapshot.disk.usedFraction, color: Theme.disk, diameter: diameter)
            }
        }
    }

    private func chips(_ snapshot: SystemSnapshot) -> some View {
        HStack(spacing: 14) {
            Chip(symbol: "thermometer.medium",
                 text: snapshot.temperatures.soc.map { Format.temperature($0, unit: unit) } ?? "–",
                 color: Theme.temperature)
            Chip(symbol: "arrow.down", text: Format.rate(snapshot.network.downloadBytesPerSecond), color: Theme.download)
            Chip(symbol: "arrow.up", text: Format.rate(snapshot.network.uploadBytesPerSecond), color: Theme.upload)
        }
    }
}

struct BatteryWidget: View {
    let size: WidgetSize
    let monitor: any SystemReadings
    let unit: TemperatureUnit

    var body: some View {
        if let battery = monitor.snapshot.battery {
            let color = Theme.battery(percent: battery.percent, charging: battery.isCharging)
            switch size {
            case .small:
                VStack(spacing: 10) {
                    BatteryRing(battery: battery, color: color, diameter: 96)
                    Text(battery.statusDescription)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(14)
            default:
                HStack(spacing: 18) {
                    BatteryRing(battery: battery, color: color, diameter: 116)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(battery.statusDescription)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if let health = battery.health {
                            detail("heart.fill", "Health", Format.percent(health))
                        }
                        if let cycles = battery.cycleCount {
                            detail("arrow.triangle.2.circlepath", "Cycles", "\(cycles)")
                        }
                        if let watts = battery.systemPowerWatts ?? battery.batteryWatts {
                            detail("bolt.fill", "Using", Format.watts(watts))
                        }
                        if let temperature = battery.temperatureCelsius {
                            detail("thermometer.medium", "Temperature", Format.temperature(temperature, unit: unit))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "powerplug.fill").font(.system(size: 24))
                WidgetWord("No battery").font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detail(_ symbol: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            WidgetWord(title).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value).monospacedDigit()
        }
        .font(.system(size: 11, weight: .medium))
    }
}

private struct BatteryRing: View {
    let battery: BatteryInfo
    let color: Color
    let diameter: CGFloat

    var body: some View {
        let line = diameter * 0.1
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: line)
            Circle()
                .trim(from: 0, to: Double(battery.percent) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .motion(Motion.gentle, value: battery.percent)
            VStack(spacing: 0) {
                if battery.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: diameter * 0.13, weight: .bold))
                        .foregroundStyle(color)
                }
                Text("\(battery.percent)%")
                    .font(.system(size: diameter * 0.22, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .frame(width: diameter, height: diameter)
        .padding(line / 2)
    }
}

struct NowPlayingWidget: View {
    let size: WidgetSize
    let media: MediaController
    /// The theme's colors, for the sample cover in previews.
    var palette: ArtPalette = .neon
    @Environment(\.widgetAccent) private var accent
    @Environment(\.widgetIsPreview) private var isPreview

    var body: some View {
        if media.info == nil, isPreview {
            // Theme previews show how a song looks, not an empty player.
            SampleTrack(size: size, accent: accent, palette: palette)
        } else {
            live
        }
    }

    @ViewBuilder
    private var live: some View {
        if let info = media.info {
            let tint = media.accentColor.map { Color(nsColor: $0) } ?? accent
            switch size {
            case .small:
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Button(action: media.openSourceApp) {
                            ArtworkView(image: media.artwork, size: 64, cornerRadius: 12)
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 0)
                        Button(action: media.togglePlayPause) {
                            Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(.primary.opacity(0.1)))
                                .contentShape(Circle())
                        }
                        .buttonStyle(NotchIconButtonStyle())
                    }
                    Spacer(minLength: 0)
                    Text(info.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                    Text(info.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(14)
            default:
                HStack(spacing: 14) {
                    Button(action: media.openSourceApp) {
                        ArtworkView(image: media.artwork, size: 138, cornerRadius: 14)
                            .shadow(color: tint.opacity(0.3), radius: 8)
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(info.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(2)
                        Text(info.artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        PlaybackScrubber(info: info, accent: tint, onSeek: media.seek(to:))
                        HStack(spacing: 22) {
                            control("backward.fill", size: 14, action: media.previousTrack)
                            control(info.isPlaying ? "pause.fill" : "play.fill", size: 20, action: media.togglePlayPause)
                            control("forward.fill", size: 14, action: media.nextTrack)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(accent)
                WidgetWord("Nothing playing")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func control(_ symbol: String, size: CGFloat, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 30, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(NotchIconButtonStyle())
    }
}

struct NoteWidget: View {
    let instance: WidgetInstance
    let store: WidgetStore

    @State private var text = ""
    @Environment(\.widgetSnapshot) private var snapshot

    var body: some View {
        if snapshot {
            // A text editor can't be drawn into a picture; the words can.
            Text(instance.options.noteText.isEmpty ? "Type a note…" : instance.options.noteText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.black.opacity(instance.options.noteText.isEmpty ? 0.3 : 0.8))
                .padding(17)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            editor
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Type a note…")
                    .foregroundStyle(.black.opacity(0.3))
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.never)
                .foregroundColor(.black.opacity(0.8))
        }
        .font(.system(size: 14, weight: .medium))
        .padding(12)
        .onAppear { text = instance.options.noteText }
        .onChange(of: text) { _, newText in
            store.update(instance.id) { $0.options.noteText = newText }
        }
    }
}

/// A made-up song with generated cover art, for previews: never a real
/// track, artist or album cover.
private struct SampleTrack: View {
    let size: WidgetSize
    let accent: Color
    var palette: ArtPalette = .neon

    var body: some View {
        let cover = ArtView(piece: ArtPiece(style: .sunset, palette: palette))
            .clipShape(RoundedRectangle(cornerRadius: size == .small ? 12 : 14, style: .continuous))
        if size == .small {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    cover.frame(width: 64, height: 64)
                    Spacer(minLength: 0)
                    Image(systemName: "pause.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.primary.opacity(0.1)))
                }
                Spacer(minLength: 0)
                Text("Neon Afterglow").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text("The Night Shift").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 14) {
                cover.frame(width: 138, height: 138).shadow(color: accent.opacity(0.3), radius: 8)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Neon Afterglow").font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Text("The Night Shift").font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                    VStack(spacing: 4) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.primary.opacity(0.15))
                                Capsule().fill(accent).frame(width: geometry.size.width * 0.42)
                            }
                        }
                        .frame(height: 4)
                        HStack {
                            Text("1:32")
                            Spacer()
                            Text("−2:07")
                        }
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 22) {
                        Image(systemName: "backward.fill").font(.system(size: 14))
                        Image(systemName: "pause.fill").font(.system(size: 20))
                        Image(systemName: "forward.fill").font(.system(size: 14))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(14)
        }
    }
}
