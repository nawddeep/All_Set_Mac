import AllSetCore
import SwiftUI

struct MenuBarLabel: View {
    let monitor: SystemMonitor
    let settings: AppSettings

    var body: some View {
        if settings.showCPUInMenuBar {
            Text("\(Image(systemName: "checkmark.seal.fill")) \(Format.percent(monitor.snapshot.cpu.total))")
                .monospacedDigit()
        } else {
            Image(systemName: "checkmark.seal.fill")
        }
    }
}

/// The panel that drops down from the menu bar icon.
struct MenuBarContentView: View {
    let services: AppServices

    var body: some View {
        let snapshot = services.monitor.snapshot
        let unit = services.settings.temperatureUnit

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.tint)
                Text("All Set").font(.headline)
                Spacer()
                if let temperature = snapshot.temperatures.soc {
                    Chip(symbol: "thermometer.medium", text: Format.temperature(temperature, unit: unit), color: Theme.temperature)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                MetricRow(symbol: "cpu", title: "CPU", detail: Format.percent(snapshot.cpu.total),
                          fraction: snapshot.cpu.total, color: Theme.cpu)
                MetricRow(symbol: "square.stack.3d.up.fill", title: "GPU",
                          detail: snapshot.gpu.map { Format.percent($0.utilization) } ?? "–",
                          fraction: snapshot.gpu?.utilization ?? 0, color: Theme.gpu)
                MetricRow(symbol: "memorychip", title: "Memory",
                          detail: "\(Format.memory(snapshot.memory.used)) of \(Format.memory(snapshot.memory.total))",
                          fraction: snapshot.memory.usedFraction, color: Theme.pressure(snapshot.memory.pressure))
                MetricRow(symbol: "internaldrive.fill", title: "Disk",
                          detail: "\(Format.bytes(Double(snapshot.disk.available))) free",
                          fraction: snapshot.disk.usedFraction, color: Theme.disk)
                if let battery = snapshot.battery {
                    MetricRow(symbol: battery.isCharging ? "battery.100percent.bolt" : "battery.75percent", title: "Battery",
                              detail: batteryDetail(battery), fraction: Double(battery.percent) / 100,
                              color: Theme.battery(percent: battery.percent, charging: battery.isCharging))
                }
            }

            HStack(spacing: 14) {
                Chip(symbol: "arrow.down", text: Format.rate(snapshot.network.downloadBytesPerSecond), color: Theme.download)
                Chip(symbol: "arrow.up", text: Format.rate(snapshot.network.uploadBytesPerSecond), color: Theme.upload)
            }
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Using the most energy")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TopAppsList(apps: snapshot.topApps, spacing: 7, track: .primary.opacity(0.1))
            }

            if let info = services.media.info {
                MiniNowPlaying(media: services.media, info: info)
            }

            if !services.workspaces.workspaces.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workspaces")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(services.workspaces.workspaces) { workspace in
                                Button {
                                    Task { await services.workspaceController.apply(workspace) }
                                } label: {
                                    Label(workspace.name, systemImage: workspace.symbol)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 14) {
                Button("Open All Set") { services.openWindow() }
                Button("Widgets") { services.openWindow(.gallery(nil)) }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { services.monitor.setViewer("menuBar", visible: true) }
        .onDisappear { services.monitor.setViewer("menuBar", visible: false) }
    }

    private func batteryDetail(_ battery: BatteryInfo) -> String {
        guard let minutes = battery.minutesRemaining else { return "\(battery.percent)%" }
        return "\(battery.percent)% · \(Format.duration(minutes: minutes))"
    }
}

private struct MetricRow: View {
    let symbol: String
    let title: String
    let detail: String
    let fraction: Double
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer()
                Text(detail)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            LevelBar(fraction: fraction, color: color, track: .primary.opacity(0.1))
                .frame(height: 4)
        }
    }
}

private struct MiniNowPlaying: View {
    let media: MediaController
    let info: NowPlayingInfo

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(image: media.artwork, size: 36, cornerRadius: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(info.title).font(.system(size: 12, weight: .semibold))
                Text(info.artist).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 4)
            Button(action: media.togglePlayPause) {
                Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.primary.opacity(0.06)))
    }
}
