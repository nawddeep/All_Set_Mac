import AllSetCore
import AppKit
import Metal
import MetalKit
import OSLog
import SwiftUI

/// Moving art drawn by the GPU. The same pictures as `ArtRenderer`, written as
/// one fragment shader: each frame costs the app a single draw call instead
/// of redrawing hundreds of shapes, so a Live Scene or art wallpaper can run
/// all day. The shader is compiled from source once, in the background, when
/// the app starts; until it's ready (or if the Mac can't), `ArtView` falls
/// back to drawing with SwiftUI.
@MainActor
final class ArtGPU {
    /// Views read this, so they switch to the GPU once the shader is ready.
    @Observable @MainActor
    final class Ready {
        var gpu: ArtGPU?
    }

    static let ready = Ready()
    static var shared: ArtGPU? { ready.gpu }
    private static var isPreparing = false
    nonisolated private static let log = Logger(subsystem: "com.pratik.allset", category: "art")

    let device: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState

    private init(device: MTLDevice, queue: MTLCommandQueue, pipeline: MTLRenderPipelineState) {
        self.device = device
        self.queue = queue
        self.pipeline = pipeline
    }

    #if DEBUG
    /// Compiles now, reporting any error: for checking the shader.
    static func compileNow() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return }
        let library = try device.makeLibrary(source: ArtShaderSource.code, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "art_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "art_fragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        ready.gpu = ArtGPU(device: device, queue: queue, pipeline: try device.makeRenderPipelineState(descriptor: descriptor))
    }
    #endif

    /// Compiles the shader off the main thread; `shared` is set when done.
    static func prepare() {
        guard ready.gpu == nil, !isPreparing, let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return }
        isPreparing = true
        Task.detached(priority: .utility) {
            do {
                let library = try await device.makeLibrary(source: ArtShaderSource.code, options: nil)
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name: "art_vertex")
                descriptor.fragmentFunction = library.makeFunction(name: "art_fragment")
                descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                let pipeline = try await device.makeRenderPipelineState(descriptor: descriptor)
                await MainActor.run {
                    ready.gpu = ArtGPU(device: device, queue: queue, pipeline: pipeline)
                    isPreparing = false
                }
            } catch {
                log.error("Art shader failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run { isPreparing = false }
            }
        }
    }
}

/// Draws a piece of art on the GPU, animating at `frameRate`.
struct MetalArtView: NSViewRepresentable {
    let gpu: ArtGPU
    let piece: ArtPiece
    var speed = 1.0
    var frameRate = 30
    /// Draws this moment instead of now, for comparing with the SwiftUI drawing.
    var fixedTime: Double?

    func makeNSView(context: Context) -> ArtMetalView {
        let view = ArtMetalView(gpu: gpu)
        update(view)
        return view
    }

    func updateNSView(_ view: ArtMetalView, context: Context) {
        update(view)
    }

    private func update(_ view: ArtMetalView) {
        view.piece = piece
        view.speed = speed
        view.fixedTime = fixedTime
        if view.preferredFramesPerSecond != frameRate { view.preferredFramesPerSecond = frameRate }
    }

    final class ArtMetalView: MTKView, MTKViewDelegate {
        private let gpu: ArtGPU
        var piece = ArtPiece(style: .blobs, palette: .sunset) {
            didSet { if piece != oldValue { colors = Self.colors(piece.palette) } }
        }
        var speed = 1.0
        var fixedTime: Double?
        private var colors = ArtMetalView.colors(.sunset)

        init(gpu: ArtGPU) {
            self.gpu = gpu
            super.init(frame: .zero, device: gpu.device)
            delegate = self
            colorPixelFormat = .bgra8Unorm
            framebufferOnly = true
            // The shader mixes colors the way Core Graphics does, in sRGB.
            (layer as? CAMetalLayer)?.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
            layer?.isOpaque = true
        }

        required init(coder: NSCoder) { fatalError("Not used") }

        private static func colors(_ palette: ArtPalette) -> [SIMD4<Float>] {
            palette.colors.map { SIMD4(Float($0.red), Float($0.green), Float($0.blue), 1) }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        #if DEBUG
        /// Frames drawn, for the CPU probe.
        static var framesDrawn = 0
        #endif

        func draw(in view: MTKView) {
            #if DEBUG
            Self.framesDrawn += 1
            #endif
            guard let pass = currentRenderPassDescriptor, let drawable = currentDrawable,
                  let buffer = gpu.queue.makeCommandBuffer(),
                  let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
            let scale = bounds.width > 0 ? Float(drawableSize.width / bounds.width) : 2
            // The same clock as the SwiftUI version, kept small so a Float holds it precisely.
            let time = fixedTime ?? (Date.now.timeIntervalSinceReferenceDate * speed).truncatingRemainder(dividingBy: 10_000)
            ArtItems.fill(&items, style: piece.style, size: bounds.size, time: time)
            var buildings = 0
            if piece.style == .skyline { ArtRenderer.skylineBuildings(size: bounds.size) { _, _, _, _ in buildings += 1 } }
            var uniforms = ArtUniforms(
                info: SIMD4(Float(bounds.width), Float(bounds.height), scale, Float(time)),
                extra: SIMD4(Float(ArtStyle.allCases.firstIndex(of: piece.style) ?? 0), Float(items.count), Float(buildings), 0),
                c0: colors[0], c1: colors[1], c2: colors[2], c3: colors[3], c4: colors[4])
            if items.isEmpty { items.append(.zero) }
            encoder.setRenderPipelineState(gpu.pipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ArtUniforms>.stride, index: 0)
            items.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 1) }
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            buffer.present(drawable)
            buffer.commit()
        }

        /// Reused every frame, so drawing allocates nothing.
        private var items: [SIMD4<Float>] = {
            var items: [SIMD4<Float>] = []
            items.reserveCapacity(ArtItems.maximum)
            return items
        }()
    }
}

/// Matches `Uniforms` in the shader.
struct ArtUniforms {
    var info: SIMD4<Float>
    var extra: SIMD4<Float>
    var c0, c1, c2, c3, c4: SIMD4<Float>
}

/// The scattered things in a picture (stars, drops, bubbles, blobs), placed
/// on the CPU with `ArtRenderer`'s own random numbers, once a frame: the GPU
/// would otherwise work them out again for every pixel.
enum ArtItems {
    static let maximum = 192

    static func fill(_ items: inout [SIMD4<Float>], style: ArtStyle, size: CGSize, time t: Double) {
        items.removeAll(keepingCapacity: true)
        let w = size.width, h = size.height, m = max(w, h)
        let random = ArtRenderer.random
        func stars(_ count: Int, area: CGSize, opacity: Double) {
            for i in 0..<count {
                let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * (0.8 + random(i, 14) * 2.5) + random(i, 15) * 6.28))
                items.append(SIMD4(Float(random(i, 11) * area.width), Float(random(i, 12) * area.height),
                                   Float(0.5 + pow(random(i, 13), 3) * 1.8), Float(twinkle * opacity)))
            }
        }
        switch style {
        case .aurora:
            stars(30, area: size, opacity: 0.5)
        case .synthwave:
            stars(25, area: CGSize(width: w, height: h * 0.58 * 0.6), opacity: 0.7)
        case .stars:
            stars(110, area: size, opacity: 1)
        case .bokeh:
            for i in 0..<22 {
                let r = m * (0.03 + random(i, 1) * 0.09)
                let x = random(i, 2) * w + sin(t * 0.3 + Double(i)) * w * 0.03
                let y = h + r - ArtRenderer.fraction(random(i, 4) + t * (0.02 + random(i, 3) * 0.05)) * (h + 2 * r)
                items.append(SIMD4(Float(x), Float(y), Float(r), Float(0.2 + random(i, 5) * 0.35)))
            }
        case .lava:
            for layer in 0..<2 {
                for i in 0..<5 {
                    let seed = i + layer * 11
                    let x = w * (0.2 + 0.6 * random(seed, 1)) + sin(t * 0.3 + Double(seed)) * w * 0.06
                    let y = h * (0.5 + 0.45 * sin(t * (0.15 + 0.08 * random(seed, 2)) + Double(seed) * 1.9))
                    items.append(SIMD4(Float(x), Float(y), Float(m * (0.08 + 0.06 * random(seed, 3))), Float(layer)))
                }
            }
        case .rain:
            for i in 0..<80 {
                let length = h * (0.04 + random(i, 2) * 0.06)
                let x = random(i, 1) * w * 1.1 - w * 0.05
                let speed = h * (0.6 + random(i, 3) * 0.8)
                let y = (random(i, 4) * h + t * speed).truncatingRemainder(dividingBy: h + length) - length
                items.append(SIMD4(Float(x), Float(y), Float(length), Float(0.2 + 0.35 * random(i, 5))))
            }
        case .orbits:
            for i in 0..<6 {
                let k = Double(i)
                let start = t * (0.35 + 0.12 * k) * (i.isMultiple(of: 2) ? 1 : -1) + k
                items.append(SIMD4(Float(start.truncatingRemainder(dividingBy: 2 * .pi)), Float(0.6 + random(i, 1) * 1.4), 0, 0))
            }
        case .clouds:
            // Seven clouds, then the sparkles.
            ArtRenderer.clouds(size: size, time: t) { items.append(SIMD4(Float($0), Float($1), Float($2), Float($3))) }
            ArtRenderer.sparkles(size: size, time: t, count: 14, salt: 20) { items.append(SIMD4(Float($0), Float($1), Float($2), Float($3))) }
        case .hearts:
            // Twenty-two hearts, then the sparkles.
            ArtRenderer.hearts(size: size, time: t) { items.append(SIMD4(Float($0), Float($1), Float($2), Float($3))) }
            ArtRenderer.sparkles(size: size, time: t, count: 10, salt: 40) { items.append(SIMD4(Float($0), Float($1), Float($2), Float($3))) }
        case .leopard:
            ArtRenderer.leopardSpots(size: size, time: t) { items.append(SIMD4(Float($0), Float($1), Float($2), Float($3))) }
        case .film:
            ArtRenderer.filmDust(size: size, time: t) { items.append(SIMD4(Float($0), Float($1), Float($2), Float($3))) }
        case .skyline:
            // Buildings (their count goes to the shader separately), then rain.
            ArtRenderer.skylineBuildings(size: size) { items.append(SIMD4(Float($0), Float($1), Float($2), Float($3))) }
            ArtRenderer.skylineRain(size: size, time: t) { items.append(SIMD4(Float($0), Float($1), Float($2), Float($3))) }
        case .embers:
            ArtRenderer.embers(size: size, time: t) { items.append(SIMD4(Float($0), Float($1), Float($2), Float($3))) }
        case .stadium:
            ArtRenderer.stadiumFlashes(size: size, time: t) { items.append(SIMD4(Float($0), Float($1), Float($2), Float($3))) }
        case .palms:
            // Two items a stroke: its ends, then its thickness.
            ArtRenderer.palmSegments(size: size, time: t) { x0, y0, x1, y1, thickness in
                items.append(SIMD4(Float(x0), Float(y0), Float(x1), Float(y1)))
                items.append(SIMD4(Float(thickness), 0, 0, 0))
            }
        case .smoke:
            // Two items a wisp: center, angle and life, then its length.
            var index = 0
            ArtRenderer.smokeWisps(size: size, time: t) { x, y, angle, life in
                items.append(SIMD4(Float(x), Float(y), Float(angle), Float(life)))
                items.append(SIMD4(Float(m * (0.16 + 0.08 * random(index, 84))), 0, 0, 0))
                index += 1
            }
        default:
            break
        }
    }
}
