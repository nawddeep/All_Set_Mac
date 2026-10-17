import Foundation
import Testing
@testable import AllSetCore

@Suite struct PermissionTests {
    @Test func onlyWhatIsUsedIsListed() {
        #expect(Permission.relevant(extras: [], widgetKinds: [.weather]).isEmpty)
        #expect(Permission.relevant(extras: [.snapping], widgetKinds: []) == [.accessibility])
        #expect(Permission.relevant(extras: [.mixer], widgetKinds: [.calendar]) == [.calendars, .audioCapture])
        #expect(Permission.relevant(extras: [], widgetKinds: [.nextEvent]) == [.calendars])
    }

    @Test func switchingOnAsksOnlyForWhatThatExtraNeeds() {
        #expect(Permission.needed(toTurnOn: .snapping) == .accessibility)
        #expect(Permission.needed(toTurnOn: .workspaces) == .accessibility)
        #expect(Permission.needed(toTurnOn: .mixer) == .audioCapture)
        // TapTap's editing actions ask when chosen; knocking itself needs nothing.
        #expect(Permission.needed(toTurnOn: .knocks) == nil)
        for extra in [Extra.clipboard, .shelf, .screenshot, .monitor] { #expect(Permission.needed(toTurnOn: extra) == nil) }
    }

    @Test func everyPermissionExplainsItself() {
        for permission in Permission.allCases {
            #expect(!permission.purpose.isEmpty && !permission.withoutIt.isEmpty)
            #expect(permission.settingsURL.scheme == "x-apple.systempreferences")
        }
    }

    @Test func onboardingShowsOnceAndNeverToOldInstalls() throws {
        let suite = "onboarding-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(!Onboarding.shouldShow(isLegacyInstall: true, defaults: defaults))
        #expect(Onboarding.shouldShow(isLegacyInstall: false, defaults: defaults))
        Onboarding.markCompleted(defaults: defaults)
        #expect(!Onboarding.shouldShow(isLegacyInstall: false, defaults: defaults))
    }
}
