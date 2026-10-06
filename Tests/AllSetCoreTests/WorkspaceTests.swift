import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite struct WindowLayoutTests {
    // A 1470×956 MacBook Air screen with a 34 pt menu bar and no Dock.
    private let visible = CGRect(x: 0, y: 0, width: 1470, height: 922)
    private let window = CGRect(x: 200, y: 200, width: 800, height: 500)

    private func frame(_ action: WindowAction, from window: CGRect? = nil, gap: CGFloat = 0, cycle: Bool = true) -> CGRect? {
        WindowLayout.frame(for: action, window: window ?? self.window, visible: visible, gap: gap, cycle: cycle)
    }

    @Test func halvesAndQuarters() {
        #expect(frame(.leftHalf) == CGRect(x: 0, y: 0, width: 735, height: 922))
        #expect(frame(.rightHalf) == CGRect(x: 735, y: 0, width: 735, height: 922))
        // AppKit coordinates: the top half has the larger y.
        #expect(frame(.topHalf) == CGRect(x: 0, y: 461, width: 1470, height: 461))
        #expect(frame(.bottomLeft) == CGRect(x: 0, y: 0, width: 735, height: 461))
        #expect(frame(.topRight) == CGRect(x: 735, y: 461, width: 735, height: 461))
        #expect(frame(.maximize) == visible)
    }

    @Test func thirdsCoverTheScreen() throws {
        let first = try #require(frame(.firstThird))
        let center = try #require(frame(.centerThird))
        let last = try #require(frame(.lastThird))
        #expect(first.minX == 0 && last.maxX == 1470)
        #expect(abs(first.maxX - center.minX) <= 1 && abs(center.maxX - last.minX) <= 1)
        #expect(frame(.lastTwoThirds)?.maxX == 1470)
    }

    @Test func repeatingLeftHalfCyclesThroughWidths() throws {
        let half = try #require(frame(.leftHalf))
        let twoThirds = try #require(frame(.leftHalf, from: half))
        #expect(abs(twoThirds.width - 980) <= 1)
        let third = try #require(frame(.leftHalf, from: twoThirds))
        #expect(abs(third.width - 490) <= 1)
        #expect(frame(.leftHalf, from: third) == half)
        #expect(frame(.leftHalf, from: half, cycle: false) == half)
        let rightHalf = try #require(frame(.rightHalf))
        let right = try #require(frame(.rightHalf, from: rightHalf))
        #expect(right.maxX == 1470 && abs(right.width - 980) <= 1)
    }

    @Test func gapsSurroundAndSeparateWindows() throws {
        let left = try #require(frame(.leftHalf, gap: 10))
        let right = try #require(frame(.rightHalf, gap: 10))
        #expect(left.minX == 10 && left.minY == 10 && left.maxY == 912)
        #expect(right.minX - left.maxX == 10)
        #expect(right.maxX == 1460)
    }

    @Test func centerKeepsTheSizeAndFitsTheScreen() {
        #expect(frame(.center) == CGRect(x: 335, y: 211, width: 800, height: 500))
        let huge = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        #expect(frame(.center, from: huge) == visible)
    }

    @Test func actionsThatNeedMoreContextReturnNil() {
        #expect(frame(.restore) == nil)
        #expect(frame(.nextDisplay) == nil)
    }

    @Test func snapZonesFollowEdgesAndCorners() {
        let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)
        #expect(WindowLayout.snapZone(at: CGPoint(x: 1, y: 500), screen: screen) == .leftHalf)
        #expect(WindowLayout.snapZone(at: CGPoint(x: 1469, y: 500), screen: screen) == .rightHalf)
        #expect(WindowLayout.snapZone(at: CGPoint(x: 700, y: 955), screen: screen) == .maximize)
        #expect(WindowLayout.snapZone(at: CGPoint(x: 1, y: 950), screen: screen) == .topLeft)
        #expect(WindowLayout.snapZone(at: CGPoint(x: 1469, y: 10), screen: screen) == .bottomRight)
        #expect(WindowLayout.snapZone(at: CGPoint(x: 100, y: 1), screen: screen) == .firstThird)
        #expect(WindowLayout.snapZone(at: CGPoint(x: 735, y: 1), screen: screen) == .centerThird)
        #expect(WindowLayout.snapZone(at: CGPoint(x: 700, y: 500), screen: screen) == nil)
    }

    @Test func movingToAnotherDisplayKeepsTheRelativeSpot() {
        let moved = WindowLayout.move(CGRect(x: 0, y: 0, width: 735, height: 461),
                                      from: CGRect(x: 0, y: 0, width: 1470, height: 922),
                                      to: CGRect(x: 1470, y: 0, width: 2560, height: 1415))
        #expect(moved == CGRect(x: 1470, y: 0, width: 1280, height: 708))
    }

    @Test func flippingBetweenCoordinateSystemsRoundTrips() {
        let appKit = CGRect(x: 10, y: 20, width: 300, height: 200)
        let accessibility = WindowLayout.flipped(appKit, primaryHeight: 956)
        #expect(accessibility == CGRect(x: 10, y: 736, width: 300, height: 200))
        #expect(WindowLayout.flipped(accessibility, primaryHeight: 956) == appKit)
    }
}

@Suite @MainActor struct WorkspaceStoreTests {
    @Test func shortcutsShowLikeMacOSMenus() {
        #expect(Shortcut.defaults[.leftHalf]?.display == "⌃⌥←")
        #expect(Shortcut.defaults[.nextDisplay]?.display == "⌃⌥⌘→")
        #expect(Shortcut.defaults.count == WindowAction.allCases.count)
    }

    @Test func customAndRemovedShortcutsPersist() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetWorkspaces-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }

        let store = WorkspaceStore(fileURL: file)
        let custom = Shortcut(keyCode: 0x00, modifiers: [.command, .option], key: "A")
        store.settings.shortcuts[.leftHalf] = .some(custom)
        store.settings.shortcuts[.center] = .some(nil)
        store.settings.gap = 12
        var workspace = Workspace(name: "Coding", symbol: "hammer.fill", apps: [
            WorkspaceApp(bundleID: "com.microsoft.VSCode", name: "Code",
                         windows: [WindowPlacement(title: "all set", screenName: "Built-in", frame: CGRect(x: 0, y: 0, width: 0.66, height: 1))]),
        ])
        workspace.shortcut = Shortcut(keyCode: 0x12, modifiers: [.control, .option], key: "1")
        store.workspaces = [workspace]

        let reloaded = WorkspaceStore(fileURL: file)
        #expect(reloaded.settings.shortcut(for: .leftHalf) == custom)
        #expect(reloaded.settings.shortcut(for: .center) == nil)
        #expect(reloaded.settings.shortcut(for: .rightHalf) == Shortcut.defaults[.rightHalf])
        #expect(reloaded.settings.gap == 12)
        #expect(reloaded.workspaces == [workspace])
    }
}

/// Review A2: switching to a workspace skipped what failed without a word,
/// and hid every other app even when nothing came back.
@Suite struct WorkspaceRestoreReportTests {
    @Test func everythingInPlaceSaysNothing() {
        let report = WorkspaceRestoreReport(apps: [.init(name: "Safari", outcome: .windows(placed: 2, offTarget: 0, missing: 0))])
        #expect(report.isComplete && report.summary == nil)
    }

    @Test func eachShortfallIsNamed() throws {
        let report = WorkspaceRestoreReport(apps: [
            .init(name: "Xcode", outcome: .notInstalled),
            .init(name: "Figma", outcome: .couldntOpen("The app is damaged.")),
            .init(name: "Safari", outcome: .windows(placed: 1, offTarget: 1, missing: 2)),
        ], skippedHidingOthers: true)
        #expect(!report.isComplete)
        let summary = try #require(report.summary)
        #expect(summary.contains("Xcode isn't installed."))
        #expect(summary.contains("Figma couldn't open: The app is damaged."))
        #expect(summary.contains("Safari: 2 windows didn't open."))
        #expect(summary.contains("Safari: 1 window couldn't be put exactly where saved."))
        #expect(summary.contains("weren't hidden"))
        #expect(report.placedWindows == 1)
    }

    @Test func aWindowCountsAsPlacedOnlyWhereItLanded() {
        let target = CGRect(x: 100, y: 50, width: 800, height: 600)
        #expect(WorkspaceRestoreReport.landed(CGRect(x: 102, y: 49, width: 801, height: 600), at: target))
        #expect(!WorkspaceRestoreReport.landed(CGRect(x: 100, y: 50, width: 1000, height: 600), at: target))
        #expect(!WorkspaceRestoreReport.landed(nil, at: target))
    }
}
