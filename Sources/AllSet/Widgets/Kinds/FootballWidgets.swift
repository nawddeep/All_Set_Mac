import AllSetCore
import SwiftUI

// Football widgets: a shirt with your name and number, a foil player card,
// a live tactics board, a stadium scoreboard and a milestone counter. All
// original drawings: no club crests, sponsors or real players' likenesses.

// MARK: Shirt

struct JerseyWidget: View {
    let instance: WidgetInstance

    private var player: PlayerDetails { instance.options.player }

    var body: some View {
        let primary = Color(player.primary)
        ZStack {
            FootballBackdrop(color: primary)
            switch instance.size {
            case .small:
                shirt.padding(14)
            case .medium:
                HStack(spacing: 14) {
                    shirt.frame(width: 136)
                    details(nameSize: 30)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            case .large, .extraLarge:
                VStack(spacing: 8) {
                    shirt.padding(.horizontal, 30)
                    VStack(spacing: 2) {
                        Text(player.name.uppercased())
                            .font(.system(size: 26, weight: .black, design: .default).width(.condensed))
                            .tracking(2)
                        if !player.tagline.isEmpty {
                            Text(player.tagline.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(3)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.vertical, 18)
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    private var shirt: some View {
        LiveArtwork(key: "\(player.name)|\(player.number)|\(player.pattern)|\(player.primary)|\(player.secondary)|\(player.trim)",
                    glow: Color(player.primary).mix(.white, 0.25), glowRadius: 14) {
            ShirtArt(player: player)
        }
    }

    private func details(nameSize: CGFloat) -> some View {
        let trim = Color(player.trim).isBright || Color(player.trim).saturationValue > 0.5 ? Color(player.trim) : Color(player.primary).mix(.white, 0.4)
        return VStack(alignment: .leading, spacing: 4) {
            Text("NO.")
                .font(.system(size: 10, weight: .bold))
                .tracking(3)
                .foregroundStyle(trim)
            Text("\(player.number)")
                .font(.system(size: 54, weight: .black).width(.condensed))
                .foregroundStyle(LinearGradient(colors: [trim.mix(.white, 0.5), trim], startPoint: .top, endPoint: .bottom))
                .shadow(color: trim.opacity(0.6), radius: 8)
                .padding(.vertical, -8)
            Text(player.name.uppercased())
                .font(.system(size: nameSize * 0.62, weight: .heavy).width(.condensed))
                .tracking(1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if !player.tagline.isEmpty {
                Text(player.tagline.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The dark stage the football widgets stand on: a floodlit haze in the
/// team's color, a pool of light that breathes, and film grain.
struct FootballBackdrop: View {
    let color: Color

    var body: some View {
        ZStack {
            LinearGradient(colors: [color.mix(.black, 0.72), .black], startPoint: .top, endPoint: .bottom)
            PulsingGlow(color: color, period: 4.2, intensity: 0.9)
                .scaleEffect(1.3)
            // Two floodlights far above.
            RadialGradient(colors: [.white.opacity(0.16), .clear], center: UnitPoint(x: 0.12, y: -0.05), startRadius: 0, endRadius: 120)
            RadialGradient(colors: [.white.opacity(0.16), .clear], center: UnitPoint(x: 0.88, y: -0.05), startRadius: 0, endRadius: 120)
            Grain(opacity: 0.07)
        }
    }
}

/// A football shirt from the back: pattern, collar, cuffs, name and number.
struct ShirtArt: View {
    let player: PlayerDetails

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let rect = CGRect(x: (geometry.size.width - side) / 2, y: (geometry.size.height - side) / 2, width: side, height: side)
            Canvas { context, _ in
                draw(in: context, rect: rect)
            }
            .overlay {
                lettering(side: side)
                    .frame(width: side, height: side)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
    }

    private func draw(in context: GraphicsContext, rect: CGRect) {
        let shape = ShirtShape().path(in: rect)
        let primary = Color(player.primary), secondary = Color(player.secondary), trim = Color(player.trim)
        var inside = context
        inside.clip(to: shape)
        inside.fill(shape, with: .color(primary))
        let w = rect.width, h = rect.height, x0 = rect.minX, y0 = rect.minY
        switch player.pattern {
        case .plain:
            break
        case .stripes:
            for index in 0..<7 where index.isMultiple(of: 2) {
                inside.fill(Path(CGRect(x: x0 + w * (0.12 + 0.108 * Double(index)), y: y0, width: w * 0.108, height: h)),
                            with: .color(secondary))
            }
        case .hoops:
            for index in 0..<8 where index.isMultiple(of: 2) {
                inside.fill(Path(CGRect(x: x0, y: y0 + h * (0.14 + 0.11 * Double(index)), width: w, height: h * 0.11)),
                            with: .color(secondary))
            }
        case .sash:
            var sash = Path()
            sash.move(to: CGPoint(x: x0 + w * 0.2, y: y0))
            sash.addLine(to: CGPoint(x: x0 + w * 0.42, y: y0))
            sash.addLine(to: CGPoint(x: x0 + w * 0.95, y: y0 + h))
            sash.addLine(to: CGPoint(x: x0 + w * 0.73, y: y0 + h))
            sash.closeSubpath()
            inside.fill(sash, with: .color(secondary))
        case .halves:
            inside.fill(Path(CGRect(x: x0 + w * 0.5, y: y0, width: w * 0.5, height: h)), with: .color(secondary))
        case .pinstripes:
            for index in 0..<16 {
                inside.fill(Path(CGRect(x: x0 + w * (0.1 + 0.055 * Double(index)), y: y0, width: max(w * 0.008, 0.8), height: h)),
                            with: .color(secondary.opacity(0.85)))
            }
        case .chevron:
            var chevron = Path()
            chevron.move(to: CGPoint(x: x0, y: y0 + h * 0.22))
            chevron.addLine(to: CGPoint(x: x0 + w * 0.5, y: y0 + h * 0.46))
            chevron.addLine(to: CGPoint(x: x0 + w, y: y0 + h * 0.22))
            chevron.addLine(to: CGPoint(x: x0 + w, y: y0 + h * 0.34))
            chevron.addLine(to: CGPoint(x: x0 + w * 0.5, y: y0 + h * 0.58))
            chevron.addLine(to: CGPoint(x: x0, y: y0 + h * 0.34))
            chevron.closeSubpath()
            inside.fill(chevron, with: .color(secondary))
        }
        // Cuffs and the collar in the trim color.
        for cuff in ShirtShape.cuffs(in: rect) { inside.fill(cuff, with: .color(trim)) }
        inside.stroke(ShirtShape.collar(in: rect), with: .color(trim), lineWidth: w * 0.035)
        // Folds and light: lighter across the shoulders, shadow down the sides.
        inside.fill(shape, with: .linearGradient(Gradient(colors: [.white.opacity(0.22), .clear, .black.opacity(0.28)]),
                                                 startPoint: CGPoint(x: rect.midX, y: y0), endPoint: CGPoint(x: rect.midX, y: y0 + h)))
        inside.fill(shape, with: .linearGradient(Gradient(stops: [.init(color: .black.opacity(0.35), location: 0.18),
                                                                 .init(color: .clear, location: 0.32),
                                                                 .init(color: .clear, location: 0.68),
                                                                 .init(color: .black.opacity(0.35), location: 0.82)]),
                                                 startPoint: CGPoint(x: x0, y: rect.midY), endPoint: CGPoint(x: x0 + w, y: rect.midY)))
        // Two soft folds hanging from the shoulders.
        for x in [0.3, 0.7] {
            var fold = Path()
            fold.move(to: CGPoint(x: x0 + w * x, y: y0 + h * 0.3))
            fold.addQuadCurve(to: CGPoint(x: x0 + w * (x < 0.5 ? x + 0.04 : x - 0.04), y: y0 + h * 0.95),
                              control: CGPoint(x: x0 + w * (x < 0.5 ? x - 0.03 : x + 0.03), y: y0 + h * 0.62))
            inside.stroke(fold, with: .color(.black.opacity(0.1)), style: StrokeStyle(lineWidth: w * 0.03, lineCap: .round))
        }
        context.stroke(shape, with: .color(.black.opacity(0.35)), lineWidth: max(w * 0.006, 0.6))
    }

    private func lettering(side: CGFloat) -> some View {
        let trim = Color(player.trim)
        return VStack(spacing: side * 0.01) {
            Text(player.name.uppercased())
                .font(.system(size: side * 0.075, weight: .heavy).width(.condensed))
                .tracking(side * 0.008)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(width: side * 0.46)
            Text("\(player.number)")
                .font(.system(size: side * 0.34, weight: .black).width(.condensed))
                .monospacedDigit()
                .shadow(color: .black.opacity(0.35), radius: 0, x: side * 0.008, y: side * 0.01)
        }
        .foregroundStyle(LinearGradient(colors: [trim.mix(.white, 0.35), trim], startPoint: .top, endPoint: .bottom))
        .offset(y: side * 0.04)
    }
}

/// A shirt seen from the back, in a square.
struct ShirtShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y) }
        var path = Path()
        path.move(to: p(0.37, 0.05))
        path.addLine(to: p(0.17, 0.1))
        path.addQuadCurve(to: p(0.01, 0.34), control: p(0.07, 0.14))
        path.addLine(to: p(0.14, 0.43))
        path.addLine(to: p(0.23, 0.31))
        path.addQuadCurve(to: p(0.22, 0.96), control: p(0.2, 0.62))
        path.addQuadCurve(to: p(0.78, 0.96), control: p(0.5, 0.99))
        path.addQuadCurve(to: p(0.77, 0.31), control: p(0.8, 0.62))
        path.addLine(to: p(0.86, 0.43))
        path.addLine(to: p(0.99, 0.34))
        path.addQuadCurve(to: p(0.83, 0.1), control: p(0.93, 0.14))
        path.addLine(to: p(0.63, 0.05))
        path.addQuadCurve(to: p(0.37, 0.05), control: p(0.5, 0.11))
        path.closeSubpath()
        return path
    }

    static func collar(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.37, y: rect.minY + rect.height * 0.052))
        path.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.63, y: rect.minY + rect.height * 0.052),
                          control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.115))
        return path
    }

    static func cuffs(in rect: CGRect) -> [Path] {
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y) }
        var left = Path()
        left.move(to: p(0.01, 0.34))
        left.addLine(to: p(0.14, 0.43))
        left.addLine(to: p(0.16, 0.4))
        left.addLine(to: p(0.035, 0.31))
        left.closeSubpath()
        var right = Path()
        right.move(to: p(0.99, 0.34))
        right.addLine(to: p(0.86, 0.43))
        right.addLine(to: p(0.84, 0.4))
        right.addLine(to: p(0.965, 0.31))
        right.closeSubpath()
        return [left, right]
    }
}

// MARK: Player card

struct PlayerCardWidget: View {
    let instance: WidgetInstance
    let library: ImageLibrary

    @State private var photo: NSImage?
    /// The player lifted out of the photo, framed to them.
    @State private var cutout: NSImage?
    private var player: PlayerDetails { instance.options.player }
    private var source: ImageSource? { instance.options.images.first }

    init(instance: WidgetInstance, library: ImageLibrary) {
        self.instance = instance
        self.library = library
        // Ready already (the Themes page makes them ahead): drawn at once, even in pictures.
        let source = instance.options.images.first
        _photo = State(initialValue: source.flatMap { library.cachedImage(for: $0, maxPixels: 700) })
        _cutout = State(initialValue: source.flatMap(SubjectCutout.known).flatMap(Self.framed))
    }

    var body: some View {
        let accent = CardPalette(finish: player.finish, accent: Color(player.primary))
        ZStack {
            FootballBackdrop(color: accent.glow)
            if player.finish == .legend || player.finish == .holo {
                Sparkles(color: .white, density: 0.8)
            }
            switch instance.size {
            case .small:
                card(accent).padding(.vertical, 12).padding(.horizontal, 26)
            case .medium:
                HStack(spacing: 18) {
                    card(accent).frame(width: 106)
                    statsPanel(accent)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
            case .large, .extraLarge:
                card(accent).padding(.vertical, 18).padding(.horizontal, 64)
            }
        }
        .environment(\.colorScheme, .dark)
        .task(id: source) {
            guard let source else {
                photo = nil
                return
            }
            photo = await library.image(for: source, maxPixels: 700)
            cutout = await SubjectCutout.cutout(for: source, library: library).flatMap(Self.framed)
        }
    }

    /// The cutout cropped to the player from the head to about the waist, like
    /// a rating card's portrait, so they fill the card's window.
    static func framed(_ cutout: SubjectCutout.Cutout) -> NSImage? {
        guard let image = cutout.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let side = SubjectCutout.Cutout.side
        var minX = side, maxX = -1, minY = side, maxY = -1
        for row in 0..<side {
            for column in 0..<side where cutout.grid[row * side + column] > 0.08 {
                minX = min(minX, column)
                maxX = max(maxX, column)
                minY = min(minY, row)
                maxY = max(maxY, row)
            }
        }
        guard maxX >= minX else { return nil }
        let w = Double(image.width), h = Double(image.height)
        let cell = (x: w / Double(side), y: h / Double(side))
        var rect = CGRect(x: Double(minX) * cell.x, y: Double(minY) * cell.y,
                          width: Double(maxX - minX + 1) * cell.x, height: h - Double(minY) * cell.y)
        let figure = Double(maxY - minY + 1) * cell.y
        rect = rect.insetBy(dx: -rect.width * 0.08, dy: 0)
        rect.origin.y = max(rect.minY - figure * 0.04, 0)
        // Head to waist: the top of the figure, whatever its pose.
        rect.size.height = min(h - rect.minY, max(figure * 0.62, h * 0.25))
        guard let cropped = image.cropping(to: rect.intersection(CGRect(x: 0, y: 0, width: w, height: h)).integral) else { return nil }
        return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
    }

    private func card(_ palette: CardPalette) -> some View {
        LiveArtwork(key: "\(player)|\(photo.map { ObjectIdentifier($0).hashValue } ?? 0)|\(cutout.map { ObjectIdentifier($0).hashValue } ?? 0)|\(instance.size)",
                    glow: palette.glow, glowRadius: 14, shinePeriod: 5) {
            PlayerCardArt(player: player, photo: photo, cutout: cutout, palette: palette, showsStats: instance.size != .medium)
        }
    }

    private func statsPanel(_ palette: CardPalette) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(player.name.uppercased())
                .font(.system(size: 20, weight: .black).width(.condensed))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(.white)
            ForEach(Array(PlayerDetails.statNames.enumerated()), id: \.offset) { index, name in
                let value = player.stats[index]
                HStack(spacing: 8) {
                    Text(name)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 26, alignment: .leading)
                    GeometryReader { geometry in
                        Capsule().fill(.white.opacity(0.1))
                            .overlay(alignment: .leading) {
                                Capsule().fill(palette.bar)
                                    .frame(width: geometry.size.width * Double(min(max(value, 0), 99)) / 99)
                                    .shadow(color: palette.glow.opacity(0.8), radius: 4)
                            }
                    }
                    .frame(height: 5)
                    Text("\(value)")
                        .font(.system(size: 11, weight: .heavy).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(width: 20, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The colors of a card's finish.
struct CardPalette {
    let fill: AnyShapeStyle
    let ink: Color
    let edge: Color
    let glow: Color
    let bar: Color

    init(finish: CardFinish, accent: Color) {
        switch finish {
        case .gold:
            fill = AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFBEFA5), Color(hex: 0xD6AE3F), Color(hex: 0xF7E08C), Color(hex: 0xB8862B)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
            ink = Color(hex: 0x3A2A08)
            edge = Color(hex: 0xFFF6C8)
            glow = Color(hex: 0xE8C15A)
            bar = Color(hex: 0xF3D36B)
        case .legend:
            fill = AnyShapeStyle(LinearGradient(colors: [.white, Color(hex: 0xEFE7D2), .white, Color(hex: 0xD8C79E)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
            ink = Color(hex: 0x3B3220)
            edge = Color(hex: 0xE9D9A6)
            glow = Color(hex: 0xF5E7BE)
            bar = Color(hex: 0xE9D9A6)
        case .night:
            fill = AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x2A2A2A), Color(hex: 0x080808), Color(hex: 0x1C1C1C)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
            ink = Color(hex: 0xF3D36B)
            edge = Color(hex: 0xE8C15A)
            glow = Color(hex: 0xE8C15A)
            bar = Color(hex: 0xE8C15A)
        case .neon:
            fill = AnyShapeStyle(LinearGradient(colors: [accent.mix(.black, 0.75), Color(hex: 0x05050C), accent.mix(.black, 0.6)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
            ink = .white
            edge = accent.mix(.white, 0.3)
            glow = accent
            bar = accent.mix(.white, 0.2)
        case .holo:
            fill = AnyShapeStyle(AngularGradient(colors: [Color(hex: 0xFFD6F6), Color(hex: 0xC9F2FF), Color(hex: 0xE6FFD6),
                                                          Color(hex: 0xFFF4C9), Color(hex: 0xE7D6FF), Color(hex: 0xFFD6F6)],
                                                 center: .center))
            ink = Color(hex: 0x2B2440)
            edge = .white
            glow = Color(hex: 0xC9B6FF)
            bar = Color(hex: 0xB9A2EE)
        }
    }
}

extension Color {
    init(hex: Int) { self.init(WidgetColor(hex: hex)) }
}
