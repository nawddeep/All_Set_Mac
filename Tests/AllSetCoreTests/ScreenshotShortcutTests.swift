import Foundation
import Testing
@testable import AllSetCore

@Suite struct ScreenshotShortcutTests {
    @Test func onlyCommandShiftFiveNeedsMacOSsShortcutOff() {
        #expect(ScreenshotShortcut.allCases.filter(\.needsSystemShortcutOff) == [.commandShift5])
        #expect(ScreenshotShortcut.off.shortcut == nil)
        let chord = ScreenshotShortcut.commandShift5.shortcut
        #expect(chord?.keyCode == 0x17 && chord?.modifiers == [.command, .shift])
        let other = ScreenshotShortcut.controlOptionCommand5.shortcut
        #expect(other?.modifiers == [.control, .option, .command])
    }

    @Test func aMissingEntryMeansOn() {
        #expect(SymbolicHotKeys.isEnabled("184", in: [:]))
        #expect(!SymbolicHotKeys.isEnabled("184", in: ["184": ["enabled": false]]))
        #expect(SymbolicHotKeys.isEnabled("184", in: ["184": ["enabled": true]]))
    }

    @Test func switchingOffAndBackOnLeavesEverythingElseAlone() {
        let others: [String: Any] = ["28": ["enabled": true, "value": ["type": "standard"]], "32": ["enabled": false]]
        let off = SymbolicHotKeys.setting("184", enabled: false, in: others, defaultEntry: SymbolicHotKeys.screenshotOptionsEntry)
        #expect(!SymbolicHotKeys.isEnabled("184", in: off))
        // The entry macOS didn't have is written in its own format.
        let entry = off["184"] as? [String: Any]
        let value = entry?["value"] as? [String: Any]
        #expect((value?["parameters"] as? [Int]) == [53, 23, 1_179_648])
        let on = SymbolicHotKeys.setting("184", enabled: true, in: off, defaultEntry: SymbolicHotKeys.screenshotOptionsEntry)
        #expect(SymbolicHotKeys.isEnabled("184", in: on))
        #expect(on.count == 3 && !SymbolicHotKeys.isEnabled("32", in: on) && SymbolicHotKeys.isEnabled("28", in: on))
    }
}

@Suite @MainActor struct ScreenshotShortcutSettingTests {
    @Test func startsOffAndSurvivesARelaunch() {
        let name = "AllSetTests-shot-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let first = AppSettings(defaults: defaults)
        #expect(first.screenshotShortcut == .off)
        first.screenshotShortcut = .controlOptionCommand5
        #expect(AppSettings(defaults: defaults).screenshotShortcut == .controlOptionCommand5)
    }
}
