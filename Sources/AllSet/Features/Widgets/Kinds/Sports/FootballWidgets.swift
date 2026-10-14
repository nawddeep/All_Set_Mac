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

/// The card itself: rating, position, portrait, name and stats on foil.
struct PlayerCardArt: View {
    let player: PlayerDetails
    let photo: NSImage?
    var cutout: NSImage?
    let palette: CardPalette
    var showsStats = true

    var body: some View {
        GeometryReader { geometry in
            let w = min(geometry.size.width, geometry.size.height * 0.72)
            let h = w / 0.72
            ZStack {
                PlayerCardShape().fill(palette.fill)
                PlayerCardShape().inset(by: w * 0.035).stroke(palette.edge.opacity(0.9), lineWidth: max(w * 0.012, 1))
                // Foil texture: fine diagonal lines.
                Canvas { context, size in
                    var index = -Int(size.height / 4)
                    while Double(index) * 4 < size.width {
                        var line = Path()
                        line.move(to: CGPoint(x: Double(index) * 4, y: 0))
                        line.addLine(to: CGPoint(x: Double(index) * 4 + size.height, y: size.height))
                        context.stroke(line, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
                        index += 1
                    }
                }
                .clipShape(PlayerCardShape())
                content(w: w, h: h)
            }
            .frame(width: w, height: h)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func content(w: CGFloat, h: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                portrait(w: w)
                    .frame(width: w * 0.8, height: h * (showsStats ? 0.5 : 0.62))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                VStack(spacing: 0) {
                    Text("\(player.rating)")
                        .font(.system(size: w * 0.2, weight: .black).width(.condensed))
                        .monospacedDigit()
                    Text(player.position.uppercased())
                        .font(.system(size: w * 0.075, weight: .bold))
                        .padding(.top, -w * 0.02)
                    Rectangle().fill(palette.ink.opacity(0.4)).frame(width: w * 0.12, height: 1).padding(.vertical, w * 0.02)
                    Text("\(player.number)")
                        .font(.system(size: w * 0.07, weight: .heavy))
                }
                .padding(.leading, w * 0.1)
                .padding(.top, w * 0.12)
            }
            .frame(height: h * (showsStats ? 0.55 : 0.68))
            Text(player.name.uppercased())
                .font(.system(size: w * 0.105, weight: .black).width(.condensed))
                .tracking(w * 0.006)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, w * 0.1)
            if !player.tagline.isEmpty {
                Text(player.tagline.uppercased())
                    .font(.system(size: w * 0.045, weight: .semibold))
                    .tracking(w * 0.01)
                    .opacity(0.7)
                    .lineLimit(1)
            }
            Rectangle().fill(palette.ink.opacity(0.35)).frame(width: w * 0.62, height: 1).padding(.vertical, w * 0.025)
            if showsStats {
                HStack(spacing: w * 0.08) {
                    statColumn(0..<3, w: w)
                    Rectangle().fill(palette.ink.opacity(0.35)).frame(width: 1, height: w * 0.26)
                    statColumn(3..<6, w: w)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(palette.ink)
    }

    private func statColumn(_ range: Range<Int>, w: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: w * 0.012) {
            ForEach(range, id: \.self) { index in
                HStack(spacing: w * 0.03) {
                    Text("\(player.stats[index])").font(.system(size: w * 0.068, weight: .heavy).monospacedDigit())
                    Text(PlayerDetails.statNames[index]).font(.system(size: w * 0.058, weight: .medium))
                }
            }
        }
    }

    @ViewBuilder
    private func portrait(w: CGFloat) -> some View {
        if let cutout {
            // The player standing on the foil, fading out at the feet.
            Color.clear
                .overlay(alignment: .top) {
                    Image(nsImage: cutout)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .clipped()
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.72), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.35), radius: w * 0.02, y: w * 0.01)
        } else if let photo {
            Image(nsImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.6), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                .mask(PlayerCardShape.window())
        } else {
            Image(systemName: "figure.soccer")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(w * 0.05)
                .foregroundStyle(palette.ink.opacity(0.85))
                .shadow(color: .white.opacity(0.3), radius: 4)
        }
    }
}

/// A shield: cut top corners and a pointed foot.
struct PlayerCardShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y) }
        var path = Path()
        path.move(to: p(0.14, 0))
        path.addLine(to: p(0.42, 0))
        path.addQuadCurve(to: p(0.58, 0), control: p(0.5, 0.035))
        path.addLine(to: p(0.86, 0))
        path.addQuadCurve(to: p(1, 0.08), control: p(0.9, 0.07))
        path.addLine(to: p(1, 0.84))
        path.addQuadCurve(to: p(0.5, 1), control: p(0.98, 0.93))
        path.addQuadCurve(to: p(0, 0.84), control: p(0.02, 0.93))
        path.addLine(to: p(0, 0.08))
        path.addQuadCurve(to: p(0.14, 0), control: p(0.1, 0.07))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> PlayerCardShape {
        var shape = self
        shape.inset += amount
        return shape
    }

    /// The portrait's arch.
    static func window() -> some Shape {
        UnevenRoundedRectangle(topLeadingRadius: 60, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 60)
    }
}

// MARK: Tactics board

struct PitchWidget: View {
    let instance: WidgetInstance

    private var match: MatchDetails { instance.options.match }

    var body: some View {
        ZStack {
            Color.black
            switch instance.size {
            case .large:
                VStack(spacing: 0) {
                    pitch.frame(height: 226)
                    MatchLine(match: match, large: true)
                        .frame(maxHeight: .infinity)
                }
            default:
                pitch
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    private var pitch: some View {
        let home = Color(match.homeColor), away = Color(match.awayColor)
        let spots = Self.positions(match.formation)
        return ZStack {
            Canvas { context, size in
                Self.drawPitch(context, size: size)
            }
            GeometryReader { geometry in
                let size = geometry.size
                ForEach(Array(spots.enumerated()), id: \.offset) { index, spot in
                    player(color: home, number: Self.numbers[index])
                        .position(x: spot.x * size.width, y: spot.y * size.height)
                    player(color: away, number: Self.numbers[index])
                        .position(x: (1 - spot.x) * size.width, y: (1 - spot.y) * size.height)
                        .opacity(0.8)
                }
            }
            BallInPlay(points: Self.passes(spots))
            VStack {
                Spacer()
                HStack {
                    Text(match.formation.title)
                        .font(.system(size: 11, weight: .heavy).monospacedDigit())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.45), in: Capsule())
                    Spacer()
                    HStack(spacing: 5) {
                        BlinkingLight(color: Color(hex: 0xFF3B30), period: 1.6, hard: false).frame(width: 6, height: 6)
                        Text(match.competition.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.5)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45), in: Capsule())
                }
            }
            .padding(6)
        }
    }

    private func player(color: Color, number: Int) -> some View {
        ZStack {
            Circle().fill(color).shadow(color: color, radius: 5)
            Circle().stroke(.white.opacity(0.85), lineWidth: 1)
            Text("\(number)")
                .font(.system(size: 7.5, weight: .heavy))
                .foregroundStyle(color.isBright ? .black : .white)
        }
        .frame(width: 15, height: 15)
    }

    static let numbers = [1, 2, 4, 5, 3, 6, 8, 10, 7, 9, 11]

    /// The home side, attacking right, as fractions of the pitch.
    static func positions(_ formation: Formation) -> [CGPoint] {
        var spots = [CGPoint(x: 0.05, y: 0.5)]
        let lines = formation.lines
        for (row, count) in lines.enumerated() {
            let x = 0.15 + 0.3 * Double(row) / Double(max(lines.count - 1, 1))
            for index in 0..<count {
                let y = count == 1 ? 0.5 : 0.2 + 0.6 * Double(index) / Double(count - 1)
                spots.append(CGPoint(x: x, y: y))
            }
        }
        return spots
    }

    /// A move up the pitch: keeper, back line, midfield, a cross, a shot.
    static func passes(_ spots: [CGPoint]) -> [CGPoint] {
        guard spots.count >= 11 else { return [] }
        return [spots[0], spots[2], spots[6], spots[8], spots[10], CGPoint(x: 0.97, y: 0.46), spots[9], spots[4]]
    }

    static func drawPitch(_ context: GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let bounds = CGRect(origin: .zero, size: size)
        context.fill(Path(bounds), with: .linearGradient(Gradient(colors: [Color(hex: 0x12421F), Color(hex: 0x0A2A14)]),
                                                         startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        // Mowing stripes.
        for index in 0..<12 where index.isMultiple(of: 2) {
            context.fill(Path(CGRect(x: w * Double(index) / 12, y: 0, width: w / 12, height: h)), with: .color(.white.opacity(0.035)))
        }
        let line = GraphicsContext.Shading.color(.white.opacity(0.5))
        let inset = CGRect(x: 8, y: 8, width: w - 16, height: h - 16)
        context.stroke(Path(inset), with: line, lineWidth: 1)
        var halfway = Path()
        halfway.move(to: CGPoint(x: w / 2, y: inset.minY))
        halfway.addLine(to: CGPoint(x: w / 2, y: inset.maxY))
        context.stroke(halfway, with: line, lineWidth: 1)
        let circle = inset.height * 0.22
        context.stroke(Path(ellipseIn: CGRect(x: w / 2 - circle, y: h / 2 - circle, width: circle * 2, height: circle * 2)), with: line, lineWidth: 1)
        context.fill(Path(ellipseIn: CGRect(x: w / 2 - 2, y: h / 2 - 2, width: 4, height: 4)), with: line)
        for side in [0.0, 1.0] {
            let box = CGSize(width: inset.width * 0.14, height: inset.height * 0.56)
            let six = CGSize(width: inset.width * 0.05, height: inset.height * 0.28)
            let x = side == 0 ? inset.minX : inset.maxX - box.width
            let x6 = side == 0 ? inset.minX : inset.maxX - six.width
            context.stroke(Path(CGRect(x: x, y: h / 2 - box.height / 2, width: box.width, height: box.height)), with: line, lineWidth: 1)
            context.stroke(Path(CGRect(x: x6, y: h / 2 - six.height / 2, width: six.width, height: six.height)), with: line, lineWidth: 1)
            let goal = CGRect(x: side == 0 ? inset.minX - 5 : inset.maxX, y: h / 2 - inset.height * 0.07, width: 5, height: inset.height * 0.14)
            context.stroke(Path(goal), with: .color(.white.opacity(0.8)), lineWidth: 1)
        }
        // Floodlight pools and a vignette.
        for x in [0.0, 1.0] {
            context.fill(Path(bounds), with: .radialGradient(Gradient(colors: [.white.opacity(0.12), .clear]),
                                                             center: CGPoint(x: w * x, y: 0), startRadius: 0, endRadius: max(w, h) * 0.6))
        }
        context.fill(Path(bounds), with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.45)]),
                                                         center: CGPoint(x: w / 2, y: h / 2), startRadius: min(w, h) * 0.3, endRadius: max(w, h) * 0.75))
    }
}

extension Color {
    /// Light enough to need dark text on top.
    var isBright: Bool {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return false }
        return 0.299 * color.redComponent + 0.587 * color.greenComponent + 0.114 * color.blueComponent > 0.62
    }
}

/// "POR 2–1 ARG", or the kickoff countdown, in one row.
private struct MatchLine: View {
    let match: MatchDetails
    var large = false

    var body: some View {
        HStack(spacing: 12) {
            team(match.home, color: Color(match.homeColor))
            Spacer(minLength: 0)
            if match.hasScore {
                Text("\(match.homeScore ?? 0) – \(match.awayScore ?? 0)")
                    .font(.system(size: 30, weight: .black).monospacedDigit())
                    .shadow(color: .white.opacity(0.5), radius: 6)
            } else {
                KickoffCountdown(kickoff: match.kickoff, size: 22)
            }
            Spacer(minLength: 0)
            team(match.away, color: Color(match.awayColor))
        }
        .padding(.horizontal, 18)
    }

    private func team(_ code: String, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4, height: 22).shadow(color: color, radius: 4)
            Text(code.uppercased().prefix(3))
                .font(.system(size: 18, weight: .black).width(.condensed))
        }
    }
}

/// "2D 04:12" to kickoff, ticking each minute; "KICKOFF" once it's time.
struct KickoffCountdown: View {
    let kickoff: Date?
    let size: CGFloat
    var color: Color = .white

    var body: some View {
        WidgetTimeline(.everyMinute) { context in
            VStack(spacing: 1) {
                Text(Self.text(until: kickoff, now: context.date))
                    .font(.system(size: size, weight: .heavy, design: .monospaced))
                    .foregroundStyle(color)
                    .shadow(color: color.opacity(0.7), radius: 6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(kickoff.map { $0 > context.date ? "TO KICKOFF" : "KICKED OFF" } ?? "SET A KICKOFF")
                    .font(.system(size: max(size * 0.32, 7), weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    static func text(until kickoff: Date?, now: Date) -> String {
        guard let kickoff else { return "--:--" }
        let seconds = Int(kickoff.timeIntervalSince(now))
        guard seconds > 0 else { return "LIVE" }
        let days = seconds / 86_400, hours = seconds % 86_400 / 3600, minutes = seconds % 3600 / 60
        return days > 0 ? String(format: "%dD %02d:%02d", days, hours, minutes) : String(format: "%02d:%02d", hours, minutes)
    }
}

// MARK: Scoreboard

/// A stadium board: LED digits behind a dot screen, team colors and a glow.
struct ScoreboardWidget: View {
    let instance: WidgetInstance

    private var match: MatchDetails { instance.options.match }
    private static let led = Color(hex: 0xFFB020)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x16181C), Color(hex: 0x050505)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Self.led.opacity(0.14), .clear], center: .center, startRadius: 0, endRadius: 200)
            board
                .overlay(LEDScreen().opacity(0.55))
                .padding(instance.size == .small ? 12 : 16)
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var board: some View {
        let live = Self.isLive(match, now: .now)
        VStack(spacing: instance.size == .small ? 6 : 10) {
            HStack(spacing: 6) {
                if live {
                    BlinkingLight(color: Color(hex: 0xFF3B30), period: 1.1).frame(width: 7, height: 7)
                    WidgetWord("LIVE").font(.system(size: 10, weight: .black)).foregroundStyle(Color(hex: 0xFF3B30))
                }
                Text(match.competition.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.5)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            if instance.size == .small {
                VStack(spacing: 4) {
                    teamRow(match.home, color: Color(match.homeColor), score: match.homeScore)
                    teamRow(match.away, color: Color(match.awayColor), score: match.awayScore)
                }
                if !match.hasScore {
                    KickoffCountdown(kickoff: match.kickoff, size: 16, color: Self.led)
                }
            } else {
                HStack(alignment: .center, spacing: 10) {
                    teamBlock(match.home, color: Color(match.homeColor))
                    Spacer(minLength: 0)
                    if match.hasScore {
                        Text("\(match.homeScore ?? 0):\(match.awayScore ?? 0)")
                            .font(.system(size: instance.size == .large ? 64 : 46, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Self.led)
                            .shadow(color: Self.led.opacity(0.8), radius: 10)
                    } else {
                        KickoffCountdown(kickoff: match.kickoff, size: instance.size == .large ? 34 : 26, color: Self.led)
                    }
                    Spacer(minLength: 0)
                    teamBlock(match.away, color: Color(match.awayColor))
                }
                if instance.size == .large, let kickoff = match.kickoff {
                    Text(kickoff.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()).uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Kicked off within the last two hours and no final score yet.
    static func isLive(_ match: MatchDetails, now: Date) -> Bool {
        guard let kickoff = match.kickoff else { return false }
        let since = now.timeIntervalSince(kickoff)
        return since >= 0 && since < 2 * 3600
    }

    private func teamBlock(_ code: String, color: Color) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 34, height: 6).shadow(color: color, radius: 6)
            Text(code.uppercased().prefix(3))
                .font(.system(size: instance.size == .large ? 30 : 24, weight: .black, design: .monospaced))
        }
    }

    private func teamRow(_ code: String, color: Color, score: Int?) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4, height: 16).shadow(color: color, radius: 4)
            Text(code.uppercased().prefix(3)).font(.system(size: 18, weight: .black, design: .monospaced))
            Spacer(minLength: 0)
            if let score {
                Text("\(score)")
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Self.led)
                    .shadow(color: Self.led.opacity(0.8), radius: 6)
            }
        }
    }
}

/// A fine grid of dark lines over the board, so it reads as LEDs.
private struct LEDScreen: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x = 0.0
            while x < size.width {
                path.addRect(CGRect(x: x, y: 0, width: 1, height: size.height))
                x += 3
            }
            var y = 0.0
            while y < size.height {
                path.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
                y += 3
            }
            context.fill(path, with: .color(.black.opacity(0.55)))
        }
        .allowsHitTesting(false)
    }
}

// MARK: Milestone

/// One big number, counted up when it appears, with a trophy that glows.
struct MilestoneWidget: View {
    let instance: WidgetInstance

    @Environment(\.widgetAccent) private var accent
    @Environment(\.widgetSnapshot) private var snapshot
    @State private var shown = 0

    private var milestone: MilestoneDetails { instance.options.milestone }

    var body: some View {
        let small = instance.size == .small
        HStack(spacing: 14) {
            if !small {
                ZStack {
                    PulsingGlow(color: accent, period: 3)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(LinearGradient(colors: [accent.mix(.white, 0.5), accent], startPoint: .top, endPoint: .bottom))
                        .shadow(color: accent.opacity(0.7), radius: 8)
                }
                .frame(width: 110)
            }
            VStack(alignment: small ? .center : .leading, spacing: 2) {
                if small {
                    Image(systemName: "trophy.fill").font(.system(size: 16)).foregroundStyle(accent)
                        .shadow(color: accent.opacity(0.7), radius: 5)
                }
                Text(milestone.label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .opacity(0.7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(snapshot ? milestone.value : shown)\(milestone.suffix)")
                    .font(.system(size: small ? 44 : 56, weight: .black).width(.condensed))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(shown)))
                    .foregroundStyle(LinearGradient(colors: [accent.mix(.white, 0.55), accent], startPoint: .top, endPoint: .bottom))
                    .shadow(color: accent.opacity(0.5), radius: 8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                if !milestone.caption.isEmpty {
                    Text(milestone.caption)
                        .font(.system(size: 11, weight: .medium))
                        .opacity(0.6)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: small ? .center : .leading)
        }
        .padding(small ? 12 : 16)
        .task(id: milestone.value) {
            // Counts up in a few steps rather than every frame.
            let target = milestone.value
            guard !snapshot, shown != target else { return }
            for step in 1...8 {
                withMotion(Motion.quick) { shown = target * step / 8 }
                try? await Task.sleep(for: .milliseconds(90))
            }
        }
    }
}

extension Color {
    /// How vivid the color is, 0 for grays.
    var saturationValue: Double {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return 0 }
        return color.saturationComponent
    }
}
