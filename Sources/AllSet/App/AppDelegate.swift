import AllSetCore
import AppKit
import MetalKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// A restore chosen before the last quit is swapped in first, so every
    /// store the services create reads the restored files.
    let services: AppServices = {
        AppData.applyStagedRestore()
        return AppServices()
    }()
    private var notch: NotchController?
    private var widgets: DesktopWidgetController?
    private var wallpaper: WallpaperController?
    private var windowManager: WindowManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Writing to the media helper after it exits should fail with an error
        // instead of killing the app.
        signal(SIGPIPE, SIG_IGN)
        // Room for photo thumbnails, so scrolling back doesn't download them again.
        URLCache.shared = URLCache(memoryCapacity: 64 << 20, diskCapacity: 512 << 20)
        // Ready before the first moving widget or wallpaper needs it.
        #if DEBUG
        // `-noGPUArt YES` keeps drawing art with SwiftUI, for comparing.
        if !UserDefaults.standard.bool(forKey: "noGPUArt") { ArtGPU.prepare() }
        #else
        ArtGPU.prepare()
        #endif

        #if DEBUG
        // `AllSet -renderWidgets /folder` draws every widget to PNGs and quits,
        // without showing anything: for checking designs. `-renderDrift /folder`
        // draws moments of a drifting mesh background.
        if let folder = UserDefaults.standard.string(forKey: "renderWidgets") {
            NSApp.setActivationPolicy(.prohibited)
            Task {
                await WidgetRenderHarness.render(to: URL(fileURLWithPath: folder), services: services)
                exit(0)
            }
            return
        }
        // `-renderDesign /folder`: every design theme in light and dark, and
        // every catalog entry, captured from real (hidden) windows.
        if let folder = UserDefaults.standard.string(forKey: "renderDesign") {
            NSApp.setActivationPolicy(.accessory)
            services.calendar.start()
            Task {
                await WidgetRenderHarness.renderDesignThemes(to: URL(fileURLWithPath: folder), services: services)
                exit(0)
            }
            return
        }
        // `-renderEntries /folder -entryCategories football,music`: those gallery
        // entries, live from hidden windows and as still snapshots.
        if let folder = UserDefaults.standard.string(forKey: "renderEntries") {
            NSApp.setActivationPolicy(.accessory)
            let names = (UserDefaults.standard.string(forKey: "entryCategories") ?? "football,music").split(separator: ",")
            Task {
                try? ArtGPU.compileNow()
                await WidgetRenderHarness.renderEntries(to: URL(fileURLWithPath: folder), services: services,
                                                        categories: names.compactMap { WidgetCategory(rawValue: String($0)) })
                exit(0)
            }
            return
        }
        if let folder = UserDefaults.standard.string(forKey: "renderWallpaperLibrary") {
            NSApp.setActivationPolicy(.accessory)
            Task {
                await WidgetRenderHarness.renderWallpaperLibrary(to: URL(fileURLWithPath: folder), services: services)
                exit(0)
            }
            return
        }
        // `-renderLidPlane /folder`: the effect on generated artwork, and the renderer's own checks.
        if let folder = UserDefaults.standard.string(forKey: "renderLidPlane") {
            NSApp.setActivationPolicy(.accessory)
            do {
                guard let gpu = MTLCreateSystemDefaultDevice() else { print("Metal unavailable"); exit(1) }
                let renderer = try LidPlaneRenderer(gpu: gpu)
                let directory = URL(fileURLWithPath: folder)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                func save(_ image: CGImage, _ name: String) {
                    try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent(name))
                }
                renderer.perspective = false
                save(try renderer.preview(to: nil, angle: 0), "open.png")
                save(try renderer.preview(to: nil, angle: 35 * .pi / 180), "folded.png")
                renderer.perspective = true
                save(try renderer.preview(to: nil, angle: 35 * .pi / 180), "perspective.png")
                try LidPlaneRenderChecks.run(renderer)
                let started = CACurrentMediaTime()
                for degrees in stride(from: 0.0, through: 60, by: 6) { _ = try renderer.preview(to: nil, angle: Float(degrees * .pi / 180)) }
                print(String(format: "preview: %.1f ms each (11 renders)", (CACurrentMediaTime() - started) * 1000 / 11))
                print(String(format: "live frame, 2560x1600 GPU: %.2f ms", renderer.frameCost(width: 2560, height: 1600, angle: 0.6)))
                func timed(_ label: String, _ count: Int = 1, _ work: () throws -> Void) rethrows {
                    let start = CACurrentMediaTime()
                    for _ in 0..<count { try work() }
                    print(String(format: "%@: %.2f ms", label, (CACurrentMediaTime() - start) * 1000 / Double(count)))
                }
                try timed("new renderer") { _ = try LidPlaneRenderer(gpu: gpu) }
                var sensor: LidSensor?
                timed("sensor connect") { sensor = LidSensor() }
                timed("sensor read", 100) { _ = sensor?.read() }
                print("sensor:", LidSensor().diagnostic, "screen access:", CGPreflightScreenCaptureAccess())
            } catch { print(error); exit(1) }
            exit(0)
        }
        if let folder = UserDefaults.standard.string(forKey: "renderPhotos") {
            NSApp.setActivationPolicy(.accessory)
            Task {
                await WidgetRenderHarness.renderPhotos(to: URL(fileURLWithPath: folder), services: services)
                exit(0)
            }
            return
        }
        if let folder = UserDefaults.standard.string(forKey: "renderIsland") {
            NSApp.setActivationPolicy(.accessory)
            services.monitor.start()
            Task {
                await WidgetRenderHarness.renderIsland(to: URL(fileURLWithPath: folder), services: services)
                exit(0)
            }
            return
        }
        if let folder = UserDefaults.standard.string(forKey: "renderScaling") {
            NSApp.setActivationPolicy(.accessory)
            Task {
                await WidgetRenderHarness.renderScaling(to: URL(fileURLWithPath: folder), services: services)
                exit(0)
            }
            return
        }
        if let folder = UserDefaults.standard.string(forKey: "renderThemeSets") {
            NSApp.setActivationPolicy(.accessory)
            Task {
                await WidgetRenderHarness.renderThemeSets(to: URL(fileURLWithPath: folder), services: services)
                exit(0)
            }
            return
        }
        // `-renderThemeCards /folder`: the Themes carousel's cards, side by side (see the harness).
        if let folder = UserDefaults.standard.string(forKey: "renderThemeCards") {
            NSApp.setActivationPolicy(.accessory)
            services.start()
            Task {
                await WidgetRenderHarness.renderThemeCards(to: URL(fileURLWithPath: folder), services: services)
                exit(0)
            }
            return
        }
        // `-renderPages /folder`: every main-window page at three sizes (see the harness).
        if let folder = UserDefaults.standard.string(forKey: "renderPages") {
            NSApp.setActivationPolicy(.accessory)
            services.start()
            Task {
                let missing = await WidgetRenderHarness.renderPages(to: URL(fileURLWithPath: folder), services: services)
                exit(missing.isEmpty ? 0 : 1)
            }
            return
        }
        if let folder = UserDefaults.standard.string(forKey: "renderGPUArt") {
            NSApp.setActivationPolicy(.accessory)
            Task {
                await WidgetRenderHarness.renderGPUArt(to: URL(fileURLWithPath: folder))
                exit(0)
            }
            return
        }
        if let folder = UserDefaults.standard.string(forKey: "renderDrift") {
            NSApp.setActivationPolicy(.accessory)
            Task {
                await WidgetRenderHarness.renderDrift(to: URL(fileURLWithPath: folder))
                exit(0)
            }
            return
        }
        // `AllSet -probe pages|widgets|wallpapers|island` prints how much CPU
        // each page or view uses while idle, in a nearly invisible window.
        if let probe = UserDefaults.standard.string(forKey: "probe") {
            NSApp.setActivationPolicy(.accessory)
            services.monitor.start()
            services.media.start()
            services.volume.start()
            services.power.start()
            Task {
                switch probe {
                case "widgets": await PageCPUProbe.runWidgets(services: services)
                case "fans": await PageCPUProbe.runFans(services: services)
                case "mystic": await PageCPUProbe.runMystic(services: services)
                case "neon": await PageCPUProbe.runNeon(services: services)
                case "wallpaperlibrary":
                    // The real wallpaper windows, so pausing rules are the app's own.
                    let wallpaper = WallpaperController(services: services)
                    wallpaper.start()
                    await PageCPUProbe.runWallpaperLibrary(services: services)
                    withExtendedLifetime(wallpaper) {}
                case "covered": await PageCPUProbe.runCovered(services: services)
                case "desktopwidgets": await PageCPUProbe.runDesktopWidgets(services: services)
                case "windowclose": await PageCPUProbe.runWindowClose(services: services)
                case "windowserver": await PageCPUProbe.runWindowServer(services: services)
                case "reveal": await PageCPUProbe.runReveal(services: services)
                case "islandmotion": await PageCPUProbe.runIslandMotion(services: services)
                case "systembuild": await SystemTab.buildTimes(services: services)
                case "search": await PageCPUProbe.runSearch(services: services)
                case "resize":
                    let widgets = DesktopWidgetController(services: services)
                    widgets.start()
                    await WidgetRenderHarness.runResize(controller: widgets, services: services,
                        to: URL(fileURLWithPath: UserDefaults.standard.string(forKey: "resizeOut") ?? NSTemporaryDirectory()))
                case "apply":
                    let widgets = DesktopWidgetController(services: services)
                    widgets.start()
                    await PageCPUProbe.runApply(services: services)
                    withExtendedLifetime(widgets) {}
                case "gallery": await PageCPUProbe.run(pages: WidgetCategory.allCases.map { ("gallery \($0.rawValue)", .gallery($0)) }, services: services)
                case "wallpapers": await PageCPUProbe.runWallpapers(services: services)
                case "island": await PageCPUProbe.runIslandViews(services: services)
                case "scroll": await PageCPUProbe.runScroll(services: services)
                case "pageswitch": await PageCPUProbe.runPageSwitch(services: services)
                case "carousel": await PageCPUProbe.runCarousel(services: services)
                case "galleryparts": await PageCPUProbe.runGalleryParts(services: services)
                default:
                    await PageCPUProbe.run(pages: [("blank", .about), ("island", .island), ("activities", .activities),
                                                   ("gallery", .gallery(nil)), ("themes", .themes), ("wallpaper", .wallpaper), ("mixer", .mixer),
                                                   ("monitor", .monitor), ("knocks", .knocks), ("clipboard", .clipboard),
                                                   ("notes", .notes), ("general", .general)], services: services)
                }
                exit(0)
            }
            return
        }
        #endif

        applyDockVisibility()
        AllSet.observe({ [services] in services.settings.showInDock }) { [weak self] _ in self?.applyDockVisibility() }

        #if DEBUG
        // `AllSet -skip notch,wallpaper,widgets,window` leaves those out, for
        // measuring what each costs the system.
        let skipped = Set((UserDefaults.standard.string(forKey: "skip") ?? "").split(separator: ",").map(String.init))
        #else
        let skipped: Set<String> = []
        #endif

        services.start()
        if !skipped.contains("notch") {
            let notch = NotchController(services: services)
            notch.start()
            self.notch = notch
            services.notch = notch
        }

        if !skipped.contains("wallpaper") {
            let wallpaper = WallpaperController(services: services)
            wallpaper.start()
            self.wallpaper = wallpaper
        }

        if !skipped.contains("widgets") {
            let widgets = DesktopWidgetController(services: services)
            widgets.start()
            self.widgets = widgets
        }

        let windowManager = WindowManager(services: services)
        windowManager.start()
        self.windowManager = windowManager
        services.windowManager = windowManager
        services.clipboardMonitor.start()

        #if DEBUG
        // `AllSet -arrangeWidgets YES` starts in arrange mode, with widgets above windows.
        if UserDefaults.standard.bool(forKey: "arrangeWidgets") {
            services.ui.isArrangingWidgets = true
        }
        // `AllSet -openPage themes|gallery|art|widget|monitor` opens the window on that page.
        if let page = UserDefaults.standard.string(forKey: "openPage") {
            switch page {
            case "art": services.openWindow(.wallpaper)
            case "widget": services.openWindow(services.widgets.widgets.first.map { .widget($0.id) })
            case "monitor": services.openWindow(.monitor)
            case "wallpaper": services.openWindow(.wallpaper)
            case "workspaces": services.openWindow(.workspaces)
            case "snapping": services.openWindow(.snapping)
            case "clipboard": services.openWindow(.clipboard)
            case "mixer": services.openWindow(.mixer)
            case "knocks": services.openWindow(.knocks)
            case "notes": services.openWindow(.notes)
            case "gallery": services.openWindow(.gallery(nil))
            case "themes": services.openWindow(.themes)
            default: services.openWindow(.island)
            }
            return
        }
        #endif

        // As a Dock app, launching should show something.
        if services.settings.showInDock, !skipped.contains("window") {
            services.openWindow()
        }
        // If a restore was waiting, say how it went, once everything is up.
        AppData.presentLaunchRestoreOutcome()
    }

    /// A Dock icon and app menu, or menu-bar-only.
    private func applyDockVisibility() {
        let policy: NSApplication.ActivationPolicy = services.settings.showInDock ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        if policy == .regular { NSApp.activate() }
    }

    /// Clicking the Dock icon (or opening the app again) brings up the window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        services.openWindow()
        return false
    }

    /// Closing the window leaves the island and widgets running.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        services.stop()
    }

    /// `allset://` links from Shortcuts, scripts, the browser or other apps.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let link = DeepLink(url) else { continue }
            services.handle(link)
        }
    }
}
