import AllSetCore
import SwiftUI

extension EnvironmentValues {
    /// False while the widget's window is covered, which pauses animations.
    @Entry var widgetIsVisible = true
    /// The most frames a second drawn art may use; widgets lower it on battery.
    @Entry var artFrameLimit: Int?
}

/// Draws an `ArtPiece`, still or animated. Animation runs at 30 fps and stops
/// when the widget can't be seen.
struct ArtView: View {
    let piece: ArtPiece
    var animated = false
    var speed = 1.0
    var frameRate = 30
    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.artFrameLimit) private var frameLimit

    var body: some View {
        let rate = max(min(frameRate, frameLimit ?? frameRate), 1)
        // Hidden or paused: a still frame, drawn once. Moving: on the GPU
        // when it's ready, which costs a fraction of drawing with SwiftUI.
        if animated, isVisible, let gpu = ArtGPU.shared {
            MetalArtView(gpu: gpu, piece: piece, speed: speed, frameRate: rate)
        } else if animated, isVisible {
            TimelineView(.animation(minimumInterval: 1.0 / Double(rate))) { context in
                canvas(time: context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000) * speed)
            }
        } else {
            // A moment where every style looks settled.
            canvas(time: 20)
        }
    }

    private func canvas(time: Double) -> some View {
        Canvas { context, size in
            ArtRenderer.draw(piece, in: context, size: size, time: time)
        }
    }
}

/// The drawing for each art style. Everything is a function of size and time,
/// with fixed pseudo-random layouts, so a piece looks the same every time.
enum ArtRenderer {
    static func draw(_ piece: ArtPiece, in context: GraphicsContext, size: CGSize, time t: Double) {
        let c = piece.palette.colors.map { Color($0) }
        let w = size.width, h = size.height, m = max(w, h)
        let bounds = CGRect(origin: .zero, size: size)
        context.fill(Path(bounds), with: .linearGradient(Gradient(colors: [c[0], c[1]]),
                                                         startPoint: .zero, endPoint: CGPoint(x: w * 0.35, y: h)))
        switch piece.style {
        case .blobs:
            for i in 0..<4 {
                let k = Double(i)
                let center = CGPoint(x: w * (0.5 + 0.38 * sin(t * (0.21 + 0.05 * k) + k * 1.7)),
                                     y: h * (0.5 + 0.38 * cos(t * (0.17 + 0.04 * k) + k * 2.3)))
                glow(context, at: center, radius: m * (0.6 - 0.07 * k), color: c[2 + i % 3], opacity: 0.85)
            }

        case .aurora:
            glow(context, at: CGPoint(x: w * 0.5, y: h * 1.15), radius: m * 0.8, color: c[4], opacity: 0.3)
            stars(context, size: size, count: 30, time: t, maxOpacity: 0.5)
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: m * 0.035))
                for i in 0..<3 {
                    auroraRibbon(layer, index: i, size: size, time: t, color: c[2 + i % 3])
                }
            }

        case .sunset:
            glow(context, at: CGPoint(x: w * 0.5, y: h * 0.68), radius: m * 0.7, color: c[3], opacity: 0.5)
            let radius = min(w, h) * 0.3
            let center = CGPoint(x: w * 0.5, y: h * 0.64 + h * 0.015 * sin(t * 0.3))
            stripedSun(context, center: center, radius: radius, colors: [c[4], c[2]], time: t)
            var water = Path()
            water.addRect(CGRect(x: 0, y: h * 0.8, width: w, height: h * 0.2))
            context.fill(water, with: .linearGradient(Gradient(colors: [c[1].opacity(0.85), c[0]]),
                                                      startPoint: CGPoint(x: 0, y: h * 0.8), endPoint: CGPoint(x: 0, y: h)))
            for i in 0..<7 {
                let k = Double(i)
                let y = h * (0.83 + 0.022 * k)
                let span = radius * (1.4 - 0.15 * k) * (0.85 + 0.15 * sin(t * 0.8 + k))
                var line = Path()
                line.move(to: CGPoint(x: w / 2 - span / 2, y: y))
                line.addLine(to: CGPoint(x: w / 2 + span / 2, y: y))
                context.stroke(line, with: .color(c[3].opacity(0.55 - 0.06 * k)), style: StrokeStyle(lineWidth: max(h * 0.008, 1), lineCap: .round))
            }

        case .waves:
            glow(context, at: CGPoint(x: w * 0.75, y: h * 0.2), radius: m * 0.35, color: c[4], opacity: 0.35)
            for i in 0..<4 {
                let k = Double(i)
                let base = h * (0.42 + 0.14 * k)
                var wave = Path()
                wave.move(to: CGPoint(x: 0, y: h))
                for step in 0...48 {
                    let x = w * Double(step) / 48
                    let y = base + h * 0.045 * (1 + 0.3 * k) * sin(x / w * .pi * 2 * (1.3 + 0.4 * k) + t * (0.5 + 0.22 * k) + k * 2)
                    wave.addLine(to: CGPoint(x: x, y: y))
                }
                wave.addLine(to: CGPoint(x: w, y: h))
                wave.closeSubpath()
                context.fill(wave, with: .color(c[2 + i % 3].opacity(0.45 + 0.15 * k)))
            }

        case .synthwave:
            let horizon = h * 0.58
            var sky = Path()
            sky.addRect(CGRect(x: 0, y: 0, width: w, height: horizon))
            context.fill(sky, with: .linearGradient(Gradient(colors: [c[0], c[2].opacity(0.85)]),
                                                    startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))
            stars(context, size: CGSize(width: w, height: horizon * 0.6), count: 25, time: t, maxOpacity: 0.7)
            var above = context
            above.clip(to: sky)
            stripedSun(above, center: CGPoint(x: w / 2, y: horizon), radius: min(w, h) * 0.3, colors: [c[4], c[2]], time: t)
            var ground = Path()
            ground.addRect(CGRect(x: 0, y: horizon, width: w, height: h - horizon))
            context.fill(ground, with: .color(c[0]))
            let grid = GraphicsContext.Shading.color(c[3].opacity(0.85))
            let travel = (t * 0.45).truncatingRemainder(dividingBy: 1)
            for i in 0..<12 {
                let p = pow((Double(i) + travel) / 12, 2.2)
                var line = Path()
                let y = horizon + (h - horizon) * p
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: w, y: y))
                context.stroke(line, with: grid, lineWidth: 1)
            }
            for i in -12...12 {
                var line = Path()
                line.move(to: CGPoint(x: w / 2 + Double(i) * w * 0.02, y: horizon))
                line.addLine(to: CGPoint(x: w / 2 + Double(i) * w * 0.16, y: h))
                context.stroke(line, with: grid, lineWidth: 1)
            }
            glow(context, at: CGPoint(x: w / 2, y: horizon), radius: w * 0.6, color: c[3], opacity: 0.25)

        case .dunes:
            glow(context, at: CGPoint(x: w * 0.7, y: h * 0.3), radius: m * 0.3, color: c[4], opacity: 0.6)
            let layers = [c[4], c[3], c[2], c[1], c[0]]
            for i in 0..<5 {
                let k = Double(i)
                let base = h * (0.38 + 0.13 * k)
                var hill = Path()
                hill.move(to: CGPoint(x: 0, y: h))
                for step in 0...48 {
                    let x = w * Double(step) / 48
                    let u = x / w
                    let y = base + h * 0.06 * sin(u * .pi * 2 * (0.6 + 0.2 * k) + k * 1.3 + t * 0.05 * (k + 1))
                        + h * 0.025 * sin(u * .pi * 2 * 2.1 + k)
                    hill.addLine(to: CGPoint(x: x, y: y))
                }
                hill.addLine(to: CGPoint(x: w, y: h))
                hill.closeSubpath()
                context.fill(hill, with: .color(layers[i].opacity(i == 0 ? 0.6 : 0.95)))
            }

        case .stars:
            glow(context, at: CGPoint(x: w * 0.3, y: h * 0.35), radius: m * 0.5, color: c[2], opacity: 0.35)
            glow(context, at: CGPoint(x: w * 0.75, y: h * 0.7), radius: m * 0.45, color: c[4], opacity: 0.25)
            stars(context, size: size, count: 110, time: t, maxOpacity: 1)
            let phase = (t / 9).truncatingRemainder(dividingBy: 1)
            if phase < 0.12 {
                let p = phase / 0.12
                let start = CGPoint(x: w * (0.2 + 0.6 * p), y: h * (0.1 + 0.3 * p))
                var streak = Path()
                streak.move(to: start)
                streak.addLine(to: CGPoint(x: start.x - w * 0.12, y: start.y - h * 0.06))
                context.stroke(streak, with: .linearGradient(Gradient(colors: [.white.opacity(0.9 * (1 - p)), .clear]),
                                                             startPoint: start, endPoint: CGPoint(x: start.x - w * 0.12, y: start.y - h * 0.06)),
                               lineWidth: 1.5)
            }

        case .bokeh:
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: m * 0.01))
                for i in 0..<22 {
                    let r = m * (0.03 + random(i, 1) * 0.09)
                    let x = random(i, 2) * w + sin(t * 0.3 + Double(i)) * w * 0.03
                    let speed = 0.02 + random(i, 3) * 0.05
                    let y = h + r - fraction(random(i, 4) + t * speed) * (h + 2 * r)
                    let circle = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
                    let color = c[2 + i % 3]
                    layer.fill(circle, with: .color(color.opacity(0.2 + random(i, 5) * 0.35)))
                    layer.stroke(circle, with: .color(color.opacity(0.4)), lineWidth: 1)
                }
            }

        case .lava:
            glow(context, at: CGPoint(x: w / 2, y: h), radius: m * 0.7, color: c[3], opacity: 0.35)
            for (layerIndex, color) in [c[2], c[4]].enumerated() {
                let blobs = lavaBlobs(layer: layerIndex, size: size, time: t)
                // A soft halo first, then the blobs merged into one goo by
                // blurring and cutting at half opacity.
                context.drawLayer { halo in
                    halo.addFilter(.blur(radius: m * 0.08))
                    for blob in blobs { halo.fill(Path(ellipseIn: blob), with: .color(color.opacity(0.45))) }
                }
                context.drawLayer { goo in
                    goo.addFilter(.alphaThreshold(min: 0.5, color: color))
                    goo.addFilter(.blur(radius: m * 0.07))
                    for blob in blobs { goo.fill(Path(ellipseIn: blob), with: .color(.black)) }
                }
            }

        case .rain:
            glow(context, at: CGPoint(x: w * 0.3, y: h * 0.25), radius: m * 0.5, color: c[2], opacity: 0.35)
            glow(context, at: CGPoint(x: w * 0.8, y: h * 0.9), radius: m * 0.4, color: c[3], opacity: 0.3)
            for i in 0..<80 {
                let length = h * (0.04 + random(i, 2) * 0.06)
                let x = random(i, 1) * w * 1.1 - w * 0.05
                let speed = h * (0.6 + random(i, 3) * 0.8)
                let y = (random(i, 4) * h + t * speed).truncatingRemainder(dividingBy: h + length) - length
                var drop = Path()
                drop.move(to: CGPoint(x: x, y: y))
                drop.addLine(to: CGPoint(x: x - length * 0.15, y: y + length))
                context.stroke(drop, with: .color(c[4].opacity(0.2 + 0.35 * random(i, 5))), lineWidth: 1)
            }

        case .orbits:
            let center = CGPoint(x: w / 2, y: h / 2)
            glow(context, at: center, radius: m * 0.4, color: c[2], opacity: 0.5)
            for i in 0..<6 {
                let k = Double(i)
                let radius = min(w, h) * (0.1 + 0.065 * k)
                let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
                context.stroke(ring, with: .color(c[4].opacity(0.14)), lineWidth: 1)
                let start = t * (0.35 + 0.12 * k) * (i.isMultiple(of: 2) ? 1 : -1) + k
                let sweep = 0.6 + random(i, 1) * 1.4
                var arc = Path()
                arc.addArc(center: center, radius: radius, startAngle: .radians(start), endAngle: .radians(start + sweep), clockwise: false)
                let color = c[2 + i % 3]
                context.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: max(min(w, h) * 0.012, 2), lineCap: .round))
                let tip = CGPoint(x: center.x + cos(start + sweep) * radius, y: center.y + sin(start + sweep) * radius)
                glow(context, at: tip, radius: min(w, h) * 0.04, color: color, opacity: 0.9)
            }

        case .stripes:
            let corner = CGPoint(x: -w * 0.05, y: h * 1.05)
            let bands = [c[2], c[3], c[4], c[3], c[2], c[1]]
            for (i, color) in bands.enumerated() {
                let k = Double(i)
                let r = m * (1.25 - 0.17 * k) + sin(t * 0.3 + k * 0.8) * m * 0.012
                context.fill(Path(ellipseIn: CGRect(x: corner.x - r, y: corner.y - r, width: 2 * r, height: 2 * r)),
                             with: .color(color))
            }

        case .clouds:
            glow(context, at: CGPoint(x: w * 0.82, y: h * 0.12), radius: m * 0.45, color: c[3], opacity: 0.45)
            clouds(size: size, time: t) { x, y, s, packed in
                let second = packed >= 2
                var layer = context
                layer.opacity = packed - (second ? 2 : 0)
                layer.drawLayer { cloud in
                    cloud.addFilter(.blur(radius: s * 0.3))
                    for puff in cloudPuffs {
                        let r = puff.z * s
                        cloud.fill(Path(ellipseIn: CGRect(x: x + puff.x * s - r, y: y + puff.y * s - r, width: 2 * r, height: 2 * r)),
                                   with: .color(second ? c[3] : c[2]))
                    }
                }
            }
            sparkles(size: size, time: t, count: 14, salt: 20) { x, y, s, twinkle in
                sparkle(context, x: x, y: y, size: s, color: .white, opacity: twinkle)
            }

        case .hearts:
            glow(context, at: CGPoint(x: w * 0.5, y: h * 0.35), radius: m * 0.6, color: c[2], opacity: 0.3)
            var index = 0
            hearts(size: size, time: t) { x, y, side, opacity in
                let angle = 0.25 * sin(t * 0.7 + Double(index) * 1.3)
                var layer = context
                layer.opacity = opacity
                layer.translateBy(x: x, y: y)
                layer.rotate(by: .radians(angle))
                let color = c[2 + index % 3]
                layer.drawLayer { heart in
                    for part in heartParts(side: side) { heart.fill(part, with: .color(color)) }
                }
                index += 1
            }
            sparkles(size: size, time: t, count: 10, salt: 40) { x, y, s, twinkle in
                sparkle(context, x: x, y: y, size: s, color: .white, opacity: twinkle)
            }

        case .spiral:
            let center = CGPoint(x: w / 2, y: h / 2)
            let spacing = min(w, h) * 0.18
            let offset = fraction(t * 0.1)
            let reach = hypot(w, h) / 2 + spacing
            // The band where the shader's fract(r/spacing - angle/2π - t) < 0.5:
            // between two Archimedean spirals half a turn's spacing apart.
            let start = -2 * .pi * offset
            let end = 2 * .pi * (reach / spacing - offset)
            let steps = max(Int((end - start) / (.pi / 40)), 8)
            var inner: [CGPoint] = []
            var outer: [CGPoint] = []
            for step in 0...steps {
                let theta: Double = start + (end - start) * Double(step) / Double(steps)
                let r: Double = spacing * (theta / (2 * .pi) + offset)
                let r2: Double = r + spacing / 2
                let (dx, dy) = (cos(theta), sin(theta))
                inner.append(CGPoint(x: center.x + dx * r, y: center.y + dy * r))
                outer.append(CGPoint(x: center.x + dx * r2, y: center.y + dy * r2))
            }
            var band = Path()
            band.addLines(inner + outer.reversed())
            band.closeSubpath()
            context.fill(band, with: .radialGradient(Gradient(colors: [c[4], c[3]]), center: center,
                                                     startRadius: 0, endRadius: m * 0.7))
            glow(context, at: center, radius: m * 0.35, color: c[2], opacity: 0.35)
            vignette(context, size: size, color: c[0], from: 0.25, to: 0.8, opacity: 0.6)

        case .leopard:
            leopardSpots(size: size, time: t) { x, y, r, turn in
                let center = CGRect(x: x - r * 0.72, y: y - r * 0.72, width: r * 1.44, height: r * 1.44)
                context.fill(Path(ellipseIn: center), with: .color(c[3].opacity(0.6)))
                for k in 0..<4 {
                    let from = turn + Double(k) * .pi / 2
                    let mark = leopardMark(turn: turn, index: k)
                    var arc = Path()
                    arc.addArc(center: CGPoint(x: x, y: y), radius: r, startAngle: .radians(from),
                               endAngle: .radians(from + mark.length), clockwise: false)
                    context.stroke(arc, with: .color(c[2]), style: StrokeStyle(lineWidth: r * mark.width, lineCap: .round))
                }
            }

        case .film:
            glow(context, at: CGPoint(x: w * (0.15 + 0.1 * sin(t * 0.13)), y: h * 0.2), radius: m * 0.55,
                 color: c[2], opacity: 0.28 + 0.07 * sin(t * 0.5))
            glow(context, at: CGPoint(x: w * 0.85, y: h * 0.85), radius: m * 0.5, color: c[4], opacity: 0.18)
            filmDust(size: size, time: t) { x, y, r, opacity in
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                             with: .color(c[4].opacity(opacity)))
            }
            vignette(context, size: size, color: .black, from: 0.3, to: 0.85, opacity: 0.55)
            let flicker = 0.025 * sin(t * 21) * sin(t * 6.7)
            context.fill(Path(bounds), with: .color(flicker > 0 ? .white.opacity(flicker) : .black.opacity(-flicker)))
            var grain = context
            grain.blendMode = .overlay
            grain.opacity = 0.16
            grain.fill(Path(bounds), with: .tiledImage(grainImage))

        case .checker:
            let cell = min(w, h) / 6
            let scroll = CGPoint(x: t * cell * 0.12, y: t * cell * 0.08)
            // The shader bends the screen into the board; this moves each
            // corner of the board back onto the screen.
            func screen(_ u: CGPoint) -> CGPoint {
                var p = CGPoint(x: u.x - scroll.x, y: u.y - scroll.y)
                for _ in 0..<3 {
                    let bend = checkerBend(p, cell: cell, m: m, time: t)
                    p = CGPoint(x: u.x - scroll.x - bend.x, y: u.y - scroll.y - bend.y)
                }
                return p
            }
            let firstColumn = Int((scroll.x / cell).rounded(.down)) - 2
            let firstRow = Int((scroll.y / cell).rounded(.down)) - 2
            let columns = Int((w / cell).rounded(.up)) + 4
            let rows = Int((h / cell).rounded(.up)) + 4
            var squares = Path()
            for j in firstRow..<(firstRow + rows) {
                for i in firstColumn..<(firstColumn + columns) where (i + j) % 2 == 0 {
                    let corners = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
                        .map { screen(CGPoint(x: Double($0.0) * cell, y: Double($0.1) * cell)) }
                    squares.addLines(corners)
                    squares.closeSubpath()
                }
            }
            context.fill(squares, with: .color(c[2]))
            glow(context, at: CGPoint(x: w / 2, y: h / 2), radius: m * 0.6, color: c[3], opacity: 0.15)

        case .skyline:
            let n = min(w, h)
            glow(context, at: CGPoint(x: w * 0.5, y: h * 0.75), radius: m * 0.7, color: c[4], opacity: 0.12)
            // A searchlight sweeping the clouds, and where it lands.
            let beam = searchlight(size: size, time: t)
            var cone = Path()
            let reach = h * 1.3
            let far = CGPoint(x: beam.base.x + beam.direction.x * reach, y: beam.base.y + beam.direction.y * reach)
            let spread = 0.07 * reach + n * 0.01
            let side = CGPoint(x: -beam.direction.y * spread, y: beam.direction.x * spread)
            cone.addLines([beam.base, CGPoint(x: far.x + side.x, y: far.y + side.y), CGPoint(x: far.x - side.x, y: far.y - side.y)])
            cone.closeSubpath()
            var soft = context
            soft.addFilter(.blur(radius: n * 0.02))
            soft.fill(cone, with: .linearGradient(Gradient(colors: [c[3].opacity(0.2), c[3].opacity(0.1)]), startPoint: beam.base, endPoint: far))
            glow(context, at: beam.spot, radius: n * 0.16, color: c[3], opacity: 0.35)
            let back = c[1].mix(c[2], 0.25), front = c[0].mix(c[1], 0.5)
            var index = 0
            skylineBuildings(size: size) { x, width, height, layer in
                let top = h - height
                context.fill(Path(CGRect(x: x, y: top, width: width, height: height)), with: .color(layer > 0.5 ? front : back))
                if layer > 0.5 {
                    var lit = Path()
                    skylineWindows(index: index, x: x, width: width, top: top, height: h, n: n, time: t) { lit.addRect($0) }
                    context.fill(lit, with: .color(c[3].opacity(0.85)))
                }
                index += 1
            }
            skylineRain(size: size, time: t) { x, y, length, opacity in
                var drop = Path()
                drop.move(to: CGPoint(x: x, y: y))
                drop.addLine(to: CGPoint(x: x - length * 0.15, y: y + length))
                context.stroke(drop, with: .color(c[4].opacity(opacity)), lineWidth: 1)
            }

        case .embers:
            glow(context, at: CGPoint(x: w * 0.5, y: h * 1.1), radius: m * 0.75, color: c[2], opacity: 0.45)
            glow(context, at: CGPoint(x: w * 0.2, y: h), radius: m * 0.4, color: c[4], opacity: 0.2)
            var index = 0
            embers(size: size, time: t) { x, y, r, brightness in
                let color = index.isMultiple(of: 2) ? c[3] : c[4]
                glow(context, at: CGPoint(x: x, y: y), radius: r * 5, color: color, opacity: 0.45 * brightness)
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                             with: .color(color.mix(.white, 0.35).opacity(brightness)))
                index += 1
            }

        case .stadium:
            let horizon = h * 0.62
            glow(context, at: CGPoint(x: w / 2, y: horizon), radius: m * 0.6, color: c[3], opacity: 0.22)
            // The stands, in tiers, with camera flashes going off.
            var stands = Path()
            stands.addRect(CGRect(x: 0, y: h * 0.36, width: w, height: horizon - h * 0.36))
            context.fill(stands, with: .linearGradient(Gradient(colors: [c[0].mix(.black, 0.3), c[1].mix(.black, 0.2)]),
                                                       startPoint: CGPoint(x: 0, y: h * 0.36), endPoint: CGPoint(x: 0, y: horizon)))
            for tier in 1..<4 {
                var line = Path()
                let y = h * 0.36 + (horizon - h * 0.36) * Double(tier) / 4
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: w, y: y))
                context.stroke(line, with: .color(c[1].opacity(0.5)), lineWidth: 1)
            }
            stadiumFlashes(size: size, time: t) { x, y, r, brightness in
                guard brightness > 0.01 else { return }
                glow(context, at: CGPoint(x: x, y: y), radius: r * 8, color: .white, opacity: 0.8 * brightness)
            }
            // The pitch, mown in bands that narrow toward the stands.
            var pitch = Path()
            pitch.addRect(CGRect(x: 0, y: horizon, width: w, height: h - horizon))
            context.fill(pitch, with: .linearGradient(Gradient(colors: [c[2].mix(.black, 0.35), c[2].mix(.black, 0.62)]),
                                                      startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)))
            for band in stride(from: 0, to: 10, by: 2) {
                let y0 = horizon + (h - horizon) * pow(Double(band) / 10, 1.6)
                let y1 = horizon + (h - horizon) * pow(Double(band + 1) / 10, 1.6)
                context.fill(Path(CGRect(x: 0, y: y0, width: w, height: y1 - y0)), with: .color(.white.opacity(0.05)))
            }
            var touchline = Path()
            touchline.move(to: CGPoint(x: 0, y: horizon + 2))
            touchline.addLine(to: CGPoint(x: w, y: horizon + 2))
            context.stroke(touchline, with: .color(.white.opacity(0.4)), lineWidth: 1)
            let circleY = horizon + (h - horizon) * 0.45
            context.stroke(Path(ellipseIn: CGRect(x: w * 0.36, y: circleY - (h - horizon) * 0.15, width: w * 0.28, height: (h - horizon) * 0.3)),
                           with: .color(.white.opacity(0.32)), lineWidth: 1)
            // Floodlights: beams onto the pitch, a halo, a white-hot bank.
            for (index, light) in stadiumLights(size: size).enumerated() {
                let flicker = 0.92 + 0.08 * sin(t * 0.7 + Double(index) * 1.3)
                let target = CGPoint(x: light.x + (w / 2 - light.x) * 0.7, y: h)
                context.drawLayer { beam in
                    beam.addFilter(.blur(radius: m * 0.02))
                    let spread = (target.y - light.y) * 0.3
                    var cone = Path()
                    cone.move(to: light)
                    cone.addLine(to: CGPoint(x: target.x - spread, y: target.y))
                    cone.addLine(to: CGPoint(x: target.x + spread, y: target.y))
                    cone.closeSubpath()
                    beam.fill(cone, with: .linearGradient(Gradient(colors: [c[4].opacity(0.16 * flicker), c[4].opacity(0.03)]),
                                                          startPoint: light, endPoint: target))
                }
                glow(context, at: light, radius: m * 0.25, color: c[4], opacity: 0.2 * flicker)
                glow(context, at: light, radius: m * 0.045, color: .white, opacity: 0.95 * flicker)
            }

        case .palms:
            let horizon = h * 0.74
            glow(context, at: CGPoint(x: w * 0.56, y: h * 0.6), radius: m * 0.55, color: c[3], opacity: 0.45)
            var above = context
            above.clip(to: Path(CGRect(x: 0, y: 0, width: w, height: horizon)))
            stripedSun(above, center: CGPoint(x: w * 0.56, y: h * 0.6), radius: min(w, h) * 0.22, colors: [c[4], c[2]], time: t)
            var sea = Path()
            sea.addRect(CGRect(x: 0, y: horizon, width: w, height: h - horizon))
            context.fill(sea, with: .linearGradient(Gradient(colors: [c[1].mix(.black, 0.25), c[0].mix(.black, 0.4)]),
                                                    startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)))
            for i in 0..<8 {
                let k = Double(i)
                let y = horizon + (h - horizon) * (0.08 + 0.11 * k)
                let span = min(w, h) * 0.3 * (1.2 - 0.1 * k) * (0.8 + 0.2 * sin(t * 0.9 + k * 1.7))
                var glint = Path()
                glint.move(to: CGPoint(x: w * 0.56 - span / 2, y: y))
                glint.addLine(to: CGPoint(x: w * 0.56 + span / 2, y: y))
                context.stroke(glint, with: .color(c[3].opacity(0.5 - 0.05 * k)), style: StrokeStyle(lineWidth: max(h * 0.006, 1), lineCap: .round))
            }
            let silhouette = GraphicsContext.Shading.color(c[0].mix(.black, 0.65))
            palmSegments(size: size, time: t) { x0, y0, x1, y1, thickness in
                var stroke = Path()
                stroke.move(to: CGPoint(x: x0, y: y0))
                stroke.addLine(to: CGPoint(x: x1, y: y1))
                context.stroke(stroke, with: silhouette, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
            }

        case .smoke:
            glow(context, at: CGPoint(x: w * 0.5, y: h * 1.05), radius: m * 0.7, color: c[3], opacity: 0.3)
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: m * 0.035))
                var index = 0
                smokeWisps(size: size, time: t) { x, y, angle, life in
                    let rx = m * (0.16 + 0.08 * random(index, 84)), ry = rx * 0.28
                    var wisp = layer
                    wisp.translateBy(x: x, y: y)
                    wisp.rotate(by: .radians(angle))
                    wisp.fill(Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)),
                              with: .radialGradient(Gradient(colors: [c[2 + index % 3].opacity(0.6 * life), c[2 + index % 3].opacity(0)]),
                                                    center: .zero, startRadius: 0, endRadius: rx))
                    index += 1
                }
            }
        }
    }

    // MARK: Stadium, palms and smoke

    /// The floodlight banks: two tall ones at the corners, two lower inside.
    static func stadiumLights(size: CGSize) -> [CGPoint] {
        let w = size.width, h = size.height
        return [CGPoint(x: w * 0.08, y: h * 0.1), CGPoint(x: w * 0.92, y: h * 0.1),
                CGPoint(x: w * 0.34, y: h * 0.2), CGPoint(x: w * 0.66, y: h * 0.2)]
    }

    /// Camera flashes in the crowd: center, radius, brightness (mostly dark).
    static func stadiumFlashes(size: CGSize, time t: Double, _ emit: (Double, Double, Double, Double) -> Void) {
        let w = size.width, h = size.height, m = max(w, h)
        for i in 0..<72 {
            let phase = fraction(t * (0.12 + 0.2 * random(i, 73)) + random(i, 74))
            let brightness = phase < 0.06 ? 1 - phase / 0.06 : 0
            emit(random(i, 70) * w, h * (0.38 + 0.22 * random(i, 71)), m * (0.0012 + 0.0014 * random(i, 72)), brightness)
        }
    }

    /// The palms as straight strokes: start, end and thickness, trunks then
    /// fronds, swaying a little in the breeze.
    static func palmSegments(size: CGSize, time t: Double, _ emit: (Double, Double, Double, Double, Double) -> Void) {
        let w = Double(size.width), h = Double(size.height), n = min(w, h)
        let palms: [(x: Double, height: Double, lean: Double)] = [(0.1, 0.8, 0.07), (0.25, 0.58, -0.04), (0.88, 0.7, -0.08)]
        for (i, palm) in palms.enumerated() {
            let sway = sin(t * 0.5 + Double(i) * 1.7) * n * 0.008
            let base = (x: palm.x * w, y: h * 1.02)
            let top = (x: base.x + palm.lean * w + sway, y: h * (1.02 - palm.height))
            let control = (x: base.x + palm.lean * w * 0.15, y: (base.y + top.y) / 2)
            var previous = base
            for k in 1...3 {
                let u = Double(k) / 3
                let point = (x: (1 - u) * (1 - u) * base.x + 2 * (1 - u) * u * control.x + u * u * top.x,
                             y: (1 - u) * (1 - u) * base.y + 2 * (1 - u) * u * control.y + u * u * top.y)
                emit(previous.x, previous.y, point.x, point.y, n * (0.03 - 0.005 * Double(k)))
                previous = point
            }
            // Fronds arch out and droop: each a blade in three strokes, thinning to a point.
            for k in 0..<9 {
                let angle = -Double.pi / 2 + (Double(k) - 4) * 0.42 + sin(t * 0.9 + Double(k) + Double(i)) * 0.05
                let length = n * (0.14 + 0.04 * random(i * 9 + k, 90))
                let droop = 0.35 + 0.35 * abs(Double(k) - 4) / 4
                var from = top
                for step in 1...3 {
                    let u = Double(step) / 3
                    let to = (x: top.x + cos(angle) * length * u,
                              y: top.y + sin(angle) * length * u + length * (droop * u * u - 0.12 * u))
                    emit(from.x, from.y, to.x, to.y, n * (0.026 - 0.007 * Double(step)))
                    from = to
                }
            }
        }
    }

    /// Wisps of smoke rising and turning: center, angle, and how far through
    /// its life it is (0 to 1 to 0).
    static func smokeWisps(size: CGSize, time t: Double, _ emit: (Double, Double, Double, Double) -> Void) {
        let w = size.width, h = size.height
        for i in 0..<12 {
            let rise = fraction(random(i, 80) + t * (0.02 + 0.015 * random(i, 81)))
            let y = h * 1.1 - rise * h * 1.4
            let x = w * (0.15 + 0.7 * random(i, 82)) + sin(t * 0.25 + Double(i)) * w * 0.08 + rise * w * 0.1 * sin(Double(i) * 2.3)
            let angle = sin(t * 0.1 + Double(i)) * 0.8 + (random(i, 83) - 0.5)
            emit(x, y, angle, sin(Double.pi * rise))
        }
    }

    // MARK: Night skyline and embers

    /// Where the searchlight stands, which way it points, and the spot it makes on the clouds.
    static func searchlight(size: CGSize, time t: Double) -> (base: CGPoint, direction: CGPoint, spot: CGPoint) {
        let base = CGPoint(x: size.width * 0.72, y: size.height * 0.95)
        let angle = -Double.pi / 2 + 0.38 * sin(t * 0.12)
        let direction = CGPoint(x: cos(angle), y: sin(angle))
        let travel = (base.y - size.height * 0.16) / max(-direction.y, 0.2)
        return (base, direction, CGPoint(x: base.x + direction.x * travel, y: base.y + direction.y * travel))
    }

    /// Two rows of buildings, back then front: left edge, width, height, and 0 or 1 for the row.
    static func skylineBuildings(size: CGSize, _ emit: (Double, Double, Double, Double) -> Void) {
        let w = size.width, h = size.height
        for layer in 0..<2 {
            var x = -random(layer, 90) * w * 0.05
            var i = 0
            while x < w && i < 24 {
                let seed = layer * 50 + i
                let width = w * (0.035 + 0.05 * random(seed, 91))
                let height = h * (layer == 0 ? 0.3 + 0.32 * random(seed, 92) : 0.16 + 0.3 * random(seed, 92))
                emit(x, width, height, Double(layer))
                x += width + (layer == 0 ? 0 : w * 0.004 * random(seed, 93))
                i += 1
            }
        }
    }

    /// The lit windows of front building `index`. A few switch on or off
    /// every so often. The shader decides each window the same way.
    static func skylineWindows(index: Int, x: Double, width: Double, top: Double, height h: Double, n: Double, time t: Double,
                               _ emit: (CGRect) -> Void) {
        let cell = max(n * 0.012, 3), rowHeight = cell * 1.5
        let columns = Int(((width - cell * 0.6) / cell).rounded(.down)) - 1
        guard columns > 0 else { return }
        var row = 0
        while top + rowHeight * 0.8 + Double(row) * rowHeight + rowHeight * 0.5 <= h {
            for column in 0..<columns where windowIsLit(column: column, row: row, building: index, time: t) {
                emit(CGRect(x: x + cell * 0.6 + Double(column) * cell, y: top + rowHeight * 0.8 + Double(row) * rowHeight,
                            width: cell * 0.55, height: rowHeight * 0.5))
            }
            row += 1
        }
    }

    static func windowIsLit(column: Int, row: Int, building: Int, time t: Double) -> Bool {
        var on = hash(column, row, building) < 0.3
        let epoch = Int((t / 9 + hash(column, row, building + 77) * 9).rounded(.down))
        if hash(column, row, epoch + building * 131) < 0.06 { on.toggle() }
        return on
    }

    /// Light rain over the city: top of the streak, length, opacity.
    static func skylineRain(size: CGSize, time t: Double, _ emit: (Double, Double, Double, Double) -> Void) {
        let w = size.width, h = size.height
        for i in 0..<60 {
            let length = h * (0.03 + random(i, 2) * 0.04)
            let x = random(i, 1) * w * 1.1 - w * 0.05
            let y = (random(i, 4) * h + t * h * (0.7 + random(i, 3) * 0.6)).truncatingRemainder(dividingBy: h + length) - length
            emit(x, y, length, 0.12 + 0.25 * random(i, 5))
        }
    }

    /// Sparks drifting up from below and fading: center, radius, brightness.
    static func embers(size: CGSize, time t: Double, _ emit: (Double, Double, Double, Double) -> Void) {
        let w = size.width, h = size.height, m = max(w, h)
        for i in 0..<40 {
            let r = m * (0.0015 + 0.003 * random(i, 62))
            let x = random(i, 63) * w + sin(t * (0.4 + random(i, 64)) + Double(i)) * w * 0.03
            let y = h + 4 * r - fraction(random(i, 65) + t * (0.03 + 0.05 * random(i, 61))) * (h * 1.05 + 8 * r)
            let flicker = 0.55 + 0.45 * sin(t * (2 + random(i, 66) * 3) + Double(i) * 2.1)
            emit(x, y, r, flicker * min(max(y / (h * 0.4), 0), 1))
        }
    }

    /// A 32-bit integer hash to 0...1, the same in the shader.
    static func hash(_ a: Int, _ b: Int, _ c: Int) -> Double {
        var x = UInt32(truncatingIfNeeded: a) &* 374_761_393 &+ UInt32(truncatingIfNeeded: b) &* 668_265_263
            &+ UInt32(truncatingIfNeeded: c) &* 2_246_822_519
        x = (x ^ (x >> 13)) &* 1_274_126_177
        x ^= x >> 16
        return Double(x & 0xFFFF) / 65_535
    }

    // MARK: Placement shared with the GPU (ArtItems), so both draw the same picture

    /// Circles making up one cloud, in units of its size: x, y, radius.
    static let cloudPuffs: [SIMD3<Double>] = [[-1.6, 0.25, 0.95], [-0.65, -0.35, 1.3], [0.55, -0.6, 1.5], [1.65, 0.1, 1.05], [0, 0.45, 1.2]]

    /// Clouds drifting right: center, size, and opacity (plus 2 for the second color).
    static func clouds(size: CGSize, time t: Double, _ emit: (Double, Double, Double, Double) -> Void) {
        let w = size.width, h = size.height, m = max(w, h)
        for i in 0..<7 {
            let s = m * (0.035 + 0.03 * random(i, 1))
            let x = fraction(random(i, 3) + t * (0.004 + 0.006 * random(i, 2))) * (w + 6 * s) - 3 * s
            let y = h * (0.08 + 0.8 * random(i, 4))
            emit(x, y, s, 0.55 + 0.35 * random(i, 5) + (i.isMultiple(of: 2) ? 0 : 2))
        }
    }

    /// Four-pointed sparkles: center, size, and brightness.
    static func sparkles(size: CGSize, time t: Double, count: Int, salt: Int, _ emit: (Double, Double, Double, Double) -> Void) {
        let m = max(size.width, size.height)
        for i in 0..<count {
            let twinkle = max(0, sin(t * (0.6 + random(i, salt + 3) * 1.4) + random(i, salt + 4) * 6.28))
            emit(random(i, salt) * size.width, random(i, salt + 1) * size.height,
                 m * (0.006 + 0.012 * random(i, salt + 2)), twinkle)
        }
    }

    /// Hearts rising: center, side of the square they're built on, and opacity.
    static func hearts(size: CGSize, time t: Double, _ emit: (Double, Double, Double, Double) -> Void) {
        let w = size.width, h = size.height, m = max(w, h)
        for i in 0..<22 {
            let side = m * (0.015 + 0.035 * random(i, 1))
            let x = random(i, 2) * w + sin(t * 0.5 + Double(i)) * w * 0.02
            let y = h + 2 * side - fraction(random(i, 4) + t * (0.015 + 0.03 * random(i, 3))) * (h + 4 * side)
            emit(x, y, side, 0.35 + 0.5 * random(i, 5))
        }
    }

    /// Leopard rosettes on a jittered grid that slides sideways and wraps:
    /// center, radius, and the turn of their broken ring.
    static func leopardSpots(size: CGSize, time t: Double, _ emit: (Double, Double, Double, Double) -> Void) {
        let w = size.width, h = size.height
        var cell = max(w, h) / 9
        var columns = Int((w / cell).rounded(.up)) + 1
        var rows = Int((h / cell).rounded(.up)) + 1
        while columns * rows > 120 {
            cell *= 1.15
            columns = Int((w / cell).rounded(.up)) + 1
            rows = Int((h / cell).rounded(.up)) + 1
        }
        let period = Double(columns) * cell
        for row in 0..<rows {
            for column in 0..<columns {
                let i = row * columns + column
                let across = (Double(column) + 0.5 + 0.5 * (random(i, 1) - 0.5) + (row.isMultiple(of: 2) ? 0 : 0.5)) * cell + t * cell * 0.05
                let x = fraction(across / period) * period - cell * 0.5
                let y = (Double(row) + 0.5 + 0.5 * (random(i, 2) - 0.5)) * cell - cell * 0.3 + sin(t * 0.25 + Double(i)) * cell * 0.03
                emit(x, y, cell * (0.24 + 0.08 * random(i, 3)), random(i, 4) * 6.283)
            }
        }
    }

    /// Each of a rosette's four marks: radians it covers and its thickness
    /// (a fraction of the radius), varied so no two rosettes look alike. The
    /// shader works these out the same way.
    static func leopardMark(turn: Double, index k: Int) -> (length: Double, width: Double) {
        (0.55 + 0.75 * fraction(turn * 3.7 + Double(k) * 1.618), 0.3 + 0.24 * fraction(turn * 5.3 + Double(k) * 0.77))
    }

    /// Specks of dust that jump about eight times a second.
    static func filmDust(size: CGSize, time t: Double, _ emit: (Double, Double, Double, Double) -> Void) {
        let frame = Int((t * 8).rounded(.down)) % 100_000
        for i in 0..<16 {
            let seed = i + frame * 37
            guard random(seed, 6) < 0.45 else { continue }
            emit(random(seed, 1) * size.width, random(seed, 2) * size.height, 0.6 + random(seed, 3) * 1.6, 0.25 + 0.45 * random(seed, 4))
        }
    }

    /// A tile of fine noise for film grain.
    private static let grainImage: Image = {
        let side = 128
        var pixels = [UInt8](repeating: 0, count: side * side)
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        for index in pixels.indices {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            pixels[index] = UInt8(truncatingIfNeeded: seed >> 56)
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: side,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return Image(systemName: "circle") }
        return Image(decorative: image, scale: 1)
    }()

    /// How far the checkerboard bends at a point on screen.
    static func checkerBend(_ p: CGPoint, cell: Double, m: Double, time t: Double) -> CGPoint {
        CGPoint(x: sin(p.y / m * 6 + t * 0.6) * cell * 0.22, y: sin(p.x / m * 5 + t * 0.5) * cell * 0.22)
    }

    /// A rotated square and two circles: the classic heart, point down.
    private static func heartParts(side a: Double) -> [Path] {
        let half = a / 2.0.squareRoot()
        var square = Path()
        square.addLines([CGPoint(x: 0, y: -half), CGPoint(x: half, y: 0), CGPoint(x: 0, y: half), CGPoint(x: -half, y: 0)])
        square.closeSubpath()
        let offset = a * 0.5 * 0.5.squareRoot()
        return [square] + [-offset, offset].map { x in
            Path(ellipseIn: CGRect(x: x - a / 2, y: -offset - a / 2, width: a, height: a))
        }
    }

    /// A four-pointed star (an astroid) with a soft glow.
    private static func sparkle(_ context: GraphicsContext, x: Double, y: Double, size s: Double, color: Color, opacity: Double) {
        guard opacity > 0.01 else { return }
        glow(context, at: CGPoint(x: x, y: y), radius: s * 2.5, color: color, opacity: 0.35 * opacity)
        var star = Path()
        for step in 0...32 {
            let theta = Double(step) / 32 * 2 * .pi
            let point = CGPoint(x: x + s * pow(cos(theta), 3), y: y + s * pow(sin(theta), 3))
            if step == 0 { star.move(to: point) } else { star.addLine(to: point) }
        }
        star.closeSubpath()
        context.fill(star, with: .color(color.opacity(opacity)))
    }

    /// Darkens toward the edges, from `from` to `to` of the longer side away from the center.
    private static func vignette(_ context: GraphicsContext, size: CGSize, color: Color, from: Double, to: Double, opacity: Double) {
        let m = max(size.width, size.height)
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(stops: [.init(color: color.opacity(0), location: from / to), .init(color: color.opacity(opacity), location: 1)]),
            center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: 0, endRadius: m * to))
    }

    private static func lavaBlobs(layer: Int, size: CGSize, time t: Double) -> [CGRect] {
        let w = size.width, h = size.height, m = max(w, h)
        return (0..<5).map { i in
            let seed = i + layer * 11
            let x: Double = w * (0.2 + 0.6 * random(seed, 1)) + sin(t * 0.3 + Double(seed)) * w * 0.06
            let y: Double = h * (0.5 + 0.45 * sin(t * (0.15 + 0.08 * random(seed, 2)) + Double(seed) * 1.9))
            let r: Double = m * (0.08 + 0.06 * random(seed, 3))
            return CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)
        }
    }

    // MARK: Pieces shared between styles

    private static func auroraRibbon(_ context: GraphicsContext, index: Int, size: CGSize, time t: Double, color: Color) {
        let w = size.width, h = size.height
        let k = Double(index)
        let base: Double = h * (0.22 + 0.16 * k)
        var top: [CGPoint] = []
        var bottom: [CGPoint] = []
        for step in 0...40 {
            let x: Double = w * Double(step) / 40
            let u: Double = x / w
            let wave: Double = sin(u * .pi * 2.2 + t * 0.35 * (1 + 0.3 * k) + k * 1.4)
            let y: Double = base + h * 0.1 * wave
            let thickness: Double = h * (0.12 + 0.08 * sin(u * .pi * 3 + t * 0.25 + k))
            top.append(CGPoint(x: x, y: y))
            bottom.append(CGPoint(x: x, y: y + thickness))
        }
        var ribbon = Path()
        ribbon.addLines(top + bottom.reversed())
        ribbon.closeSubpath()
        let gradient = Gradient(colors: [color.opacity(0.9), color.opacity(0)])
        context.fill(ribbon, with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: base - h * 0.1),
                                                   endPoint: CGPoint(x: 0, y: base + h * 0.25)))
    }

    private static func glow(_ context: GraphicsContext, at center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [color.opacity(opacity), color.opacity(0)]),
                                                                  center: center, startRadius: 0, endRadius: radius))
    }

    /// A retro sun with horizontal slots cut out of its lower half, drifting down.
    private static func stripedSun(_ context: GraphicsContext, center: CGPoint, radius: CGFloat, colors: [Color], time t: Double) {
        context.drawLayer { layer in
            let sun = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            layer.fill(sun, with: .linearGradient(Gradient(colors: colors),
                                                  startPoint: CGPoint(x: center.x, y: center.y - radius),
                                                  endPoint: CGPoint(x: center.x, y: center.y + radius)))
            layer.blendMode = .destinationOut
            let gap = radius * 0.2
            let drift = (t * 0.15).truncatingRemainder(dividingBy: 1) * gap
            for i in 0..<7 {
                let y = center.y + radius * 0.05 + Double(i) * gap + drift
                let thickness = gap * (0.12 + 0.07 * Double(i))
                layer.fill(Path(CGRect(x: center.x - radius, y: y, width: radius * 2, height: thickness)), with: .color(.black))
            }
        }
    }

    private static func stars(_ context: GraphicsContext, size: CGSize, count: Int, time t: Double, maxOpacity: Double) {
        for i in 0..<count {
            let x = random(i, 11) * size.width
            let y = random(i, 12) * size.height
            let r = 0.5 + pow(random(i, 13), 3) * 1.8
            let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * (0.8 + random(i, 14) * 2.5) + random(i, 15) * 6.28))
            context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(twinkle * maxOpacity)))
        }
    }

    /// A stable pseudo-random number in 0..<1 for an index and a salt.
    static func random(_ index: Int, _ salt: Int) -> Double {
        var x = UInt64(truncatingIfNeeded: index &* 374_761_393 &+ salt &* 668_265_263 &+ 1)
        x = (x ^ (x >> 13)) &* 1_274_126_177
        x ^= x >> 16
        return Double(x % 10_000) / 10_000
    }

    static func fraction(_ value: Double) -> Double {
        value - value.rounded(.down)
    }
}
