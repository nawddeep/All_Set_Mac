import AllSetCore
import SwiftUI

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
struct GlitterTexture: View {
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
