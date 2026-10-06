import AllSetCore
import AppKit
import SwiftUI

/// A photo behind a widget: filling it, softened if asked, and shaded at the
/// top and bottom where text usually sits, so white text always reads.
struct PhotoBackground: View {
    let source: ImageSource
    var blur = 0.0
    let library: ImageLibrary

    var body: some View {
        // Widget-sized: a copy of at most 768 pixels is sharp at any widget size.
        PhotoContent(source: source, filter: .none, tint: .white, animated: false, library: library, maxPixels: 768)
            .blur(radius: blur * 22, opaque: true)
            .overlay {
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.32), location: 0),
                    .init(color: .black.opacity(0.04), location: 0.38),
                    .init(color: .black.opacity(0.06), location: 0.62),
                    .init(color: .black.opacity(0.45), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
            .overlay(Grain(opacity: 0.05))
    }
}

/// Colors from a palette drifting into one another, like the iOS gradients.
/// The mesh is drawn once and Core Animation turns and blends it, so a widget
/// that drifts all day costs nothing between frames.
struct MeshBackground: View {
    let palette: ArtPalette
    var animated = true
    var speed = 1.0
    @Environment(\.widgetIsVisible) private var isVisible
    @State private var frames: MeshFrames?

    var body: some View {
        Group {
            if #available(macOS 15, *) {
                if animated, isVisible, let frames {
                    DriftingImage(image: frames.base, overlay: frames.overlay, motion: .flow, period: 22 / max(speed, 0.1))
                } else {
                    Self.mesh(palette, time: 3)
                }
            } else {
                ArtView(piece: ArtPiece(style: .blobs, palette: palette), animated: animated && isVisible, speed: speed)
            }
        }
        .overlay(Grain(opacity: 0.07))
        .task(id: palette) {
            guard animated, #available(macOS 15, *) else { return }
            frames = Self.frames(for: palette)
        }
    }

    struct MeshFrames {
        let base: CGImage
        let overlay: CGImage
    }

    @MainActor private static var cache: [ArtPalette: MeshFrames] = [:]

    /// Two moments of the mesh, drawn once per palette.
    @available(macOS 15, *)
    private static func frames(for palette: ArtPalette) -> MeshFrames? {
        if let cached = cache[palette] { return cached }
        func render(_ time: Double) -> CGImage? {
            let renderer = ImageRenderer(content: mesh(palette, time: time).frame(width: 420, height: 420))
            renderer.scale = 1
            return renderer.cgImage
        }
        guard let base = render(3), let overlay = render(8.5) else { return nil }
        let frames = MeshFrames(base: base, overlay: overlay)
        cache[palette] = frames
        return frames
    }

    @available(macOS 15, *)
    private static func mesh(_ palette: ArtPalette, time: Double) -> some View {
        MeshGradient(width: 3, height: 3, points: points(time), colors: colors(palette), smoothsColors: true)
    }

    /// The palette spread over the grid: dark corners, accents in between.
    private static func colors(_ palette: ArtPalette) -> [Color] {
        let c = palette.colors.map { Color($0) }
        return [c[0], c[2], c[1],
                c[3], c[4], c[2],
                c[1], c[3], c[0]]
    }

    /// Corners stay put; edge points slide along their edge; the middle wanders.
    private static func points(_ t: Double) -> [SIMD2<Float>] {
        func wave(_ speed: Double, _ phase: Double, _ amount: Double) -> Float {
            Float(sin(t * speed + phase) * amount)
        }
        return [
            [0, 0], [0.5 + wave(0.9, 0, 0.18), 0], [1, 0],
            [0, 0.5 + wave(0.7, 1.3, 0.2)], [0.5 + wave(0.6, 2, 0.16), 0.5 + wave(0.8, 0.4, 0.16)], [1, 0.5 + wave(0.75, 2.6, 0.2)],
            [0, 1], [0.5 + wave(0.85, 3.1, 0.18), 1], [1, 1],
        ]
    }
}

/// Fine film grain, which makes flat gradients and photos look richer. One
/// small noise tile, drawn once and repeated.
struct Grain: View {
    var opacity = 0.06

    var body: some View {
        Image(nsImage: Self.tile)
            .resizable(resizingMode: .tile)
            .blendMode(.overlay)
            .opacity(opacity)
            .allowsHitTesting(false)
    }

    /// Gray noise stored as color pixels in the layout Core Animation keeps
    /// (BGRA, sRGB), so tiling it never converts a pixel.
    @MainActor private static let tile: NSImage = {
        let side = 128
        let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        if let pixels = context.data?.bindMemory(to: UInt8.self, capacity: side * side * 4) {
            for index in 0..<(side * side) {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let value = UInt8(truncatingIfNeeded: seed >> 56)
                pixels[index * 4] = value
                pixels[index * 4 + 1] = value
                pixels[index * 4 + 2] = value
                pixels[index * 4 + 3] = 255
            }
        }
        let image = context.makeImage()!
        return NSImage(cgImage: image, size: NSSize(width: side, height: side))
    }()
}
