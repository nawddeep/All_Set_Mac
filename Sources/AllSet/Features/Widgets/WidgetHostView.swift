import AllSetCore
import AppKit
import SwiftUI

extension EnvironmentValues {
    /// Highlight color for the widget's content: the user's tint on neutral
    /// backgrounds, white on a tinted one, the art's own accent on art.
    @Entry var widgetAccent: Color = .accentColor
    /// Previews blur their own window's content instead of the desktop behind it.
    @Entry var widgetIsPreview = false
    /// Shows time-of-day widgets at this moment instead of now, for previews.
    @Entry var widgetDate: Date?
    /// Theme previews draw in the theme's font and corners, not the current ones.
    @Entry var widgetFontOverride: WidgetFont?
    @Entry var widgetCornerOverride: Double?
    /// What right-clicking a desktop widget offers; nil in previews.
    @Entry var widgetMenu: WidgetMenuActions?
}

/// A desktop widget's right-click menu actions.
struct WidgetMenuActions {
    let sizes: [WidgetSize]
    let size: WidgetSize
    /// Drawn larger or smaller than its size, from dragging its corner.
    let isResized: Bool
    let isExtraSmall: Bool
    let isArranging: Bool
    let edit: @MainActor () -> Void
    let resize: @MainActor (WidgetSize) -> Void
    let extraSmall: @MainActor () -> Void
    let resetScale: @MainActor () -> Void
    let cleanUp: @MainActor () -> Void
    let toggleArranging: @MainActor () -> Void
    let remove: @MainActor () -> Void
}

/// The widget's own right-click items. Widgets with menus of their own add
/// these after a divider, so Remove is always one right-click away.
struct WidgetMenuItems: View {
    @Environment(\.widgetMenu) private var actions

    var body: some View {
        if let actions {
            Button("Edit Widget…", action: actions.edit)
            if actions.sizes.count > 1 || actions.sizes.contains(.small) {
                let hasExtraSmall = actions.sizes.contains(.small)
                Picker("Size", selection: Binding(
                    get: { actions.isExtraSmall ? "xs" : actions.size.rawValue },
                    set: { choice in
                        if choice == "xs" { actions.extraSmall() } else if let size = WidgetSize(rawValue: choice) { actions.resize(size) }
                    }
                )) {
                    if hasExtraSmall { Text("Extra Small").tag("xs") }
                    ForEach(actions.sizes) { size in
                        Text(size.title).tag(size.rawValue)
                    }
                }
            }
            if actions.isResized {
                Button("Reset to \(actions.size.title) Size", action: actions.resetScale)
            }
            Divider()
            Button("Clean Up Widgets", action: actions.cleanUp)
            Button(actions.isArranging ? "Done Arranging" : "Arrange Widgets", action: actions.toggleArranging)
            Divider()
            Button("Remove Widget", role: .destructive, action: actions.remove)
        }
    }
}

extension Color {
    init(_ color: WidgetColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue)
    }
}

extension WidgetColor {
    init?(_ color: Color) {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        self.init(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
    }
}

extension WidgetFont {
    var design: Font.Design {
        switch self {
        case .standard, .condensed, .expanded: .default
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }

    var width: Font.Width {
        switch self {
        case .condensed: .condensed
        case .expanded: .expanded
        default: .standard
        }
    }
}

extension WidgetInstance {
    /// The design theme that draws it, if any: kinds with their own backgrounds ignore themes.
    var designTheme: DesignTheme? {
        guard !kind.isFreeform, !kind.paintsOwnBackground else { return nil }
        return DesignTheme.named(options.designTheme)
    }

    /// Sits on a card with an edge and a shadow; false for freeform kinds and "No Card".
    var hasCard: Bool { !kind.isFreeform && (designTheme != nil || material != .clear || kind == .note) }
}

/// A shadow in the widget's theme: soft, none, a hard offset block, or the
/// two-sided light of neumorphism.
private struct ThemedShadow: ViewModifier {
    let instance: WidgetInstance
    let isDragging: Bool
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        let lift = isDragging ? 1.6 : 1.0
        if let theme = instance.designTheme {
            let isDark = theme.isDark(instance.options.appearance, systemIsDark: systemScheme == .dark)
            switch theme.shadow {
            case .none:
                content.shadow(color: .black.opacity(isDragging ? 0.3 : 0), radius: 10, y: 6)
            case .hard(let offset):
                let palette = theme.palette(dark: isDark)
                content.shadow(color: isDark ? Color(palette.accent) : .black, radius: 0, x: offset * lift, y: offset * lift)
            case .neumorphic:
                content
                    .shadow(color: .black.opacity(isDark ? 0.5 : 0.18), radius: 8, x: 5, y: 5)
                    .shadow(color: .white.opacity(isDark ? 0.05 : 0.6), radius: 8, x: -4, y: -4)
            case .soft:
                content.shadow(color: .black.opacity(isDragging ? 0.35 : 0.18), radius: isDragging ? 12 : 7, y: isDragging ? 7 : 3)
            }
        } else {
            content.shadow(color: .black.opacity(!instance.hasCard ? 0 : isDragging ? 0.35 : 0.2),
                           radius: isDragging ? 12 : 6, y: isDragging ? 7 : 2)
        }
    }
}

/// Everything inside one widget window: the widget, its background, and the
/// arrange-mode outline, drag handling and buttons.
struct WidgetHostView: View {
    let id: UUID
    let services: AppServices
    /// Whether this widget's window is covered.
    var window = WidgetWindowState()
    let onDrag: @MainActor (WidgetDragPhase) -> Void
    var onResize: @MainActor (WidgetDragPhase) -> Void = { _ in }
    let onRemove: @MainActor () -> Void
    let onConfigure: @MainActor () -> Void

    @State private var isDragging = false

    var body: some View {
        if var instance = services.widgets.instance(id) {
            // While its corner is dragged, the layout the drag has reached.
            let _ = window.liveSize.map { instance.size = $0 }
            let ownScale = window.liveScale ?? instance.scale
            let cinematic = instance.options.cinematicClock || instance.options.cinematicStyle
            let contentStretch = window.liveStretch ?? instance.stretch
            let ownStretch = cinematic ? 1 : contentStretch
            let arranging = services.ui.isArrangingWidgets
            let radius = instance.designTheme?.cornerRadius ?? instance.options.cornerRadius ?? services.settings.widgetCornerRadius
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

            WidgetBody(instance: instance, services: services, onConfigure: onConfigure)
            .frame(width: cinematic ? instance.size.dimensions.width : nil,
                   height: cinematic ? instance.size.dimensions.height * contentStretch : nil)
            // Covered widgets, and all of them in Low Power Mode or with Reduce
            // Motion on, hold still.
            .environment(\.widgetIsVisible, !window.isOccluded && !services.ui.performance.pausesDecorativeMotion)
            // Data keeps coming while they can be seen, whatever the motion setting.
            .environment(\.widgetIsOnScreen, !window.isOccluded)
            // Slow, drifting art looks the same at fewer frames; fewer still on battery.
            .environment(\.artFrameLimit, services.ui.performance.artFrameRate)
            .environment(\.widgetRefreshScale, services.ui.performance.networkRefreshScale)
            // Drag a widget straight from the desktop; it settles into the
            // nearest free slot. Clicks still reach its buttons.
            .simultaneousGesture(moveGesture, including: arranging ? .subviews : .all)
            .overlay {
                if arranging {
                    // Covers the widget so its controls don't react while arranging.
                    shape
                        .strokeBorder(.white.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .background(shape.fill(Color.white.opacity(0.001)))
                        .contentShape(shape)
                        .gesture(moveGesture)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .topLeading) {
                if arranging {
                    ArrangeBadge(symbol: "minus", color: .red, help: "Remove", action: onRemove)
                        .offset(x: -9, y: -9)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .overlay(alignment: .topTrailing) {
                if arranging {
                    ArrangeBadge(symbol: "slider.horizontal.3", color: Color(white: 0.35), help: "Options", action: onConfigure)
                        .offset(x: 9, y: -9)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // Every widget, theme or not: hover its corner (or arrange) and drag.
                if window.cornerHovered || window.isResizing || arranging {
                    ResizeHandle(isActive: window.isResizing, onResize: resize)
                        // The same size on screen whatever the widget's own scale.
                        .scaleEffect(x: 1 / ownScale, y: 1 / (ownScale * ownStretch))
                        .offset(x: 9, y: 9)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .scaleEffect(isDragging ? 1.03 : 1)
            // Freeform widgets cast their own shadows.
            .modifier(ThemedShadow(instance: instance, isDragging: isDragging))
            .contextMenu { WidgetMenuItems() }
            .environment(\.widgetMenu, menuActions(for: instance, arranging: arranging))
            .motion(Motion.responsive, value: isDragging)
            .motion(Motion.quick, value: arranging)
            .motion(Motion.quick, value: window.cornerHovered)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { _ in
                // The corner handle is resizing it, not moving it.
                guard !window.isResizing else { return }
                if !isDragging { isDragging = true }
                onDrag(.changed)
            }
            .onEnded { _ in
                guard isDragging else { return }
                isDragging = false
                onDrag(.ended)
            }
    }

    private func resize(_ phase: WidgetDragPhase) {
        switch phase {
        case .changed:
            if !window.isResizing { window.isResizing = true }
            onResize(.changed)
        case .ended:
            onResize(.ended)
            window.isResizing = false
        }
    }

    private func menuActions(for instance: WidgetInstance, arranging: Bool) -> WidgetMenuActions {
        WidgetMenuActions(
            sizes: instance.kind.supportedSizes,
            size: instance.size,
            isResized: instance.scale != 1 || instance.stretch != 1,
            isExtraSmall: instance.isExtraSmall,
            isArranging: arranging,
            edit: onConfigure,
            resize: { [services, id] size in withMotion(Motion.responsive) { services.resizeWidget(id, to: size) } },
            extraSmall: { [services, id] in
                withMotion(Motion.responsive) { services.resizeWidget(id, to: WidgetResize.Result(size: .small, scale: WidgetResize.extraSmallScale)) }
            },
            resetScale: { [services, id] in
                guard let size = services.widgets.instance(id)?.size else { return }
                services.resizeWidget(id, to: WidgetResize.Result(size: size, scale: 1))
            },
            cleanUp: { [services] in services.cleanUpWidgets() },
            toggleArranging: { [services] in services.ui.isArrangingWidgets.toggle() },
            remove: onRemove
        )
    }
}

/// A widget at its real size, with its background and fonts: used on the
/// desktop and, scaled down, for previews in Widget Studio.
struct WidgetBody: View {
    let instance: WidgetInstance
    let services: AppServices
    var onConfigure: @MainActor () -> Void = {}
    @Environment(\.widgetFontOverride) private var fontOverride
    @Environment(\.widgetCornerOverride) private var cornerOverride
    @Environment(\.widgetIsPreview) private var isPreview
    /// The Mac's appearance (nothing above has overridden it yet).
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        Group {
            if instance.kind == .clock, instance.options.cinematicClock {
                ClockWidget(instance: instance)
                    .onTapGesture { if !isPreview { services.openWindow(.widget(instance.id)) } }
            } else if instance.options.cinematicStyle, CinematicWidgetFace.supports(instance.kind) {
                CinematicWidgetFace(instance: instance, services: services)
            } else if let theme = instance.designTheme {
                themed(theme)
            } else {
                classic
            }
        }
        .textCase(instance.options.textCase.swiftUI)
        .environment(\.widgetRenames, instance.options.renamedText)
        // In the margin under the card, so it never takes a slot of its own.
        .overlay(alignment: Alignment(horizontal: instance.options.footnoteStyle.alignment.swiftUI, vertical: .bottom)) {
            let footnote = instance.options.footnote.trimmingCharacters(in: .whitespacesAndNewlines)
            if !footnote.isEmpty {
                WidgetFootnote(text: footnote, style: instance.options.footnoteStyle)
                    .frame(maxWidth: instance.size.dimensions.width, alignment: Alignment(horizontal: instance.options.footnoteStyle.alignment.swiftUI, vertical: .top))
                    .offset(y: instance.options.footnoteStyle.size.points + 3)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Drawn by a design theme: its card, colors, type and corners.
    private func themed(_ theme: DesignTheme) -> some View {
        let isDark = theme.isDark(instance.options.appearance, systemIsDark: systemScheme == .dark)
        let palette = theme.palette(dark: isDark)
        let accent = services.themes.accent(for: theme, palette: palette, isDark: isDark, override: instance.options.accent,
                                            mode: instance.options.accentMode)
        return DesignSurface(theme: theme, palette: palette, isDark: isDark, accent: accent, transparency: instance.options.transparency) {
            WidgetContent(instance: instance, services: services, onConfigure: onConfigure)
        }
        .frame(width: instance.size.dimensions.width, height: instance.size.dimensions.height)
        .fontDesign((instance.options.font ?? theme.typography.font).design)
        .fontWidth((instance.options.font ?? theme.typography.font).width)
        .environment(\.widgetStyle, .themed(theme, palette: palette, isDark: isDark, accent: accent))
        .environment(\.widgetAccent, accent)
    }

    private var classic: some View {
        let radius = instance.options.cornerRadius ?? cornerOverride ?? services.settings.widgetCornerRadius
        let font = instance.options.font ?? fontOverride ?? services.settings.widgetFont
        let accent = Self.accent(for: instance)
        return WidgetSurface(instance: instance, cornerRadius: radius, library: services.images) {
            WidgetContent(instance: instance, services: services, onConfigure: onConfigure)
        }
        .frame(width: instance.size.dimensions.width, height: instance.size.dimensions.height)
        // Whatever a widget draws, nothing gets past its rounded edge.
        .clipShape(RoundedRectangle(cornerRadius: instance.kind.isFreeform ? 0 : radius, style: .continuous)
                   .inset(by: instance.kind.isFreeform ? -WidgetWindow.margin : 0))
        .fontDesign(font.design)
        .fontWidth(font.width)
        .environment(\.widgetAccent, accent)
        .environment(\.widgetStyle, .classic(font: font, accent: accent, cornerRadius: radius))
    }

    static func accent(for instance: WidgetInstance) -> Color {
        if let accent = instance.options.accent { return Color(accent) }
        switch instance.material {
        case .tinted, .photo:
            return .white
        case .mesh:
            return Color(instance.options.art.palette.colors[instance.options.art.palette.isLight ? 2 : 4])
        case .art:
            let palette = instance.options.art.palette
            return Color(palette.colors[palette.isLight ? 2 : 4])
        default:
            return Color(instance.tint)
        }
    }
}

/// A widget scaled to fit `fit`, not interactive. For galleries and inspectors.
struct WidgetPreview: View {
    let instance: WidgetInstance
    let services: AppServices
    let fit: CGSize

    var body: some View {
        let size = instance.size.dimensions
        let scale = min(1, fit.width / size.width, fit.height / size.height)
        WidgetBody(instance: instance, services: services)
            .environment(\.widgetIsPreview, true)
            .allowsHitTesting(false)
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            .scaleEffect(scale)
            .frame(width: size.width * scale, height: size.height * scale)
    }
}

private struct ArrangeBadge: View {
    let symbol: String
    let color: Color
    let help: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(color))
                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// The arrow in a widget's bottom-right corner: drag it and the widget grows
/// or shrinks from its top-left, live.
private struct ResizeHandle: View {
    let isActive: Bool
    let onResize: @MainActor (WidgetDragPhase) -> Void

    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Circle().fill(Color(white: isActive ? 0.12 : 0.3)))
            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            .scaleEffect(isActive ? 1.15 : 1)
            .motion(Motion.quick, value: isActive)
            // More to grab than the badge itself.
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
            .gesture(
                // Global, since the widget's own frame moves under the pointer.
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { _ in onResize(.changed) }
                    .onEnded { _ in onResize(.ended) }
            )
            .modifier(ResizeCursor())
            .help("Drag to resize")
    }
}

/// The diagonal resize pointer, where macOS offers one.
private struct ResizeCursor: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.pointerStyle(.frameResize(position: .bottomTrailing))
        } else {
            content
        }
    }
}

/// Picks the view for the widget's kind, and what a click on it opens:
/// system widgets open the Monitor, clocks their settings. Buttons inside a
/// widget keep their own clicks.
struct WidgetContent: View {
    let instance: WidgetInstance
    let services: AppServices
    let onConfigure: @MainActor () -> Void
    @Environment(\.widgetIsPreview) private var isPreview
    @Environment(\.widgetIsVisible) private var isVisible

    /// Live stats on the desktop and under the pointer; elsewhere in the app
    /// (a gallery of previews) the calm copy, which changes every few seconds.
    private var readings: any SystemReadings {
        isPreview && !isVisible ? services.monitor.calm : services.monitor
    }

    var body: some View {
        if !isPreview, let page = Self.clickPage(for: instance) {
            kindView
                .contentShape(Rectangle())
                .onTapGesture { services.openWindow(page) }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens \(page == .monitor ? "the Monitor" : "its settings")")
        } else {
            kindView
        }
    }

    private static func clickPage(for instance: WidgetInstance) -> AppPage? {
        switch instance.kind {
        case .system, .metric, .battery, .terminal: .monitor
        case .clock: .widget(instance.id)
        default: nil
        }
    }

    @ViewBuilder
    private var kindView: some View {
        switch instance.kind {
        case .clock:
            ClockWidget(instance: instance)
        case .calendar:
            CalendarWidget(instance: instance, calendar: services.calendar)
        case .weather:
            WeatherWidget(instance: instance, weather: services.weather,
                          unit: services.settings.temperatureUnit, onConfigure: onConfigure)
        case .system:
            SystemWidget(size: instance.size, monitor: readings, unit: services.settings.temperatureUnit)
        case .battery:
            BatteryWidget(size: instance.size, monitor: readings, unit: services.settings.temperatureUnit)
        case .nowPlaying:
            NowPlayingWidget(size: instance.size, media: services.media, palette: instance.options.art.palette)
        case .note:
            NoteWidget(instance: instance, store: services.widgets)
        case .photo:
            PhotoWidget(instance: instance, library: services.images)
        case .ambient:
            AmbientWidget(instance: instance)
        case .quote:
            QuoteWidget(instance: instance)
        case .countdown:
            CountdownWidget(instance: instance)
        case .lockScreen:
            LockScreenWidget(instance: instance, library: services.images)
        case .vinyl:
            VinylWidget(size: instance.size, media: services.media)
        case .moon:
            MoonWidget(size: instance.size)
        case .daylight:
            DaylightWidget(instance: instance,
                           fallbackLocation: services.widgets.widgets.lazy.compactMap(\.options.location).first)
        case .polaroids:
            PolaroidsWidget(instance: instance, library: services.images)
        case .todo:
            TodoWidget(instance: instance, notes: services.notes)
        case .focus:
            FocusWidget(instance: instance, store: services.widgets)
        case .stopwatch:
            StopwatchWidget(instance: instance, store: services.widgets)
        case .shortcuts:
            ShortcutsWidget(instance: instance)
        case .sticker:
            StickerWidget(instance: instance)
        case .neon:
            NeonSignWidget(instance: instance)
        case .terminal:
            TerminalWidget(instance: instance, monitor: readings, unit: services.settings.temperatureUnit)
        case .dots:
            DotsWidget(instance: instance)
        case .metric:
            SystemMetricWidget(instance: instance, monitor: readings, unit: services.settings.temperatureUnit)
        case .date:
            DateWidget(instance: instance)
        case .nextEvent:
            NextEventWidget(instance: instance, calendar: services.calendar)
        case .goals:
            GoalsWidget(instance: instance, store: services.widgets)
        case .habits:
            HabitsWidget(instance: instance, store: services.widgets)
        case .reading:
            ReadingWidget(instance: instance, store: services.widgets)
        case .github:
            GitHubWidget(instance: instance, github: services.github, onConfigure: onConfigure)
        case .status:
            StatusWidget(instance: instance, status: services.status)
        case .airQuality:
            AirQualityWidget(instance: instance, weather: services.weather, onConfigure: onConfigure)
        case .retroWindow:
            RetroWindowWidget(instance: instance)
        case .enso:
            EnsoWidget(instance: instance)
        case .magazine:
            MagazineWidget(instance: instance)
        case .jersey:
            JerseyWidget(instance: instance)
        case .playerCard:
            PlayerCardWidget(instance: instance, library: services.images)
        case .pitch:
            PitchWidget(instance: instance)
        case .scoreboard:
            ScoreboardWidget(instance: instance)
        case .milestone:
            MilestoneWidget(instance: instance)
        case .cassette:
            CassetteWidget(instance: instance, media: services.media)
        case .vhs:
            VHSWidget(instance: instance, library: services.images)
        case .visualizer:
            VisualizerWidget(instance: instance, media: services.media)
        case .ticket:
            TicketWidget(instance: instance)
        case .wordArt:
            WordArtWidget(instance: instance)
        case .spiral:
            SpiralWidget(instance: instance)
        case .charm:
            CharmWidget(instance: instance)
        case .label:
            LabelWidget(instance: instance)
        case .aura:
            AuraWidget(instance: instance)
        case .tarot:
            TarotWidget(instance: instance)
        case .zodiac:
            ZodiacWidget(instance: instance)
        case .eightBall:
            EightBallWidget(instance: instance)
        case .candle:
            CandleWidget(instance: instance)
        }
    }
}

/// The widget's background, clipped to its rounded shape.
struct WidgetSurface<Content: View>: View {
    let instance: WidgetInstance
    let cornerRadius: CGFloat
    var library: ImageLibrary?
    @ViewBuilder var content: Content
    @Environment(\.widgetSnapshot) private var snapshot

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if instance.kind.isFreeform {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !instance.hasCard {
            // Straight on the wallpaper: a soft shadow keeps it readable.
            let ink = instance.options.ink ?? WidgetColor(red: 1, green: 1, blue: 1)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(Color(ink))
                .shadow(color: ink.isLight ? .black.opacity(0.45) : .white.opacity(0.5), radius: 3, y: 1)
                .environment(\.colorScheme, ink.isLight ? .dark : .light)
        } else {
            card(shape)
                .modifier(InkModifier(ink: instance.options.ink))
        }
    }

    @ViewBuilder
    private func card(_ shape: RoundedRectangle) -> some View {
        Group {
            if instance.kind == .note {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.paper(instance.options.noteColor))
                    .environment(\.colorScheme, .light)
            } else {
                switch instance.material {
                case .glass:
                    glass(shape)
                case .dark:
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            ZStack {
                                VisualEffectBlur(material: .hudWindow, appearance: .darkAqua, cornerRadius: cornerRadius)
                                Color.black.opacity(0.3)
                            }
                        }
                        .environment(\.colorScheme, .dark)
                case .light:
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            ZStack {
                                VisualEffectBlur(material: .popover, appearance: .aqua, cornerRadius: cornerRadius)
                                Color.white.opacity(0.45)
                            }
                        }
                        .environment(\.colorScheme, .light)
                case .tinted:
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.tintGradient(instance.tint))
                        .environment(\.colorScheme, .dark)
                case .paper:
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            Theme.paperCard(instance.tint)
                                .overlay(Grain(opacity: 0.05))
                        }
                        .environment(\.colorScheme, instance.tint.isLight ? .light : .dark)
                case .frosted:
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            ZStack {
                                VisualEffectBlur(material: .hudWindow, appearance: instance.tint.isLight ? .aqua : .darkAqua,
                                                 cornerRadius: cornerRadius)
                                Color(instance.tint).opacity(0.62)
                            }
                        }
                        .environment(\.colorScheme, instance.tint.isLight ? .light : .dark)
                case .outline:
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(Color(instance.options.ink ?? WidgetColor(red: 1, green: 1, blue: 1)).opacity(0.45), lineWidth: 1)
                        }
                        .environment(\.colorScheme, .dark)
                case .clear:
                    // Only notes get here: "No Card" is handled above.
                    content
                case .art:
                    let isLight = instance.options.art.palette.isLight
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            ArtView(piece: instance.options.art, animated: instance.options.animateArt,
                                    speed: instance.options.artSpeed)
                                .overlay(Color.black.opacity(isLight ? 0 : 0.12))
                        }
                        .environment(\.colorScheme, isLight ? .light : .dark)
                case .photo:
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        // Keeps small text readable on any photo.
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                        .background {
                            if let library {
                                PhotoBackground(source: instance.options.background ?? .web(CuratedBackgrounds.suggestion(0)),
                                                blur: instance.options.backgroundBlur, library: library)
                                    // Widgets full of small text get a little more shade.
                                    .overlay(Color.black.opacity([.calendar, .system, .battery, .weather].contains(instance.kind) ? 0.22 : 0))
                            } else {
                                Color.black
                            }
                        }
                        .environment(\.colorScheme, .dark)
                case .mesh:
                    let isLight = instance.options.art.palette.isLight
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            MeshBackground(palette: instance.options.art.palette, animated: instance.options.animateArt,
                                           speed: instance.options.artSpeed)
                        }
                        .environment(\.colorScheme, isLight ? .light : .dark)
                }
            }
        }
        .clipShape(shape)
        // A thin bright edge and a soft sheen along the top, like glass.
        .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.08)],
                                                   startPoint: .top, endPoint: .bottom), lineWidth: 0.75))
    }

    @ViewBuilder
    private func glass(_ shape: RoundedRectangle) -> some View {
        if snapshot {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VisualEffectBlur(material: .popover, appearance: nil, cornerRadius: cornerRadius))
        } else if #available(macOS 26, *) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassEffect(.regular, in: shape)
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VisualEffectBlur(material: .popover, appearance: nil, cornerRadius: cornerRadius))
        }
    }
}

/// Text in the theme's ink color, when it has one.
private struct InkModifier: ViewModifier {
    let ink: WidgetColor?

    func body(content: Content) -> some View {
        if let ink {
            content.foregroundStyle(Color(ink))
        } else {
            content
        }
    }
}

/// Blurs whatever is behind the window (the wallpaper, for a widget).
struct VisualEffectBlurLayer: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let appearance: NSAppearance.Name?
    let cornerRadius: CGFloat
    @Environment(\.widgetIsPreview) private var isPreview

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        update(view)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        update(view)
    }

    private func update(_ view: NSVisualEffectView) {
        view.blendingMode = isPreview ? .withinWindow : .behindWindow
        view.material = material
        view.appearance = appearance.flatMap(NSAppearance.init(named:))
        // Behind-window blur ignores SwiftUI's clip, so round it with a mask.
        view.maskImage = Self.roundedMask(radius: cornerRadius)
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// The floating bar shown while arranging widgets.
struct ArrangeToolbar: View {
    let onAdd: @MainActor () -> Void
    let onDone: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 18))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Arranging widgets").font(.system(size: 13, weight: .semibold))
                Text("Drag to move. They snap into line.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Add Widget…", action: onAdd)
            Button("Done", action: onDone)
                .keyboardShortcut(.defaultAction)
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .modifier(ToolbarBackground())
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The floating bar while a theme is tried on the desktop.
struct ThemePreviewBar: View {
    let name: String
    let onKeep: @MainActor () -> Void
    let onRevert: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 18))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Previewing \(name)").font(.system(size: 13, weight: .semibold))
                Text("Keep it, or go back to your desktop as it was.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Go Back", action: onRevert)
                .keyboardShortcut(.cancelAction)
            Button("Keep Theme", action: onKeep)
                .keyboardShortcut(.defaultAction)
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .modifier(ToolbarBackground())
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ToolbarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(VisualEffectBlur(material: .hudWindow, appearance: nil, cornerRadius: 30))
                .clipShape(Capsule())
        }
    }
}

/// Blurs whatever is behind the window; in snapshots, a tint of the same
/// weight, since there's nothing behind a picture to blur.
struct VisualEffectBlur: View {
    let material: NSVisualEffectView.Material
    let appearance: NSAppearance.Name?
    let cornerRadius: CGFloat
    @Environment(\.widgetSnapshot) private var snapshot
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if snapshot {
            let dark = appearance == .darkAqua || (appearance == nil && colorScheme == .dark)
            (dark ? Color(white: 0.12) : Color(white: 0.96)).opacity(material == .hudWindow ? 0.72 : 0.6)
        } else {
            VisualEffectBlurLayer(material: material, appearance: appearance, cornerRadius: cornerRadius)
        }
    }
}
