import AllSetCore
import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

// `ScreenshotStudio`, the document and its AI conversation, is in AllSetCore
// (AI/ScreenshotStudio.swift) so its request handling can be tested.

/// Opens the studio, taking a screenshot first when asked.
@MainActor
final class ScreenshotStudioController {
    static let shared = ScreenshotStudioController()

    let studio = ScreenshotStudio()
    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?

    /// Lets you drag out an area of the screen (Esc cancels), then opens it in the studio.
    func capture(services: AppServices?) async {
        services?.notch?.close()
        // Out of the way while the area is chosen.
        let wasShowing = window?.isVisible == true
        window?.orderOut(nil)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("AllSet-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: file) }
        _ = await CommandRunner.run("/usr/sbin/screencapture", ["-i", "-x", file.path], timeout: nil)
        guard let picture = ScreenshotStudio.picture(at: file) else {
            if wasShowing { show() }
            return
        }
        studio.load(picture.image, pixelsPerPoint: Double(NSScreen.main?.backingScaleFactor ?? 2), reducedFrom: picture.reducedFrom)
        show()
    }

    /// Opens a picture from a file.
    func open() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url, let picture = ScreenshotStudio.picture(at: url) else { return }
        studio.load(picture.image, reducedFrom: picture.reducedFrom)
        show()
    }

    func show() {
        if window == nil {
            let controller = NSHostingController(rootView: ScreenshotStudioView(studio: studio))
            // Fixed limits instead of ones re-derived from content each layout
            // pass, which can loop (see MainWindowController).
            controller.sizingOptions = []
            let window = NSWindow(contentViewController: controller)
            window.title = "AI Screenshot"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.isReleasedWhenClosed = false
            window.contentMinSize = NSSize(width: 900, height: 560)
            window.setContentSize(NSSize(width: 1180, height: 760))
            window.center()
            window.setFrameAutosaveName("AllSetScreenshot")
            self.window = window
            // Closing the window stops the request in flight and lets go of the
            // undo history and AI session; the picture as it is now stays, so
            // reopening shows it. (Hiding it to choose a capture area isn't a close.)
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.studio.windowClosed() }
            }
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

struct ScreenshotStudioView: View {
    let studio: ScreenshotStudio

    @State private var status: String?

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                ZStack {
                    Color.black.opacity(0.85)
                    if let image = studio.image {
                        Image(decorative: image, scale: NSScreen.main?.backingScaleFactor ?? 2)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
                            .padding(28)
                            .id(studio.versionCount)
                            .transition(.opacity)
                    } else {
                        ContentUnavailableView("No screenshot", systemImage: "camera.viewfinder",
                                               description: Text("Take one from the Dynamic Island or All Set's AI Screenshot page."))
                    }
                    if studio.isWorking {
                        ProgressView()
                            .controlSize(.large)
                            .padding(20)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .motion(Motion.standard, value: studio.versionCount)

                HStack(spacing: 10) {
                    Button { Task { await ScreenshotStudioController.shared.capture(services: nil) } } label: {
                        Label("New Screenshot", systemImage: "camera.viewfinder")
                    }
                    Button("Open…") { ScreenshotStudioController.shared.open() }
                    Spacer()
                    if let status {
                        Text(status).foregroundStyle(.secondary).transition(.opacity)
                    }
                    Button { studio.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                        .disabled(studio.versionCount < 2 || studio.isWorking)
                        .keyboardShortcut("z")
                    Button { copy() } label: { Label("Copy", systemImage: "doc.on.doc") }
                        .disabled(studio.image == nil)
                    Button { save() } label: { Label("Save…", systemImage: "square.and.arrow.down") }
                        .disabled(studio.image == nil)
                        .keyboardShortcut("s")
                }
                .padding(12)
                .background(.bar)
            }

            Divider()
            AIPanel(studio: studio)
                .frame(width: 340)
        }
        .frame(minWidth: 900, minHeight: 560)
        .motion(Motion.standard, value: status)
    }

    private func copy() {
        guard let image = studio.image else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([NSImage(cgImage: image, size: .zero)])
        flash("Copied")
    }

    private func save() {
        guard let image = studio.image,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        panel.nameFieldStringValue = "Screenshot \(Date.now.formatted(date: .abbreviated, time: .shortened)).png"
            .replacingOccurrences(of: ":", with: ".")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try png.write(to: url)
            flash("Saved")
        } catch {
            flash("Couldn't save: \(error.localizedDescription)")
        }
    }

    private func flash(_ message: String) {
        status = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if status == message { status = nil }
        }
    }
}

/// The side panel: pick an AI, give it a key once, then say what to change.
private struct AIPanel: View {
    let studio: ScreenshotStudio

    @State private var instruction = ""
    @State private var keyDraft = ""
    @State private var hasKey = false
    @State private var editingKey = false
    @State private var keyProblem: String?

    private let suggestions = [
        "Blur any personal info",
        "Highlight the error message",
        "Crop to just the window",
        "Add an arrow pointing to the main button",
        "What does this screen say?",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Ask AI", systemImage: "sparkles").font(.headline)
                Spacer()
                Button { editingKey.toggle() } label: { Image(systemName: "key.fill") }
                    .buttonStyle(.borderless)
                    .help("\(studio.provider.title) API key")
            }
            Picker("", selection: Binding(get: { studio.provider }, set: { studio.provider = $0 })) {
                ForEach(AIProvider.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(studio.provider == .claude
                 ? "Claude edits by instruction: blur, hide, crop, highlight, arrows and labels. Or ask about what's on screen."
                 : "ChatGPT redraws the whole picture as you describe. Slower, and small text may change.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !hasKey || editingKey {
                keyCard
            }

            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if studio.messages.isEmpty {
                            Text("Try:").font(.caption).foregroundStyle(.secondary)
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(suggestion) { send(suggestion) }
                                    .buttonStyle(.bordered)
                                    .disabled(!hasKey || studio.image == nil || studio.isWorking)
                            }
                        }
                        ForEach(studio.messages) { message in
                            bubble(message).id(message.id)
                        }
                        if studio.isWorking {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("\(studio.provider.title) is working…").foregroundStyle(.secondary)
                            }
                            .id("working")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: studio.messages.count) {
                    withMotion(Motion.standard) { reader.scrollTo(studio.messages.last?.id, anchor: .bottom) }
                }
            }

            HStack(spacing: 8) {
                TextField("What should change?", text: $instruction, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onSubmit { send(instruction) }
                if studio.isWorking {
                    Button { studio.cancel() } label: { Image(systemName: "stop.circle.fill").font(.title2) }
                        .buttonStyle(.borderless)
                        .help("Stop")
                        .accessibilityLabel("Stop")
                } else {
                    Button { send(instruction) } label: { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                        .buttonStyle(.borderless)
                        .disabled(instruction.trimmingCharacters(in: .whitespaces).isEmpty || !hasKey || studio.image == nil)
                        .keyboardShortcut(.return, modifiers: .command)
                        .help("Send")
                        .accessibilityLabel("Send")
                }
            }
        }
        .padding(16)
        .onAppear(perform: refreshKey)
        .onChange(of: studio.provider) { refreshKey() }
    }

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(studio.provider.title) API key").font(.subheadline.weight(.semibold))
            Text("\(studio.provider.title) doesn't let other apps sign in to your account; paste an API key instead. It's kept in your Mac's keychain and only sent to \(studio.provider == .claude ? "Anthropic" : "OpenAI"). Usage is billed to that account.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            SecureField(studio.provider.keyPrefix + "…", text: $keyDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit(saveKey)
            if let keyProblem {
                Text(keyProblem).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Link("Get a key", destination: studio.provider.keyPageURL)
                Spacer()
                if hasKey {
                    Button("Remove", role: .destructive) {
                        AIKeychain.setKey(nil, for: studio.provider)
                        refreshKey()
                    }
                }
                Button("Save", action: saveKey)
                    .buttonStyle(.borderedProminent)
                    .disabled(keyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .font(.callout)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.6)))
    }

    private func bubble(_ message: ScreenshotStudio.Message) -> some View {
        let isUser = message.role == .user
        return HStack {
            if isUser { Spacer(minLength: 30) }
            VStack(alignment: .leading, spacing: 3) {
                Text(message.text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 12).fill(
                        isUser ? Color.accentColor.opacity(0.22)
                            : message.role == .problem ? Color.orange.opacity(0.18) : Color.primary.opacity(0.07)))
                if let detail = message.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 10)
                }
            }
            if !isUser { Spacer(minLength: 30) }
        }
    }

    private func send(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        instruction = ""
        Task { await studio.ask(text) }
    }

    private func saveKey() {
        guard AIKeychain.setKey(keyDraft, for: studio.provider) else {
            keyProblem = "Couldn't save the key in your keychain. The previous key, if any, is unchanged."
            return
        }
        keyProblem = nil
        keyDraft = ""
        editingKey = false
        refreshKey()
    }

    private func refreshKey() {
        hasKey = AIKeychain.key(for: studio.provider) != nil
    }
}

/// The main window's page: take a screenshot and open the studio.
/// Which chord starts an AI screenshot from any app.
private struct ShortcutPicker: View {
    let services: AppServices

    var body: some View {
        let settings = services.settings
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionHeader(title: "Keyboard shortcut", subtitle: "Start a screenshot from any app, without opening All Set.")
            HStack(spacing: DS.Space.xs) {
                ForEach(ScreenshotShortcut.allCases) { choice in
                    FilterPill(title: choice.title, isSelected: settings.screenshotShortcut == choice) {
                        withMotion(Motion.responsive) { settings.screenshotShortcut = choice }
                    }
                }
            }
            if let problem = services.screenshotShortcut.problem {
                Text(problem).dsText(.meta).foregroundStyle(.red)
            } else if settings.screenshotShortcut == .commandShift5 {
                Text("macOS\u{2019}s own screenshot toolbar is switched off while All Set runs, and comes back when you quit All Set or pick another choice. Screen recording from that toolbar isn\u{2019}t available meanwhile.")
                    .dsText(.meta)
            }
        }
    }
}

struct ScreenshotPage: View {
    let services: AppServices

    var body: some View {
        PageScaffold {
            // A utility page: the two ways in sit in the header, and what follows
            // (the shortcut, what to ask for) is in view without scrolling. The
            // decorative canvas that used to hold the buttons took the first screen.
            PageHeader(eyebrow: "Tools", title: "AI Screenshot",
                       subtitle: "Drag out part of the screen, then tell Claude or ChatGPT what to change.") {
                HStack(spacing: DS.Space.xs) {
                    Button("Open a Picture…") { ScreenshotStudioController.shared.open() }
                        .buttonStyle(.pill)
                    Button {
                        Task { await ScreenshotStudioController.shared.capture(services: services) }
                    } label: {
                        Label("Take Screenshot", systemImage: "camera.viewfinder")
                    }
                    .buttonStyle(.pillProminent)
                }
            }

            ShortcutPicker(services: services)

            VStack(alignment: .leading, spacing: DS.Space.m) {
                SectionHeader(title: "Ask for anything", subtitle: "Also in the Dynamic Island (the camera button) and as a TapTap action.")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: DS.Space.m, alignment: .top)], alignment: .leading, spacing: DS.Space.m) {
                    idea("eye.slash.fill", "Blur personal details", "Names, emails, faces and numbers.")
                    idea("highlighter", "Highlight", "Point out what matters with a box or a glow.")
                    idea("crop", "Crop and annotate", "Arrows, labels and a tighter frame.")
                    idea("text.bubble.fill", "Ask what\u{2019}s on screen", "Explain an error, a chart or a menu.")
                }
            }
        }
    }

    private func idea(_ symbol: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.Ink.primary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(DS.Surface.hover))
            Text(title).dsText(.headline).padding(.top, DS.Space.xxs)
            Text(detail).dsText(.meta).fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.m)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).fill(DS.Surface.raised))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).strokeBorder(DS.Surface.hairline))
    }
}
