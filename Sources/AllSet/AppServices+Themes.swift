import AllSetCore
import AppKit

/// A theme set being tried on the desktop, and everything to put back.
struct ThemePreview: Equatable {
    let setID: String
    let before: DesktopSnapshot
}

/// A change to the whole desktop that can be taken back, and the desktop
/// from before it.
struct DesktopUndo: Equatable {
    enum Change: Equatable {
        /// A theme set, by name, went on.
        case theme(String)
        /// A wallpaper was picked. The widgets stay; taking it back puts the
        /// previous wallpaper back.
        case wallpaper
        /// The theme, by name, was turned off: widgets cleared, look reset.
        case turnedOff(String)
    }

    let change: Change
    let before: DesktopSnapshot
    let id = UUID()
}

/// How a theme set goes onto the desktop. Every mode can be undone.
enum ThemeInstall {
    /// The set's widgets replace the current ones.
    case replace
    /// The set's widgets join the current ones, in free spots.
    case add
    /// The current widgets take on the set's look; nothing is added.
    case restyle
}

extension AppServices {
    /// Installs a theme set: its widgets, look and (if asked) wallpaper.
    @discardableResult
    func install(_ set: ThemeSet, mode: ThemeInstall, wallpaper setsWallpaper: Bool) -> Bool {
        // With a monitor connected, asks which display gets the widgets.
        var target = NSScreen.screens.first
        if mode != .restyle {
            guard let chosen = chooseThemeScreen(for: set) else { return false }
            target = chosen
        }
        // Installing over a preview starts from the desktop before the preview.
        if ui.themePreview != nil { endThemePreview(keep: false) }
        let before = desktopSnapshot
        switch mode {
        case .replace:
            replaceWidgets(on: target, with: themeWidgets(set, on: target))
            themeStats.record(.install, for: set.id)
        case .add:
            let screen = target
            let bounds = screen?.visibleFrame.size ?? CGSize(width: 1440, height: 860)
            let added = ThemeSet.personalized(set.widgets(screenName: screen?.localizedName, bounds: bounds),
                                              with: themePhotos.sources(for: set.id)).map { $0.placed(on: screen) }
            for widget in prepared(added) { addWidget(widget) }
            themeStats.record(.install, for: set.id)
        case .restyle:
            if let theme = set.designTheme {
                apply(theme, wallpaper: false)
            } else if let setup = set.setup {
                apply(setup, wallpaper: false)
            }
            themeStats.record(.apply, for: set.id)
        }
        if setsWallpaper, let source = set.wallpaper { wallpaper.set(source) }
        settings.adopt(set)
        if recordChange(.theme(set.name), before: before) {
            ui.toast = Toast(message: "\(set.name) is on your desktop", symbol: "wand.and.stars")
        }
        return true
    }

    /// Tries a set on the desktop until Keep or Go Back. It's put there
    /// exactly as Install would, so Keep has nothing left to change.
    func previewOnDesktop(_ set: ThemeSet, wallpaper setsWallpaper: Bool) {
        guard let target = chooseThemeScreen(for: set) else { return }
        if ui.themePreview != nil { endThemePreview(keep: false) }
        let before = desktopSnapshot
        // Written down before anything changes: quitting or a crash mid-trial
        // then puts this desktop back rather than keeping the trial.
        guard desktopJournal.beginPreview(PendingPreview(setID: set.id, before: before)) else {
            ui.toast = Toast(message: "Couldn't start the preview: your desktop couldn't be saved first", symbol: "exclamationmark.triangle")
            return
        }
        ui.themePreview = ThemePreview(setID: set.id, before: before)
        replaceWidgets(on: target, with: themeWidgets(set, on: target))
        if setsWallpaper, let source = set.wallpaper { wallpaper.set(source) }
        settings.adopt(set)
        themeStats.record(.preview, for: set.id)
    }

    func endThemePreview(keep: Bool) {
        guard let preview = ui.themePreview else { return }
        ui.themePreview = nil
        if keep {
            // Undo goes back to the desktop from before the preview.
            if let set = ThemeLibrary.set(preview.setID) {
                recordChange(.theme(set.name), before: preview.before)
                themeStats.record(.install, for: set.id)
            }
            if !desktopJournal.keepPreview() {
                ui.toast = Toast(message: "Kept, but couldn't record that: the next launch may undo this theme",
                                 symbol: "exclamationmark.triangle")
            }
        } else {
            report(desktopJournal.restorePreview(settings: settings, widgets: widgets, wallpaper: wallpaper), atLaunch: false)
        }
    }

    /// A preview the app quit or crashed during: puts back the desktop from before it.
    /// Called at launch, before any window shows.
    func recoverInterruptedPreview() {
        report(desktopJournal.restorePreview(settings: settings, widgets: widgets, wallpaper: wallpaper), atLaunch: true)
    }

    private func report(_ outcome: PreviewRestore, atLaunch: Bool) {
        switch outcome {
        case .nothingPending, .wasKept:
            break
        case .restored(let setID):
            guard atLaunch else { return }
            let name = ThemeLibrary.set(setID)?.name ?? "A theme"
            ui.toast = Toast(message: "\(name) was only a preview: your desktop is back", symbol: "arrow.uturn.backward")
        case .notSaved:
            // The record stays, so the next launch restores and saves again.
            ui.toast = Toast(message: "Your desktop is back but couldn't be saved; it will be restored again next launch",
                             symbol: "exclamationmark.triangle")
        }
    }

    /// The desktop before the last whole-desktop change, kept on disk: what
    /// Restore Previous Desktop brings back, long after the Undo offer is gone.
    var previousDesktop: PreviousDesktop? { desktopJournal.previous }

    /// Brings back the desktop from before the last change. The desktop it replaces
    /// becomes the previous one, so doing it twice returns to where you were. The
    /// stored copy is replaced only once the restored desktop has been saved.
    func restorePreviousDesktop() {
        if ui.themePreview != nil { endThemePreview(keep: false) }
        guard let previous = desktopJournal.previous else { return }
        let current = desktopSnapshot
        previous.before.restore(settings: settings, widgets: widgets, wallpaper: wallpaper)
        guard widgets.saveNow(), wallpaper.saveNow() else {
            ui.toast = Toast(message: "Restored, but couldn't save it: the stored previous desktop is kept", symbol: "exclamationmark.triangle")
            return
        }
        ui.desktopUndo = nil
        if desktopJournal.remember(PreviousDesktop(change: "Restored the previous desktop", before: current)) {
            ui.toast = Toast(message: "Previous desktop restored", symbol: "arrow.uturn.backward")
        } else {
            ui.toast = Toast(message: "Previous desktop restored, but the one before it couldn't be kept to switch back to",
                             symbol: "exclamationmark.triangle")
        }
    }

    /// Offers Undo for a change and keeps the desktop from before it on disk. False
    /// (and a warning shown) if that copy couldn't be saved.
    @discardableResult
    private func recordChange(_ change: DesktopUndo.Change, before: DesktopSnapshot) -> Bool {
        ui.desktopUndo = DesktopUndo(change: change, before: before)
        let words = switch change {
        case .theme(let name): "\(name) went on"
        case .wallpaper: "New wallpaper"
        case .turnedOff(let name): "\(name) was turned off"
        }
        guard desktopJournal.remember(PreviousDesktop(change: words, before: before)) else {
            ui.toast = Toast(message: "Done, but a copy of the previous desktop couldn't be saved: Undo works only until you quit",
                             symbol: "exclamationmark.triangle")
            return false
        }
        return true
    }

    /// Puts back the desktop from before the last theme (widgets, size,
    /// font, corners, theme and wallpaper), or the previous wallpaper.
    func undoDesktopChange() {
        guard let undo = ui.desktopUndo else { return }
        // The undo reaches further back than any preview on top of it.
        ui.themePreview = nil
        undo.before.restore(settings: settings, widgets: widgets, wallpaper: wallpaper)
        let saved = widgets.saveNow() && wallpaper.saveNow()
        // A preview record under it is superseded by this desktop once it's saved.
        if saved { desktopJournal.endPreview() }
        ui.desktopUndo = nil
        if !saved {
            ui.toast = Toast(message: "Undone, but couldn't save it", symbol: "exclamationmark.triangle")
        }
    }

    /// Takes the current theme off the desktop: its widgets go and the widget
    /// look returns to a fresh install's. The wallpaper stays. Undo puts it all back.
    func turnOffTheme() {
        if ui.themePreview != nil { endThemePreview(keep: false) }
        let name = settings.activeThemeSet.flatMap { ThemeLibrary.set($0)?.name } ?? "The theme"
        let before = desktopSnapshot
        widgets.replaceAll(with: [])
        settings.resetWidgetLook()
        ui.isArrangingWidgets = false
        if recordChange(.turnedOff(name), before: before) {
            ui.toast = Toast(message: "\(name) is off", symbol: "power")
        }
    }

    /// A wallpaper the person picked. Only the wallpaper changes: the widgets and
    /// their look stay (clearing them is its own action, Turn Off on a theme).
    /// Undo, and Restore Previous Desktop later, put the old wallpaper back.
    func pickWallpaper(_ source: WallpaperSource) {
        if ui.themePreview != nil { endThemePreview(keep: false) }
        let before = desktopSnapshot
        wallpaper.set(source)
        ui.toast = Toast(message: "Wallpaper applied", symbol: "photo.artframe")
        guard wallpaper.config != before.wallpaper else { return }
        recordChange(.wallpaper, before: before)
    }

    private var desktopSnapshot: DesktopSnapshot {
        DesktopSnapshot(settings: settings, widgets: widgets, wallpaper: wallpaper)
    }

    /// A set's widgets with the person's photos, sized and centered to fill
    /// the chosen screen, whatever its size, and lined up on its grid.
    private func themeWidgets(_ set: ThemeSet, on screen: NSScreen?) -> [WidgetInstance] {
        let layout = set.widgets(screenName: screen?.localizedName, bounds: Self.unbounded).map { $0.placed(on: screen) }
        let personal = ThemeSet.personalized(layout, with: themePhotos.sources(for: set.id))
        let arranged = gridArranged(fittedToScreen(personal, on: screen))
        // Opened up to the screen's edges, so a wide display has no bare sides.
        return prepared(screen.map { widgetGrid(on: $0).spread(arranged) } ?? arranged)
    }

    /// The widgets on `screen` replaced by `new`; those on other displays stay.
    private func replaceWidgets(on screen: NSScreen?, with new: [WidgetInstance]) {
        guard let screen, NSScreen.screens.count > 1 else { return widgets.replaceAll(with: new) }
        widgets.replaceAll(with: widgets.widgets.filter { !shows($0, on: screen) } + new)
    }

    /// Where a theme's widgets go. One display needs no question; with a
    /// monitor connected, asks: this Mac or the monitor. Nil when cancelled.
    private func chooseThemeScreen(for set: ThemeSet) -> NSScreen? {
        let screens = NSScreen.screens.sorted { ($0.isBuiltIn ? 0 : 1) < ($1.isBuiltIn ? 0 : 1) }
        guard screens.count > 1 else { return screens.first }
        let alert = NSAlert()
        alert.messageText = "Where should \(set.name) go?"
        alert.informativeText = "A second display is connected. The theme's widgets go on the one you pick; the other keeps its own."
        for screen in screens { alert.addButton(withTitle: screen.isBuiltIn ? "On this Mac" : "On \(screen.localizedName)") }
        alert.addButton(withTitle: "Cancel")
        let index = alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        return screens.indices.contains(index) ? screens[index] : nil
    }

    /// Gives location-based widgets a city: one already used, else a guess
    /// from the Mac's time zone, so they don't arrive asking for one.
    private func prepared(_ instances: [WidgetInstance]) -> [WidgetInstance] {
        let city = widgets.widgets.lazy.compactMap(\.options.location).first ?? TimeZonePlace.guess()
        return instances.map { widget in
            var widget = widget
            if [.weather, .airQuality, .daylight].contains(widget.kind), widget.options.location == nil {
                widget.options.location = city
            }
            return widget
        }
    }
}

extension AppServices {
    /// Asks for photos, then puts the whole set on the desktop with them in
    /// every picture slot. Returns false when nothing was chosen.
    @discardableResult
    func installWithMyPhotos(_ set: ThemeSet, wallpaper setsWallpaper: Bool) async -> Bool {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.image, .folder]
        panel.prompt = "Use These"
        panel.message = "Choose photos for \(set.name). They fill every photo, tape and print in the theme."
        guard panel.runModal() == .OK else { return false }
        let names = await images.importImages(from: panel.urls)
        guard !names.isEmpty else { return false }
        themePhotos.set(names, for: set.id)
        install(set, mode: .replace, wallpaper: setsWallpaper)
        return true
    }
}
