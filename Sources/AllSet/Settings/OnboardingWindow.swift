import AllSetCore
import AppKit
import SwiftUI

/// The first-run welcome, in its own small window: what All Set is, which
/// extras to switch on, how permissions work, then a first theme. Shown once
/// to a new install (`Onboarding.shouldShow`). Nothing is asked for here.
@MainActor
final class OnboardingController: NSObject, NSWindowDelegate {
    static let shared = OnboardingController()
    private var window: NSWindow?

    func showIfNeeded(services: AppServices) {
        guard Onboarding.shouldShow(isLegacyInstall: services.extras.isLegacyInstall) else { return }
        show(services: services)
    }

    func show(services: AppServices, step: OnboardingView.Step = .welcome) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let view = OnboardingView(services: services, step: step) { [weak self] in self?.finish() }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
                              styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Welcome to All Set"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view.environment(\.colorScheme, .dark))
        window.center()
        window.delegate = self
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// Lets the render harness close one step's window and draw the next.
    func forget() { window = nil }

    /// The window as it is, for the render harness.
    var currentWindow: NSWindow? { window }

    private func finish() {
        Onboarding.markCompleted()
        window?.close()
    }

    /// Closing early counts as done: it's a welcome, not a gate.
    func windowWillClose(_ notification: Notification) {
        Onboarding.markCompleted()
        window?.delegate = nil
        window = nil
    }
}

struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, extras, permissions, ready
    }

    let services: AppServices
    @State var step: Step
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            Group {
                switch step {
                case .welcome: welcome
                case .extras: extras
                case .permissions: permissions
                case .ready: ready
                }
            }
            .id(step)
            // Opacity and a short rise only: cheap to draw, and plain under Reduce Motion.
            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 12)), removal: .opacity))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .padding(.horizontal, 40)
        .padding(.top, 48)
        .padding(.bottom, 28)
        .frame(width: 640, height: 520)
        .background(DS.Surface.canvasLift)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text("WELCOME").dsText(.eyebrow).foregroundStyle(DS.Ink.secondary)
            Text("All Set").dsText(.title)
            Text("A desktop that looks the way you want, in four parts:").dsText(.body).foregroundStyle(DS.Ink.secondary)
            feature("capsule.fill", "Dynamic Island", "Music, timers, notes and live stats around the notch.")
            feature("square.grid.2x2.fill", "Widgets", "Clocks, calendars, weather, photos and more on your desktop.")
            feature("wand.and.stars", "Themes", "Whole desktops (widgets, look and wallpaper) in one click, with Undo.")
            feature("photo.artframe", "Wallpaper", "Live wallpapers drawn on your Mac, or your own videos.")
        }
    }

    private var extras: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("EXTRAS").dsText(.eyebrow).foregroundStyle(DS.Ink.secondary)
            Text("Anything else you'd like?").dsText(.title)
            Text("These are off unless you switch them on, and you can change your mind any time in Extras.")
                .dsText(.body).foregroundStyle(DS.Ink.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    ForEach(Extra.allCases) { extra in ExtraToggle(extra: extra, services: services) }
                }
            }
        }
    }

    private var permissions: some View {
        let needed = Permission.relevant(extras: services.extras.enabled, widgetKinds: [])
        return VStack(alignment: .leading, spacing: DS.Space.m) {
            Text("PERMISSIONS").dsText(.eyebrow).foregroundStyle(DS.Ink.secondary)
            Text("Asked for only when needed").dsText(.title)
            Text("All Set never asks for a permission up front. macOS asks the first time you use something that needs one, and Settings › General › Permissions shows where each stands.")
                .dsText(.body).foregroundStyle(DS.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if needed.isEmpty {
                feature("checkmark.shield", "Nothing to allow", "With what you've chosen, All Set needs no permission at all.")
            }
            ForEach(needed) { permission in
                feature("lock.shield", permission.title, permission.purpose)
            }
            feature("network", "Network use", "Weather, photo search and GitHub widgets fetch what they show; Settings › General lists every connection.")
        }
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text("READY").dsText(.eyebrow).foregroundStyle(DS.Ink.secondary)
            Text("Pick a first theme").dsText(.title)
            Text("A theme sets up widgets, their look and a wallpaper together. Try one on with Preview; Undo puts your desktop back.")
                .dsText(.body).foregroundStyle(DS.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            // Progress dots, one per step.
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { item in
                    Circle().fill(item == step ? DS.Ink.primary : DS.Ink.tertiary).frame(width: 6, height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
            Spacer()
            if step != .welcome {
                Button("Back") { go(-1) }.buttonStyle(.pill)
            }
            if step == .ready {
                Button("Skip") { done() }.buttonStyle(.pill)
                Button("Browse Themes") {
                    done()
                    services.openWindow(.themes)
                }
                .buttonStyle(.pillProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Continue") { go(1) }
                    .buttonStyle(.pillProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func go(_ delta: Int) {
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        withMotion(Motion.standard) { step = next }
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: DS.Space.s) {
            Image(systemName: symbol).frame(width: 24).foregroundStyle(DS.Ink.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).dsText(.headline)
                Text(detail).dsText(.meta).foregroundStyle(DS.Ink.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
