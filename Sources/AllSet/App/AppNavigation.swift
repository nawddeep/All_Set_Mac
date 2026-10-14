import AllSetCore
import SwiftUI

// The main window's floating navigation: five places along the top, and the
// pages of the current one as pills beneath. `AppPage` stays the single
// source of truth, so deep links, `openWindow` and `-openPage` are unchanged.

/// The five places of the main window.
enum NavSection: String, CaseIterable, Identifiable {
    case island, desktop, workspace, tools, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .island: "Island"
        case .desktop: "Desktop"
        case .workspace: "Workspace"
        case .tools: "Tools"
        case .system: "System"
        }
    }

    var symbol: String {
        switch self {
        case .island: "capsule.fill"
        case .desktop: "macwindow"
        case .workspace: "rectangle.split.2x1.fill"
        case .tools: "wrench.and.screwdriver.fill"
        case .system: "gearshape.fill"
        }
    }

    /// Where a click on the section lands the first time.
    var home: AppPage {
        switch self {
        case .island: .island
        case .desktop: .themes
        case .workspace: .snapping
        case .tools: .clipboard
        case .system: .monitor
        }
    }

    static func of(_ page: AppPage) -> NavSection {
        switch page {
        case .island, .activities: .island
        case .favorites, .themes, .themeSet, .gallery, .widget, .widgetAppearance, .wallpaper, .wallpaperOptions, .desktop: .desktop
        case .snapping, .workspaces: .workspace
        case .clipboard, .shelf, .mixer, .knocks, .notes, .screenshot: .tools
        case .monitor, .lidPlane, .general, .about: .system
        }
    }
}

/// One page's pill in the second row.
struct NavItem: Identifiable {
    let page: AppPage
    let title: String
    let symbol: String
    var badge = 0

    var id: String { title }

    /// Detail pages, and pages reached from another page rather than a pill,
    /// light up the pill they belong to.
    func matches(_ current: AppPage) -> Bool {
        switch (page, current) {
        case (.themes, .themeSet), (.gallery, .gallery), (.desktop, .widget): true
        case (.themes, .favorites), (.wallpaper, .wallpaperOptions), (.desktop, .widgetAppearance): true
        default: page == current
        }
    }

    /// Pages with no pill of their own: each is a setting or a view of
    /// something that has one, and is opened from there (Favorites is a filter
    /// on Themes, Wallpaper Options a button on Wallpaper, Look & Layout a
    /// button on On Your Desktop). Still found by search and by links.
    static func secondary(in section: NavSection) -> [NavItem] {
        switch section {
        case .desktop:
            [NavItem(page: .favorites, title: "Favorites", symbol: "heart.fill"),
             NavItem(page: .widgetAppearance, title: "Look & Layout", symbol: "paintbrush.fill"),
             NavItem(page: .wallpaperOptions, title: "Wallpaper Options", symbol: "slider.horizontal.3")]
        default: []
        }
    }

    @MainActor
    static func items(in section: NavSection, services: AppServices) -> [NavItem] {
        switch section {
        case .island:
            [NavItem(page: .island, title: "Dynamic Island", symbol: "capsule.fill"),
             NavItem(page: .activities, title: "Live Activities", symbol: "waveform")]
        case .desktop:
            // Three things to find a look with, then the desktop you have. What
            // used to sit beside them (see `secondary`) is next to what it controls.
            [NavItem(page: .themes, title: "Themes", symbol: "wand.and.stars"),
             NavItem(page: .gallery(nil), title: "Widgets", symbol: "square.grid.2x2.fill"),
             NavItem(page: .wallpaper, title: "Wallpaper", symbol: "photo.artframe"),
             NavItem(page: .desktop, title: "On Your Desktop", symbol: "rectangle.on.rectangle", badge: services.widgets.widgets.count)]
        case .workspace:
            [NavItem(page: .snapping, title: "Window Snapping", symbol: "rectangle.split.2x1.fill"),
             NavItem(page: .workspaces, title: "Workspaces", symbol: "square.stack.3d.down.right.fill")]
        case .tools:
            [NavItem(page: .clipboard, title: "Clipboard", symbol: "doc.on.clipboard.fill", badge: services.clipboard.items.count),
             NavItem(page: .shelf, title: "Shelf", symbol: "tray.full.fill", badge: services.shelf.items.count),
             NavItem(page: .mixer, title: "Sound Mixer", symbol: "slider.vertical.3"),
             NavItem(page: .knocks, title: "TapTap", symbol: "hand.tap.fill"),
             NavItem(page: .screenshot, title: "AI Screenshot", symbol: "camera.viewfinder"),
             NavItem(page: .notes, title: "Notes", symbol: "note.text", badge: services.notes.notes.filter { !$0.isDone }.count)]
        case .system:
            [NavItem(page: .monitor, title: "Monitor", symbol: "gauge.with.dots.needle.50percent"),
             NavItem(page: .lidPlane, title: "Lid Plane", symbol: "laptopcomputer"),
             NavItem(page: .general, title: "General", symbol: "gearshape.fill"),
             NavItem(page: .about, title: "About", symbol: "info.circle.fill")]
        }
    }
}
