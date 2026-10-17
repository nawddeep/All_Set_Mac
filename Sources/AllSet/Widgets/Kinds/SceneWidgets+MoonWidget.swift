import AllSetCore
import AppKit
import CoreImage
import SwiftUI
import Vision

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
struct NightSky: View {
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
