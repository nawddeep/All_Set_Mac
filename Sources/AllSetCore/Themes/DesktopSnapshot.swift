import Foundation

/// Everything putting a theme on the desktop can change, captured before it
/// does so it can all be put back: the widgets, their size, font and corners,
/// which theme they're dressed in, whether they show, and the wallpaper.
/// Undo and a desktop preview's Go Back both restore one of these, so neither
/// can leave half of a theme behind.
public struct DesktopSnapshot: Codable, Equatable, Sendable {
    public var widgets: [WidgetInstance]
    public var scale: Double
    public var screenFits: [String: ScreenFit]
    public var font: WidgetFont
    public var cornerRadius: Double
    public var widgetTheme: String?
    public var designTheme: String?
    public var activeThemeSet: String?
    public var showWidgets: Bool
    public var wallpaper: WallpaperConfig

    @MainActor
    public init(settings: AppSettings, widgets: WidgetStore, wallpaper: WallpaperStore) {
        self.widgets = widgets.widgets
        scale = settings.widgetScale
        screenFits = settings.screenFits
        font = settings.widgetFont
        cornerRadius = settings.widgetCornerRadius
        widgetTheme = settings.widgetTheme
        designTheme = settings.widgetDesignTheme
        activeThemeSet = settings.activeThemeSet
        showWidgets = settings.showWidgets
        self.wallpaper = wallpaper.config
    }

    @MainActor
    public func restore(settings: AppSettings, widgets: WidgetStore, wallpaper: WallpaperStore) {
        widgets.replaceAll(with: self.widgets)
        settings.widgetScale = scale
        settings.screenFits = screenFits
        settings.widgetFont = font
        settings.widgetCornerRadius = cornerRadius
        settings.widgetTheme = widgetTheme
        settings.widgetDesignTheme = designTheme
        settings.activeThemeSet = activeThemeSet
        settings.showWidgets = showWidgets
        // Only when it differs: setting it restarts the wallpaper.
        if wallpaper.config != self.wallpaper { wallpaper.config = self.wallpaper }
    }
}

extension AppSettings {
    /// What a theme set decides beyond its widgets, the same however it was
    /// put on the desktop (installed, added, restyled or kept after a
    /// preview): an original setup's font and corners, which theme the
    /// desktop is in, and that widgets show.
    public func adopt(_ set: ThemeSet) {
        if let setup = set.setup {
            widgetFont = setup.font
            widgetCornerRadius = setup.cornerRadius
        }
        widgetDesignTheme = set.designTheme?.id
        widgetTheme = set.setup?.id
        activeThemeSet = set.id
        showWidgets = true
    }

    /// Forgets any theme: the widget font, corners and size go back to a
    /// fresh install's, and no theme is on.
    public func resetWidgetLook() {
        widgetFont = Self.defaultWidgetFont
        widgetCornerRadius = Self.defaultWidgetCornerRadius
        widgetScale = 1
        widgetTheme = nil
        widgetDesignTheme = nil
        activeThemeSet = nil
    }
}
