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
            if store.removedShellCommands > 0 {
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.shield").foregroundStyle(.orange)
                        Text(store.removedShellCommands == 1
                             ? "A knock was set to run a shell command. All Set no longer runs shell commands, so that slot is now empty. To automate something, choose Run Shortcut instead."
                             : "\(store.removedShellCommands) knocks were set to run shell commands. All Set no longer runs shell commands, so those slots are now empty. To automate something, choose Run Shortcut instead.")
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button("OK") { store.acknowledgeRemovedShellCommands() }
                    }
                }
            }
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
struct KnockHeader: View {
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

struct KnockDots: View {
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
struct KnockRow: View {
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
struct KnockMeter: View {
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
struct MeterBars: NSViewRepresentable {
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

struct SensitivityControls: View {
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
