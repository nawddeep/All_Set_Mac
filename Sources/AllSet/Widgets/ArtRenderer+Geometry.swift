import AllSetCore
import SwiftUI

/// The shapes and positions behind each art style, as functions of size and time.
extension ArtRenderer {
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
    static let grainImage: Image = {
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
    static func heartParts(side a: Double) -> [Path] {
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
    static func sparkle(_ context: GraphicsContext, x: Double, y: Double, size s: Double, color: Color, opacity: Double) {
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
    static func vignette(_ context: GraphicsContext, size: CGSize, color: Color, from: Double, to: Double, opacity: Double) {
        let m = max(size.width, size.height)
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(stops: [.init(color: color.opacity(0), location: from / to), .init(color: color.opacity(opacity), location: 1)]),
            center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: 0, endRadius: m * to))
    }

    static func lavaBlobs(layer: Int, size: CGSize, time t: Double) -> [CGRect] {
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

    static func auroraRibbon(_ context: GraphicsContext, index: Int, size: CGSize, time t: Double, color: Color) {
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

    static func glow(_ context: GraphicsContext, at center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [color.opacity(opacity), color.opacity(0)]),
                                                                  center: center, startRadius: 0, endRadius: radius))
    }

    /// A retro sun with horizontal slots cut out of its lower half, drifting down.
    static func stripedSun(_ context: GraphicsContext, center: CGPoint, radius: CGFloat, colors: [Color], time t: Double) {
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

    static func stars(_ context: GraphicsContext, size: CGSize, count: Int, time t: Double, maxOpacity: Double) {
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
