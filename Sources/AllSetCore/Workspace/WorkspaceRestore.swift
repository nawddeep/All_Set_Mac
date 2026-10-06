import Foundation

/// What switching to a workspace did, app by app. A workspace restores a
/// layout: it opens the apps and moves the windows they open themselves to
/// where they were saved. It doesn't reopen documents.
public struct WorkspaceRestoreReport: Equatable, Sendable {
    public enum Outcome: Equatable, Sendable {
        case notInstalled
        case couldntOpen(String)
        /// Windows moved where they were saved; moved but not landing there
        /// (the app refused or limited the size); saved but never opened.
        case windows(placed: Int, offTarget: Int, missing: Int)
    }

    public struct App: Equatable, Sendable {
        public var name: String
        public var outcome: Outcome

        public init(name: String, outcome: Outcome) {
            self.name = name
            self.outcome = outcome
        }
    }

    public var apps: [App] = []
    /// Asked to hide other apps but didn't, because nothing from the workspace
    /// came up: hiding everything else would have left an empty desktop.
    public var skippedHidingOthers = false

    public init(apps: [App] = [], skippedHidingOthers: Bool = false) {
        self.apps = apps
        self.skippedHidingOthers = skippedHidingOthers
    }

    public var placedWindows: Int {
        apps.reduce(0) { total, app in
            if case .windows(let placed, _, _) = app.outcome { total + placed } else { total }
        }
    }

    /// Every app open and every window where it was saved.
    public var isComplete: Bool {
        !skippedHidingOthers && apps.allSatisfy { app in
            if case .windows(_, 0, 0) = app.outcome { true } else { false }
        }
    }

    /// Says what didn't come back as saved; nil when everything did.
    public var summary: String? {
        guard !isComplete else { return nil }
        var lines: [String] = []
        for app in apps {
            switch app.outcome {
            case .notInstalled:
                lines.append("\(app.name) isn't installed.")
            case .couldntOpen(let reason):
                lines.append("\(app.name) couldn't open: \(reason)")
            case .windows(_, let offTarget, let missing):
                if missing > 0 { lines.append("\(app.name): \(Self.windows(missing)) didn't open.") }
                if offTarget > 0 { lines.append("\(app.name): \(Self.windows(offTarget)) couldn't be put exactly where saved.") }
            }
        }
        if skippedHidingOthers { lines.append("Other apps weren't hidden, since nothing from the workspace opened.") }
        return lines.joined(separator: "\n")
    }

    private static func windows(_ count: Int) -> String { count == 1 ? "1 window" : "\(count) windows" }

    /// Whether a window ended up where it was put, give or take a few points
    /// (apps round frames, and some keep a minimum size).
    public static func landed(_ frame: CGRect?, at target: CGRect, tolerance: CGFloat = 4) -> Bool {
        guard let frame else { return false }
        return abs(frame.minX - target.minX) <= tolerance && abs(frame.minY - target.minY) <= tolerance
            && abs(frame.width - target.width) <= tolerance && abs(frame.height - target.height) <= tolerance
    }
}
