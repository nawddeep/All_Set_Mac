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
    /// A new install starts on a chord that takes nothing from macOS.
    @Test func startsWithoutTakeoverAndSurvivesARelaunch() {
        let name = "AllSetTests-shot-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let first = AppSettings(defaults: defaults)
        #expect(first.screenshotShortcut == .controlOptionCommand5)
        #expect(!first.screenshotShortcut.needsSystemShortcutOff)
        first.screenshotShortcut = .off
        #expect(AppSettings(defaults: defaults).screenshotShortcut == .off)
    }
}

@Suite struct SystemShortcutPlanTests {
    @Test func takesOnlyWhatItIsAskedToAndGivesBackOnlyWhatItTook() {
        // Asked to take it while macOS has it: switch off, and remember we did.
        #expect(SystemShortcutPlan.decide(wanted: true, marked: false, systemOn: true) == (.switchOff, true))
        // Asked, but the person had switched it off themselves: leave it theirs.
        #expect(SystemShortcutPlan.decide(wanted: true, marked: false, systemOn: false) == (.leave, false))
        // Asked again after a relaunch: still ours.
        #expect(SystemShortcutPlan.decide(wanted: true, marked: true, systemOn: false) == (.leave, true))
        // Not wanted any more (another choice, quit, extra off, after a crash): give it back.
        #expect(SystemShortcutPlan.decide(wanted: false, marked: true, systemOn: false) == (.switchOn, false))
        // Someone already turned it back on: nothing to do, forget the marker.
        #expect(SystemShortcutPlan.decide(wanted: false, marked: true, systemOn: true) == (.leave, false))
        // Never ours: never touched.
        #expect(SystemShortcutPlan.decide(wanted: false, marked: false, systemOn: false) == (.leave, false))
    }
}
