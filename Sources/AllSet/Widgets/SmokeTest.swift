import AllSetCore
import AppKit

#if DEBUG

/// `-smokeTest <folder>`: walks through the app the way a person would and
/// writes `smoke-report.json` there; exits 1 if any step failed.
///
/// Refuses to run unless `CFFIXED_USER_HOME` points at a throwaway folder,
/// so the person's widgets, notes and wallpapers are never read or changed.
/// Run with `-skip wallpaper,widgets,notch`, so the real desktop and system
/// wallpaper aren't touched either. The one real system setting it touches
/// is macOS's ⌘⇧5 shortcut, and only to check it comes back exactly as it was.
@MainActor
enum SmokeTest {
    struct Step: Codable {
        let name: String
        let ok: Bool
        let detail: String
    }

    static func run(to folder: URL, services: AppServices) async {
        var steps: [Step] = []
        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            steps.append(Step(name: name, ok: ok, detail: detail))
            print("\(ok ? "PASS" : "FAIL")  \(name)\(detail.isEmpty ? "" : ": \(detail)")")
        }

        // 0. Never on real data.
        let home = (ProcessInfo.processInfo.environment["CFFIXED_USER_HOME"]).map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path } ?? ""
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].resolvingSymlinksInPath().path
        guard !home.isEmpty, support.hasPrefix(home) else {
            print("smokeTest: set CFFIXED_USER_HOME to an empty folder first; refusing to run on real data")
            exit(2)
        }
        check("data folder is the throwaway one", true, support)

        // 1. Onboarding, every step.
        for step in OnboardingView.Step.allCases {
            OnboardingController.shared.show(services: services, step: step)
            try? await Task.sleep(for: .milliseconds(300))
            check("onboarding \(step)", OnboardingController.shared.currentWindow?.isVisible == true)
            OnboardingController.shared.currentWindow?.delegate = nil
            OnboardingController.shared.currentWindow?.close()
            OnboardingController.shared.forget()
        }

        // 2. Every page opens, extras on so theirs show too.
        for extra in Extra.allCases { services.extras.set(extra, on: true) }
        let pages = NavSection.allCases.flatMap { NavItem.items(in: $0, services: services) + NavItem.secondary(in: $0) }.map(\.page)
        for page in pages {
            services.openWindow(page)
            try? await Task.sleep(for: .milliseconds(250))
            let shown = NSApp.windows.contains { $0.isVisible && $0.title == "All Set" }
            check("page \(page)", shown && services.ui.page == page)
        }

        // 3. A widget: add, move, resize, remove.
        let added = services.addWidget(WidgetInstance(kind: .clock))
        check("widget added", services.widgets.instance(added.id) != nil)
        services.widgets.update(added.id) { $0.offset = CGPoint(x: 200, y: 120) }
        check("widget moved", services.widgets.instance(added.id)?.offset == CGPoint(x: 200, y: 120))
        services.resizeWidget(added.id, to: .large)
        check("widget resized", services.widgets.instance(added.id)?.size == .large)

        // 4. A theme on, then Undo puts the desktop back.
        let before = services.widgets.widgets
        if let set = ThemeLibrary.all.first {
            let installed = services.install(set, mode: .restyle, wallpaper: false)
            check("theme applied", installed && services.ui.desktopUndo != nil, set.id)
            services.undoDesktopChange()
            check("theme undone", services.widgets.widgets == before)
        } else {
            check("theme applied", false, "no themes")
        }

        services.removeWidget(added.id)
        check("widget removed", services.widgets.instance(added.id) == nil)

        // 5. A built-in wallpaper.
        let wallpaper = BuiltInWallpaper.all[0]
        services.pickWallpaper(wallpaper.source)
        check("built-in wallpaper set", services.wallpaper.config.source == wallpaper.source, wallpaper.name)

        // 6. Every extra off and on again.
        for extra in Extra.allCases {
            services.extras.set(extra, on: false)
            try? await Task.sleep(for: .milliseconds(100))
            let off = !services.extras.isOn(extra)
            services.extras.set(extra, on: true)
            try? await Task.sleep(for: .milliseconds(100))
            check("extra \(extra) off and on", off && services.extras.isOn(extra))
        }

        // 7. ⌘⇧5: taken, then given back exactly as it was.
        let original = SymbolicHotKeys.isEnabled(SymbolicHotKeys.screenshotOptions, in: systemHotKeys())
        if original {
            services.settings.screenshotShortcut = .commandShift5
            try? await Task.sleep(for: .seconds(1))
            let taken = !SymbolicHotKeys.isEnabled(SymbolicHotKeys.screenshotOptions, in: systemHotKeys())
            services.settings.screenshotShortcut = .controlOptionCommand5
            try? await Task.sleep(for: .seconds(1))
            let back = SymbolicHotKeys.isEnabled(SymbolicHotKeys.screenshotOptions, in: systemHotKeys())
            check("⌘⇧5 taken over", taken)
            check("⌘⇧5 given back as it was", back == original)
        } else {
            check("⌘⇧5 left alone (it was already off on this Mac)", true)
        }

        // 8. Quit cleanly.
        services.stop()
        check("services stopped", true)

        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(steps).write(to: folder.appendingPathComponent("smoke-report.json"))
        let failed = steps.filter { !$0.ok }.count
        print("smokeTest: \(steps.count - failed) passed, \(failed) failed")
        exit(failed == 0 ? 0 : 1)
    }

    private static func systemHotKeys() -> [String: Any] {
        CFPreferencesAppSynchronize("com.apple.symbolichotkeys" as CFString)
        return CFPreferencesCopyValue("AppleSymbolicHotKeys" as CFString, "com.apple.symbolichotkeys" as CFString,
                                      kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: Any] ?? [:]
    }
}

#endif
