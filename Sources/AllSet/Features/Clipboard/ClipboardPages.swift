import AllSetCore
import AppKit
import SwiftUI

/// Clipboard history in full: search, filters, pins and settings.
struct ClipboardPage: View {
    let services: AppServices

    @State private var query = ""
    @State private var kind: ClipboardItem.Kind?
    @State private var confirmingClear = false
    @State private var confirmingErase = false
    @State private var status: String?

    var body: some View {
        let store = services.clipboard
        let results = store.search(query, kind: kind)
        // A plain stack, not HSplitView: the split view is AppKit's and would
        // slide under the floating navigation.
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: DS.Space.m) {
                    PageHeader(eyebrow: store.items.isEmpty ? "Tools" : "\(store.items.count) items", title: "Clipboard",
                               subtitle: "Everything you copy, searchable. Double-click to copy again.")
                    SearchField(text: $query, prompt: "Search your clipboard")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Space.xs) {
                            FilterPill(title: "All", symbol: "square.grid.2x2", isSelected: kind == nil) { kind = nil }
                            ForEach(ClipboardItem.Kind.allCases, id: \.self) { item in
                                FilterPill(title: item.title, symbol: item.symbol, isSelected: kind == item) { kind = item }
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
                .padding(.horizontal, DS.Space.l)
                .padding(.top, DS.Space.l)
                .padding(.bottom, DS.Space.s)

                if !store.settings.hasChosen {
                    ClipboardFirstRun(store: store)
                        .frame(maxHeight: .infinity, alignment: .top)
                } else if results.isEmpty {
                    EmptyState(symbol: "doc.on.clipboard",
                               title: !store.items.isEmpty ? "No matches" : store.settings.isEnabled ? "Nothing copied yet" : "Clipboard history is off",
                               message: !store.items.isEmpty ? "Try another search or filter."
                                   : store.settings.isEnabled
                                   ? "Copy some text, a link, an image or files and they\u{2019}ll appear here."
                                   : "Nothing you copy is being saved. Turn on \u{201C}Keep clipboard history\u{201D} to start.")
                        .frame(maxHeight: .infinity)
                } else {
                    List(results) { item in
                        ClipboardRow(item: item, services: services)
                            .contextMenu { actions(for: item) }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { store.remove(item.id) } label: { Label("Delete", systemImage: "trash") }
                                Button { store.togglePin(item.id) } label: { Label(item.isPinned ? "Unpin" : "Pin", systemImage: "pin") }
                                    .tint(.orange)
                            }
                            .onTapGesture(count: 2) {
                                services.clipboardMonitor.copy(item)
                                show("Copied")
                            }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                }
                if let status {
                    GlassPanel(cornerRadius: 18, padding: 0) {
                        Text(status).dsText(.body).padding(.horizontal, DS.Space.m).frame(height: 36)
                    }
                    .padding(.bottom, DS.Space.m)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(minWidth: 380, maxWidth: .infinity)

            Divider().opacity(0.5)

            Form {
                ClipboardSettingsSections(services: services, confirmingClear: $confirmingClear, confirmingErase: $confirmingErase)
            }
            .dsFormStyle()
            .frame(width: 340)
        }
        .motion(Motion.standard, value: status)
        .confirmationDialog("Clear clipboard history?", isPresented: $confirmingClear) {
            Button("Clear History", role: .destructive) { store.clear() }
        } message: {
            Text("Pinned items stay.")
        }
        .confirmationDialog("Erase all \(store.items.count) items, pinned ones too?", isPresented: $confirmingErase) {
            Button("Erase Everything", role: .destructive) {
                show(store.eraseEverything() ? "Clipboard history erased" : "Couldn\u{2019}t erase the saved history")
            }
        } message: {
            Text("Every saved copy and picture is removed from this Mac. This can\u{2019}t be undone.")
        }
    }

    @ViewBuilder
    private func actions(for item: ClipboardItem) -> some View {
        Button("Copy") {
            services.clipboardMonitor.copy(item)
            show("Copied")
        }
        if item.kind == .image {
            Button("Copy Text in Image") {
                Task {
                    let found = await services.clipboardMonitor.copyText(from: item)
                    show(found ? "Copied the text in the image" : "No text found in the image")
                }
            }
        }
        if item.kind == .link, let url = item.text.flatMap(URL.init(string:)) {
            Button("Open Link") { NSWorkspace.shared.open(url) }
        }
        if item.kind == .files, let urls = item.fileURLs {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(urls) }
            Button("Add to Shelf") { services.shelf.add(urls) }
        }
        Divider()
        Button(item.isPinned ? "Unpin" : "Pin") { services.clipboard.togglePin(item.id) }
        Button("Delete", role: .destructive) { services.clipboard.remove(item.id) }
    }

    private func show(_ message: String) {
        status = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if status == message { status = nil }
        }
    }
}

/// Asked once, before anything is collected: what turning history on saves,
/// where, and for how long. Either answer is remembered.
private struct ClipboardFirstRun: View {
    let store: ClipboardStore

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text("Keep a history of what you copy?").dsText(.section)
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                point("doc.on.clipboard", "Text, links, pictures and the names of files you copy are saved, so you can find and paste them again.")
                point("internaldrive", "They are kept in a file on this Mac and sent nowhere. They aren\u{2019}t encrypted: anything that can read your files can read them.")
                point("key", "Copies made in password managers, and anything an app marks as private, are left out. Other copies can still contain something sensitive.")
                point("clock", "Kept for 30 days, up to 200 items, unless you pin them. You can change both, and erase everything, at any time.")
            }
            HStack(spacing: DS.Space.s) {
                Button("Turn On Clipboard History") { store.choose(collect: true) }
                    .buttonStyle(.pillProminent)
                Button("Not Now") { store.choose(collect: false) }
                    .buttonStyle(.pill)
            }
            Text("Nothing is being saved yet. You can change your mind in the settings on the right.")
                .dsText(.meta)
        }
        .padding(DS.Space.l)
        .frame(maxWidth: 560, alignment: .leading)
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).dsText(.body).fixedSize(horizontal: false, vertical: true)
        } icon: {
            // One width for every symbol, so the lines of text start together.
            Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 22)
        }
    }
}

private struct ClipboardSettingsSections: View {
    let services: AppServices
    @Binding var confirmingClear: Bool
    @Binding var confirmingErase: Bool

    var body: some View {
        let store = services.clipboard
        Section {
            SettingToggle("Keep clipboard history",
                          detail: "Saved in a file on this Mac, not encrypted, sent nowhere.",
                          isOn: Binding(get: { store.settings.isEnabled }, set: { store.choose(collect: $0) }))
            Picker("Forget after", selection: binding(\.expiryDays)) {
                ForEach(ClipboardSettings.expiryChoices, id: \.self) { days in
                    Text(days == 1 ? "1 day" : "\(days) days").tag(Int?.some(days))
                }
                Text("Never").tag(Int?.none)
            }
            .help("Pinned items are kept whatever this says")
            Picker("Remember", selection: binding(\.historyLimit)) {
                ForEach([50, 100, 200, 500, 1000], id: \.self) { count in
                    Text("\(count) items").tag(count)
                }
            }
            SettingToggle("Clear history when All Set quits", detail: "Pinned items stay.", isOn: binding(\.clearOnQuit))
            SettingToggle("Paste when chosen",
                          detail: Accessibility.isTrusted ? "Choosing an item pastes it into the app in front." : "Needs Accessibility access, like window snapping.",
                          isOn: binding(\.pasteOnSelect))
            LabeledContent("Open picker") {
                ShortcutRecorder(shortcut: binding(\.pickerShortcut),
                                 onRecording: { services.windowManager?.setRecordingShortcut($0) })
            }
            if services.ui.shortcutConflicts.contains("clipboard") {
                Label("Another app uses this shortcut", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        } header: {
            Text("Clipboard")
        }

        Section {
            ForEach(store.settings.ignoredApps, id: \.self) { bundleID in
                HStack {
                    AppIcon(bundleIdentifier: bundleID, size: 18)
                    Text(AppIconCache.name(for: bundleID) ?? bundleID)
                        .foregroundStyle(AppIconCache.name(for: bundleID) == nil ? .secondary : .primary)
                    Spacer()
                    Button {
                        store.settings.ignoredApps.removeAll { $0 == bundleID }
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Stop Ignoring")
                    .accessibilityLabel("Stop ignoring \(AppIconCache.name(for: bundleID) ?? bundleID)")
                }
            }
            Menu("Add Running App") {
                ForEach(runningApps, id: \.self) { bundleID in
                    Button(AppIconCache.name(for: bundleID) ?? bundleID) {
                        store.settings.ignoredApps.append(bundleID)
                    }
                }
            }
        } header: {
            Text("Never record from")
        } footer: {
            Text("Password managers are ignored out of the box, and so is anything apps mark as private.")
        }

        Section {
            Button("Clear History…", role: .destructive) { confirmingClear = true }
                .disabled(store.items.allSatisfy(\.isPinned))
            Button("Erase Everything…", role: .destructive) { confirmingErase = true }
                .disabled(store.items.isEmpty)
        } footer: {
            Text("Clear History keeps pinned items. Erase Everything removes them too, with every saved picture.")
        }
    }

    private var runningApps: [String] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleIdentifier)
            .filter { !services.clipboard.settings.ignoredApps.contains($0) }
            .sorted()
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<ClipboardSettings, Value>) -> Binding<Value> {
        Binding(get: { services.clipboard.settings[keyPath: keyPath] },
                set: { services.clipboard.settings[keyPath: keyPath] = $0 })
    }
}

/// The shelf, larger: everything parked, with room to drop more.
struct ShelfPage: View {
    let services: AppServices
    @State private var isTargeted = false
    @State private var pdfStatus: String?

    var body: some View {
        let shelf = services.shelf
        PageScaffold {
            PageHeader(eyebrow: shelf.items.isEmpty ? "Tools" : "\(shelf.items.count) parked", title: "Shelf",
                       subtitle: "Drop files on the notch (or here) to keep them handy, then drag them into any app or folder. Files stay where they are; the shelf just remembers them.") {
                if !shelf.items.isEmpty {
                    FlowLayout(spacing: DS.Space.xs) {
                        if let pdfStatus {
                            Text(pdfStatus).dsText(.meta).frame(height: 34)
                        }
                        if ShelfActions.canMakePDF(shelf) {
                            Button {
                                Task { pdfStatus = await ShelfActions.makePDF(shelf) }
                            } label: {
                                Label("Make PDF", systemImage: "doc.richtext")
                            }
                            .buttonStyle(.pill)
                            .help("Combine the pictures and PDFs here into one PDF, saved to Downloads")
                        }
                        Button {
                            ShelfActions.airDrop(shelf.items.map(\.url))
                        } label: {
                            Label("AirDrop All", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.pill)
                        Button("Clear", role: .destructive) { shelf.clear() }
                            .buttonStyle(.pill)
                    }
                    .fixedSize()
                }
            }

            if shelf.items.isEmpty {
                EmptyState(symbol: "tray.and.arrow.down.fill", title: "Drop files here",
                           message: "Pictures and PDFs can become one PDF with Make PDF.")
                    .frame(minHeight: 260)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.media, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                        .foregroundStyle(isTargeted ? Color.white.opacity(0.7) : DS.Surface.hairline.opacity(3)))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: DS.Space.s)], spacing: DS.Space.s) {
                    ForEach(shelf.items) { item in
                        ShelfTile(item: item, shelf: shelf, iconSize: 64)
                    }
                }
            }
        }
        .onDrop(of: ShelfDrop.types, isTargeted: $isTargeted) { providers in
            ShelfDrop.accept(providers, into: shelf)
        }
    }
}
