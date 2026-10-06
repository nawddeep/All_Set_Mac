import AllSetCore
import SwiftUI

/// Instant-film prints lying loose on the desktop. A click drops the next one
/// on top; the slideshow setting does it on its own.
struct PolaroidsWidget: View {
    let instance: WidgetInstance
    let library: ImageLibrary

    /// How many prints have been dealt; the newest few are on show.
    @State private var dealt = 0
    @State private var isHovered = false
    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.widgetIsPreview) private var isPreview

    private var images: [ImageSource] {
        instance.options.images.isEmpty ? CuratedBackgrounds.polaroidStarters.map(ImageSource.web) : instance.options.images
    }

    var body: some View {
        let images = images
        let slots = Self.slots(for: instance.size)
        let shown = max(min(slots.count, images.count), 1)
        let width = Self.printWidth(for: instance.size)

        ZStack {
            // Each print keeps its identity as it moves down the pile, so it
            // slides into its new place; the oldest fades away underneath.
            ForEach((dealt - shown + 1)...dealt, id: \.self) { deal in
                let position = deal - (dealt - shown + 1)
                let slot = slots[slots.count - shown + position]
                let isTop = position == shown - 1
                PolaroidPrint(source: images[((deal % images.count) + images.count) % images.count],
                              caption: isTop ? instance.options.caption : "",
                              width: width, filter: instance.options.photoFilter, library: library)
                    .rotationEffect(.degrees(slot.angle + (isTop && isHovered ? -1.5 : 0)))
                    .offset(x: slot.x, y: slot.y - (isTop && isHovered ? 3 : 0))
                    .zIndex(Double(deal))
                    .transition(.asymmetric(
                        insertion: .offset(x: 30, y: -60).combined(with: .scale(scale: 1.15)).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.92))
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { deal() }
        .onHover { hovering in
            withMotion(Motion.press) { isHovered = hovering }
        }
        .help(images.count > shown ? "Click for the next photo" : "")
        .task(id: "\(instance.options.slideshowInterval)-\(isVisible)") {
            let interval = instance.options.slideshowInterval
            guard interval > 0, isVisible, !isPreview else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                deal()
            }
        }
    }

    private func deal() {
        guard images.count > 1 else { return }
        withMotion(Motion.responsive) { dealt += 1 }
    }

    static func printWidth(for size: WidgetSize) -> CGFloat {
        switch size {
        case .small: 104
        case .medium: 108
        case .large, .extraLarge: 190
        }
    }

    /// Where each print lies, from the bottom of the pile to the top.
    static func slots(for size: WidgetSize) -> [(x: CGFloat, y: CGFloat, angle: Double)] {
        switch size {
        case .small:
            [(-10, 4, -9), (9, -2, 6), (0, 2, -2)]
        case .medium:
            [(-108, 4, -8), (0, -2, 3), (108, 3, -4)]
        case .large, .extraLarge:
            [(-38, -30, -10), (40, -18, 8), (-14, 26, 4), (6, 8, -3)]
        }
    }
}

/// One print: the photo in its white frame, wider at the bottom, with an
/// optional line of handwriting.
struct PolaroidPrint: View {
    let source: ImageSource
    let caption: String
    let width: CGFloat
    var filter: PhotoFilter = .none
    let library: ImageLibrary

    var body: some View {
        // Real instant film: 79 mm square picture on an 88 by 107 mm card.
        let border = width * 0.055
        let photo = width - border * 2
        let bottom = width * 107 / 88 - photo - border
        VStack(spacing: 0) {
            PhotoContent(source: source, filter: filter, tint: .white, animated: false, library: library,
                         maxPixels: Int(width * 2))
                .frame(width: photo, height: photo)
                .clipped()
                // Film sits slightly below the card's surface.
                .overlay(LinearGradient(colors: [.black.opacity(0.14), .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.12)))
                .overlay(Rectangle().strokeBorder(.black.opacity(0.08), lineWidth: 0.5))
            Text(caption)
                .typeface("Bradley Hand", size: width * 0.1)
                .foregroundStyle(Color(red: 0.2, green: 0.22, blue: 0.3))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 4)
                .frame(width: photo, height: bottom)
        }
        .padding([.top, .horizontal], border)
        .background(Color(red: 0.975, green: 0.968, blue: 0.95))
        .overlay(Grain(opacity: 0.06))
        .compositingGroup()
        .shadow(color: .black.opacity(0.28), radius: 1.5, y: 1)
        .shadow(color: .black.opacity(0.25), radius: 8, y: 5)
        .environment(\.colorScheme, .light)
    }
}
