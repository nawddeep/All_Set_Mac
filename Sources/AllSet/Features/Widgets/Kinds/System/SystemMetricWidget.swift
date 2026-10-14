import AllSetCore
import SwiftUI

/// One reading from the Mac, designed for each size: a glance when small,
/// context when medium, the whole story when large. Numbers arrive with the
/// monitor's samples, which only run while a stats widget can be seen.
struct SystemMetricWidget: View {
    let instance: WidgetInstance
    let monitor: any SystemReadings
    let unit: TemperatureUnit
    @Environment(\.widgetRefreshScale) private var refreshScale

    @Environment(\.widgetStyle) private var style
    @State private var wifi: WiFiStatus?

    private var size: WidgetSize { instance.size }
    private var small: Bool { size == .small }

    var body: some View {
        let snapshot = monitor.snapshot
        content(snapshot)
            .padding(WidgetMetrics.padding(size))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .widgetRefresh(every: instance.options.metric == .wifi ? instance.options.refresh.interval(for: .wifi).map { $0 * refreshScale } : nil,
                           id: instance.options.metric) {
                if instance.options.metric == .wifi { wifi = WiFiReader.read() }
            }
    }

    @ViewBuilder
    private func content(_ s: SystemSnapshot) -> some View {
        switch instance.options.metric {
        case .cpu: cpu(s)
        case .memory: memory(s)
        case .disk: disk(s)
        case .storage: storage(s)
        case .network: network(s)
        case .wifi: wifiView
        case .battery: battery(s)
        case .batteryHealth: batteryHealth(s)
        case .uptime: uptime
        case .status: status(s)
        }
    }

    private func percent(_ fraction: Double) -> String { String(Int((min(max(fraction, 0), 1) * 100).rounded())) }

    // MARK: CPU

    @ViewBuilder
    private func cpu(_ s: SystemSnapshot) -> some View {
        let history = monitor.cpuHistory.values
        let detail = "User \(Format.percent(s.cpu.user)) · System \(Format.percent(s.cpu.system))"
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader(title: "CPU", symbol: "cpu")
                Spacer(minLength: 0)
                WidgetMetric(value: percent(s.cpu.total), unit: "%", size: 40)
                WidgetSparkline(values: history, capacity: SystemMonitor.historyLength, maxValue: 1).frame(height: 26)
            }
        case .medium:
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    WidgetHeader(title: "CPU", symbol: "cpu")
                    Spacer(minLength: 0)
                    WidgetMetric(value: percent(s.cpu.total), unit: "%", size: 44)
                    Text(detail).font(style.body(11)).foregroundStyle(style.secondary).lineLimit(1)
                }
                .frame(width: 138, alignment: .leading)
                VStack(spacing: 8) {
                    WidgetSparkline(values: history, capacity: SystemMonitor.historyLength, maxValue: 1)
                    WidgetCoreBars(loads: s.cpu.perCore, kinds: s.cpu.coreKinds).frame(height: 44)
                }
            }
        case .large, .extraLarge:
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(title: "CPU", symbol: "cpu", detail: coreSummary(s))
                HStack(alignment: .lastTextBaseline) {
                    WidgetMetric(value: percent(s.cpu.total), unit: "%", size: 48)
                    Spacer()
                    Text(detail).font(style.body(11)).foregroundStyle(style.secondary)
                }
                WidgetSparkline(values: history, capacity: SystemMonitor.historyLength, maxValue: 1).frame(height: 54)
                WidgetCoreBars(loads: s.cpu.perCore, kinds: s.cpu.coreKinds).frame(height: 40)
                WidgetDivider()
                WidgetWord("Busiest").font(style.label()).foregroundStyle(style.secondary)
                TopAppsList(apps: Array(s.topApps.prefix(3)), spacing: 7, track: style.ink.opacity(0.12))
                Spacer(minLength: 0)
            }
        }
    }

    private func coreSummary(_ s: SystemSnapshot) -> String {
        let e = s.cpu.coreKinds.filter { $0 == .efficiency }.count, p = s.cpu.coreKinds.filter { $0 == .performance }.count
        return e + p > 0 ? "\(e)E · \(p)P cores" : "\(s.cpu.perCore.count) cores"
    }

    // MARK: Memory

    @ViewBuilder
    private func memory(_ s: SystemSnapshot) -> some View {
        let m = s.memory
        let pressure = HStack(spacing: 4) {
            Image(systemName: m.pressure == .normal ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Text("Pressure: \(m.pressure.title)")
        }
        .font(style.body(11))
        .foregroundStyle(m.pressure == .normal ? AnyShapeStyle(style.secondary) : AnyShapeStyle(Color.orange))
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader(title: "Memory", symbol: "memorychip")
                Spacer(minLength: 0)
                WidgetMetric(value: percent(m.usedFraction), unit: "%", size: 40)
                WidgetBar(fraction: m.usedFraction)
                Text("\(Format.memory(m.used)) of \(Format.memory(m.total))").font(style.body(11)).foregroundStyle(style.secondary)
            }
        case .medium:
            HStack(spacing: 18) {
                ZStack {
                    WidgetRing(fraction: m.usedFraction, lineWidth: 9)
                    WidgetMetric(value: percent(m.usedFraction), unit: "%", size: 26, alignment: .center)
                }
                .frame(width: 104, height: 104)
                VStack(alignment: .leading, spacing: 5) {
                    WidgetHeader(title: "Memory", symbol: "memorychip", detail: Format.memory(m.total))
                    row("App", Format.memory(m.app))
                    row("Wired", Format.memory(m.wired))
                    row("Compressed", Format.memory(m.compressed))
                    row("Cached", Format.memory(m.cached))
                    pressure
                }
            }
        case .large, .extraLarge:
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(title: "Memory", symbol: "memorychip", detail: "\(Format.memory(m.used)) of \(Format.memory(m.total))")
                HStack(alignment: .lastTextBaseline) {
                    WidgetMetric(value: percent(m.usedFraction), unit: "%", size: 48)
                    Spacer()
                    pressure
                }
                WidgetSparkline(values: monitor.memoryHistory.values, capacity: SystemMonitor.historyLength, maxValue: 1).frame(height: 44)
                HStack(spacing: 14) {
                    tile("App", Format.memory(m.app))
                    tile("Wired", Format.memory(m.wired))
                    tile("Compressed", Format.memory(m.compressed))
                    tile("Swap", Format.memory(m.swapUsed))
                }
                WidgetDivider()
                WidgetWord("Using the most").font(style.label()).foregroundStyle(style.secondary)
                ForEach(s.memoryApps.prefix(4)) { app in
                    row(app.name, Format.memory(app.bytes))
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Disk activity and storage

    @ViewBuilder
    private func disk(_ s: SystemSnapshot) -> some View {
        let d = s.disk
        let scale = max(d.readBytesPerSecond, d.writeBytesPerSecond, 50_000_000)
        VStack(alignment: .leading, spacing: small ? 8 : 10) {
            WidgetHeader(title: "Disk", symbol: "internaldrive", detail: small ? nil : "\(Format.memory(d.available)) free")
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    WidgetMetric(value: Format.rate(d.readBytesPerSecond), caption: "Read", size: small ? 20 : 26)
                    WidgetBar(fraction: d.readBytesPerSecond / scale)
                }
                VStack(alignment: .leading, spacing: 4) {
                    WidgetMetric(value: Format.rate(d.writeBytesPerSecond), caption: "Write", size: small ? 20 : 26)
                    WidgetBar(fraction: d.writeBytesPerSecond / scale, color: style.accent.opacity(0.6))
                }
            }
            if size == .large || size == .extraLarge {
                WidgetDivider()
                storageRows(d)
            }
        }
    }

    @ViewBuilder
    private func storage(_ s: SystemSnapshot) -> some View {
        let d = s.disk
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader(title: "Storage", symbol: "externaldrive.fill")
                Spacer(minLength: 0)
                WidgetMetric(value: Format.memory(d.available), caption: "Free", size: 30)
                WidgetBar(fraction: d.usedFraction)
                Text("of \(Format.memory(d.total))").font(style.body(11)).foregroundStyle(style.secondary)
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(title: "Storage", symbol: "externaldrive.fill", detail: "Macintosh HD")
                HStack(alignment: .lastTextBaseline) {
                    WidgetMetric(value: Format.memory(d.available), unit: "free", size: 36)
                    Spacer()
                    Text("\(percent(d.usedFraction))% used").font(style.body(12)).foregroundStyle(style.secondary)
                }
                WidgetBar(fraction: d.usedFraction, height: 8)
                storageRows(d)
                Spacer(minLength: 0)
            }
        }
    }

    private func storageRows(_ d: DiskUsage) -> some View {
        VStack(spacing: 4) {
            row("Used", Format.memory(d.total - d.available))
            row("Available", Format.memory(d.available))
            row("Capacity", Format.memory(d.total))
        }
    }

    // MARK: Network and Wi-Fi

    @ViewBuilder
    private func network(_ s: SystemSnapshot) -> some View {
        let n = s.network
        let down = monitor.downloadHistory.values, up = monitor.uploadHistory.values
        let top = max((down + up).max() ?? 0, 100_000)
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader(title: "Network", symbol: "arrow.up.arrow.down")
                Spacer(minLength: 0)
                WidgetMetric(value: Format.rate(n.downloadBytesPerSecond), caption: "↓ Download", size: 22)
                WidgetMetric(value: Format.rate(n.uploadBytesPerSecond), caption: "↑ Upload", size: 15)
                WidgetSparkline(values: down, capacity: SystemMonitor.historyLength, maxValue: top).frame(height: 18)
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(title: "Network", symbol: "arrow.up.arrow.down", detail: "last minute")
                HStack(spacing: 24) {
                    WidgetMetric(value: Format.rate(n.downloadBytesPerSecond), caption: "↓ Download", size: 26)
                    WidgetMetric(value: Format.rate(n.uploadBytesPerSecond), caption: "↑ Upload", size: 26)
                }
                ZStack {
                    WidgetSparkline(values: down, capacity: SystemMonitor.historyLength, maxValue: top)
                    WidgetSparkline(values: up, capacity: SystemMonitor.historyLength, maxValue: top, color: style.accent.opacity(0.45))
                }
                .frame(maxHeight: size == .medium ? .infinity : 110)
                if size != .medium {
                    WidgetDivider()
                    row("Peak down", Format.rate(down.max() ?? 0))
                    row("Peak up", Format.rate(up.max() ?? 0))
                    Spacer(minLength: 0)
                }
            }
        }
    }

    @ViewBuilder
    private var wifiView: some View {
        let status = wifi ?? WiFiStatus(isPoweredOn: true)
        let bars = Image(systemName: status.isPoweredOn ? "wifi" : "wifi.slash", variableValue: Double(status.bars) / 4)
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader(title: "Wi-Fi", symbol: "wifi")
                Spacer(minLength: 0)
                bars.font(.system(size: 34, weight: .medium)).foregroundStyle(style.accent)
                Text(status.quality).font(style.title(15))
                Text(status.signal.map { "\($0) dBm" } ?? "—").font(style.body(11)).foregroundStyle(style.secondary)
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(title: status.networkName ?? "Wi-Fi", symbol: "wifi", detail: status.band.map { "\($0) GHz" })
                HStack(spacing: 16) {
                    bars.font(.system(size: 46, weight: .medium)).foregroundStyle(style.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.quality).font(style.title(20))
                        Text(status.signal.map { "Signal \($0) dBm" } ?? "No signal").font(style.body(12)).foregroundStyle(style.secondary)
                    }
                }
                row("Speed", status.transmitRate.map { "\(Int($0)) Mbps" } ?? "—")
                row("Channel", status.channel.map(String.init) ?? "—")
                if size != .medium {
                    row("Noise", status.noise.map { "\($0) dBm" } ?? "—")
                    row("Signal to noise", status.signal.flatMap { signal in status.noise.map { "\(signal - $0) dB" } } ?? "—")
                    if status.networkName == nil {
                        Text("The network's name needs Location access for All Set in System Settings.")
                            .font(style.body(10)).foregroundStyle(style.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Battery

    @ViewBuilder
    private func battery(_ s: SystemSnapshot) -> some View {
        if let b = s.battery {
            let state = b.isCharging ? "Charging" : b.isPluggedIn ? "Plugged in" : "On battery"
            let remaining = b.minutesRemaining.map { Format.duration(minutes: $0) + (b.isCharging ? " to full" : " left") }
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(title: "Battery", symbol: b.isCharging ? "battery.100percent.bolt" : "battery.75percent", detail: small ? nil : state)
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        WidgetRing(fraction: Double(b.percent) / 100, color: b.percent <= 20 && !b.isCharging ? .orange : nil,
                                   lineWidth: small ? 7 : 9)
                        WidgetMetric(value: "\(b.percent)", unit: "%", size: small ? 22 : 26, alignment: .center)
                    }
                    .frame(width: small ? 84 : 100, height: small ? 84 : 100)
                    if !small {
                        VStack(alignment: .leading, spacing: 5) {
                            row("Time", remaining ?? "—")
                            row("Health", b.health.map(Format.percent) ?? "—")
                            row("Draw", b.systemPowerWatts.map { Format.watts($0) } ?? "—")
                        }
                    }
                }
                if small { Text(remaining ?? state).font(style.body(11)).foregroundStyle(style.secondary) }
            }
        } else {
            WidgetStateView(kind: .empty, symbol: "powerplug.fill", title: "No battery", message: "This Mac runs on power.")
        }
    }

    @ViewBuilder
    private func batteryHealth(_ s: SystemSnapshot) -> some View {
        if let b = s.battery {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(title: "Battery Health", symbol: "heart.text.square", detail: small ? nil : b.condition)
                Spacer(minLength: 0)
                WidgetMetric(value: b.health.map { percent($0) } ?? "—", unit: "%", caption: "Maximum capacity", size: small ? 34 : 42)
                if let health = b.health { WidgetBar(fraction: health) }
                if small {
                    Text(b.cycleCount.map { "\($0) cycles" } ?? "Cycles unknown").font(style.body(11)).foregroundStyle(style.secondary)
                } else {
                    row("Cycles", b.cycleCount.map(String.init) ?? "—")
                    row("Capacity", "\(b.fullChargeCapacity.map(String.init) ?? "—") of \(b.designCapacity.map(String.init) ?? "—") mAh")
                    if size != .medium {
                        row("Condition", b.condition ?? "—")
                        row("Temperature", b.temperatureCelsius.map { Format.temperature($0, unit: unit) } ?? "—")
                        Text("Batteries wear with use. Below 80% macOS recommends service.")
                            .font(style.body(10)).foregroundStyle(style.secondary)
                    }
                }
            }
        } else {
            WidgetStateView(kind: .empty, symbol: "powerplug.fill", title: "No battery", message: "This Mac runs on power.")
        }
    }

    // MARK: Uptime and status

    private var uptime: some View {
        let seconds = ProcessInfo.processInfo.systemUptime
        let minutes = Int(seconds / 60)
        let days = minutes / 1440, hours = minutes / 60 % 24
        let text = days > 0 ? "\(days)d \(hours)h" : "\(hours)h \(minutes % 60)m"
        let since = Date.now.addingTimeInterval(-seconds)
        return WidgetTimeline(.periodic(from: .now, by: 60)) { _ in
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader(title: "Uptime", symbol: "clock.arrow.circlepath")
                Spacer(minLength: 0)
                WidgetMetric(value: text, size: small ? 32 : 40)
                Text("Since \(since.formatted(.dateTime.weekday(.abbreviated).hour().minute()))")
                    .font(style.body(11)).foregroundStyle(style.secondary)
            }
        }
    }

    @ViewBuilder
    private func status(_ s: SystemSnapshot) -> some View {
        let checks = StatusCheckRow.checks(s)
        let problems = checks.filter { !$0.ok }
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader(title: "Status", symbol: "checkmark.shield")
                Spacer(minLength: 0)
                Image(systemName: problems.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(problems.isEmpty ? style.accent : .orange)
                Text(problems.isEmpty ? "All good" : "\(problems.count) to look at").font(style.title(16))
                Text(problems.first?.detail ?? "Cool, calm and roomy").font(style.body(11)).foregroundStyle(style.secondary).lineLimit(1)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(title: "System Status", symbol: "checkmark.shield", detail: problems.isEmpty ? "All good" : "\(problems.count) issue\(problems.count == 1 ? "" : "s")")
                ForEach(checks, id: \.title) { check in
                    HStack(spacing: 8) {
                        Image(systemName: check.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(check.ok ? style.accent : .orange)
                            .frame(width: 16)
                        WidgetWord(check.title).font(style.body(12))
                        Spacer()
                        Text(check.detail).font(style.body(12)).foregroundStyle(style.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Pieces

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(style.secondary)
            Spacer(minLength: 6)
            Text(value).monospacedDigit()
        }
        .font(style.body(12))
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(style.label(10)).foregroundStyle(style.secondary)
            Text(value).font(style.body(13, weight: .semibold)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

/// A health check for the System Status widget. Words and symbols carry the
/// meaning, not only color.
struct StatusCheckRow {
    let title: String
    let detail: String
    let ok: Bool

    static func checks(_ s: SystemSnapshot) -> [StatusCheckRow] {
        var rows = [
            StatusCheckRow(title: "Temperature", detail: s.thermal.title, ok: s.thermal == .nominal || s.thermal == .fair),
            StatusCheckRow(title: "Memory", detail: s.memory.pressure.title, ok: s.memory.pressure == .normal),
            StatusCheckRow(title: "CPU", detail: Format.percent(s.cpu.total), ok: s.cpu.total < 0.85),
            StatusCheckRow(title: "Storage", detail: "\(Format.memory(s.disk.available)) free", ok: s.disk.usedFraction < 0.9),
        ]
        if let battery = s.battery {
            rows.append(StatusCheckRow(title: "Battery", detail: "\(battery.percent)%\(battery.isCharging ? ", charging" : "")",
                                       ok: battery.percent > 15 || battery.isPluggedIn))
        }
        return rows
    }
}

/// A bar per core: performance cores in the accent, efficiency cores softer.
struct WidgetCoreBars: View {
    let loads: [Double]
    let kinds: [CoreKind]
    @Environment(\.widgetStyle) private var style

    var body: some View {
        Canvas { context, size in
            guard !loads.isEmpty else { return }
            let gap: CGFloat = 3
            let width = (size.width - gap * CGFloat(loads.count - 1)) / CGFloat(loads.count)
            for (index, load) in loads.enumerated() {
                let x = CGFloat(index) * (width + gap)
                let track = Path(roundedRect: CGRect(x: x, y: 0, width: width, height: size.height), cornerRadius: min(width / 2, 3))
                context.fill(track, with: .color(style.ink.opacity(0.1)))
                let height = size.height * CGFloat(min(max(load, 0), 1))
                let bar = Path(roundedRect: CGRect(x: x, y: size.height - height, width: width, height: height), cornerRadius: min(width / 2, 3))
                let efficiency = kinds.indices.contains(index) && kinds[index] == .efficiency
                context.fill(bar, with: .color(style.accent.opacity(efficiency ? 0.55 : 1)))
            }
        }
        .accessibilityLabel("Per-core load")
    }
}
