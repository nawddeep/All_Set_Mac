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
struct ThemedShadow: ViewModifier {
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

struct ArrangeBadge: View {
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
struct ResizeHandle: View {
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
struct ResizeCursor: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.pointerStyle(.frameResize(position: .bottomTrailing))
        } else {
            content
        }
    }
}
