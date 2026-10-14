import AllSetCore
import AppKit
import SwiftUI

/// Every page of the main window.
enum AppPage: Hashable {
    // Dynamic Island
    case island
    case activities
    // Widgets
    case favorites
    /// Whole-desktop looks.
    case themes
    /// One theme set's page.
    case themeSet(String)
    /// The widget gallery, for one category or (nil) all of them.
    case gallery(WidgetCategory?)
    /// Customizing a widget that's on the desktop.
    case widget(UUID)
    case widgetAppearance
    /// The widgets on the desktop now.
    case desktop
    // Wallpaper
    case wallpaper
    case wallpaperOptions
    // Workspace
    case snapping
    case workspaces
    // Tools
    case clipboard
    case shelf
    case mixer
    case knocks
    case notes
    case screenshot
    // System
    case monitor
    case lidPlane
    case general
    case about
}

/// The one window of the app, opened from the Dock, the menu bar, the notch
/// and the widgets.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()

    private var window: NSWindow?

    /// Closing lets the whole window go. Kept, a closed window's pages stay
    /// alive unseen: no `onDisappear` runs, so a page that asked for live
    /// system readings kept the monitor sampling every two seconds for the
    /// rest of the session, and every picture it had shown stayed in memory.
    /// The page on show is kept in `UIState`, so reopening lands on it again.
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === window else { return }
        closing.delegate = nil
        closing.contentViewController = nil
        window = nil
        // Theme previews and the pictures pages showed were only for this
        // window; desktop widgets keep the recent ones they use.
        services?.releaseCachedPictures(keeping: 0.25)
        CinemaArtwork.clear()
        LibraryPreviewCache.clear()
    }

    private weak var services: AppServices?

    /// No title or bar: the page runs to the top, the navigation floats
    /// beneath the window buttons, and each page names itself.
    static func dress(_ window: NSWindow) {
        window.title = "All Set"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(DS.Surface.canvasLift)
    }

    static func contentController(services: AppServices) -> NSViewController {
        let controller = NSViewController()
        let host = MainCanvasHostingView(rootView: MainView(services: services, ui: services.ui))
        // Adaptive grids must not drive the window's size on every layout pass.
        host.sizingOptions = []
        controller.view = host
        return controller
    }

    func show(services: AppServices) {
        self.services = services
        if window == nil {
            let controller = Self.contentController(services: services)
            let window = NSWindow(contentViewController: controller)
            Self.dress(window)
            window.isReleasedWhenClosed = false
            window.contentMinSize = NSSize(width: 900, height: 600)
            window.setContentSize(NSSize(width: 1120, height: 760))
            window.center()
            window.setFrameAutosaveName("AllSetMain")
            window.delegate = self
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

/// The canvas paints the entire window. Reporting that to AppKit avoids
/// rebuilding opaque descendant regions for every card while scrolling.
private final class MainCanvasHostingView: NSHostingView<MainView> {
    override var isOpaque: Bool { true }
}

struct MainView: View {
    let services: AppServices
    @Bindable var ui: UIState
    @State private var cinemaWindowVisible = true
    private var cinema: Bool {
        switch ui.page { case .gallery: true; default: false }
    }

    var body: some View {
        GeometryReader { viewport in
            // Keep the same design proportions, but give large windows readable
            // controls instead of spreading small text across a full screen.
            let scale = DS.Space.windowScale(for: viewport.size)
            content
                .frame(width: viewport.size.width / scale, height: viewport.size.height / scale)
                .scaleEffect(scale, anchor: .topLeading)
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    private var content: some View {
        GeometryReader { geometry in
            // A page swaps at once and eases in under a Core Animation veil
            // (`PageVeil`); the navigation stays put above it.
            ZStack {
                detail(ui.page ?? .island)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(ui.page)
            }
            // Navigation animates its selection, without animating the layout
            // of both the old and new page throughout the transition.
            .transaction(value: ui.page) { $0.animation = nil }
            .overlay(PageVeil(page: ui.page))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                if ui.page != .wallpaper { navigation(width: geometry.size.width) }
            }
            .overlay(alignment: .top) {
                if ui.page == .wallpaper { navigation(width: geometry.size.width) }
            }
            .overlay(alignment: .top) {
                if let toast = ui.toast {
                    ToastView(toast: toast, ui: ui).padding(.top, 64)
                }
            }
            .overlay {
                if ui.isSearching { SearchOverlay(services: services, ui: ui) }
            }
            .background {
                Button("Search") { withMotion(Motion.quick) { ui.isSearching.toggle() } }
                    .keyboardShortcut("k", modifiers: .command)
                    .opacity(0).accessibilityHidden(true)
            }
            .overlay(alignment: .bottom) {
                if let removed = ui.removedWidget {
                    RemovedWidgetBar(removed: removed, services: services)
                        .padding(.bottom, DS.Space.l)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background {
            if ui.page == .wallpaper { WallpaperAtmosphere(services: services) }
            else if cinema { StudioAtmosphere(services: services) }
            else { WindowBackdrop(paused: ui.performance.pausesDecorativeMotion) }
        }
        .ignoresSafeArea(.container, edges: .top)
        .environment(ui)
        .background { if cinema { CinemaWindowPresence(visible: $cinemaWindowVisible) } }
        .environment(\.widgetIsOnScreen, cinema ? cinemaWindowVisible : true)
        // The main window is always dark: the content (art, wallpapers,
        // themes) leads, and a dark canvas is what lets it. Desktop widgets
        // and the notch keep their own appearance.
        .preferredColorScheme(.dark)
    }

    private func navigation(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            CinemaNavigation(services: services)
            let problems = services.saveProblems
            if !problems.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                    Label(problems.map { "Couldn't save \($0.what): \($0.why)" }.joined(separator: "\n")
                            + "\nYour changes stay while All Set is open and are saved with the next change, or now with Try Again.",
                          systemImage: "exclamationmark.triangle.fill")
                        .dsText(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Try Again") { services.retrySaves() }
                }
                .padding(.horizontal, DS.Space.m)
                .padding(.vertical, DS.Space.xs)
                .background(RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous).fill(Color.orange.opacity(0.22)))
                .padding(.horizontal, DS.Space.pageMargin(for: width))
                .padding(.bottom, DS.Space.xs)
            }
            if services.widgets.unreadableCount > 0 {
                Label("\(services.widgets.unreadableCount) saved widget(s) can't be shown by this version. They're kept and will return in a version that knows them.",
                      systemImage: "exclamationmark.triangle.fill")
                    .dsText(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.Space.m)
                    .padding(.vertical, DS.Space.xs)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous).fill(Color.orange.opacity(0.22)))
                    .padding(.horizontal, DS.Space.pageMargin(for: width))
                    .padding(.bottom, DS.Space.xs)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    @ViewBuilder
    private func detail(_ page: AppPage) -> some View {
        switch page {
        case .island:
            IslandPage(services: services)
        case .activities:
            FormPage(eyebrow: "Island", title: "Live Activities", subtitle: "What the notch shows around itself while things happen.") {
                ActivitySettings(settings: services.settings, media: services.media)
            }
        case .favorites:
            FavoritesPage(services: services)
        case .themes:
            ThemesPage(services: services)
        case .themeSet(let id):
            ThemeDetailPage(setID: id, services: services)
                .id(id)
        case .gallery(let category):
            GalleryPage(category: category, services: services)
        case .widget(let id):
            WidgetInspector(id: id, services: services)
        case .widgetAppearance:
            FormPage(eyebrow: "Desktop", title: "Look & Layout", subtitle: "How every widget looks and lines up, all at once.") {
                WidgetSettings(settings: services.settings, services: services)
            }
        case .desktop:
            DesktopWidgetsPage(services: services)
        case .wallpaper:
            ClassicWallpaperPage(services: services)
        case .wallpaperOptions:
            WallpaperOptionsPage(services: services)
        case .snapping:
            WindowSnappingPage(services: services)
        case .workspaces:
            WorkspacesPage(services: services)
        case .clipboard:
            ClipboardPage(services: services)
        case .shelf:
            ShelfPage(services: services)
        case .mixer:
            SoundMixerPage(services: services)
        case .knocks:
            KnockPage(services: services)
        case .notes:
            NotesPage(notes: services.notes)
        case .screenshot:
            ScreenshotPage(services: services)
        case .monitor:
            MonitorPage(services: services)
        case .lidPlane:
            LidPlanePage(services: services)
        case .general:
            FormPage(eyebrow: "System", title: "General", subtitle: "Startup, the Dock, the menu bar, and your data.") {
                GeneralSettings(settings: services.settings)
                DataPrivacySettings(services: services)
            }
        case .about:
            FormPage(eyebrow: "System", title: "About") { AboutSettings() }
        }
    }
}

/// "Removed Clock. Undo" for a few seconds after a widget leaves the desktop:
/// a floating capsule at the bottom of the window.
private struct RemovedWidgetBar: View {
    let removed: RemovedWidget
    let services: AppServices

    var body: some View {
        GlassPanel(cornerRadius: 22, padding: 0) {
            HStack(spacing: DS.Space.s) {
                Image(systemName: removed.instance.kind.symbol).foregroundStyle(DS.Ink.secondary)
                Text("Removed \(removed.instance.kind.title) from the desktop.").dsText(.body)
                Button("Undo") { withMotion(Motion.quick) { services.undoRemoveWidget() } }
                    .buttonStyle(.pillProminent)
            }
            .padding(.leading, DS.Space.m)
            .padding(.trailing, DS.Space.xxs + 1)
            .frame(height: 44)
        }
        .dsElevated()
        .task(id: removed.id) {
            try? await Task.sleep(for: .seconds(8))
            if services.ui.removedWidget?.id == removed.id {
                withMotion(Motion.quick) { services.ui.removedWidget = nil }
            }
        }
    }
}

/// A settings page: its header and any lead content (a preview, a stage) on
/// the canvas, then grouped form sections.
struct FormPage<Lead: View, Content: View>: View {
    var eyebrow: String?
    var title: String?
    var subtitle: String?
    @ViewBuilder var lead: Lead
    @ViewBuilder var content: Content

    var body: some View {
        Form {
            if title != nil || Lead.self != EmptyView.self {
                // A section of nothing but a header: grouped forms draw headers
                // on the canvas, outside the rounded boxes.
                Section {
                } header: {
                    VStack(alignment: .leading, spacing: DS.Space.l) {
                        if let title { PageHeader(eyebrow: eyebrow, title: title, subtitle: subtitle) }
                        lead
                    }
                    .textCase(nil)
                    .padding(.bottom, DS.Space.m)
                }
            }
            content
        }
        .dsFormStyle()
    }
}

extension FormPage where Lead == EmptyView {
    init(eyebrow: String? = nil, title: String? = nil, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle, lead: { EmptyView() }, content: content)
    }
}
