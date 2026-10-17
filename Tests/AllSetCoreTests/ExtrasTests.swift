import Foundation
import Testing
@testable import AllSetCore

@MainActor @Suite struct ExtrasTests {
    private func defaults() throws -> (UserDefaults, String) {
        let suite = "extras-\(UUID())"
        return (try #require(UserDefaults(suiteName: suite)), suite)
    }

    @Test func aNewInstallStartsWithEveryExtraOff() throws {
        let (defaults, suite) = try defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let extras = ExtrasSettings(defaults: defaults, existingData: false)
        #expect(extras.enabled.isEmpty)
        #expect(!extras.isLegacyInstall)
        // Decided once: data appearing later doesn't turn everything on.
        #expect(ExtrasSettings(defaults: defaults, existingData: true).enabled.isEmpty)
    }

    @Test func anInstallFromBeforeExtrasKeepsEverythingOn() throws {
        let (defaults, suite) = try defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let extras = ExtrasSettings(defaults: defaults, existingData: true)
        #expect(extras.enabled == Set(Extra.allCases))
        #expect(extras.isLegacyInstall)
        extras.set(.knocks, on: false)
        let reread = ExtrasSettings(defaults: defaults, existingData: false)
        #expect(!reread.isOn(.knocks) && reread.isOn(.mixer) && reread.isLegacyInstall)
    }

    @Test func existingDataMeansAnyVisibleFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("extras-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(!ExtrasSettings.hasExistingData(in: folder))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data().write(to: folder.appendingPathComponent(".DS_Store"))
        #expect(!ExtrasSettings.hasExistingData(in: folder))
        try Data("[]".utf8).write(to: folder.appendingPathComponent("widgets.json"))
        #expect(ExtrasSettings.hasExistingData(in: folder))
    }

    @Test func knocksFollowTheInstallWhenNothingWasSaved() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("knocks-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(!KnockStore(fileURL: file).settings.isEnabled)
        #expect(KnockStore(fileURL: file, enabledWithoutFile: true).settings.isEnabled)
    }
}
