import AllSetCore
import AppKit
import SwiftUI

/// What the picker is showing: the search and the highlighted row.
@Observable @MainActor
final class PickerState {
    var query = "" { didSet { selection = 0 } }
    var selection = 0
}

/// A panel that takes the keyboard without making All Set the active app, so
/// the app being used stays in front and receives the paste.
private final class PickerPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    override var canBecomeKey: Bool { true }
}

/// The ⌃⌥V clipboard picker: search, arrow keys, Return to paste.
@MainActor
final class ClipboardPickerController {
    static let shared = ClipboardPickerController()

    private var panel: PickerPanel?
    private let state = PickerState()
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private weak var services: AppServices?

    func toggle(services: AppServices) {
        if panel?.isVisible == true { close() } else { show(services: services) }
    }

    func show(services: AppServices) {
        self.services = services
        state.query = ""
        let panel = self.panel ?? makePanel(services: services)
        self.panel = panel

        let size = CGSize(width: 620, height: 470)
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            panel.setFrame(CGRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2 + visible.height * 0.08,
                                  width: size.width, height: size.height), display: true)
        }
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) ?? false } ? nil : event
        }
        resignObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    func close() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        panel?.orderOut(nil)
    }

    private func makePanel(services: AppServices) -> PickerPanel {
        let panel = PickerPanel()
        let view = ClipboardPickerView(state: state, services: services) { [weak self] item in
            self?.pick(item)
        }
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []
        panel.contentView = host
        return panel
    }

    private var results: [ClipboardItem] {
        services?.clipboard.search(state.query) ?? []
    }

    private func pick(_ item: ClipboardItem) {
        close()
        services?.clipboardMonitor.paste(item)
    }

    /// True when the key was handled.
    private func handle(_ event: NSEvent) -> Bool {
        let command = event.modifierFlags.contains(.command)
        let items = results
        switch event.keyCode {
        case 53: // Esc
            close()
        case 125: // ↓
            state.selection = min(state.selection + 1, max(items.count - 1, 0))
        case 126: // ↑
            state.selection = max(state.selection - 1, 0)
        case 36, 76: // Return, Enter
            if items.indices.contains(state.selection) { pick(items[state.selection]) }
        case 51 where command: // ⌘⌫
            if items.indices.contains(state.selection) { services?.clipboard.remove(items[state.selection].id) }
        default:
            guard command, let characters = event.charactersIgnoringModifiers else { return false }
            if let digit = Int(characters), (1...9).contains(digit), items.indices.contains(digit - 1) {
                pick(items[digit - 1])
            } else if characters == "p", items.indices.contains(state.selection) {
                services?.clipboard.togglePin(items[state.selection].id)
            } else {
                return false
            }
        }
        return true
    }
}

private struct ClipboardPickerView: View {
    @Bindable var state: PickerState
    let services: AppServices
    let onPick: (ClipboardItem) -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        let results = services.clipboard.search(state.query)
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("Search your clipboard", text: $state.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .focused($searchFocused)
                Text("\(results.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            Divider()

            if results.isEmpty {
                ContentUnavailableView(state.query.isEmpty ? "Nothing copied yet" : "No matches",
                                       systemImage: "doc.on.clipboard",
                                       description: Text(state.query.isEmpty ? "Things you copy will appear here." : "Try another word."))
                    .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                                ClipboardRow(item: item, index: index, isSelected: index == state.selection, services: services)
                                    .id(item.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onPick(item) }
                                    .onHover { if $0 { state.selection = index } }
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: state.selection) { _, selection in
                        guard results.indices.contains(selection) else { return }
                        withMotion(Motion.quick) { proxy.scrollTo(results[selection].id) }
                    }
                }
            }

            Divider()
            HStack(spacing: 14) {
                hint("↩", "Paste")
                hint("⌘1–9", "Quick paste")
                hint("⌘P", "Pin")
                hint("⌘⌫", "Delete")
                Spacer()
                hint("esc", "Close")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
        .background(VisualEffectBlur(material: .hudWindow, appearance: nil, cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .onAppear { searchFocused = true }
    }

    private func hint(_ key: String, _ title: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.caption.weight(.semibold).monospaced())
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(.primary.opacity(0.1)))
            Text(title)
        }
    }
}

/// One history entry: a thumbnail or kind icon, the preview and where it came from.
struct ClipboardRow: View {
    let item: ClipboardItem
    var index: Int?
    var isSelected = false
    let services: AppServices
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: compact ? 28 : 38, height: compact ? 28 : 38)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.preview.isEmpty ? " " : item.preview)
                    .font(.system(size: compact ? 12 : 13, weight: .medium))
                    .lineLimit(compact ? 1 : 2)
                HStack(spacing: 5) {
                    if let source = item.sourceBundleID {
                        AppIcon(bundleIdentifier: source, size: 12)
                    }
                    Text(item.date, format: .relative(presentation: .named))
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            if item.isPinned {
                Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(.orange)
            }
            if let index, index < 9, !compact {
                Text("⌘\(index + 1)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, compact ? 6 : 10)
        .padding(.vertical, compact ? 4 : 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.28) : .clear))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if item.kind == .image, let url = services.clipboard.imageURL(item) {
            FileThumbnail(url: url, images: services.images, maxPixels: 160)
        } else if item.kind == .files, let url = item.fileURLs?.first {
            Image(nsImage: AppIconCache.icon(forPath: url.path)).resizable()
        } else {
            Image(systemName: item.kind.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(item.kind == .link ? Color.blue : .secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.08))
        }
    }
}

