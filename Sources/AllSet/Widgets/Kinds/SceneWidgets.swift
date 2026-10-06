import AllSetCore
import AppKit
import CoreImage
import SwiftUI
import Vision

// MARK: Lock Screen

/// A big clock over a photo. With a clear subject in the photo (a person, a
/// pet), the subject stands in front of the time, as on the iPhone, and the
/// time moves aside if the subject would hide it.
struct LockScreenWidget: View {
    let instance: WidgetInstance
    let library: ImageLibrary

    @State private var cutout: SubjectCutout.Cutout?

    init(instance: WidgetInstance, library: ImageLibrary) {
        self.instance = instance
        self.library = library
        let background = instance.material == .photo
            ? (instance.options.background ?? .web(CuratedBackgrounds.suggestion(0))) : nil
        _cutout = State(initialValue: instance.options.depthEffect ? background.flatMap(SubjectCutout.known) : nil)
    }

    private var options: WidgetOptions { instance.options }
    private var background: ImageSource? {
        instance.material == .photo ? (options.background ?? .web(CuratedBackgrounds.suggestion(0))) : nil
    }

    var body: some View {
        let layout = placement
        WidgetTimeline(.periodic(from: Self.minuteStart(.now), by: 60)) { context in
            ZStack {
                clock(context.date, alignment: layout.alignment)
                if let cutout, layout.depth {
                    Color.clear
                        .overlay {
                            Image(nsImage: cutout.image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .clipped()
                        .shadow(color: .black.opacity(0.25), radius: 10)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
        }
        .motion(Motion.gentle, value: cutout != nil)
        .task(id: "\(String(describing: background))|\(options.depthEffect)") {
            // Art has no subject to lift, and the library returns nothing for it.
            guard options.depthEffect, let background else {
                cutout = nil
                return
            }
            cutout = await SubjectCutout.cutout(for: background, library: library)
        }
    }

    /// Where the time goes, and whether the subject may stand in front of it:
    /// the spot the subject covers least, and depth only if it hides little.
    private var placement: (alignment: HorizontalAlignment, depth: Bool) {
        guard let cutout else { return (.center, false) }
        let size = instance.size.dimensions
        let candidates: [HorizontalAlignment] = instance.size == .medium ? [.center, .leading, .trailing] : [.center]
        let scored = candidates.map { alignment in
            (alignment, cutout.coverage(of: clockRect(alignment, in: size), widgetSize: size))
        }
        let best = scored.min { $0.1 < $1.1 } ?? (.center, 1)
        return (best.0, best.1 < 0.42)
    }

    /// Roughly where the time sits, for measuring what covers it.
    private func clockRect(_ alignment: HorizontalAlignment, in size: CGSize) -> CGRect {
        let fontSize = timeSize
        let stacked = options.clockFace == .stacked && instance.size != .medium
        let height = stacked ? fontSize * 1.6 : fontSize * 0.95
        let width = stacked ? fontSize * 1.3 : fontSize * 2.3
        let top: CGFloat = (instance.size == .large ? 26 : 14) + (instance.size == .large ? 24 : 18)
        let x: CGFloat = switch alignment {
        case .leading: 16
        case .trailing: size.width - width - 16
        default: (size.width - width) / 2
        }
        return CGRect(x: x, y: top, width: width, height: height)
    }

    private var timeSize: CGFloat {
        switch instance.size {
        case .small: 50
        case .medium: 76
        case .large, .extraLarge: 118
        }
    }

    @ViewBuilder
    private func clock(_ date: Date, alignment: HorizontalAlignment) -> some View {
        let day = WidgetDateFormat.string(date, template: "EEEEdMMMM")
        VStack(alignment: alignment, spacing: instance.size == .small ? 0 : 2) {
            Text(day)
                .font(.system(size: instance.size == .large ? 19 : 14, weight: .semibold))
                .opacity(0.9)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if options.clockFace == .stacked, instance.size != .medium {
                StackedTime(hour: WidgetDateFormat.string(date, format: options.use24Hour ? "HH" : "h"),
                            minute: WidgetDateFormat.string(date, format: "mm"), size: timeSize)
            } else {
                Text(WidgetDateFormat.string(date, format: options.use24Hour ? "HH:mm" : "h:mm"))
                    .font(.system(size: timeSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.top, instance.size == .large ? 26 : 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: Alignment(horizontal: alignment, vertical: .top))
        .motion(Motion.gentle, value: alignment == .center ? 0 : alignment == .leading ? 1 : 2)
    }

    private static func minuteStart(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60)
    }
}

/// The subject of a photo, cut out with Vision, for drawing over the time.
@MainActor
enum SubjectCutout {
    struct Cutout {
        let image: NSImage
        /// How much of each cell of a 32×32 grid over the photo is subject, 0...1, row by row from the top.
        let grid: [Float]
        let aspect: CGFloat

        static let side = 32

        /// Share of `rect` (in widget points) the subject covers, with the
        /// photo filling a widget of `widgetSize`.
        func coverage(of rect: CGRect, widgetSize: CGSize) -> Double {
            // The photo fills the widget, trimmed on one axis.
            let scale = max(widgetSize.width / aspect, widgetSize.height)
            let shown = CGSize(width: aspect * scale, height: scale)
            let origin = CGPoint(x: (widgetSize.width - shown.width) / 2, y: (widgetSize.height - shown.height) / 2)
            var total = 0.0, count = 0.0
            let steps = 10
            for row in 0..<steps {
                for column in 0..<steps {
                    let point = CGPoint(x: rect.minX + rect.width * (Double(column) + 0.5) / Double(steps),
                                        y: rect.minY + rect.height * (Double(row) + 0.5) / Double(steps))
                    let u = (point.x - origin.x) / shown.width, v = (point.y - origin.y) / shown.height
                    guard (0..<1).contains(u), (0..<1).contains(v) else { continue }
                    total += Double(grid[Int(v * Double(Self.side)) * Self.side + Int(u * Double(Self.side))])
                    count += 1
                }
            }
            return count > 0 ? total / count : 0
        }
    }

    /// Nil inside means "looked, and there's no clear subject".
    private static var cache: [ImageSource: Cutout?] = [:]

    /// A cutout already made, without waiting.
    static func known(_ source: ImageSource) -> Cutout? {
        cache[source] ?? nil
    }

    static func cutout(for source: ImageSource, library: ImageLibrary) async -> Cutout? {
        if let known = cache[source] { return known }
        // A widget-sized copy, decoded off the main thread: the widget is at
        // most about 700 pixels across, and Vision works as well at this size.
        guard let image = await library.image(for: source, maxPixels: 1024),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let lifted = await Task.detached(priority: .utility) { lift(cgImage) }.value
        let cutout = lifted.map {
            Cutout(image: NSImage(cgImage: $0.image, size: .zero), grid: $0.grid,
                   aspect: CGFloat(cgImage.width) / CGFloat(max(cgImage.height, 1)))
        }
        cache[source] = .some(cutout)
        return cutout
    }

    /// The masked subject at the photo's full framing and where it sits, or
    /// nil when there's no subject, or it fills most of the frame.
    nonisolated static func lift(_ original: CGImage) -> (image: CGImage, grid: [Float])? {
        let image = downscaled(original, longestSide: 1024) ?? original
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first, !observation.allInstances.isEmpty,
              let mask = try? observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler),
              let buffer = try? observation.generateMaskedImage(ofInstances: observation.allInstances, from: handler,
                                                                croppedToInstancesExtent: false)
        else { return nil }
        let grid = Self.grid(of: mask)
        let coverage = grid.reduce(0, +) / Float(grid.count)
        guard (0.03...0.7).contains(coverage) else { return nil }
        let masked = CIImage(cvPixelBuffer: buffer)
        guard let result = CIContext().createCGImage(masked, from: masked.extent) else { return nil }
        return (result, grid)
    }

    /// The mask averaged into a 32×32 grid.
    nonisolated private static func grid(of mask: CVPixelBuffer) -> [Float] {
        let side = Cutout.side
        var grid = [Float](repeating: 0, count: side * side)
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return grid }
        let width = CVPixelBufferGetWidth(mask), height = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        var counts = [Float](repeating: 0, count: side * side)
        for y in stride(from: 0, to: height, by: 4) {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float32.self)
            let cellRow = min(y * side / height, side - 1)
            for x in stride(from: 0, to: width, by: 4) {
                let cell = cellRow * side + min(x * side / width, side - 1)
                grid[cell] += row[x] > 0.5 ? 1 : 0
                counts[cell] += 1
            }
        }
        for index in grid.indices where counts[index] > 0 {
            grid[index] /= counts[index]
        }
        return grid
    }

    nonisolated private static func downscaled(_ image: CGImage, longestSide: Int) -> CGImage? {
        let scale = min(1, Double(longestSide) / Double(max(image.width, image.height)))
        guard scale < 1 else { return image }
        let width = Int(Double(image.width) * scale), height = Int(Double(image.height) * scale)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}

// MARK: Vinyl

/// A record that spins while music plays, the artwork as its label, on a
/// blurred wash of the artwork.
struct VinylWidget: View {
    let size: WidgetSize
    let media: MediaController

    @State private var isHovering = false

    var body: some View {
        let info = media.info
        let playing = info?.isPlaying ?? false
        ZStack {
            backdrop
            switch size {
            case .small:
                VStack(spacing: 8) {
                    Record(artwork: media.artwork, playing: playing)
                        .frame(width: 112, height: 112)
                    caption(info, compact: true)
                }
                .padding(12)
            case .medium:
                HStack(spacing: 16) {
                    Record(artwork: media.artwork, playing: playing)
                        .frame(width: 138, height: 138)
                    VStack(alignment: .leading, spacing: 10) {
                        caption(info, compact: false)
                        controls(info)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(15)
            case .large, .extraLarge:
                VStack(spacing: 14) {
                    Record(artwork: media.artwork, playing: playing)
                        .frame(width: 236, height: 236)
                    caption(info, compact: false)
                    controls(info)
                }
                .padding(18)
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .onHover { isHovering = $0 }
    }

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.12), Color(white: 0.04)], startPoint: .top, endPoint: .bottom)
            if let artwork = media.artwork {
                Color.clear
                    .overlay {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .blur(radius: 34, opaque: true)
                    .saturation(1.3)
                    .overlay(Color.black.opacity(0.42))
                    .transition(.opacity)
            }
            Grain(opacity: 0.06)
        }
        .motion(Motion.gentle, value: media.artwork)
    }

    @ViewBuilder
    private func caption(_ info: NowPlayingInfo?, compact: Bool) -> some View {
        VStack(alignment: compact ? .center : .leading, spacing: 2) {
            Text(info.map { $0.title.isEmpty ? "Unknown title" : $0.title } ?? "Nothing playing")
                .font(.system(size: compact ? 12 : 15, weight: .semibold))
            Text(info.map { $0.artist.isEmpty ? $0.album : $0.artist } ?? "Play some music")
                .font(.system(size: compact ? 10 : 12))
                .foregroundStyle(.white.opacity(0.7))
        }
        .lineLimit(1)
        .multilineTextAlignment(compact ? .center : .leading)
    }

    @ViewBuilder
    private func controls(_ info: NowPlayingInfo?) -> some View {
        HStack(spacing: 22) {
            button("backward.fill", size: 14, action: media.previousTrack)
            button(info?.isPlaying == true ? "pause.fill" : "play.fill", size: 20, action: media.togglePlayPause)
            button("forward.fill", size: 14, action: media.nextTrack)
        }
        .opacity(info == nil ? 0.4 : 1)
        .disabled(info == nil)
    }

    private func button(_ symbol: String, size: CGFloat, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 30, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

/// Grooves, a sheen that stays put while the disc turns, the label, and a
/// tonearm that swings on when music plays.
private struct Record: View {
    let artwork: NSImage?
    let playing: Bool
    @Environment(\.widgetIsVisible) private var isVisible

    /// The disc drawn once per artwork; Core Animation turns it, since it
    /// can spin for hours.
    @State private var face: CGImage?

    /// 33⅓ turns a minute.
    private static let secondsPerTurn = 1.8

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().fill(Color(white: 0.06))
                    .shadow(color: .black.opacity(0.5), radius: side * 0.05, y: side * 0.02)
                if let face {
                    SpinningImage(image: face, isSpinning: playing && isVisible, secondsPerTurn: Self.secondsPerTurn)
                } else {
                    disc(side: side)
                }
                // Light catching the grooves.
                Circle()
                    .fill(AngularGradient(colors: [.white.opacity(0), .white.opacity(0.14), .white.opacity(0),
                                                   .white.opacity(0), .white.opacity(0.1), .white.opacity(0)],
                                          center: .center))
                    .padding(side * 0.04)
                    .allowsHitTesting(false)
                tonearm(side: side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: FaceKey(artwork: artwork.map(ObjectIdentifier.init), side: side)) {
                let renderer = ImageRenderer(content: disc(side: side).frame(width: side, height: side))
                renderer.scale = 2
                face = renderer.cgImage
            }
        }
    }

    private struct FaceKey: Hashable {
        let artwork: ObjectIdentifier?
        let side: CGFloat
    }

    private func disc(side: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color(white: 0.06))
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let outer = size.width / 2 * 0.96
                var radius = outer
                var index = 0
                while radius > size.width * 0.2 {
                    let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                    context.stroke(ring, with: .color(.white.opacity(index % 3 == 0 ? 0.07 : 0.03)), lineWidth: 0.6)
                    radius -= size.width * 0.012
                    index += 1
                }
            }
            label
                .frame(width: side * 0.38, height: side * 0.38)
            Circle()
                .fill(Color(white: 0.85))
                .frame(width: side * 0.035, height: side * 0.035)
        }
    }

    @ViewBuilder
    private var label: some View {
        if let artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(Circle())
        } else {
            Circle().fill(LinearGradient(colors: [Color(red: 0.9, green: 0.35, blue: 0.3), Color(red: 0.95, green: 0.62, blue: 0.3)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Image(systemName: "music.note").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.8)))
        }
    }

    private func tonearm(side: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(LinearGradient(colors: [Color(white: 0.85), Color(white: 0.55)], startPoint: .leading, endPoint: .trailing))
                .frame(width: side * 0.03, height: side * 0.52)
            RoundedRectangle(cornerRadius: side * 0.012)
                .fill(Color(white: 0.75))
                .frame(width: side * 0.06, height: side * 0.1)
                .offset(y: side * 0.49)
        }
        .frame(height: side * 0.6, alignment: .top)
        .rotationEffect(.degrees(playing ? 24 : 6), anchor: .top)
        .overlay(alignment: .top) {
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.9), Color(white: 0.45)], center: .center, startRadius: 0, endRadius: side * 0.05))
                .frame(width: side * 0.1, height: side * 0.1)
                .offset(y: -side * 0.03)
        }
        .offset(x: side * 0.42, y: -side * 0.34)
        .shadow(color: .black.opacity(0.45), radius: 3, x: 2, y: 3)
        .motion(Motion.gentle, value: playing)
    }
}

// MARK: Moon

/// Tonight's moon on a starry sky, and when the next phases come.
struct MoonWidget: View {
    let size: WidgetSize

    var body: some View {
        WidgetTimeline(.periodic(from: .now, by: 1800)) { context in
            let phase = MoonPhase(date: context.date)
            ZStack {
                NightSky()
                switch size {
                case .small:
                    VStack(spacing: 8) {
                        MoonDisc(phase: phase).frame(width: 92, height: 92)
                        VStack(spacing: 1) {
                            Text(phase.name.rawValue).font(.system(size: 13, weight: .semibold))
                            Text("\(Int((phase.illumination * 100).rounded()))% lit").font(.system(size: 11)).opacity(0.7)
                        }
                    }
                case .medium:
                    HStack(spacing: 18) {
                        MoonDisc(phase: phase).frame(width: 126, height: 126)
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                WidgetWord("TONIGHT").font(.system(size: 10, weight: .bold)).opacity(0.6)
                                Text(phase.name.rawValue).font(.system(size: 19, weight: .semibold, design: .serif))
                                Text("\(Int((phase.illumination * 100).rounded()))% lit · \(Int(phase.age.rounded())) days old")
                                    .font(.system(size: 11)).opacity(0.7)
                            }
                            upcoming(after: context.date, count: 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(18)
                case .large, .extraLarge:
                    VStack(spacing: 14) {
                        Text(phase.name.rawValue).font(.system(size: 24, weight: .semibold, design: .serif))
                        MoonDisc(phase: phase).frame(width: 170, height: 170)
                        Text("\(Int((phase.illumination * 100).rounded()))% lit").font(.system(size: 13)).opacity(0.7)
                        upcoming(after: context.date, count: 4)
                    }
                    .padding(20)
                }
            }
            .foregroundStyle(.white)
        }
        .environment(\.colorScheme, .dark)
    }

    private func upcoming(after date: Date, count: Int) -> some View {
        let phases: [(String, String, Double)] = [
            ("New", "circle", 0), ("First Quarter", "circle.lefthalf.filled", 0.25),
            ("Full", "circle.fill", 0.5), ("Last Quarter", "circle.righthalf.filled", 0.75),
        ]
        let next = phases.map { ($0.0, $0.1, MoonPhase.next($0.2, after: date)) }.sorted { $0.2 < $1.2 }.prefix(count)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(next), id: \.0) { name, symbol, when in
                HStack(spacing: 6) {
                    Image(systemName: symbol).font(.system(size: 10)).frame(width: 14)
                    Text(name).font(.system(size: 11, weight: .medium))
                    Spacer(minLength: 4)
                    Text(when.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.system(size: 11)).opacity(0.7)
                }
            }
        }
    }
}

/// Deep blue to violet, with fixed stars.
private struct NightSky: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.05, blue: 0.14), Color(red: 0.12, green: 0.07, blue: 0.26)],
                           startPoint: .top, endPoint: .bottom)
            Starfield()
            Grain(opacity: 0.05)
        }
    }
}

/// Fixed stars, the same every time.
struct Starfield: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x51A7_E5
            func random() -> Double {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double(seed >> 11) / Double(1 << 53)
            }
            for _ in 0..<Int(size.width * size.height / 900) {
                let point = CGPoint(x: random() * size.width, y: random() * size.height)
                let radius = 0.3 + random() * 1.1
                context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: radius, height: radius)),
                             with: .color(.white.opacity(0.25 + random() * 0.6)))
            }
        }
    }
}

/// The moon, lit as it is at this phase: the terminator is half an ellipse.
struct MoonDisc: View {
    let phase: MoonPhase

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2 * 0.92
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            // Glow, then the dark side lit faintly by the Earth.
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius * 1.25, y: center.y - radius * 1.25,
                                                width: radius * 2.5, height: radius * 2.5)),
                         with: .radialGradient(Gradient(colors: [.white.opacity(0.18 * phase.illumination), .clear]),
                                               center: center, startRadius: radius * 0.8, endRadius: radius * 1.25))
            context.fill(disc, with: .color(Color(red: 0.16, green: 0.17, blue: 0.22)))

            let lit = litPath(center: center, radius: radius)
            context.drawLayer { layer in
                layer.clip(to: lit)
                layer.fill(disc, with: .radialGradient(Gradient(colors: [Color(white: 0.98), Color(red: 0.85, green: 0.84, blue: 0.8)]),
                                                       center: CGPoint(x: center.x - radius * 0.3, y: center.y - radius * 0.3),
                                                       startRadius: 0, endRadius: radius * 1.5))
                // The maria, soft-edged, roughly where the real ones sit.
                layer.drawLayer { maria in
                    maria.addFilter(.blur(radius: radius * 0.07))
                    let seas: [(Double, Double, Double, Double)] = [
                        (-0.42, -0.05, 0.34, 0.5),   // Oceanus Procellarum
                        (-0.18, -0.42, 0.22, 0.45),  // Imbrium
                        (0.18, -0.32, 0.15, 0.45),   // Serenitatis
                        (0.3, -0.04, 0.2, 0.4),      // Tranquillitatis
                        (0.64, -0.2, 0.1, 0.42),     // Crisium
                        (0.46, 0.28, 0.12, 0.35),    // Fecunditatis
                        (0.05, 0.3, 0.13, 0.3),      // Nubium
                    ]
                    for (x, y, r, depth) in seas {
                        let rect = CGRect(x: center.x + x * radius - r * radius, y: center.y + y * radius - r * radius * 0.85,
                                          width: r * radius * 2, height: r * radius * 1.7)
                        maria.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.42, green: 0.43, blue: 0.47).opacity(depth)))
                    }
                }
                // A bright young crater (Tycho) low in the south.
                let tycho = CGRect(x: center.x - radius * 0.14, y: center.y + radius * 0.62, width: radius * 0.07, height: radius * 0.07)
                layer.fill(Path(ellipseIn: tycho), with: .color(.white.opacity(0.7)))
                // Darker toward the edge, as a sphere is.
                layer.fill(disc, with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.22)]),
                                                       center: center, startRadius: radius * 0.55, endRadius: radius))
            }
            // A soft edge between light and dark.
            context.stroke(lit, with: .color(.white.opacity(0.06)), lineWidth: radius * 0.02)
        }
    }

    /// The lit part: the bright half of the disc, with the terminator's half
    /// ellipse added (gibbous) or cut away (crescent). Lit on the right while
    /// waxing, as seen from the northern hemisphere.
    private func litPath(center: CGPoint, radius: CGFloat) -> Path {
        let fraction = phase.fraction
        let waxing = fraction < 0.5
        // Width of the terminator ellipse, 1 at new and full, 0 at quarters.
        let squash = CGFloat(abs(cos(2 * .pi * fraction)))
        let side: CGFloat = waxing ? 1 : -1
        let gibbous = phase.illumination > 0.5
        var path = Path()
        let steps = 48
        // The bright limb, top to bottom.
        for step in 0...steps {
            let angle = -Double.pi / 2 + Double(step) / Double(steps) * .pi
            let point = CGPoint(x: center.x + side * radius * cos(angle), y: center.y + radius * sin(angle))
            step == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        // The terminator, bottom to top.
        for step in 0...steps {
            let angle = Double.pi / 2 - Double(step) / Double(steps) * .pi
            let bulge = (gibbous ? -side : side) * radius * squash * cos(angle)
            path.addLine(to: CGPoint(x: center.x + bulge, y: center.y + radius * sin(angle)))
        }
        path.closeSubpath()
        return path
    }
}
