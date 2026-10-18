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
    @FocusState private var isFieldFocused: Bool

    private var state: AccessState? { controller.gate?.state }
    private var isChecking: Bool { state == .checking }

    private var message: String? {
        if let problem = controller.buildProblem { return problem }
        if case .locked(let message) = state { return message }
        return nil
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
            Button(action: submit) {
                HStack(spacing: DS.Space.xs) {
                    if isChecking { ProgressView().controlSize(.small) }
                    Text(isChecking ? "Checking\u{2026}" : "Continue")
                }
                .frame(minWidth: 120)
            }
            .buttonStyle(.pillProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!canContinue)
            Text(message ?? " ")
                .dsText(.meta)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(message == nil ? 0 : 1)
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
            isFieldFocused = true
        }
    }

    private var field: some View {
        TextField("ALLSET-XXXX-XXXX-XXXX", text: $typed)
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundStyle(DS.Ink.primary)
            .multilineTextAlignment(.center)
            .autocorrectionDisabled()
            .focused($isFieldFocused)
            .onSubmit(submit)
            .disabled(isChecking || controller.gate == nil)
            .padding(.horizontal, DS.Space.s)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: DS.Radius.control).fill(DS.Surface.raised))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.control).strokeBorder(DS.Surface.hairline))
            .accessibilityLabel("Access key")
    }

    private func submit() {
        guard canContinue else { return }
        controller.submit(typed)
    }
}
