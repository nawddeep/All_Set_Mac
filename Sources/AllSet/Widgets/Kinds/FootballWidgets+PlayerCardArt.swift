import AllSetCore
import SwiftUI

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
struct MatchLine: View {
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
struct LEDScreen: View {
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
