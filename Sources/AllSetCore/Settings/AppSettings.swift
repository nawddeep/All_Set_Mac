import Foundation
import Observation

public enum NotchDisplay: String, CaseIterable, Identifiable, Sendable {
    /// The MacBook's own screen, falling back to the primary one when it's closed.
    case builtIn
    /// The screen with the menu bar.
    case primary

    public var id: String { rawValue }
    public var title: String { self == .builtIn ? "Built-in display" : "Primary display" }
}

/// Which tab the island shows when it opens.
public enum NotchStartTab: String, CaseIterable, Identifiable, Sendable {
    case last
    case home
    case system

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .last: "Where I left it"
        case .home: "Home"
        case .system: "System"
        }
    }
}

/// User preferences, persisted to UserDefaults as they change.
@Observable @MainActor
public final class AppSettings {
    // Notch
    public var notchEnabled: Bool { didSet { save(notchEnabled, Key.notchEnabled) } }
    public var notchStartTab: NotchStartTab { didSet { save(notchStartTab.rawValue, Key.notchStartTab) } }
    public var notchDisplay: NotchDisplay { didSet { save(notchDisplay.rawValue, Key.notchDisplay) } }
    public var expandOnHover: Bool { didSet { save(expandOnHover, Key.expandOnHover) } }
    /// Seconds the pointer must rest on the notch before it opens.
    public var hoverDelay: Double { didSet { save(hoverDelay, Key.hoverDelay) } }
    public var hapticFeedback: Bool { didSet { save(hapticFeedback, Key.hapticFeedback) } }

    // Live activities
    public var showNowPlaying: Bool { didSet { save(showNowPlaying, Key.showNowPlaying) } }
    public var showVolume: Bool { didSet { save(showVolume, Key.showVolume) } }
    public var showBattery: Bool { didSet { save(showBattery, Key.showBattery) } }
    public var showAudioDevice: Bool { didSet { save(showAudioDevice, Key.showAudioDevice) } }

    // App
    public var showInDock: Bool { didSet { save(showInDock, Key.showInDock) } }

    /// The chord that starts an AI screenshot from any app.
    public var screenshotShortcut: ScreenshotShortcut { didSet { save(screenshotShortcut.rawValue, Key.screenshotShortcut) } }

    // Menu bar
    public var showMenuBarIcon: Bool { didSet { save(showMenuBarIcon, Key.showMenuBarIcon) } }
    public var showCPUInMenuBar: Bool { didSet { save(showCPUInMenuBar, Key.showCPUInMenuBar) } }

    // Desktop widgets
    public var showWidgets: Bool { didSet { save(showWidgets, Key.showWidgets) } }
    public var widgetFont: WidgetFont { didSet { save(widgetFont.rawValue, Key.widgetFont) } }
    public var widgetCornerRadius: Double { didSet { save(widgetCornerRadius, Key.widgetCornerRadius) } }
    /// How large desktop widgets are drawn, 1 for their natural size. Applying a
    /// theme sets it so the theme's grid fills the screen.
    public var widgetScale: Double {
        didSet {
            save(widgetScale, Key.widgetScale)
            // The size slider is for every display at once.
            if !screenFits.isEmpty { screenFits = screenFits.mapValues { var fit = $0; fit.scale = widgetScale; return fit } }
        }
    }
    /// Each display's own widget size and the screen size its widgets were last
    /// laid out for, by display id (by name when saved before ids). A new size
    /// (a resolution change, another monitor) refits that display's widgets.
    public var screenFits: [String: ScreenFit] {
        didSet { defaults.set(try? JSONEncoder().encode(screenFits), forKey: Key.screenFits) }
    }

    /// The widget size on a display: its own, else the desktop-wide one.
    public func widgetScale(for screenName: String?) -> Double {
        screenName.flatMap { screenFits[$0]?.scale } ?? widgetScale
    }

    public func widgetScale(for display: DisplayInfo?) -> Double {
        display.flatMap { DisplayIdentity.value(in: screenFits, for: $0)?.scale } ?? widgetScale
    }

    /// A display's fit, saved under its id (or found under its name, saved before ids).
    public func screenFit(for display: DisplayInfo) -> ScreenFit? {
        DisplayIdentity.value(in: screenFits, for: display)
    }
    public nonisolated static let widgetScaleRange: ClosedRange<Double> = 0.4...2
    /// The widget look before any theme: a fresh install's, and what a
    /// cleared desktop goes back to.
    public nonisolated static let defaultWidgetFont = WidgetFont.rounded
    public nonisolated static let defaultWidgetCornerRadius = 22.0
    /// The theme last applied, by id; nil once widgets have been styled by hand.
    public var widgetTheme: String? { didSet { defaults.set(widgetTheme, forKey: Key.widgetTheme) } }
    /// The design theme new widgets start in; nil for their own looks.
    public var widgetDesignTheme: String? { didSet { defaults.set(widgetDesignTheme, forKey: Key.widgetDesignTheme) } }
    /// The theme set last put on the desktop, by `ThemeSet.id`; nil once it is turned off or the look reset.
    public var activeThemeSet: String? { didSet { defaults.set(activeThemeSet, forKey: Key.activeThemeSet) } }

    // System monitor
    /// Seconds between samples while stats are on screen.
    public var refreshInterval: Double { didSet { save(refreshInterval, Key.refreshInterval) } }
    public var temperatureUnit: TemperatureUnit { didSet { save(temperatureUnit.rawValue, Key.temperatureUnit) } }

    @ObservationIgnored private let defaults: UserDefaults

    enum Key {
        static let notchEnabled = "notch.enabled"
        static let notchStartTab = "notch.startTab"
        static let showInDock = "app.showInDock"
        static let notchDisplay = "notch.display"
        static let expandOnHover = "notch.expandOnHover"
        static let hoverDelay = "notch.hoverDelay"
        static let hapticFeedback = "notch.hapticFeedback"
        static let showNowPlaying = "activities.nowPlaying"
        static let showVolume = "activities.volume"
        static let showBattery = "activities.battery"
        static let showAudioDevice = "activities.audioDevice"
        static let showMenuBarIcon = "menuBar.showIcon"
        static let showCPUInMenuBar = "menuBar.showCPU"
        static let showWidgets = "widgets.show"
        static let widgetFont = "widgets.font"
        static let widgetCornerRadius = "widgets.cornerRadius"
        static let widgetScale = "widgets.scale"
        static let screenshotShortcut = "screenshot.shortcut"
        static let widgetTheme = "widgets.theme"
        static let widgetDesignTheme = "widgets.designTheme"
        static let activeThemeSet = "widgets.themeSet"
        static let screenFits = "widgets.screenFits"
        static let refreshInterval = "monitor.refreshInterval"
        static let temperatureUnit = "monitor.temperatureUnit"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        notchEnabled = defaults.object(forKey: Key.notchEnabled) as? Bool ?? true
        notchStartTab = defaults.string(forKey: Key.notchStartTab).flatMap(NotchStartTab.init) ?? .last
        showInDock = defaults.object(forKey: Key.showInDock) as? Bool ?? true
        notchDisplay = defaults.string(forKey: Key.notchDisplay).flatMap(NotchDisplay.init) ?? .builtIn
        expandOnHover = defaults.object(forKey: Key.expandOnHover) as? Bool ?? true
        hoverDelay = defaults.object(forKey: Key.hoverDelay) as? Double ?? 0.15
        hapticFeedback = defaults.object(forKey: Key.hapticFeedback) as? Bool ?? true
        showNowPlaying = defaults.object(forKey: Key.showNowPlaying) as? Bool ?? true
        showVolume = defaults.object(forKey: Key.showVolume) as? Bool ?? true
        showBattery = defaults.object(forKey: Key.showBattery) as? Bool ?? true
        showAudioDevice = defaults.object(forKey: Key.showAudioDevice) as? Bool ?? true
        screenshotShortcut = defaults.string(forKey: Key.screenshotShortcut).flatMap(ScreenshotShortcut.init) ?? .off
        showMenuBarIcon = defaults.object(forKey: Key.showMenuBarIcon) as? Bool ?? true
        showCPUInMenuBar = defaults.object(forKey: Key.showCPUInMenuBar) as? Bool ?? false
        showWidgets = defaults.object(forKey: Key.showWidgets) as? Bool ?? true
        widgetFont = defaults.string(forKey: Key.widgetFont).flatMap(WidgetFont.init) ?? Self.defaultWidgetFont
        widgetCornerRadius = defaults.object(forKey: Key.widgetCornerRadius) as? Double ?? Self.defaultWidgetCornerRadius
        widgetScale = min(max(defaults.object(forKey: Key.widgetScale) as? Double ?? 1, Self.widgetScaleRange.lowerBound),
                          Self.widgetScaleRange.upperBound)
        widgetTheme = defaults.string(forKey: Key.widgetTheme)
        widgetDesignTheme = defaults.string(forKey: Key.widgetDesignTheme)
        activeThemeSet = defaults.string(forKey: Key.activeThemeSet)
        screenFits = defaults.data(forKey: Key.screenFits).flatMap { try? JSONDecoder().decode([String: ScreenFit].self, from: $0) } ?? [:]
        refreshInterval = defaults.object(forKey: Key.refreshInterval) as? Double ?? 1
        temperatureUnit = defaults.string(forKey: Key.temperatureUnit).flatMap(TemperatureUnit.init) ?? .celsius
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }
}

/// A display's widget size and the screen size (visible area, points) the widgets
/// on it were laid out for.
public struct ScreenFit: Codable, Equatable, Sendable {
    public var scale: Double
    public var width: Double
    public var height: Double

    public init(scale: Double, size: CGSize) {
        self.scale = scale
        width = Double(size.width)
        height = Double(size.height)
    }

    public var size: CGSize { CGSize(width: width, height: height) }
}
