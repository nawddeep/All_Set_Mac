import Foundation
import Testing
@testable import AllSetCore

/// Review A3: records were matched to displays by name, so two monitors of
/// the same model shared one; and native tiling was assumed on macOS 14.
@Suite struct DisplayIdentityTests {
    private let builtIn = DisplayInfo(id: "B-1", name: "Built-in Retina Display")
    private let left = DisplayInfo(id: "D-LEFT", name: "DELL U2723QE")
    private let right = DisplayInfo(id: "D-RIGHT", name: "DELL U2723QE")

    @Test func twoMonitorsOfOneModelAreTwoDisplays() {
        let displays = [builtIn, left, right]
        #expect(DisplayIdentity.index(id: "D-RIGHT", name: "DELL U2723QE", in: displays) == 2)
        #expect(DisplayIdentity.index(id: "D-LEFT", name: "DELL U2723QE", in: displays) == 1)
    }

    @Test func namesStillFindRecordsSavedBeforeIDs() {
        let displays = [builtIn, left, right]
        // Saved with a name only: the first display with it, as before.
        #expect(DisplayIdentity.index(id: nil, name: "DELL U2723QE", in: displays) == 1)
        // Its monitor swapped for the same model: found by name.
        #expect(DisplayIdentity.index(id: "D-OLD", name: "DELL U2723QE", in: [builtIn, right]) == 1)
        #expect(DisplayIdentity.index(id: "D-OLD", name: "Gone", in: displays) == nil)
    }

    @Test func mapsPreferTheIDThenTheName() {
        let map = ["DELL U2723QE": 1.0, "D-RIGHT": 2.0]
        #expect(DisplayIdentity.value(in: map, for: right) == 2.0)
        #expect(DisplayIdentity.value(in: map, for: left) == 1.0)
        #expect(DisplayIdentity.value(in: map, for: builtIn) == nil)
    }

    @Test @MainActor func eachIdenticalMonitorKeepsItsOwnWidgetSize() throws {
        let suite = "AllSetTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.screenFits[left.id] = ScreenFit(scale: 1.2, size: CGSize(width: 3840, height: 2160))
        settings.screenFits[right.id] = ScreenFit(scale: 1.8, size: CGSize(width: 3840, height: 2160))
        #expect(settings.widgetScale(for: left) == 1.2)
        #expect(settings.widgetScale(for: right) == 1.8)
        #expect(settings.widgetScale(for: builtIn) == settings.widgetScale)
    }

    @Test func widgetsKeepTheirDisplayIDAndOldLayoutsStillLoad() throws {
        var widget = WidgetInstance(kind: .clock, screenName: "DELL U2723QE")
        widget.screenID = "D-RIGHT"
        let copy = try JSONDecoder().decode(WidgetInstance.self, from: JSONEncoder().encode(widget))
        #expect(copy.screenID == "D-RIGHT" && copy.screenName == "DELL U2723QE")

        // A layout saved before ids: no screenID key at all.
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(widget)) as? [String: Any])
        json["screenID"] = nil
        let legacy = try JSONDecoder().decode(WidgetInstance.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(legacy.screenID == nil && legacy.screenName == "DELL U2723QE")

        let placement = try JSONDecoder().decode(WindowPlacement.self, from: Data(#"{"screenName":"DELL U2723QE","frame":[[0,0],[1,1]]}"#.utf8))
        #expect(placement.screenID == nil && placement.screenName == "DELL U2723QE")
    }

    @Test func nativeTilingExistsFromMacOS15() {
        #expect(!WindowLayout.nativeTilingIsOn(preference: nil, osMajor: 14))
        #expect(!WindowLayout.nativeTilingIsOn(preference: true, osMajor: 14))
        #expect(WindowLayout.nativeTilingIsOn(preference: nil, osMajor: 15))
        #expect(!WindowLayout.nativeTilingIsOn(preference: false, osMajor: 26))
    }
}
