import AllSetCore
import AppKit
import Observation

/// Starts an AI screenshot from a chord in any app. ⌘⇧5 belongs to macOS's
/// own screenshot toolbar, which gets the keys first, so taking it over means
/// switching that shortcut off, and putting it back when All Set quits or the
/// setting changes. A marker in UserDefaults remembers that All Set switched
/// it off, so even a crash can't leave a Mac without it.
@Observable @MainActor
final class ScreenshotShortcutController {
    @ObservationIgnored private let services: AppServices
    private static let group = "screenshot"
    private static let marker = "screenshot.systemShortcutOffByAllSet"
    private static let domain = "com.apple.symbolichotkeys" as CFString
    private static let table = "AppleSymbolicHotKeys" as CFString

    /// Set when the chosen chord couldn't be taken, for the Screenshot page.
    private(set) var problem: String?

    init(services: AppServices) {
        self.services = services
    }

    func start() {
        apply()
        observe({ [services] in services.settings.screenshotShortcut }) { [weak self] _ in self?.apply() }
    }

    /// Hands macOS's shortcut back; the setting stays, so the next launch takes it over again.
    func stop() {
        HotKeyCenter.shared.unregisterAll(group: Self.group)
        restoreSystemShortcut()
    }

    func apply() {
        HotKeyCenter.shared.unregisterAll(group: Self.group)
        problem = nil
        let choice = services.settings.screenshotShortcut
        if choice.needsSystemShortcutOff {
            takeOverSystemShortcut()
        } else {
            restoreSystemShortcut()
        }
        guard let chord = choice.shortcut else { return }
        let registered = HotKeyCenter.shared.register(chord, group: Self.group) { [weak self] in
            guard let self else { return }
            Task { await ScreenshotStudioController.shared.capture(services: self.services) }
        }
        if !registered {
            problem = "Another app already uses \(chord.modifiers.symbols)\(chord.key)."
        }
    }

    // MARK: macOS's own shortcut

    private func hotKeys() -> [String: Any] {
        CFPreferencesCopyValue(Self.table, Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: Any] ?? [:]
    }

    private func write(_ hotKeys: [String: Any]) {
        CFPreferencesSetValue(Self.table, hotKeys as CFDictionary, Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        // The system reads the change when asked to, not by watching the file.
        let activate = Process()
        activate.executableURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings")
        activate.arguments = ["-u"]
        try? activate.run()
    }

    private func takeOverSystemShortcut() {
        let current = hotKeys()
        guard SymbolicHotKeys.isEnabled(SymbolicHotKeys.screenshotOptions, in: current) else { return }
        UserDefaults.standard.set(true, forKey: Self.marker)
        write(SymbolicHotKeys.setting(SymbolicHotKeys.screenshotOptions, enabled: false, in: current,
                                      defaultEntry: SymbolicHotKeys.screenshotOptionsEntry))
    }

    private func restoreSystemShortcut() {
        guard UserDefaults.standard.bool(forKey: Self.marker) else { return }
        UserDefaults.standard.removeObject(forKey: Self.marker)
        let current = hotKeys()
        guard !SymbolicHotKeys.isEnabled(SymbolicHotKeys.screenshotOptions, in: current) else { return }
        write(SymbolicHotKeys.setting(SymbolicHotKeys.screenshotOptions, enabled: true, in: current,
                                      defaultEntry: SymbolicHotKeys.screenshotOptionsEntry))
    }
}
