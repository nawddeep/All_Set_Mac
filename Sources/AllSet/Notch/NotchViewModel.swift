import AllSetCore
import CoreGraphics
import Observation

/// Something shown beside the closed notch, like the iPhone's Dynamic Island.
enum LiveActivity: Equatable {
    case nowPlaying
    case volume(level: Float, muted: Bool)
    case power(percent: Int, pluggedIn: Bool)
    case lowBattery(percent: Int)
    case audioDevice(name: String, kind: AudioDeviceKind)
    /// A knock on the case, with what it did.
    case knock(count: KnockCount, symbol: String, failed: Bool)

    /// Width added on each side of the notch.
    var sideWidth: CGFloat {
        switch self {
        case .nowPlaying: 42
        case .volume: 70
        case .power, .lowBattery: 64
        case .audioDevice: 46
        case .knock: 48
        }
    }

    /// Extra height below the notch for a line of text.
    var captionHeight: CGFloat {
        if case .audioDevice = self { 26 } else { 0 }
    }

    /// Changes of kind cross-fade; changes within a kind (the volume level
    /// moving) update in place.
    var kind: String {
        switch self {
        case .nowPlaying: "nowPlaying"
        case .volume: "volume"
        case .power: "power"
        case .lowBattery: "lowBattery"
        case .audioDevice: "audioDevice"
        case .knock: "knock"
        }
    }
}

@Observable @MainActor
final class NotchViewModel {
    enum Tab: CaseIterable {
        case home
        case tray
        case mixer
        case notes
        case system
    }

    var geometry: NotchGeometry
    var isExpanded = false
    /// Pointer resting on the closed notch; it grows slightly as a hint.
    var isHovering = false
    var tab: Tab = .home {
        didSet { if tab != oldValue { tabDirection = (Tab.allCases.firstIndex(of: tab) ?? 0) - (Tab.allCases.firstIndex(of: oldValue) ?? 0) } }
    }
    /// Which way the last tab switch went along the row: positive to the right.
    var tabDirection = 1
    /// Short-lived activities (volume, charging...) that take over for a moment.
    var transientActivity: LiveActivity?
    var showsNowPlaying = false
    /// Typing in the island: it stays open even if the pointer leaves.
    var isEditing = false

    init(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    var activity: LiveActivity? {
        guard !isExpanded else { return nil }
        return transientActivity ?? (showsNowPlaying ? .nowPlaying : nil)
    }

    static func expandedSize(for tab: Tab) -> CGSize {
        switch tab {
        case .home: CGSize(width: 640, height: 200)
        case .tray: CGSize(width: 700, height: 210)
        case .mixer: CGSize(width: 700, height: 240)
        case .notes: CGSize(width: 640, height: 250)
        case .system: CGSize(width: 860, height: 300)
        }
    }

    /// Fits the largest state plus room for its shadow.
    static let windowSize = CGSize(width: 940, height: 340)

    var shapeSize: CGSize {
        if isExpanded { return Self.expandedSize(for: tab) }
        let notch = geometry.notchRect.size
        if let activity {
            return CGSize(width: notch.width + activity.sideWidth * 2, height: notch.height + activity.captionHeight)
        }
        return isHovering ? CGSize(width: notch.width + 14, height: notch.height + 4) : notch
    }

    var topCornerRadius: CGFloat { isExpanded ? 14 : 6 }

    var bottomCornerRadius: CGFloat {
        if isExpanded { return 28 }
        return (activity?.captionHeight ?? 0) > 0 ? 16 : 10
    }
}
