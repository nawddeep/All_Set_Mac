import AllSetCore
import SwiftUI

// Music widgets: a mixtape whose reels turn with the music, a photo on an old
// VHS tape, a visualizer, a ticket stub and word art. The motion (reels,
// tracking noise, bars, sparkles, shine) runs in Core Animation.

// MARK: Cassette

struct CassetteWidget: View {
    let instance: WidgetInstance
    let media: MediaController

    var body: some View {
        let tint = Color(instance.tint)
        let info = media.info
        let title = info.map { $0.title.isEmpty ? "Unknown title" : $0.title } ?? instance.options.customText
        let artist = info.map { $0.artist.isEmpty ? $0.album : $0.artist } ?? ""
        let progress = info.flatMap { info in info.duration.map { info.elapsed() / max($0, 1) } } ?? 0.35
        ZStack {
            LinearGradient(colors: [tint.mix(.black, 0.8), .black], startPoint: .top, endPoint: .bottom)
            PulsingGlow(color: tint, period: 4, intensity: 0.7).scaleEffect(1.2)
            Grain(opacity: 0.08)
            switch instance.size {
            case .small:
                CassetteArt(title: title, tint: tint, progress: progress, playing: info?.isPlaying ?? false)
                    .padding(12)
            case .medium:
                CassetteArt(title: title, tint: tint, progress: progress, playing: info?.isPlaying ?? false)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 40)
            case .large, .extraLarge:
                VStack(spacing: 14) {
                    CassetteArt(title: title, tint: tint, progress: progress, playing: info?.isPlaying ?? false)
                        .frame(height: 196)
                    VStack(spacing: 3) {
                        Text(info == nil ? "Nothing playing" : title)
                            .font(.system(size: 16, weight: .semibold))
                        Text(info == nil ? "Press play and the reels turn" : artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .lineLimit(1)
                    MediaButtons(media: media)
                }
                .padding(18)
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}

/// Back, play and skip, for music widgets.
struct MediaButtons: View {
    let media: MediaController

    var body: some View {
        let info = media.info
        HStack(spacing: 26) {
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

/// A cassette: smoky shell, a handwritten label, and two reels whose tape
/// moves from left to right as the song plays.
struct CassetteArt: View {
    let title: String
    let tint: Color
    let progress: Double
    let playing: Bool

    @State private var hub: CGImage?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            let w = min(geometry.size.width, geometry.size.height * 1.58)
            let h = w / 1.58
            ZStack {
                shell(w: w, h: h)
                label(w: w, h: h)
                    .frame(width: w * 0.86, height: h * 0.6)
                    .position(x: w / 2, y: h * 0.39)
                reels(w: w, h: h)
                foot(w: w, h: h)
            }
            .frame(width: w, height: h)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shadow(color: tint.opacity(0.45), radius: 14)
        }
        .task(id: displayScale) {
            let renderer = ImageRenderer(content: ReelHub().frame(width: 60, height: 60))
            renderer.scale = max(displayScale, 2)
            hub = renderer.cgImage
        }
    }

    private func shell(w: CGFloat, h: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: w * 0.05, style: .continuous)
        return ZStack {
            shape.fill(LinearGradient(colors: [tint.mix(.black, 0.45).opacity(0.95), Color(white: 0.06).opacity(0.97)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            shape.strokeBorder(.white.opacity(0.18), lineWidth: 1)
            // Screws in the corners and the middle of the foot.
            ForEach(Array([CGPoint(x: 0.04, y: 0.06), CGPoint(x: 0.96, y: 0.06), CGPoint(x: 0.04, y: 0.94),
                           CGPoint(x: 0.96, y: 0.94), CGPoint(x: 0.5, y: 0.9)].enumerated()), id: \.offset) { _, point in
                Circle().fill(Color(white: 0.55)).frame(width: w * 0.022)
                    .overlay(Rectangle().fill(.black.opacity(0.6)).frame(width: w * 0.016, height: 0.8))
                    .position(x: w * point.x, y: h * point.y)
            }
        }
    }

    private func label(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: w * 0.02).fill(Color(hex: 0xF3EBDD))
            VStack(spacing: h * 0.018) {
                Rectangle().fill(tint).frame(height: h * 0.035)
                Rectangle().fill(tint.mix(.white, 0.35)).frame(height: h * 0.02)
                Spacer()
                Rectangle().fill(tint.mix(.white, 0.35)).frame(height: h * 0.02)
            }
            .padding(.top, h * 0.03)
            .padding(.bottom, h * 0.03)
            HStack(alignment: .firstTextBaseline, spacing: w * 0.02) {
                Text("A")
                    .font(.system(size: h * 0.13, weight: .black))
                    .foregroundStyle(tint.mix(.black, 0.3))
                Text(title.isEmpty ? "summer mix" : title)
                    .font(.custom("Bradley Hand", size: h * 0.1))
                    .fontDesign(nil)
                    .foregroundStyle(Color(hex: 0x1F2A6B))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 0)
                Text("90 MIN")
                    .font(.system(size: h * 0.045, weight: .bold))
                    .foregroundStyle(.black.opacity(0.45))
            }
            .padding(.horizontal, w * 0.04)
            .padding(.top, h * 0.1)
        }
    }

    private func reels(w: CGFloat, h: CGFloat) -> some View {
        let window = CGRect(x: w * 0.24, y: h * 0.4, width: w * 0.52, height: h * 0.2)
        let clamped = min(max(progress, 0), 1)
        let hubSide = h * 0.17
        let smallest = hubSide * 0.62, largest = h * 0.19
        return ZStack {
            RoundedRectangle(cornerRadius: h * 0.05).fill(Color.black.opacity(0.78))
                .overlay(RoundedRectangle(cornerRadius: h * 0.05).strokeBorder(.white.opacity(0.15), lineWidth: 0.8))
                .frame(width: window.width, height: window.height)
                .position(x: window.midX, y: window.midY)
            // Tape wound on each reel.
            ForEach(0..<2, id: \.self) { side in
                let radius = smallest + (largest - smallest) * (side == 0 ? 1 - clamped : clamped)
                let x = side == 0 ? w * 0.33 : w * 0.67
                Circle().fill(Color(hex: 0x2A1C16))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(x: x, y: window.midY)
                    .mask(Rectangle().frame(width: window.width, height: window.height).position(x: window.midX, y: window.midY))
                Group {
                    if let hub {
                        SpinningImage(image: hub, isSpinning: playing, secondsPerTurn: 2.4)
                    } else {
                        ReelHub()
                    }
                }
                .frame(width: hubSide, height: hubSide)
                .position(x: x, y: window.midY)
            }
        }
    }

    private func foot(w: CGFloat, h: CGFloat) -> some View {
        var path = Path()
        path.move(to: CGPoint(x: w * 0.18, y: h))
        path.addLine(to: CGPoint(x: w * 0.24, y: h * 0.8))
        path.addLine(to: CGPoint(x: w * 0.76, y: h * 0.8))
        path.addLine(to: CGPoint(x: w * 0.82, y: h))
        return ZStack {
            path.fill(Color.black.opacity(0.35))
            path.stroke(.white.opacity(0.15), lineWidth: 0.8)
            ForEach([0.38, 0.62], id: \.self) { x in
                Circle().fill(.black.opacity(0.8)).frame(width: w * 0.035).position(x: w * x, y: h * 0.9)
            }
        }
    }
}

/// The white plastic hub a reel turns on.
private struct ReelHub: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().fill(Color(white: 0.92))
                Circle().fill(Color(white: 0.25)).frame(width: side * 0.42)
                ForEach(0..<6, id: \.self) { index in
                    Rectangle().fill(Color(white: 0.92))
                        .frame(width: side * 0.08, height: side * 0.16)
                        .offset(y: -side * 0.17)
                        .rotationEffect(.degrees(Double(index) * 60))
                }
                Circle().strokeBorder(Color(white: 0.7), lineWidth: side * 0.03)
            }
            .frame(width: side, height: side)
        }
    }
}

// MARK: VHS

/// A photo as a frame of home video: soft colors, scanlines, a tracking band
/// rolling through, REC blinking and the date in the corner.
struct VHSWidget: View {
    let instance: WidgetInstance
    let library: ImageLibrary

    var body: some View {
        let options = instance.options
        let source = options.images.first ?? .art(ArtPiece(style: .sunset, palette: .peach))
        let small = instance.size == .small
        let osd = Font.system(size: small ? 10 : 13, weight: .bold, design: .monospaced)
        ZStack {
            PhotoContent(source: source, filter: options.photoFilter, tint: .white, animated: false, library: library, maxPixels: 900)
                .saturation(1.15)
                .blur(radius: 0.5)
                .overlay(Rectangle().fill(LinearGradient(colors: [Color(hex: 0xFF7A59).opacity(0.18), Color(hex: 0x3A7BD5).opacity(0.14)],
                                                         startPoint: .top, endPoint: .bottom)).blendMode(.softLight))
            Scanlines()
            TrackingBand()
            RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center, startRadius: 60, endRadius: 260)
            VStack {
                HStack {
                    HStack(spacing: 5) {
                        BlinkingLight(color: Color(hex: 0xFF2D2D), period: 1.4).frame(width: small ? 7 : 9, height: small ? 7 : 9)
                        WidgetWord("REC")
                    }
                    Spacer()
                    Text(small ? "SP" : "PLAY ▶  SP")
                }
                Spacer()
                HStack(alignment: .bottom) {
                    Text(options.caption.isEmpty ? "SUMMER 1996" : options.caption.uppercased())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    WidgetTimeline(.everyMinute) { context in
                        Text(context.date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute()).uppercased())
                    }
                }
            }
            .font(osd)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 0, x: 1, y: 1)
            .shadow(color: .white.opacity(0.35), radius: 3)
            .padding(small ? 10 : 14)
        }
        .environment(\.colorScheme, .dark)
    }
}

/// Dark lines every third point, like a picture on a CRT.
private struct Scanlines: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            var y = 0.0
            while y < size.height {
                path.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
                y += 3
            }
            context.fill(path, with: .color(.black.opacity(0.2)))
        }
        .allowsHitTesting(false)
    }
}

// MARK: Visualizer

struct VisualizerWidget: View {
    let instance: WidgetInstance
    let media: MediaController

    var body: some View {
        let tint = Color(instance.tint)
        let colors = [tint.mix(.black, 0.35), tint, tint.mix(.white, 0.6)]
        let info = media.info
        let playing = info?.isPlaying ?? false
        let style = instance.options.visualizer
        ZStack {
            LinearGradient(colors: [tint.mix(.black, 0.85), .black], startPoint: .top, endPoint: .bottom)
            PulsingGlow(color: tint, period: playing ? 1.8 : 4.5, intensity: 0.6).scaleEffect(1.2)
            if style == .ring {
                ZStack {
                    EqualizerBars(style: .ring, colors: colors, isPlaying: playing, count: 48)
                    artwork(tint: tint)
                        .frame(width: instance.size == .small ? 62 : 104, height: instance.size == .small ? 62 : 104)
                    if instance.size == .large {
                        VStack {
                            Spacer()
                            caption(info)
                        }
                        .padding(.bottom, 16)
                    }
                }
                .padding(instance.size == .small ? 6 : 10)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if instance.size != .small { caption(info) }
                    EqualizerBars(style: style, colors: colors, isPlaying: playing,
                                  count: instance.size == .small ? 14 : 30)
                }
                .padding(instance.size == .small ? 14 : 18)
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    private func artwork(tint: Color) -> some View {
        ZStack {
            if let artwork = media.artwork {
                Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [tint, tint.mix(.black, 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note").font(.system(size: 26, weight: .semibold))
            }
        }
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
        .shadow(color: tint.opacity(0.8), radius: 12)
    }

    private func caption(_ info: NowPlayingInfo?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(info.map { $0.title.isEmpty ? "Unknown title" : $0.title } ?? "Play something")
                .font(.system(size: 14, weight: .semibold))
            Text(info.map { $0.artist.isEmpty ? $0.album : $0.artist } ?? "The bars dance to your music")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
        }
        .lineLimit(1)
    }
}

// MARK: Ticket

/// A ticket stub: the show, the venue, a barcode, and the days to go.
struct TicketWidget: View {
    let instance: WidgetInstance

    var body: some View {
        let ticket = instance.options.ticket
        LiveArtwork(key: "\(ticket)|\(instance.tint)|\(instance.size)|\(Calendar.current.startOfDay(for: .now))",
                    glow: nil, float: true, shine: true, shinePeriod: 7) {
            TicketArt(ticket: ticket, accent: Color(instance.tint), compact: instance.size == .small)
        }
        .padding(instance.size == .small ? 8 : 6)
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
    }
}

struct TicketArt: View {
    let ticket: TicketDetails
    let accent: Color
    var compact = false

    private static let paper = Color(hex: 0xF5EFE3)
    private static let ink = Color(hex: 0x1C1A17)

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width, h = geometry.size.height
            let tear = compact ? 0.62 : 0.72
            ZStack(alignment: .topLeading) {
                TicketShape(tear: tear).fill(Self.paper)
                // A colored band down the left.
                TicketShape(tear: tear).fill(accent).mask(alignment: .leading) {
                    Rectangle().frame(width: w * 0.05)
                }
                Path { path in
                    path.move(to: CGPoint(x: w * tear, y: h * 0.12))
                    path.addLine(to: CGPoint(x: w * tear, y: h * 0.88))
                }
                .stroke(Self.ink.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                main(w: w * tear, h: h)
                    .frame(width: w * tear, height: h)
                stub(w: w * (1 - tear), h: h)
                    .frame(width: w * (1 - tear), height: h)
                    .offset(x: w * tear)
            }
            .foregroundStyle(Self.ink)
        }
    }

    private func main(w: CGFloat, h: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: h * 0.03) {
            Text(compact ? "ADMIT ONE" : "ADMIT ONE · \(ticket.seat.uppercased())")
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .font(.system(size: h * 0.065, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(accent.mix(.black, 0.35))
            Text(ticket.headline.uppercased())
                .font(.system(size: h * (compact ? 0.17 : 0.2), weight: .black).width(.compressed))
                .lineLimit(2)
                .minimumScaleFactor(0.5)
            if !compact {
                Text(ticket.subtitle)
                    .font(.system(size: h * 0.085, design: .serif).italic())
                    .lineLimit(1)
                    .opacity(0.75)
            }
            Spacer(minLength: 0)
            HStack(spacing: w * 0.05) {
                if let date = ticket.date {
                    Text(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased())
                }
                if !compact {
                    Text(ticket.venue.uppercased()).lineLimit(1)
                }
            }
            .font(.system(size: h * 0.065, weight: .semibold, design: .monospaced))
            .opacity(0.8)
        }
        .padding(.leading, w * 0.13)
        .padding(.trailing, w * 0.05)
        .padding(.vertical, h * 0.12)
    }

    private func stub(w: CGFloat, h: CGFloat) -> some View {
        VStack(spacing: h * 0.03) {
            WidgetTimeline(.everyMinute) { context in
                let days = ticket.date.map { Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: context.date),
                                                                               to: Calendar.current.startOfDay(for: $0)).day ?? 0 }
                VStack(spacing: 0) {
                    Text(days.map { $0 > 0 ? "\($0)" : $0 == 0 ? "TONIGHT" : "SEEN" } ?? "SOON")
                        .font(.system(size: h * (days.map { $0 > 0 } ?? false ? 0.24 : 0.1), weight: .black).width(.condensed))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    if let days, days > 0 {
                        Text(days == 1 ? "DAY TO GO" : "DAYS TO GO")
                            .font(.system(size: h * 0.05, weight: .bold))
                            .tracking(1)
                    }
                }
            }
            Barcode(seed: ticket.headline)
                .frame(height: h * 0.2)
                .padding(.horizontal, w * 0.12)
        }
        .padding(.vertical, h * 0.14)
        .frame(maxWidth: .infinity)
    }
}

/// A ticket with rounded corners and a notch at each end of the tear line.
struct TicketShape: Shape {
    let tear: Double

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.height * 0.08, 12)
        let notch = min(rect.height * 0.08, 10)
        let x = rect.minX + rect.width * tear
        var notches = Path()
        notches.addEllipse(in: CGRect(x: x - notch, y: rect.minY - notch, width: notch * 2, height: notch * 2))
        notches.addEllipse(in: CGRect(x: x - notch, y: rect.maxY - notch, width: notch * 2, height: notch * 2))
        return Path(roundedRect: rect, cornerRadius: radius, style: .continuous).subtracting(notches)
    }
}

/// Bars of pseudo-random widths from the text, so each ticket has its own.
struct Barcode: View {
    let seed: String

    var body: some View {
        Canvas { context, size in
            var hash = UInt64(5381)
            for byte in seed.utf8 { hash = hash &* 33 &+ UInt64(byte) }
            var x = 0.0
            while x < size.width {
                hash = hash &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let width = Double(1 + (hash >> 60) % 3)
                if (hash >> 58) % 3 != 0 {
                    context.fill(Path(CGRect(x: x, y: 0, width: width, height: size.height)), with: .color(.primary))
                }
                x += width + 1
            }
        }
    }
}

// MARK: Word Art

struct WordArtWidget: View {
    let instance: WidgetInstance

    var body: some View {
        let options = instance.options
        let text = options.customText.isEmpty ? "Legend" : options.customText
        let tint = Color(instance.tint)
        let size: CGFloat = switch instance.size {
        case .small: 40
        case .medium: 60
        case .large, .extraLarge: 86
        }
        ZStack {
            LiveArtwork(key: "\(text)|\(options.wordArt)|\(options.textStyle)|\(instance.tint)|\(instance.size)",
                        glow: WordArtText.glow(options.wordArt, tint: tint), glowRadius: 12,
                        float: false, shine: options.wordArt != .neon, shinePeriod: 4.5) {
                WordArtText(text: text, finish: options.wordArt, style: options.textStyle, tint: tint, size: size)
            }
            if options.wordArt == .glitter || options.wordArt == .holo {
                Sparkles(color: tint.mix(.white, 0.6), density: 1.6)
                    .padding(instance.size == .small ? 16 : 24)
            }
        }
    }
}

struct WordArtText: View {
    let text: String
    let finish: WordArtFinish
    let style: TextStyle
    let tint: Color
    let size: CGFloat

    static func glow(_ finish: WordArtFinish, tint: Color) -> Color {
        switch finish {
        case .chrome: .white.opacity(0.55)
        case .gold: Color(hex: 0xE8C15A)
        case .neon, .glitter: tint
        case .fire: Color(hex: 0xFF6A00)
        case .ice: Color(hex: 0x7FD8FF)
        case .holo: Color(hex: 0xC9B6FF)
        }
    }

    var body: some View {
        Text(text)
            .textStyle(style, size: size)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.25)
            .padding(.horizontal, size * 0.2)
            .foregroundStyle(fill)
            .overlay {
                if finish == .glitter {
                    GlitterTexture()
                        .mask(Text(text).textStyle(style, size: size).multilineTextAlignment(.center).lineLimit(3)
                              .minimumScaleFactor(0.25).padding(.horizontal, size * 0.2))
                }
            }
            .shadow(color: finish == .neon ? tint : .black.opacity(0.45), radius: finish == .neon ? 2 : 0, x: 0, y: finish == .neon ? 0 : 1.5)
            .shadow(color: finish == .neon ? tint.opacity(0.9) : .clear, radius: 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fill: AnyShapeStyle {
        func vertical(_ hexes: [(Int, Double)]) -> AnyShapeStyle {
            AnyShapeStyle(LinearGradient(stops: hexes.map { .init(color: Color(hex: $0.0), location: $0.1) },
                                         startPoint: .top, endPoint: .bottom))
        }
        switch finish {
        case .chrome:
            return vertical([(0xFFFFFF, 0), (0xC9D1DE, 0.38), (0x3A3F4B, 0.52), (0xF2F5FA, 0.64), (0x8A93A6, 1)])
        case .gold:
            return vertical([(0xFFF6C8, 0), (0xE8C15A, 0.4), (0x8A6A1F, 0.54), (0xF6E27A, 0.68), (0xB8862B, 1)])
        case .neon:
            return AnyShapeStyle(tint.mix(.white, 0.72))
        case .glitter:
            return AnyShapeStyle(LinearGradient(colors: [tint.mix(.white, 0.45), tint, tint.mix(.black, 0.25)],
                                                startPoint: .top, endPoint: .bottom))
        case .fire:
            return vertical([(0xFFF4B0, 0), (0xFFB347, 0.35), (0xFF5E00, 0.7), (0xB3001B, 1)])
        case .ice:
            return vertical([(0xFFFFFF, 0), (0xBDEBFF, 0.4), (0x5BC0EB, 0.6), (0xE0F7FF, 1)])
        case .holo:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFB3E6), Color(hex: 0xB3E5FF), Color(hex: 0xD4FFB3),
                                                         Color(hex: 0xFFF1B3), Color(hex: 0xD9B3FF)],
                                                startPoint: .leading, endPoint: .trailing))
        }
    }
}

/// White specks for glitter letters.
private struct GlitterTexture: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x2545_F491_4F6C_DD1D
            let count = Int(size.width * size.height / 18)
            for _ in 0..<count {
                seed ^= seed << 13
                seed ^= seed >> 7
                seed ^= seed << 17
                let x = Double(seed % 10_000) / 10_000 * size.width
                let y = Double((seed >> 20) % 10_000) / 10_000 * size.height
                let r = 0.4 + Double((seed >> 40) % 100) / 100
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(.white.opacity(0.35 + Double((seed >> 50) % 60) / 100)))
            }
        }
        .blendMode(.screen)
    }
}
