import AllSetCore
import AppKit

/// Saves the windows on screen as a workspace, and brings a workspace back:
/// opening its apps, placing their windows, and hiding everything else.
@MainActor
final class WorkspaceController {
    private let services: AppServices

    init(services: AppServices) {
        self.services = services
    }

    /// Every visible app with open windows, front-most first.
    func captureCurrentLayout() -> [WorkspaceApp] {
        guard Accessibility.isTrusted else { return [] }
        let me = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isHidden && $0.processIdentifier != me && $0.bundleIdentifier != nil
        }
        let order = Self.frontToBackPIDs()
        let sorted = apps.sorted { (order.firstIndex(of: $0.processIdentifier) ?? .max) < (order.firstIndex(of: $1.processIdentifier) ?? .max) }

        return sorted.compactMap { app in
            let placements = AXWindow.windows(of: app.processIdentifier)
                .filter { $0.isStandard && !$0.isMinimized }
                .compactMap { window -> WindowPlacement? in
                    guard let frame = window.frame.map(appKit), let screen = screen(for: frame) else { return nil }
                    let visible = screen.visibleFrame
                    let relative = CGRect(x: (frame.minX - visible.minX) / visible.width,
                                          y: (frame.minY - visible.minY) / visible.height,
                                          width: frame.width / visible.width,
                                          height: frame.height / visible.height)
                    return WindowPlacement(title: window.title, screenID: screen.stableID, screenName: screen.localizedName, frame: relative)
                }
            guard !placements.isEmpty, let bundleID = app.bundleIdentifier else { return nil }
            return WorkspaceApp(bundleID: bundleID, name: app.localizedName ?? bundleID, windows: placements)
        }
    }

    /// Opens the workspace's apps and puts their windows where they were
    /// saved, then says what didn't come back that way (in
    /// `ui.workspaceReports`): it restores a layout, not documents.
    @discardableResult
    func apply(_ workspace: Workspace) async -> WorkspaceRestoreReport? {
        guard Accessibility.isTrusted else {
            Accessibility.requestAccess()
            return nil
        }
        guard services.ui.applyingWorkspace == nil else { return nil }
        services.ui.applyingWorkspace = workspace.id
        defer { services.ui.applyingWorkspace = nil }
        var outcomes: [String: WorkspaceRestoreReport.Outcome] = [:]

        // Open what isn't running, without stealing focus yet.
        for app in workspace.apps where running(app.bundleID) == nil {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) else {
                outcomes[app.bundleID] = .notInstalled
                continue
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            do {
                _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            } catch {
                outcomes[app.bundleID] = .couldntOpen(error.localizedDescription)
            }
        }

        // Back to front, so the first app ends up on top.
        for app in workspace.apps.reversed() where outcomes[app.bundleID] == nil {
            guard let running = running(app.bundleID) else {
                outcomes[app.bundleID] = .couldntOpen("it quit while opening")
                continue
            }
            running.unhide()
            var windows = await standardWindows(of: running.processIdentifier, atLeast: app.windows.count)
            var placed = 0, offTarget = 0, missing = 0
            for placement in app.windows {
                let index = windows.firstIndex { placement.title?.isEmpty == false && $0.title == placement.title }
                    ?? (windows.isEmpty ? nil : 0)
                guard let index else {
                    missing += 1
                    continue
                }
                let window = windows.remove(at: index)
                let screen = NSScreen.matching(id: placement.screenID, name: placement.screenName) ?? NSScreen.main
                guard let visible = screen?.visibleFrame else {
                    missing += 1
                    continue
                }
                let target = CGRect(x: visible.minX + placement.frame.minX * visible.width,
                                    y: visible.minY + placement.frame.minY * visible.height,
                                    width: placement.frame.width * visible.width,
                                    height: placement.frame.height * visible.height).integral
                let wanted = WindowLayout.flipped(target, primaryHeight: primaryHeight)
                // Checked by reading it back: an app can accept a frame and still limit it.
                if window.setFrame(wanted), WorkspaceRestoreReport.landed(window.frame, at: wanted) {
                    placed += 1
                } else {
                    offTarget += 1
                }
                window.raise()
            }
            outcomes[app.bundleID] = .windows(placed: placed, offTarget: offTarget, missing: missing)
            running.activate()
        }

        var report = WorkspaceRestoreReport(apps: workspace.apps.map {
            .init(name: $0.name, outcome: outcomes[$0.bundleID] ?? .windows(placed: 0, offTarget: 0, missing: $0.windows.count))
        })
        if workspace.hideOthers {
            if report.placedWindows == 0 {
                report.skippedHidingOthers = true
            } else {
                let keep = Set(workspace.apps.map(\.bundleID))
                let me = ProcessInfo.processInfo.processIdentifier
                for app in NSWorkspace.shared.runningApplications
                where app.activationPolicy == .regular && app.processIdentifier != me && !keep.contains(app.bundleIdentifier ?? "") {
                    app.hide()
                }
            }
        }
        if let first = workspace.apps.first, let app = running(first.bundleID) {
            app.activate()
        }
        services.ui.workspaceReports[workspace.id] = report
        return report
    }

    // MARK: Helpers

    private func running(_ bundleID: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    }

    /// An app that just launched takes a moment to open its windows.
    private func standardWindows(of pid: pid_t, atLeast count: Int) async -> [AXWindow] {
        var windows: [AXWindow] = []
        for _ in 0..<32 {
            windows = AXWindow.windows(of: pid).filter { $0.isStandard && !$0.isMinimized }
            if windows.count >= count { break }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return windows
    }

    private static func frontToBackPIDs() -> [pid_t] {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var order: [pid_t] = []
        for window in info where (window[kCGWindowLayer as String] as? Int) == 0 {
            if let pid = window[kCGWindowOwnerPID as String] as? pid_t, !order.contains(pid) { order.append(pid) }
        }
        return order
    }

    private var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    private func appKit(_ rect: CGRect) -> CGRect { WindowLayout.flipped(rect, primaryHeight: primaryHeight) }

    private func screen(for frame: CGRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) } ?? NSScreen.main
    }
}
