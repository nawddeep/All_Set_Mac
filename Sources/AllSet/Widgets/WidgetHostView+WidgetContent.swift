import AllSetCore
import AppKit
import SwiftUI

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
struct InkModifier: ViewModifier {
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

struct ToolbarBackground: ViewModifier {
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
