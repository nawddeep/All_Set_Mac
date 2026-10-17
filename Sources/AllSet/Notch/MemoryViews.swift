import AllSetCore
import AppKit
import SwiftUI

/// Freeing memory: quitting the apps that use most.
@MainActor
enum MemoryActions {
    /// Apps can be quit; loose processes and All Set itself can't from here.
    static func canQuit(_ app: AppMemory) -> Bool {
        app.isApp && app.id != Bundle.main.bundlePath
    }

    /// Asks the app to quit, as the Dock's Quit does, so it can save its work.
    static func quit(_ app: AppMemory) {
        for running in NSWorkspace.shared.runningApplications where running.bundleURL?.path == app.id {
            running.terminate()
        }
    }
}

/// The island's heaviest apps, by energy or by memory.
struct TopAppsCard: View {
    let services: AppServices

    private enum Mode {
        case energy, memory
    }

    @State private var mode = Mode.energy

    var body: some View {
        let snapshot = services.monitor.snapshot
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                modeButton("Energy", symbol: "bolt.fill", .energy)
                modeButton("Memory", symbol: "memorychip", .memory)
            }
            switch mode {
            case .energy:
                TopAppsList(apps: snapshot.topApps)
                    .padding(.top, 2)
                    .frame(maxHeight: .infinity, alignment: .top)
            case .memory:
                MemoryAppsList(apps: snapshot.memoryApps)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.06)))
    }

    private func modeButton(_ title: String, symbol: String, _ value: Mode) -> some View {
        Button {
            withMotion(Motion.quick) { mode = value }
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(mode == value ? .white : .secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(.white.opacity(mode == value ? 0.16 : 0)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Apps by memory, each with a bar scaled to the heaviest and a Quit button on hover.
struct MemoryAppsList: View {
    let apps: [AppMemory]

    var body: some View {
        let top = Double(max(apps.map(\.bytes).max() ?? 1, 1))
        if apps.isEmpty {
            Text("Measuring…")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } else {
            // Not animated, like the energy list: it changes too often.
            VStack(spacing: 7) {
                ForEach(apps) { app in
                    MemoryAppRow(app: app, fraction: Double(app.bytes) / top)
                }
            }
        }
    }
}

private struct MemoryAppRow: View {
    let app: AppMemory
    let fraction: Double

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: AppIconCache.icon(forPath: app.id))
                .resizable()
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if isHovering, MemoryActions.canQuit(app) {
                        Button("Quit") { MemoryActions.quit(app) }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.orange)
                            .buttonStyle(.plain)
                            .help("Quit \(app.name) to free its memory")
                    } else {
                        Text(Format.memory(app.bytes))
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                LevelBar(fraction: fraction, color: Theme.memory, track: .white.opacity(0.14))
                    .frame(height: 4)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}
