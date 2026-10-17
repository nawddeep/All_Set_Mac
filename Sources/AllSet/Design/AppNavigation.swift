import AllSetCore
import SwiftUI

// The main window's floating navigation: four places along the top, and the
// pages of the current one as pills beneath. `AppPage` stays the single
// source of truth, so deep links, `openWindow` and `-openPage` are unchanged.

/// The four places of the main window: the island, the desktop (themes,
/// widgets, wallpaper), the extras that are switched on, and the app itself.
enum NavSection: String, CaseIterable, Identifiable {
    case island, desktop, extras, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .island: "Island"
        case .desktop: "Desktop"
        case .extras: "Extras"
        case .system: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .island: "capsule.fill"
        case .desktop: "macwindow"
        case .extras: "puzzlepiece.extension.fill"
        case .system: "gearshape.fill"
        }
    }

    /// Where a click on the section lands the first time.
    var home: AppPage {
        switch self {
        case .island: .island
        case .desktop: .themes
        case .extras: .extras
        case .system: .general
        }
    }

    static func of(_ page: AppPage) -> NavSection {
        switch page {
        case .island, .activities, .notes: .island
        case .favorites, .themes, .themeSet, .gallery, .widget, .widgetAppearance, .wallpaper, .wallpaperOptions, .desktop: .desktop
        case .extras, .snapping, .workspaces, .clipboard, .shelf, .mixer, .knocks, .screenshot, .monitor: .extras
        case .general, .about: .system
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
             NavItem(page: .activities, title: "Live Activities", symbol: "waveform"),
             NavItem(page: .notes, title: "Notes", symbol: "note.text", badge: services.notes.notes.filter { !$0.isDone }.count)]
        case .desktop:
            // Three things to find a look with, then the desktop you have. What
            // used to sit beside them (see `secondary`) is next to what it controls.
            [NavItem(page: .themes, title: "Themes", symbol: "wand.and.stars"),
             NavItem(page: .gallery(nil), title: "Widgets", symbol: "square.grid.2x2.fill"),
             NavItem(page: .wallpaper, title: "Wallpaper", symbol: "photo.artframe"),
             NavItem(page: .desktop, title: "On Your Desktop", symbol: "rectangle.on.rectangle", badge: services.widgets.widgets.count)]
        case .extras:
            // The switches first; then a pill for each extra that's on.
            [NavItem(page: .extras, title: "Manage", symbol: "switch.2")]
                + Extra.allCases.filter(services.extras.isOn).map { extra in
                    NavItem(page: extra.page, title: extra.shortTitle, symbol: extra.symbol, badge: badge(for: extra, services: services))
                }
        case .system:
            [NavItem(page: .general, title: "General", symbol: "gearshape.fill"),
             NavItem(page: .about, title: "About", symbol: "info.circle.fill")]
        }
    }
}

extension NavItem {
    @MainActor
    fileprivate static func badge(for extra: Extra, services: AppServices) -> Int {
        switch extra {
        case .clipboard: services.clipboard.items.count
        case .shelf: services.shelf.items.count
        default: 0
        }
    }
}

extension Extra {
    /// The extra's page in the main window.
    var page: AppPage {
        switch self {
        case .snapping: .snapping
        case .workspaces: .workspaces
        case .clipboard: .clipboard
        case .shelf: .shelf
        case .mixer: .mixer
        case .knocks: .knocks
        case .screenshot: .screenshot
        case .monitor: .monitor
        }
    }

    /// The pill's name, short enough for a row of them.
    var shortTitle: String {
        switch self {
        case .clipboard: "Clipboard"
        case .monitor: "Monitor"
        default: title
        }
    }
}

extension AppPage {
    /// The extra a page belongs to, if it belongs to one.
    var extra: Extra? { Extra.allCases.first { $0.page == self } }
}
