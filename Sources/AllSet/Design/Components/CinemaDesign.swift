import AllSetCore
import AppKit
import SwiftUI

/// Small, byte-bounded static art cache. No video, shader or live blur for scenery.
@MainActor enum CinemaArtwork {
    private static var cache = CostCache<String, NSImage>(costLimit: 32 * 1024 * 1024, countLimit: 8)
    static func image(_ name: String) -> NSImage? {
        if let image = cache.value(forKey: name) { return image }
        guard let url = StudioScenery.url(name), let image = NSImage(contentsOf: url) else { return nil }
        cache.insert(image, forKey: name, cost: Int(image.size.width * image.size.height) * 4)
        return image
    }
    static func clear() { cache.removeAll() }
}

struct CinemaImage: View {
    let name: String
    var alignment: Alignment = .center
    var body: some View {
        GeometryReader { geometry in
            if let image = CinemaArtwork.image(name) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignment).clipped()
            } else { Color(red: 0.02, green: 0.045, blue: 0.105) }
        }
        .accessibilityHidden(true)
    }
}

/// One persistent navigation cluster across every section and detail page.
struct CinemaNavigation: View {
    let services: AppServices
    @State private var lastPage: [NavSection: AppPage] = [:]
    @Namespace private var selection
    private var page: AppPage { services.ui.page ?? .island }
    private var section: NavSection { .of(page) }
    private var items: [NavItem] { NavItem.items(in: section, services: services) }
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                HStack {
                    Text("All Set").font(.system(size: 14, weight: .medium)).padding(.leading, 103)
                    Spacer()
                }
                HStack(spacing: 2) {
                    ForEach(Array(NavSection.allCases.enumerated()), id: \.element) { index, option in
                        Button { navigate(lastPage[option] ?? option.home) } label: {
                            Text(option.title).foregroundStyle(option == section ? .white : .white.opacity(0.65))
                                .padding(.horizontal, 27.5).frame(height: 34)
                                .contentShape(Capsule())
                                .background {
                                    if option == section {
                                        Capsule().fill(.white.opacity(0.17)).matchedGeometryEffect(id: "section", in: selection)
                                    }
                                }
                        }.buttonStyle(.plain).accessibilityAddTraits(option == section ? .isSelected : [])
                        // ⌘1–⌘5, as the README promises and the earlier navigation had.
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                        .help("\(option.title) (⌘\(index + 1))")
                    }
                }
                .font(.system(size: 14)).padding(3)
                .background(Capsule().fill(Color(red: 0.015, green: 0.028, blue: 0.065).opacity(0.45)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.1)))
                .accessibilityIdentifier("studio.navigation.sections")
            }.frame(height: 40)
            ViewThatFits(in: .horizontal) {
                pageLinks
                ScrollView(.horizontal, showsIndicators: false) { pageLinks.padding(.horizontal, 16) }
            }.frame(height: 34)
        }
        .foregroundStyle(.white).padding(.top, 6).padding(.bottom, 12)
        .onChange(of: page, initial: true) { _, new in lastPage[.of(new)] = new }
    }
    private func navigate(_ next: AppPage) {
        withMotion(Motion.standard) { services.ui.page = next }
    }
    private var pageLinks: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                let selected = item.matches(page)
                Button { navigate(item.page) } label: {
                    Text(item.title).font(.system(size: 13, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? .white : .white.opacity(0.8))
                        .padding(.horizontal, 16).frame(height: 34)
                        .contentShape(Capsule())
                        .background {
                            if selected {
                                Capsule().fill(Color(red: 0.08, green: 0.22, blue: 0.42).opacity(0.7))
                                    .matchedGeometryEffect(id: "page", in: selection)
                            }
                        }
                }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
            }
        }.fixedSize().id(section).transition(.opacity)
        .accessibilityIdentifier("studio.navigation.pages")
    }
}

struct CinemaChip: View {
    let title: String
    var selected = false
    var whiteSelection = false
    var horizontalPadding: CGFloat = 18
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected && whiteSelection ? Color.black : Color.white.opacity(selected ? 1 : 0.78))
                .padding(.horizontal, horizontalPadding).frame(height: 32)
                .contentShape(Capsule())
                .background(Capsule().fill(selected ? (whiteSelection ? Color.white : Color(red: 0.3, green: 0.36, blue: 0.52)) : .clear))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct CinemaIcon: View {
    let symbol: String
    let label: String
    var diameter: CGFloat = 40
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: diameter > 40 ? 20 : 18, weight: .regular))
                .foregroundStyle(.white).frame(width: diameter, height: diameter)
                .contentShape(Circle())
                .background(Circle().fill(Color(red: 0.025, green: 0.045, blue: 0.09).opacity(0.65)))
                .overlay(Circle().strokeBorder(.white.opacity(0.13)))
        }.buttonStyle(.plain).accessibilityLabel(label).help(label)
    }
}

struct CinematicClockFace: View {
    let instance: WidgetInstance
    let date: Date
    private var zone: TimeZone { instance.options.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current }
    var body: some View {
        GeometryReader { g in
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(WidgetDateFormat.string(date, template: "EEEE", timeZone: zone).uppercased())
                        .font(.system(size: g.size.width * (g.size.width / g.size.height > 1.7 ? 0.027 : 0.055), weight: .semibold)).tracking(4.5)
                    Spacer(minLength: 0)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(WidgetDateFormat.string(date, format: (instance.options.use24Hour ? "HH:mm" : "h:mm") + (instance.options.showSeconds ? ":ss" : ""), timeZone: zone))
                            .font(.system(size: g.size.width * (g.size.width / g.size.height > 1.7 ? 0.17 : 0.25), weight: .regular)).tracking(-2)
                            .lineLimit(1).minimumScaleFactor(0.72)
                        if !instance.options.use24Hour {
                            Text(WidgetDateFormat.string(date, format: "a", timeZone: zone)).font(.system(size: g.size.width * 0.049))
                        }
                    }
                    Text(WidgetDateFormat.string(date, template: "dMMMM", timeZone: zone))
                        .font(.system(size: g.size.width * (g.size.width / g.size.height > 1.7 ? 0.048 : 0.088))).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if g.size.width / g.size.height > 1.7 {
                    CinemaDial(date: date, zone: zone, showSeconds: true).frame(width: g.size.height * 0.70, height: g.size.height * 0.70)
                }
            }
            .padding(.horizontal, g.size.width * 0.068).padding(.vertical, g.size.height * 0.14)
            .foregroundStyle(.white)
            .background {
                if instance.material == .photo || instance.material == .frosted {
                    CinemaImage(name: background, alignment: .top)
                    if instance.material == .frosted {
                        LinearGradient(colors: [Color(red: 0.49, green: 0.55, blue: 0.95).opacity(0.66), .clear, .blue.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                    } else {
                        LinearGradient(colors: [.black.opacity(0.16), .clear, .black.opacity(0.12)], startPoint: .top, endPoint: .bottom)
                    }
                } else if instance.material == .mesh {
                    LinearGradient(colors: [.indigo, .purple.opacity(0.55), Color(red: 0.01, green: 0.06, blue: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing)
                } else if instance.material == .paper {
                    Color(red: 0.19, green: 0.25, blue: 0.38)
                } else { Color(red: 0.025, green: 0.045, blue: 0.1).opacity(instance.material == .outline ? 0.3 : 0.98) }
            }
            .clipShape(RoundedRectangle(cornerRadius: g.size.height * 0.13))
            .overlay(RoundedRectangle(cornerRadius: g.size.height * 0.13).strokeBorder(
                LinearGradient(colors: instance.material == .frosted
                    ? [.white.opacity(0.95), Color(red: 0.62, green: 0.64, blue: 1).opacity(0.75), .white.opacity(0.8)]
                    : [.cyan.opacity(0.35), .indigo.opacity(0.3), .white.opacity(0.14)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: instance.material == .frosted ? 1.7 : 1))
            .overlay {
                if instance.material == .frosted {
                    RoundedRectangle(cornerRadius: g.size.height * 0.13).strokeBorder(.white.opacity(0.40), lineWidth: 3)
                        .blur(radius: 3).allowsHitTesting(false)
                }
            }
        }
    }
    private var background: String {
        if case .bundled(let name) = instance.options.background { return name }
        return StudioScenery.wallpaper
    }
}

/// Static ticks plus minute-aligned hands: no per-second page invalidation.
struct CinemaDial: View {
    let date: Date
    var zone: TimeZone = .current
    var showSeconds = false
    var body: some View {
        GeometryReader { g in
            let side = min(g.size.width, g.size.height)
            let calendar = Calendar.current
            let hour = Double(calendar.dateComponents(in: zone, from: date).hour ?? 0)
            let minute = Double(calendar.dateComponents(in: zone, from: date).minute ?? 0)
            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    for i in 0..<60 {
                        let angle = Double(i) / 60 * 2 * .pi
                        let outside = side * 0.48, inside = outside - side * (i % 5 == 0 ? 0.055 : 0.025)
                        var path = Path()
                        path.move(to: CGPoint(x: center.x + sin(angle) * inside, y: center.y - cos(angle) * inside))
                        path.addLine(to: CGPoint(x: center.x + sin(angle) * outside, y: center.y - cos(angle) * outside))
                        context.stroke(path, with: .color(.white.opacity(i % 5 == 0 ? 0.95 : 0.65)), lineWidth: i % 5 == 0 ? 1.5 : 0.8)
                    }
                }
                ForEach([12, 3, 6, 9], id: \.self) { number in
                    let angle = Double(number) / 12 * 2 * .pi
                    Text("\(number)").font(.system(size: side * 0.078))
                        .offset(x: sin(angle) * side * 0.36, y: -cos(angle) * side * 0.36)
                }
                hand(side * 0.28, side * 0.017, (hour + minute / 60) * 30, .white)
                hand(side * 0.39, side * 0.012, minute * 6, .white)
                if showSeconds {
                    hand(side * 0.4, side * 0.005, Double(calendar.dateComponents(in: zone, from: date).second ?? 0) * 6, Color(red: 0.3, green: 0.7, blue: 1))
                }
                Circle().fill(.white).frame(width: 4, height: 4)
            }.frame(width: side, height: side).frame(width: g.size.width, height: g.size.height)
        }
    }
    private func hand(_ length: CGFloat, _ width: CGFloat, _ angle: Double, _ color: Color) -> some View {
        Capsule().fill(color).frame(width: width, height: length).offset(y: -length / 2).rotationEffect(.degrees(angle))
    }
}

struct CinemaWidgetPreview: View {
    let instance: WidgetInstance
    let services: AppServices
    let fit: CGSize
    var live = false
    @Environment(\.widgetIsOnScreen) private var onScreen
    var body: some View {
        Group {
            if instance.options.cinematicClock || instance.options.cinematicStyle {
                WidgetBody(instance: instance, services: services).frame(width: fit.width, height: fit.height)
            } else {
                let dimensions = instance.footprint
                let scale = min(fit.width / dimensions.width, fit.height / dimensions.height)
                WidgetBody(instance: instance, services: services)
                    .frame(width: dimensions.width, height: dimensions.height)
                    .scaleEffect(scale).frame(width: dimensions.width * scale, height: dimensions.height * scale)
            }
        }
        .environment(\.widgetIsPreview, true).environment(\.widgetIsVisible, live && onScreen)
        .environment(\.widgetIsOnScreen, live && onScreen).environment(\.widgetSnapshot, !live)
        .allowsHitTesting(false)
    }
}

/// Stops preview players and clocks when their actual AppKit window is hidden.
struct CinemaWindowPresence: NSViewRepresentable {
    @Binding var visible: Bool
    func makeNSView(context: Context) -> CinemaPresenceView { CinemaPresenceView() }
    func updateNSView(_ view: CinemaPresenceView, context: Context) {
        view.changed = { value in if visible != value { visible = value } }
    }
    static func dismantleNSView(_ view: CinemaPresenceView, coordinator: ()) { view.stop() }
}

final class CinemaPresenceView: NSView {
    var changed: ((Bool) -> Void)?
    nonisolated(unsafe) private var token: NSObjectProtocol?
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stop()
        guard let window else { return }
        token = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.report() }
        }
        DispatchQueue.main.async { [weak self] in self?.report() }
    }
    private func report() { changed?(window?.occlusionState.contains(.visible) ?? false) }
    func stop() { if let token { NotificationCenter.default.removeObserver(token) }; token = nil }
    deinit { if let token { NotificationCenter.default.removeObserver(token) } }
}

struct CinemaActionStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold))
            .foregroundStyle(prominent ? Color.black : .white)
            .padding(.horizontal, 16).frame(height: 40)
            .contentShape(Capsule())
            .background(Capsule().fill(prominent ? .white : .black.opacity(0.2)))
            .overlay(Capsule().strokeBorder(.white.opacity(prominent ? 0 : 0.6), lineWidth: 1.2))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
