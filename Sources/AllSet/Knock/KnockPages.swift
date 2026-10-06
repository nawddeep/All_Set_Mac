import AllSetCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// TapTap: pick what a single, double and triple knock do.
struct KnockPage: View {
    let services: AppServices

    @State private var choosing: KnockCount?
    @State private var showsMore = false

    var body: some View {
        let knocks = services.knocks
        let store = knocks.store
        FormPage(eyebrow: "Tools", title: "TapTap",
                 subtitle: "Knock on your Mac to run something: one, two or three knocks, each its own action.") {
            Section {
                KnockHeader(knocks: knocks, isEnabled: binding(\.isEnabled))
            }

            if KnockListener.isSupported {
                Section {
                    ForEach(KnockCount.allCases) { count in
                        KnockRow(count: count, action: store.settings[count],
                                 choose: { choosing = count },
                                 clear: { store.settings[count] = nil },
                                 test: { action in Task { await knocks.test(action, count: count) } })
                    }
                } footer: {
                    Text("Knock with a knuckle on the palm rest, next to the trackpad.")
                }

                Section {
                    DisclosureGroup("More settings", isExpanded: $showsMore) {
                        KnockMeter(listener: knocks.listener, threshold: store.settings.sensitivity.threshold)
                        SensitivityControls(sensitivity: binding(\.sensitivity))
                        LabeledContent("Knock speed") {
                            HStack {
                                Slider(value: binding(\.tapWindow), in: DetectorConfiguration.tapWindowRange, step: 0.01)
                                    .frame(width: 200)
                                Text("\(Int((store.settings.tapWindow * 1000).rounded())) ms")
                                    .monospacedDigit()
                                    .frame(width: 56, alignment: .trailing)
                            }
                        }
                        Toggle("Ignore knocks while typing", isOn: binding(\.ignoreWhileTyping))
                        Toggle("Rest on battery (saves power)", isOn: binding(\.restOnBattery))
                            .help("Listening reads the motion sensor about 800 times a second. Off, knocks also work away from the charger.")
                        Toggle("Rest in Low Power Mode", isOn: binding(\.restInLowPowerMode))
                        Toggle("Show knocks in the Dynamic Island", isOn: binding(\.showInIsland))
                        Toggle("Click when a knock is heard", isOn: binding(\.playSound))
                    }
                }
            }
        }
        .onAppear { knocks.isTuning = true }
        .onDisappear { knocks.isTuning = false }
        .sheet(item: $choosing) { count in
            KnockActionPicker(services: services, title: "\(count.title) knock", current: store.settings[count]) { action in
                store.settings[count] = action
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<KnockSettings, Value>) -> Binding<Value> {
        Binding(get: { services.knockStore.settings[keyPath: keyPath] },
                set: { services.knockStore.settings[keyPath: keyPath] = $0 })
    }
}

/// On or off, whether the sensor is listening, and what the last knock did.
private struct KnockHeader: View {
    let knocks: KnockController
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.accentColor.gradient))
                .symbolEffect(.bounce, value: knocks.listener.tapPulse)
            VStack(alignment: .leading, spacing: 3) {
                Text("TapTap").font(.headline)
                Label(statusText, systemImage: statusSymbol)
                    .font(.callout)
                    .foregroundStyle(statusColor)
                if let outcome = knocks.lastOutcome {
                    TimelineView(.periodic(from: .now, by: 5)) { _ in
                        Text(describe(outcome))
                            .font(.caption)
                            .foregroundStyle(outcome.failure == nil ? Color.secondary : .orange)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            Toggle("TapTap", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(!KnockListener.isSupported)
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        switch knocks.listener.status {
        case .off: "Off"
        case .listening: "Listening for knocks"
        case .resting: "Resting on battery, in Low Power Mode, or while the display is off or the Mac is locked"
        case .noSensor: "This Mac has no motion sensor"
        case .retrying: "The motion sensor stopped; trying again"
        }
    }

    private var statusSymbol: String {
        switch knocks.listener.status {
        case .listening: "waveform"
        case .resting: "moon.fill"
        case .noSensor, .retrying: "exclamationmark.triangle.fill"
        case .off: "pause.circle"
        }
    }

    private var statusColor: Color {
        switch knocks.listener.status {
        case .listening: .green
        case .noSensor, .retrying: .orange
        default: .secondary
        }
    }

    private func describe(_ outcome: KnockController.Outcome) -> String {
        let ago = outcome.date.formatted(.relative(presentation: .named))
        let what = outcome.action?.title ?? "nothing"
        if let failure = outcome.failure {
            return "\(outcome.count.title) knock \(ago): \(what) didn't work. \(failure)"
        }
        return "\(outcome.count.title) knock \(ago): \(what)"
    }
}

private struct KnockDots: View {
    let count: KnockCount

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<count.rawValue, id: \.self) { _ in
                Circle().frame(width: 6, height: 6)
            }
        }
    }
}

/// "Single knock → Google Chrome", with buttons to change, try or clear it.
private struct KnockRow: View {
    let count: KnockCount
    let action: KnockAction?
    let choose: () -> Void
    let clear: () -> Void
    let test: (KnockAction) -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                KnockDots(count: count)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 26, alignment: .leading)
                Text("\(count.title) knock")
                    .font(.body.weight(.medium))
            }
            .frame(width: 150, alignment: .leading)

            Image(systemName: "arrow.right")
                .foregroundStyle(.tertiary)

            if let action {
                ActionIcon(action: action, size: 22)
                Text(action.title)
                    .lineLimit(1)
            } else {
                Text("Nothing")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let action {
                Button { test(action) } label: { Image(systemName: "play.fill") }
                    .help("Try it")
                Button(action: clear) { Image(systemName: "xmark") }
                    .help("Do nothing")
            }
            Button(action == nil ? "Choose…" : "Change…", action: choose)
        }
        .buttonStyle(.bordered)
        .padding(.vertical, 4)
    }
}

/// An app's own icon for opening it; the action's symbol otherwise.
struct ActionIcon: View {
    let action: KnockAction
    let size: CGFloat

    var body: some View {
        if case .openApp(let bundleID, _) = action {
            AppIcon(bundleIdentifier: bundleID, size: size)
        } else {
            Image(systemName: action.symbol)
                .foregroundStyle(Color.accentColor)
                .frame(width: size, height: size)
        }
    }
}


/// What the sensor feels right now, against the threshold a knock must cross.
private struct KnockMeter: View {
    let listener: KnockListener
    let threshold: Double

    @State private var flash = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Live")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if flash {
                    Text("Knock")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                        .transition(.scale.combined(with: .opacity))
                } else if listener.status != .listening {
                    Text("Not listening")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            MeterBars(listener: listener, threshold: threshold)
                .frame(height: 96)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text("Knock and watch it cross the red line. Typing and moving the Mac should stay under it; if they don't, pick a firmer setting.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .motion(Motion.press, value: flash)
        .onChange(of: listener.tapPulse) {
            flash = true
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                flash = false
            }
        }
    }
}

/// The meter's bars, drawn by Core Animation as readings arrive rather than
/// through SwiftUI, which would lay out the whole page 30 times a second.
private struct MeterBars: NSViewRepresentable {
    let listener: KnockListener
    let threshold: Double

    func makeNSView(context: Context) -> MeterBarsView {
        let view = MeterBarsView()
        view.threshold = threshold
        listener.onMeter = { [weak view] values in view?.show(values) }
        listener.startMetering()
        view.stop = { [listener] in
            listener.stopMetering()
            listener.onMeter = nil
        }
        return view
    }

    func updateNSView(_ view: MeterBarsView, context: Context) {
        view.threshold = threshold
    }

    static func dismantleNSView(_ view: MeterBarsView, coordinator: ()) {
        MainActor.assumeIsolated {
            view.stop?()
        }
    }

    func makeCoordinator() {}
}

final class MeterBarsView: NSView {
    var threshold = 0.1 {
        didSet { if threshold != oldValue { redraw() } }
    }
    var stop: (() -> Void)?

    /// The top of the meter in g; a square-root scale keeps small movements visible.
    private let ceiling = 0.6
    private let quiet = CAShapeLayer()
    private let loud = CAShapeLayer()
    private let line = CAShapeLayer()
    private var values: [Double] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        line.lineDashPattern = [4, 3]
        line.lineWidth = 1
        line.fillColor = nil
        for sublayer in [quiet, loud, line] {
            layer?.addSublayer(sublayer)
        }
        applyColors()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }

    override func layout() {
        super.layout()
        redraw()
    }

    func show(_ values: [Double]) {
        self.values = values
        redraw()
    }

    private func applyColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            quiet.fillColor = NSColor.controlAccentColor.withAlphaComponent(0.7).cgColor
            loud.fillColor = NSColor.systemOrange.cgColor
            line.strokeColor = NSColor.systemRed.withAlphaComponent(0.75).cgColor
        }
    }

    private func level(_ value: Double) -> CGFloat {
        CGFloat((min(max(value, 0), ceiling) / ceiling).squareRoot())
    }

    private func redraw() {
        let size = bounds.size
        guard size.width > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let limit = KnockListener.meterLength
        let width = size.width / CGFloat(limit)
        let quietPath = CGMutablePath()
        let loudPath = CGMutablePath()
        for (index, value) in values.enumerated() {
            let height = max(size.height * level(value), 1)
            let bar = CGRect(x: CGFloat(limit - values.count + index) * width, y: 0, width: max(width - 1, 1), height: height)
            (value >= threshold ? loudPath : quietPath).addRect(bar)
        }
        quiet.path = quietPath
        loud.path = loudPath
        let y = size.height * level(threshold)
        let linePath = CGMutablePath()
        linePath.move(to: CGPoint(x: 0, y: y))
        linePath.addLine(to: CGPoint(x: size.width, y: y))
        line.path = linePath
        CATransaction.commit()
    }
}

private struct SensitivityControls: View {
    @Binding var sensitivity: Sensitivity

    private enum Choice: Hashable {
        case preset(Sensitivity)
        case custom
    }

    var body: some View {
        let choice = Binding<Choice>(
            get: { if case .custom = sensitivity { .custom } else { .preset(sensitivity) } },
            set: { newValue in
                switch newValue {
                case .preset(let preset): sensitivity = preset
                case .custom: sensitivity = .custom(sensitivity.threshold)
                }
            }
        )
        Picker("Knock strength", selection: choice) {
            ForEach(Sensitivity.presets, id: \.self) { preset in
                Text(preset.title).tag(Choice.preset(preset))
            }
            Text("Custom").tag(Choice.custom)
        }
        .pickerStyle(.segmented)
        if case .custom = sensitivity {
            LabeledContent("Threshold") {
                HStack {
                    Slider(value: Binding(get: { sensitivity.threshold }, set: { sensitivity = .custom($0) }),
                           in: 0.02...0.6)
                        .frame(width: 200)
                    Text(String(format: "%.2f g", sensitivity.threshold))
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }
            }
        }
    }
}
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
    @State private var command = ""

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
            if needle.isEmpty {
                Section("Shell Command") {
                    HStack {
                        TextField("open ~/Downloads", text: $command)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button("Use") { choose(.shellCommand(command.trimmingCharacters(in: .whitespaces))) }
                            .disabled(command.trimmingCharacters(in: .whitespaces).isEmpty)
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
