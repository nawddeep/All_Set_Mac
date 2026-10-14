import AllSetCore
import SwiftUI

/// Detailed stats: a 3×2 grid of cards, with the heaviest apps alongside.
struct SystemTab: View {
    let services: AppServices

    var body: some View {
        let monitor = services.monitor
        let snapshot = monitor.snapshot
        let unit = services.settings.temperatureUnit

        // Every card gets its exact size up front. Left to share out flexible
        // space, the stacks measure each card several times over, which made
        // this the slowest tab to open.
        GeometryReader { geometry in
            let card = CGSize(width: ((geometry.size.width - 216 - 10 - 20) / 3).rounded(.down),
                              height: ((geometry.size.height - 10) / 2).rounded(.down))
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        CPUCard(cpu: snapshot.cpu, temperature: snapshot.temperatures.soc, thermal: snapshot.thermal, unit: unit)
                            .frame(width: card.width, height: card.height)
                        GPUCard(gpu: snapshot.gpu, history: monitor.gpuHistory)
                            .frame(width: card.width, height: card.height)
                        MemoryCard(memory: snapshot.memory)
                            .frame(width: card.width, height: card.height)
                    }
                    HStack(spacing: 10) {
                        NetworkCard(network: snapshot.network, download: monitor.downloadHistory, upload: monitor.uploadHistory)
                            .frame(width: card.width, height: card.height)
                        DiskCard(disk: snapshot.disk, temperature: snapshot.temperatures.ssd, unit: unit)
                            .frame(width: card.width, height: card.height)
                        Group {
                            if let battery = snapshot.battery {
                                BatteryCard(battery: battery, unit: unit)
                            } else {
                                CPUHistoryCard(history: monitor.cpuHistory)
                            }
                        }
                        .frame(width: card.width, height: card.height)
                    }
                }
                TopAppsCard(services: services)
                    .frame(width: 216, height: geometry.size.height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
        }
    }
}

private struct CPUCard: View {
    let cpu: CPUUsage
    let temperature: Double?
    let thermal: ThermalLevel
    let unit: TemperatureUnit

    var body: some View {
        StatCard(title: "CPU", symbol: "cpu", color: Theme.cpu, value: Format.percent(cpu.total)) {
            VStack(alignment: .leading, spacing: 6) {
                CoreBars(perCore: cpu.perCore, kinds: cpu.coreKinds)
                HStack(spacing: 8) {
                    Legend(color: Theme.efficiencyCore, text: "\(count(.efficiency)) Eff")
                    Legend(color: Theme.cpu, text: "\(count(.performance)) Perf")
                    Spacer(minLength: 0)
                    if let temperature {
                        Text("\(Format.temperature(temperature, unit: unit)) · \(thermal.title)")
                            .foregroundStyle(Theme.thermal(thermal))
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
    }

    private func count(_ kind: CoreKind) -> Int {
        cpu.coreKinds.filter { $0 == kind }.count
    }
}

private struct GPUCard: View {
    let gpu: GPUUsage?
    let history: RollingSeries

    var body: some View {
        StatCard(title: "GPU", symbol: "square.stack.3d.up.fill", color: Theme.gpu,
                 value: gpu.map { Format.percent($0.utilization) } ?? "–") {
            VStack(alignment: .leading, spacing: 6) {
                Sparkline(values: history.values, capacity: history.capacity, color: Theme.gpu, maxValue: 1)
                if let memory = gpu?.memoryInUse {
                    Text("\(Format.memory(memory)) in use")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct MemoryCard: View {
    let memory: MemoryUsage

    var body: some View {
        StatCard(title: "Memory", symbol: "memorychip", color: Theme.memory, value: Format.percent(memory.usedFraction)) {
            VStack(alignment: .leading, spacing: 7) {
                Text("\(Format.memory(memory.used)) of \(Format.memory(memory.total))")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                UsageBar(segments: [
                    .init(fraction: share(memory.app), color: Theme.memory),
                    .init(fraction: share(memory.wired), color: Theme.disk),
                    .init(fraction: share(memory.compressed), color: Theme.gpu),
                ])
                .frame(height: 6)
                HStack(spacing: 8) {
                    Legend(color: Theme.memory, text: "App")
                    Legend(color: Theme.disk, text: "Wired")
                    Legend(color: Theme.gpu, text: "Compressed")
                }
                Text("Pressure \(memory.pressure.title) · Swap \(Format.memory(memory.swapUsed))")
                    .foregroundStyle(memory.pressure == .normal ? Color.secondary : Theme.pressure(memory.pressure))
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    private func share(_ bytes: UInt64) -> Double {
        memory.total > 0 ? Double(bytes) / Double(memory.total) : 0
    }
}

private struct NetworkCard: View {
    let network: NetworkRates
    let download: RollingSeries
    let upload: RollingSeries

    var body: some View {
        let peak = max(download.maximum, upload.maximum, 1024)
        StatCard(title: "Network", symbol: "network", color: Theme.download) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Chip(symbol: "arrow.down", text: Format.rate(network.downloadBytesPerSecond), color: Theme.download)
                    Chip(symbol: "arrow.up", text: Format.rate(network.uploadBytesPerSecond), color: Theme.upload)
                }
                ZStack {
                    Sparkline(values: download.values, capacity: download.capacity, color: Theme.download, maxValue: peak)
                    Sparkline(values: upload.values, capacity: upload.capacity, color: Theme.upload, maxValue: peak, filled: false)
                }
            }
        }
    }
}

private struct DiskCard: View {
    let disk: DiskUsage
    let temperature: Double?
    let unit: TemperatureUnit

    var body: some View {
        StatCard(title: "Disk", symbol: "internaldrive.fill", color: Theme.disk, value: Format.percent(disk.usedFraction)) {
            VStack(alignment: .leading, spacing: 7) {
                Text("\(Format.bytes(Double(disk.available))) free of \(Format.bytes(Double(disk.total)))")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.primary)
                LevelBar(fraction: disk.usedFraction, color: Theme.disk)
                    .frame(height: 6)
                HStack(spacing: 10) {
                    Text("Read \(Format.rate(disk.readBytesPerSecond))")
                    Text("Write \(Format.rate(disk.writeBytesPerSecond))")
                }
                .monospacedDigit()
                if let temperature {
                    Text("SSD \(Format.temperature(temperature, unit: unit))")
                }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}

private struct BatteryCard: View {
    let battery: BatteryInfo
    let unit: TemperatureUnit

    var body: some View {
        let color = Theme.battery(percent: battery.percent, charging: battery.isCharging)
        StatCard(title: "Battery", symbol: battery.isCharging ? "battery.100percent.bolt" : "battery.75percent",
                 color: color, value: "\(battery.percent)%") {
            VStack(alignment: .leading, spacing: 7) {
                Text(battery.statusDescription)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                LevelBar(fraction: Double(battery.percent) / 100, color: color)
                    .frame(height: 6)
                HStack(spacing: 8) {
                    if let health = battery.health {
                        Text("Health \(Format.percent(health))")
                    }
                    if let cycles = battery.cycleCount {
                        Text("\(cycles) cycles")
                    }
                }
                HStack(spacing: 8) {
                    if let watts = battery.systemPowerWatts ?? battery.batteryWatts {
                        Text("Using \(Format.watts(watts))")
                    }
                    if let temperature = battery.temperatureCelsius {
                        Text(Format.temperature(temperature, unit: unit))
                    }
                    if battery.isLowPowerMode {
                        Text("Low Power").foregroundStyle(.yellow)
                    }
                }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}

private struct CPUHistoryCard: View {
    let history: RollingSeries

    var body: some View {
        StatCard(title: "CPU History", symbol: "waveform.path.ecg", color: Theme.cpu) {
            Sparkline(values: history.values, capacity: history.capacity, color: Theme.cpu, maxValue: 1)
        }
    }
}

/// Per-core load, efficiency cores first as the hardware numbers them.
private struct CoreBars: View {
    let perCore: [Double]
    let kinds: [CoreKind]

    var body: some View {
        BarGauge(values: perCore,
                 colors: perCore.indices.map { index in
                     (index < kinds.count ? kinds[index] : .unknown) == .efficiency ? Theme.efficiencyCore : Theme.cpu
                 })
    }
}

#if DEBUG
extension SystemTab {
    /// `AllSet -probe systembuild`: how long each part of this tab takes to build and lay out.
    @MainActor static func buildTimes(services: AppServices) async {
        let monitor = services.monitor
        try? await Task.sleep(for: .seconds(3))
        let snapshot = monitor.snapshot
        let unit = services.settings.temperatureUnit
        let parts: [(String, CGSize, () -> AnyView)] = [
            ("whole tab", CGSize(width: 820, height: 240), { AnyView(SystemTab(services: services)) }),
            ("cpu", CGSize(width: 190, height: 115), { AnyView(CPUCard(cpu: snapshot.cpu, temperature: snapshot.temperatures.soc, thermal: snapshot.thermal, unit: unit)) }),
            ("gpu", CGSize(width: 190, height: 115), { AnyView(GPUCard(gpu: snapshot.gpu, history: monitor.gpuHistory)) }),
            ("memory", CGSize(width: 190, height: 115), { AnyView(MemoryCard(memory: snapshot.memory)) }),
            ("network", CGSize(width: 190, height: 115), { AnyView(NetworkCard(network: snapshot.network, download: monitor.downloadHistory, upload: monitor.uploadHistory)) }),
            ("disk", CGSize(width: 190, height: 115), { AnyView(DiskCard(disk: snapshot.disk, temperature: snapshot.temperatures.ssd, unit: unit)) }),
            ("battery", CGSize(width: 190, height: 115), { AnyView(snapshot.battery.map { AnyView(BatteryCard(battery: $0, unit: unit)) } ?? AnyView(EmptyView())) }),
            ("top apps", CGSize(width: 216, height: 240), { AnyView(TopAppsCard(services: services)) }),
            ("empty", CGSize(width: 190, height: 115), { AnyView(Color.clear) }),
        ]
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 300), styleMask: [.borderless], backing: .buffered, defer: false)
        window.alphaValue = 0.01
        window.orderFrontRegardless()
        for (name, size, make) in parts {
            var times: [Double] = []
            for _ in 0..<9 {
                let start = CACurrentMediaTime()
                let host = NSHostingView(rootView: make().environment(\.colorScheme, .dark))
                host.frame = CGRect(origin: .zero, size: size)
                window.contentView = host
                host.layoutSubtreeIfNeeded()
                host.displayIfNeeded()
                CATransaction.flush()
                times.append(CACurrentMediaTime() - start)
                try? await Task.sleep(for: .milliseconds(30))
            }
            times.sort()
            print(String(format: "%-10@ first %5.1f ms, median %5.1f ms", name as NSString, times.first! * 1000, times[4] * 1000))
        }
        window.close()
    }
}
#endif
