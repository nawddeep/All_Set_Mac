import AllSetCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Chooses what a knock does: an app to open (the usual choice), or one of
/// the other actions.
struct KnockActionPicker: View {
    let services: AppServices
    let title: String
    let current: KnockAction?
    let onPick: (KnockAction) -> Void

    private enum Mode: Hashable {
        case apps, actions
    }

    @Environment(\.dismiss) private var dismiss
    @State private var mode = Mode.apps
    @State private var query = ""
    @State private var apps: [InstalledApp]?
    @State private var shortcuts: [String] = []

    var body: some View {
        VStack(spacing: 12) {
            Text("\(title) does…").font(.headline)
            Picker("", selection: $mode) {
                Text("Open an App").tag(Mode.apps)
                Text("Other Actions").tag(Mode.actions)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 280)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(mode == .apps ? "Search apps" : "Search actions", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.07)))

            Group {
                if mode == .apps { appList } else { actionList }
            }
            .frame(maxHeight: .infinity)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 440, height: 560)
        .task {
            apps = await Task.detached { InstalledApp.all() }.value
            shortcuts = await Task.detached { Self.shortcutNames() }.value
        }
    }

    private var appList: some View {
        Group {
            if let apps {
                let matches = SearchMatch.rank(apps, by: query, name: \.name)
                List(matches) { app in
                    let action = KnockAction.openApp(bundleID: app.id, name: app.name)
                    Button { choose(action) } label: {
                        HStack(spacing: 10) {
                            Image(nsImage: AppIconCache.icon(forPath: app.path))
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text(app.name)
                            Spacer()
                            if action == current {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var actionList: some View {
        let workspaces = services.workspaces.workspaces.map { KnockAction.applyWorkspace(id: $0.id, name: $0.name) }
        var all = KnockAction.simple
        all.insert(contentsOf: IslandTab.allCases.map { .openIsland($0) }, at: 1)
        all += workspaces + [.leftHalf, .rightHalf, .maximize, .center].map { .moveWindow($0) }
        all += shortcuts.map { .runShortcut(name: $0) }
        all += KnockAction.soundNames.map { .playSound(name: $0) }
        let needle = query.trimmingCharacters(in: .whitespaces)
        let sections = KnockAction.Category.allCases.filter { $0 != .apps }.compactMap { category -> (KnockAction.Category, [KnockAction])? in
            let actions = all.filter { $0.category == category && SearchMatch.containsAll(needle, in: $0.title) }
            return actions.isEmpty ? nil : (category, actions)
        }
        return List {
            ForEach(sections, id: \.0) { category, actions in
                Section(category.title) {
                    ForEach(actions) { action in
                        Button { choose(action) } label: {
                            HStack(spacing: 10) {
                                ActionIcon(action: action, size: 22)
                                Text(action.title)
                                Spacer()
                                if action == current {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func choose(_ action: KnockAction) {
        onPick(action)
        dismiss()
    }

    /// The Shortcuts app's shortcuts, by name.
    nonisolated private static func shortcutNames() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["list"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

/// An app in the Applications folders.
struct InstalledApp: Identifiable, Sendable {
    /// The bundle ID.
    let id: String
    let name: String
    let path: String

    /// Every app in /Applications, /System/Applications and ~/Applications
    /// (and their Utilities folders), by name.
    static func all() -> [InstalledApp] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let folders = ["/Applications", "/Applications/Utilities", "/System/Applications",
                       "/System/Applications/Utilities", home + "/Applications"]
        var seen = Set<String>()
        var apps: [InstalledApp] = []
        func add(_ path: String) {
            guard let id = Bundle(path: path)?.bundleIdentifier, id != Bundle.main.bundleIdentifier,
                  seen.insert(id).inserted else { return }
            let name = FileManager.default.displayName(atPath: path)
            apps.append(InstalledApp(id: id, name: name.hasSuffix(".app") ? String(name.dropLast(4)) : name, path: path))
        }
        for folder in folders {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
            for name in names where !name.hasPrefix(".") {
                let path = folder + "/" + name
                if name.hasSuffix(".app") {
                    add(path)
                } else if name != "Utilities" {
                    // Suites keep their apps a folder down: "Adobe Photoshop 2026", "Chrome Apps".
                    var isFolder: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: path, isDirectory: &isFolder), isFolder.boolValue else { continue }
                    let inner = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
                    for innerName in inner where innerName.hasSuffix(".app") { add(path + "/" + innerName) }
                }
            }
        }
        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
