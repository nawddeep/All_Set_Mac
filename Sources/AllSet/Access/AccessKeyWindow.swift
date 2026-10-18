import AllSetCore
import AppKit
import SwiftUI

/// The key screen: a small window in the middle of the screen, and the only
/// thing All Set shows until the library server accepts a key. Closing it quits.
@MainActor
final class AccessKeyWindow: NSObject, NSWindowDelegate {
    static let shared = AccessKeyWindow()
    private var window: NSWindow?

    func show(controller: AccessController) {
        // In front, with a Dock icon, whatever the Dock setting says (it applies once unlocked).
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: AccessKeyView.size.width, height: AccessKeyView.size.height),
                              styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = String(localized: "All Set")
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AccessKeyView(controller: controller).environment(\.colorScheme, .dark))
        window.center()
        window.delegate = self
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// Once unlocked: goes without quitting.
    func close() {
        guard let window else { return }
        window.delegate = nil
        window.close()
        self.window = nil
    }

    /// Nothing works without a key, so a closed key screen is a quit.
    func windowWillClose(_ notification: Notification) {
        window = nil
        NSApp.terminate(nil)
    }
}

struct AccessKeyView: View {
    static let size = CGSize(width: 440, height: 340)

    let controller: AccessController
    @State private var typed = ""
    /// The key the message is about; typing something else hides it.
    @State private var messageKey: String?
    /// Bumped to put the cursor in the field (when the window opens, after a refusal).
    @State private var focusRequests = 0

    private var state: AccessState? { controller.gate?.state }
    private var isChecking: Bool { state == .checking }

    private var message: String? {
        if let problem = controller.buildProblem { return problem }
        guard case .locked(let message) = state, messageKey == nil || messageKey == typed else { return nil }
        return message
    }

    private var canContinue: Bool {
        guard controller.gate != nil, !isChecking else { return false }
        return !AccessGate.normalized(typed).isEmpty || controller.gate?.hasSavedKey == true
    }

    var body: some View {
        VStack(spacing: DS.Space.m) {
            Text("All Set").dsText(.title)
            Text("Enter your access key to start").dsText(.body).foregroundStyle(DS.Ink.secondary)
            field
                .padding(.top, DS.Space.xs)
            // The same size checking or not: the spinner takes the label's place.
            Button(action: submit) {
                Text("Continue")
                    .opacity(isChecking ? 0 : 1)
                    .overlay { if isChecking { ProgressView().controlSize(.small) } }
                    .frame(width: 120)
            }
            .buttonStyle(.pillProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!canContinue)
            // Room for two lines whether or not there's a message, so nothing moves.
            Text(message ?? "")
                .dsText(.meta)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30, alignment: .top)
                .accessibilityHidden(message == nil)
            Spacer(minLength: 0)
            Text("Don\u{2019}t have a key? Ask the person who shared All Set with you.")
                .dsText(.meta)
                .foregroundStyle(DS.Ink.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.top, DS.Space.xxl)
        .padding(.bottom, DS.Space.l)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(DS.Surface.canvasLift)
        .task {
            // After the window has become key, or the focus doesn't take.
            try? await Task.sleep(for: .milliseconds(150))
            focusRequests += 1
        }
        // Back in the field after a key is turned down, to fix it and try again.
        .onChange(of: isChecking) { _, checking in
            if !checking { focusRequests += 1 }
        }
    }

    private var field: some View {
        KeyField(text: $typed, placeholder: "ALLSET-XXXX-XXXX-XXXX", focusRequests: focusRequests,
                 isEnabled: controller.gate != nil, onSubmit: submit)
            .padding(.horizontal, DS.Space.s)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: DS.Radius.control).fill(DS.Surface.raised))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.control).strokeBorder(DS.Surface.hairline))
            .accessibilityLabel("Access key")
    }

    private func submit() {
        guard canContinue else { return }
        messageKey = typed
        controller.submit(typed)
    }
}

/// The key field: AppKit's single-line field, centred both ways. SwiftUI's
/// plain field dropped its text to another line once typing began.
private struct KeyField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let focusRequests: Int
    let isEnabled: Bool
    let onSubmit: () -> Void

    private static let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = Self.font
        field.textColor = NSColor.white.withAlphaComponent(0.95)
        field.alignment = .center
        field.usesSingleLineMode = true
        field.maximumNumberOfLines = 1
        field.lineBreakMode = .byClipping
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        let centred = NSMutableParagraphStyle()
        centred.alignment = .center
        field.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [
            .font: Self.font,
            .foregroundColor: NSColor.white.withAlphaComponent(0.40),
            .paragraphStyle: centred,
        ])
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        field.isEnabled = isEnabled
        if context.coordinator.focusRequests != focusRequests {
            context.coordinator.focusRequests = focusRequests
            field.window?.makeFirstResponder(field)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: KeyField
        var focusRequests = 0

        init(parent: KeyField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            parent.onSubmit()
            return true
        }
    }
}
