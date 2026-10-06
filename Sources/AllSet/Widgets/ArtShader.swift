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

/// The art styles as Metal. Coordinates are points with the origin at the
/// top left, as in `ArtRenderer`; each style follows its drawing there.
enum ArtShaderSource {
    static let code = """
    #include <metal_stdlib>
    using namespace metal;

    struct Uniforms {
        float4 info;   // width, height (points), pixels per point, time
        float4 extra;  // style, item count
        float4 c[5];   // palette: background top, bottom, three accents
    };

    struct VOut { float4 position [[position]]; };

    vertex VOut art_vertex(uint id [[vertex_id]]) {
        float2 p = float2((id << 1) & 2, id & 2);
        VOut out;
        out.position = float4(p * 2 - 1, 0, 1);
        return out;
    }

    static float fract1(float v) { return v - floor(v); }

    // Paints `color` over `dst` with coverage `a`.
    static float3 over(float3 dst, float3 color, float a) { return mix(dst, color, clamp(a, 0.0, 1.0)); }

    // Coverage of a shape from its signed distance (negative inside), anti-aliased over a pixel.
    static float cover(float d, float px) { return clamp(0.5 - d / px, 0.0, 1.0); }

    // Coverage blurred over `radius`, for shapes drawn inside a blur filter.
    static float soft(float d, float radius) { return 1.0 - smoothstep(-radius, radius, d); }

    static float3 glow(float3 dst, float2 p, float2 center, float radius, float3 color, float opacity) {
        return over(dst, color, opacity * max(0.0, 1.0 - length(p - center) / radius));
    }

    static float segment(float2 p, float2 a, float2 b) {
        float2 pa = p - a, ba = b - a;
        float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
        return length(pa - ba * h);
    }

    // Stars placed on the CPU: x, y, radius, opacity.
    static float3 stars(float3 dst, float2 p, constant float4 *items, int count, float px) {
        for (int i = 0; i < count; i++) {
            float4 s = items[i];
            if (abs(p.x - s.x) > 3.0 || abs(p.y - s.y) > 3.0) continue;
            dst = over(dst, float3(1), cover(length(p - s.xy) - s.z, px) * s.w);
        }
        return dst;
    }

    // A four-pointed sparkle (x, y, size, brightness) with a soft glow.
    static float3 sparkle(float3 dst, float2 p, float4 s, float3 color, float px) {
        if (s.w < 0.01) return dst;
        float2 a = abs(p - s.xy) / s.z;
        if (a.x > 2.5 || a.y > 2.5) return dst;
        dst = glow(dst, p, s.xy, s.z * 2.5, color, 0.35 * s.w);
        float f = pow(a.x, 0.6667) + pow(a.y, 0.6667) - 1.0;
        return over(dst, color, cover(f * s.z * 0.5, px) * s.w);
    }

    // Distance to a heart built on a square of side `a` turned 45°, point down.
    static float heartDistance(float2 q, float a) {
        float k = 0.70710678;
        float2 r = float2((q.x + q.y) * k, (q.y - q.x) * k);
        float2 d = abs(r) - a * 0.5;
        float box = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
        float h = a * 0.5 * k;
        float c1 = length(q - float2(-h, -h)) - a * 0.5;
        float c2 = length(q - float2(h, -h)) - a * 0.5;
        return min(box, min(c1, c2));
    }

    // ArtRenderer.hash: a 32-bit integer hash to 0...1.
    static float hash3(int a, int b, int c) {
        uint x = uint(a) * 374761393u + uint(b) * 668265263u + uint(c) * 2246822519u;
        x = (x ^ (x >> 13)) * 1274126177u;
        x ^= x >> 16;
        return float(x & 0xFFFFu) / 65535.0;
    }

    // ArtRenderer.windowIsLit.
    static bool windowLit(int column, int row, int building, float t) {
        bool on = hash3(column, row, building) < 0.3;
        int epoch = int(floor(t / 9.0 + hash3(column, row, building + 77) * 9.0));
        if (hash3(column, row, epoch + building * 131) < 0.06) on = !on;
        return on;
    }

    // Noise that changes every frame, for film grain.
    static float grain(float2 cell, float frame) {
        return fract1(sin(dot(cell + frame * float2(7.13, 3.71), float2(12.9898, 78.233))) * 43758.5453);
    }

    // A retro sun with slots cut from its lower half, drifting down. Returns coverage and color.
    static float4 stripedSun(float2 p, float2 center, float radius, float3 top, float3 bottom, float t, float px) {
        float inside = cover(length(p - center) - radius, px);
        if (inside <= 0.0) return float4(0);
        float gap = radius * 0.2;
        float drift = fract1(t * 0.15) * gap;
        for (int i = 0; i < 7; i++) {
            float y = center.y + radius * 0.05 + float(i) * gap + drift;
            float thickness = gap * (0.12 + 0.07 * float(i));
            if (p.y >= y && p.y <= y + thickness) return float4(0);
        }
        float f = clamp((p.y - (center.y - radius)) / (2.0 * radius), 0.0, 1.0);
        return float4(mix(top, bottom, f), inside);
    }

    fragment float4 art_fragment(VOut in [[stage_in]], constant Uniforms &u [[buffer(0)]],
                                 constant float4 *items [[buffer(1)]]) {
        float w = u.info.x, h = u.info.y, scale = u.info.z, t = u.info.w;
        float m = max(w, h), n = min(w, h);
        float px = 1.0 / scale;
        float2 p = in.position.xy / scale;
        int style = int(u.extra.x + 0.5);
        int count = int(u.extra.y + 0.5);
        float3 c0 = u.c[0].rgb, c1 = u.c[1].rgb, c2 = u.c[2].rgb, c3 = u.c[3].rgb, c4 = u.c[4].rgb;
        float3 accents[3] = { c2, c3, c4 };

        // Background: top color to bottom color, slanting.
        float2 gradientEnd = float2(w * 0.35, h);
        float3 col = mix(c0, c1, clamp(dot(p, gradientEnd) / dot(gradientEnd, gradientEnd), 0.0, 1.0));

        switch (style) {
        case 0: { // blobs
            for (int i = 0; i < 4; i++) {
                float k = float(i);
                float2 center = float2(w * (0.5 + 0.38 * sin(t * (0.21 + 0.05 * k) + k * 1.7)),
                                       h * (0.5 + 0.38 * cos(t * (0.17 + 0.04 * k) + k * 2.3)));
                col = glow(col, p, center, m * (0.6 - 0.07 * k), accents[i % 3], 0.85);
            }
            break;
        }
        case 1: { // aurora
            col = glow(col, p, float2(w * 0.5, h * 1.15), m * 0.8, c4, 0.3);
            col = stars(col, p, items, count, px);
            float blur = m * 0.035;
            for (int i = 0; i < 3; i++) {
                float k = float(i);
                float uu = p.x / w;
                float base = h * (0.22 + 0.16 * k);
                float y0 = base + h * 0.1 * sin(uu * M_PI_F * 2.2 + t * 0.35 * (1.0 + 0.3 * k) + k * 1.4);
                float y1 = y0 + h * (0.12 + 0.08 * sin(uu * M_PI_F * 3.0 + t * 0.25 + k));
                float inside = soft(y0 - p.y, blur) * soft(p.y - y1, blur);
                float fade = 0.9 * (1.0 - clamp((p.y - (base - h * 0.1)) / (h * 0.35), 0.0, 1.0));
                col = over(col, accents[i % 3], inside * fade);
            }
            break;
        }
        case 2: { // sunset
            col = glow(col, p, float2(w * 0.5, h * 0.68), m * 0.7, c3, 0.5);
            float radius = n * 0.3;
            float4 sun = stripedSun(p, float2(w * 0.5, h * 0.64 + h * 0.015 * sin(t * 0.3)), radius, c4, c2, t, px);
            col = over(col, sun.rgb, sun.a);
            if (p.y >= h * 0.8) {
                float f = clamp((p.y - h * 0.8) / (h * 0.2), 0.0, 1.0);
                float alpha = mix(0.85, 1.0, f);
                float3 premultiplied = mix(c1 * 0.85, c0, f);
                col = col * (1.0 - alpha) + premultiplied;
            }
            for (int i = 0; i < 7; i++) {
                float k = float(i);
                float y = h * (0.83 + 0.022 * k);
                float span = radius * (1.4 - 0.15 * k) * (0.85 + 0.15 * sin(t * 0.8 + k));
                float d = segment(p, float2(w / 2 - span / 2, y), float2(w / 2 + span / 2, y)) - max(h * 0.008, 1.0) / 2;
                col = over(col, c3, cover(d, px) * (0.55 - 0.06 * k));
            }
            break;
        }
        case 3: { // waves
            col = glow(col, p, float2(w * 0.75, h * 0.2), m * 0.35, c4, 0.35);
            for (int i = 0; i < 4; i++) {
                float k = float(i);
                float base = h * (0.42 + 0.14 * k);
                float y = base + h * 0.045 * (1.0 + 0.3 * k)
                    * sin(p.x / w * M_PI_F * 2.0 * (1.3 + 0.4 * k) + t * (0.5 + 0.22 * k) + k * 2.0);
                col = over(col, accents[i % 3], cover(y - p.y, px) * (0.45 + 0.15 * k));
            }
            break;
        }
        case 4: { // synthwave
            float horizon = h * 0.58;
            if (p.y < horizon) {
                float f = clamp(p.y / horizon, 0.0, 1.0);
                float alpha = mix(1.0, 0.85, f);
                col = col * (1.0 - alpha) + mix(c0, c2 * 0.85, f);
                col = stars(col, p, items, count, px);
                float4 sun = stripedSun(p, float2(w / 2, horizon), n * 0.3, c4, c2, t, px);
                col = over(col, sun.rgb, sun.a);
            } else {
                col = c0;
                float travel = fract1(t * 0.45);
                for (int i = 0; i < 12; i++) {
                    float y = horizon + (h - horizon) * pow((float(i) + travel) / 12.0, 2.2);
                    col = over(col, c3, cover(abs(p.y - y) - 0.5, px) * 0.85);
                }
                for (int i = -12; i <= 12; i++) {
                    float d = segment(p, float2(w / 2 + float(i) * w * 0.02, horizon), float2(w / 2 + float(i) * w * 0.16, h)) - 0.5;
                    col = over(col, c3, cover(d, px) * 0.85);
                }
            }
            col = glow(col, p, float2(w / 2, horizon), w * 0.6, c3, 0.25);
            break;
        }
        case 5: { // dunes
            col = glow(col, p, float2(w * 0.7, h * 0.3), m * 0.3, c4, 0.6);
            float3 layers[5] = { c4, c3, c2, c1, c0 };
            for (int i = 0; i < 5; i++) {
                float k = float(i);
                float uu = p.x / w;
                float y = h * (0.38 + 0.13 * k)
                    + h * 0.06 * sin(uu * M_PI_F * 2.0 * (0.6 + 0.2 * k) + k * 1.3 + t * 0.05 * (k + 1.0))
                    + h * 0.025 * sin(uu * M_PI_F * 2.0 * 2.1 + k);
                col = over(col, layers[i], cover(y - p.y, px) * (i == 0 ? 0.6 : 0.95));
            }
            break;
        }
        case 6: { // stars
            col = glow(col, p, float2(w * 0.3, h * 0.35), m * 0.5, c2, 0.35);
            col = glow(col, p, float2(w * 0.75, h * 0.7), m * 0.45, c4, 0.25);
            col = stars(col, p, items, count, px);
            float phase = fract1(t / 9.0);
            if (phase < 0.12) {
                float q = phase / 0.12;
                float2 start = float2(w * (0.2 + 0.6 * q), h * (0.1 + 0.3 * q));
                float2 end = start - float2(w * 0.12, h * 0.06);
                float along = clamp(dot(p - start, end - start) / dot(end - start, end - start), 0.0, 1.0);
                col = over(col, float3(1), cover(segment(p, start, end) - 0.75, px) * 0.9 * (1.0 - q) * (1.0 - along));
            }
            break;
        }
        case 7: { // bokeh
            float blur = m * 0.01;
            for (int i = 0; i < count; i++) {
                float4 b = items[i];
                float d = length(p - b.xy) - b.z;
                if (d > blur * 2.0 + 1.0) continue;
                float3 color = accents[i % 3];
                col = over(col, color, soft(d, blur) * b.w);
                col = over(col, color, soft(abs(d) - 0.5, blur) * 0.4);
            }
            break;
        }
        case 8: { // lava
            col = glow(col, p, float2(w / 2, h), m * 0.7, c3, 0.35);
            float3 colors[2] = { c2, c4 };
            for (int layer = 0; layer < 2; layer++) {
                float halo = 0.0, field = 0.0;
                for (int i = 0; i < count; i++) {
                    float4 b = items[i];
                    if (int(b.w + 0.5) != layer) continue;
                    float d = length(p - b.xy) - b.z;
                    // SwiftUI's blur radius spreads about half as far as `soft`'s.
                    halo = max(halo, soft(d, m * 0.04));
                    field += soft(d, m * 0.03);
                }
                col = over(col, colors[layer], halo * 0.45);
                // Blobs melt together where their blurred edges add up past half.
                float edge = max(fwidth(field), 1e-4);
                col = over(col, colors[layer], clamp((field - 0.5) / edge + 0.5, 0.0, 1.0));
            }
            break;
        }
        case 9: { // rain
            col = glow(col, p, float2(w * 0.3, h * 0.25), m * 0.5, c2, 0.35);
            col = glow(col, p, float2(w * 0.8, h * 0.9), m * 0.4, c3, 0.3);
            for (int i = 0; i < count; i++) {
                float4 drop = items[i];
                float length = drop.z;
                if (p.x > drop.x + 1.0 || p.x < drop.x - length * 0.15 - 1.0) continue;
                float d = segment(p, drop.xy, float2(drop.x - length * 0.15, drop.y + length)) - 0.5;
                col = over(col, c4, cover(d, px) * drop.w);
            }
            break;
        }
        case 10: { // orbits
            float2 center = float2(w / 2, h / 2);
            col = glow(col, p, center, m * 0.4, c2, 0.5);
            float2 q = p - center;
            float distance = length(q);
            float angle = atan2(q.y, q.x);
            float width = max(n * 0.012, 2.0);
            for (int i = 0; i < 6; i++) {
                float k = float(i);
                float radius = n * (0.1 + 0.065 * k);
                col = over(col, c4, cover(abs(distance - radius) - 0.5, px) * 0.14);
                float start = items[i].x;
                float sweep = items[i].y;
                float into = fract1((angle - start) / (2.0 * M_PI_F)) * 2.0 * M_PI_F;
                float d = into <= sweep ? abs(distance - radius) - width / 2 : 1e5;
                float2 a = center + radius * float2(cos(start), sin(start));
                float2 b = center + radius * float2(cos(start + sweep), sin(start + sweep));
                d = min(d, min(length(p - a), length(p - b)) - width / 2);
                float3 color = accents[i % 3];
                col = over(col, color, cover(d, px));
                col = glow(col, p, b, n * 0.04, color, 0.9);
            }
            break;
        }
        case 11: { // stripes
            float2 corner = float2(-w * 0.05, h * 1.05);
            float3 bands[6] = { c2, c3, c4, c3, c2, c1 };
            float distance = length(p - corner);
            for (int i = 0; i < 6; i++) {
                float k = float(i);
                float r = m * (1.25 - 0.17 * k) + sin(t * 0.3 + k * 0.8) * m * 0.012;
                col = over(col, bands[i], cover(distance - r, px));
            }
            break;
        }
        case 12: { // clouds
            col = glow(col, p, float2(w * 0.82, h * 0.12), m * 0.45, c3, 0.45);
            float3 puffs[5] = { float3(-1.6, 0.25, 0.95), float3(-0.65, -0.35, 1.3), float3(0.55, -0.6, 1.5),
                                float3(1.65, 0.1, 1.05), float3(0.0, 0.45, 1.2) };
            for (int i = 0; i < min(count, 7); i++) {
                float4 c = items[i];
                float s = c.z;
                float2 q = (p - c.xy) / s;
                if (abs(q.x) > 3.4 || abs(q.y) > 2.9) continue;
                float d = 1e5;
                for (int j = 0; j < 5; j++) d = min(d, length(q - puffs[j].xy) - puffs[j].z);
                bool second = c.w >= 2.0;
                col = over(col, second ? c3 : c2, soft(d * s, s * 0.35) * (c.w - (second ? 2.0 : 0.0)));
            }
            for (int i = 7; i < count; i++) col = sparkle(col, p, items[i], float3(1), px);
            break;
        }
        case 13: { // hearts
            col = glow(col, p, float2(w * 0.5, h * 0.35), m * 0.6, c2, 0.3);
            for (int i = 0; i < min(count, 22); i++) {
                float4 heart = items[i];
                float2 d = p - heart.xy;
                if (abs(d.x) > heart.z * 1.3 || abs(d.y) > heart.z * 1.3) continue;
                float angle = 0.25 * sin(t * 0.7 + float(i) * 1.3);
                float cs = cos(angle), sn = sin(angle);
                float2 q = float2(cs * d.x + sn * d.y, -sn * d.x + cs * d.y);
                col = over(col, accents[i % 3], cover(heartDistance(q, heart.z), px) * heart.w);
            }
            for (int i = 22; i < count; i++) col = sparkle(col, p, items[i], float3(1), px);
            break;
        }
        case 14: { // spiral
            float2 center = float2(w / 2, h / 2);
            float spacing = n * 0.18;
            float2 q = p - center;
            float r = length(q);
            float s = fract1(r / spacing - atan2(q.y, q.x) / (2.0 * M_PI_F) - t * 0.1);
            float d = (s < 0.5 ? -min(s, 0.5 - s) : min(s - 0.5, 1.0 - s)) * spacing;
            col = over(col, mix(c4, c3, clamp(r / (m * 0.7), 0.0, 1.0)), cover(d, px));
            col = glow(col, p, center, m * 0.35, c2, 0.35);
            col = mix(col, c0, clamp((r / m - 0.25) / 0.55, 0.0, 1.0) * 0.6);
            break;
        }
        case 15: { // leopard
            float quarter = M_PI_F * 0.5;
            for (int i = 0; i < count; i++) {
                float4 spot = items[i];
                float2 q = p - spot.xy;
                float radius = spot.z;
                if (abs(q.x) > radius * 1.4 || abs(q.y) > radius * 1.4) continue;
                float len = length(q);
                col = over(col, c3, cover(len - radius * 0.72, px) * 0.6);
                float into = fract1((atan2(q.y, q.x) - spot.w) / (2.0 * M_PI_F)) * 2.0 * M_PI_F;
                float k = floor(into / quarter);
                float next = fmod(k + 1.0, 4.0);
                // Matches ArtRenderer.leopardMark.
                float arc = 0.55 + 0.75 * fract1(spot.w * 3.7 + k * 1.618);
                float width = radius * (0.3 + 0.24 * fract1(spot.w * 5.3 + k * 0.77));
                float nextWidth = radius * (0.3 + 0.24 * fract1(spot.w * 5.3 + next * 0.77));
                float d;
                if (into - k * quarter <= arc) {
                    d = abs(len - radius) - width * 0.5;
                } else {
                    // Between marks: the nearer rounded end, this mark's or the next one's.
                    float a0 = spot.w + k * quarter + arc, a1 = spot.w + (k + 1.0) * quarter;
                    d = min(length(q - radius * float2(cos(a0), sin(a0))) - width * 0.5,
                            length(q - radius * float2(cos(a1), sin(a1))) - nextWidth * 0.5);
                }
                col = over(col, c2, cover(d, px));
            }
            break;
        }
        case 16: { // film
            col = glow(col, p, float2(w * (0.15 + 0.1 * sin(t * 0.13)), h * 0.2), m * 0.55, c2, 0.28 + 0.07 * sin(t * 0.5));
            col = glow(col, p, float2(w * 0.85, h * 0.85), m * 0.5, c4, 0.18);
            for (int i = 0; i < count; i++) {
                float4 speck = items[i];
                if (abs(p.x - speck.x) > 3.0 || abs(p.y - speck.y) > 3.0) continue;
                col = over(col, c4, cover(length(p - speck.xy) - speck.z, px) * speck.w);
            }
            float r = length(p - float2(w / 2, h / 2));
            col = mix(col, float3(0), clamp((r / m - 0.3) / 0.55, 0.0, 1.0) * 0.55);
            float flicker = 0.025 * sin(t * 21.0) * sin(t * 6.7);
            col = flicker > 0.0 ? mix(col, float3(1), flicker) : mix(col, float3(0), -flicker);
            float frame = floor(fmod(t * 12.0, 64.0));
            col = clamp(col + (grain(floor(p * scale / 1.5), frame) - 0.5) * 0.09, 0.0, 1.0);
            break;
        }
        case 17: { // checker
            float cell = n / 6.0;
            float2 bend = float2(sin(p.y / m * 6.0 + t * 0.6), sin(p.x / m * 5.0 + t * 0.5)) * cell * 0.22;
            float2 u = (p + bend + float2(t * cell * 0.12, t * cell * 0.08)) / cell;
            float ramp = cell / (M_PI_F * px);
            float cx = clamp(sin(M_PI_F * u.x) * ramp, -1.0, 1.0);
            float cy = clamp(sin(M_PI_F * u.y) * ramp, -1.0, 1.0);
            col = over(col, c2, 0.5 + 0.5 * cx * cy);
            col = glow(col, p, float2(w / 2, h / 2), m * 0.6, c3, 0.15);
            break;
        }
        case 18: { // skyline
            int buildings = int(u.extra.z + 0.5);
            col = glow(col, p, float2(w * 0.5, h * 0.75), m * 0.7, c4, 0.12);
            // The searchlight: a soft cone, and the spot where it meets the clouds.
            float2 base = float2(w * 0.72, h * 0.95);
            float angle = -M_PI_F / 2.0 + 0.38 * sin(t * 0.12);
            float2 dir = float2(cos(angle), sin(angle));
            float2 q = p - base;
            float along = dot(q, dir);
            if (along > 0.0) {
                float across = abs(q.x * dir.y - q.y * dir.x);
                float spread = 0.07 * along + n * 0.01 * along / (h * 1.3);
                float beam = (1.0 - smoothstep(spread * 0.55, spread + n * 0.02, across)) * mix(0.2, 0.1, clamp(along / (h * 1.3), 0.0, 1.0));
                col = over(col, c3, beam);
            }
            float travel = (base.y - h * 0.16) / max(-dir.y, 0.2);
            col = glow(col, p, base + dir * travel, n * 0.16, c3, 0.35);
            float3 back = mix(c1, c2, 0.25), front = mix(c0, c1, 0.5);
            float cell = max(n * 0.012, 3.0), rowHeight = cell * 1.5;
            for (int i = 0; i < buildings; i++) {
                float4 b = items[i];
                float top = h - b.z;
                if (p.x < b.x || p.x >= b.x + b.y || p.y < top) continue;
                bool isFront = b.w > 0.5;
                col = isFront ? front : back;
                if (!isFront) continue;
                int columns = int(floor((b.y - cell * 0.6) / cell)) - 1;
                float2 local = float2(p.x - b.x - cell * 0.6, p.y - top - rowHeight * 0.8);
                if (local.x < 0.0 || local.y < 0.0) continue;
                int column = int(floor(local.x / cell)), row = int(floor(local.y / rowHeight));
                if (column >= columns) continue;
                float fx = local.x - float(column) * cell, fy = local.y - float(row) * rowHeight;
                if (top + rowHeight * 0.8 + float(row) * rowHeight + rowHeight * 0.5 > h) continue;
                if (fx < cell * 0.55 && fy < rowHeight * 0.5 && windowLit(column, row, i, t)) col = mix(col, c3, 0.85);
            }
            for (int i = buildings; i < count; i++) {
                float4 drop = items[i];
                float length = drop.z;
                if (p.x > drop.x + 1.0 || p.x < drop.x - length * 0.15 - 1.0) continue;
                float d = segment(p, drop.xy, float2(drop.x - length * 0.15, drop.y + length)) - 0.5;
                col = over(col, c4, cover(d, px) * drop.w);
            }
            break;
        }
        case 19: { // embers
            col = glow(col, p, float2(w * 0.5, h * 1.1), m * 0.75, c2, 0.45);
            col = glow(col, p, float2(w * 0.2, h), m * 0.4, c4, 0.2);
            for (int i = 0; i < count; i++) {
                float4 e = items[i];
                float d = length(p - e.xy);
                if (d > e.z * 5.0) continue;
                float3 color = (i % 2 == 0) ? c3 : c4;
                col = glow(col, p, e.xy, e.z * 5.0, color, 0.45 * e.w);
                col = over(col, mix(color, float3(1), 0.35), cover(d - e.z, px) * e.w);
            }
            break;
        }
        case 20: { // stadium
            float horizon = h * 0.62;
            col = glow(col, p, float2(w / 2, horizon), m * 0.6, c3, 0.22);
            if (p.y >= h * 0.36 && p.y < horizon) {
                float f = (p.y - h * 0.36) / (horizon - h * 0.36);
                col = mix(mix(c0, float3(0), 0.3), mix(c1, float3(0), 0.2), f);
                for (int tier = 1; tier < 4; tier++) {
                    float y = h * 0.36 + (horizon - h * 0.36) * float(tier) / 4.0;
                    col = over(col, c1, cover(abs(p.y - y) - 0.5, px) * 0.5);
                }
            }
            for (int i = 0; i < count; i++) {
                float4 flash = items[i];
                if (flash.w <= 0.01) continue;
                col = glow(col, p, flash.xy, flash.z * 8.0, float3(1), 0.8 * flash.w);
            }
            if (p.y >= horizon) {
                float f = (p.y - horizon) / (h - horizon);
                col = mix(mix(c2, float3(0), 0.35), mix(c2, float3(0), 0.62), f);
                int band = int(floor(pow(f, 1.0 / 1.6) * 10.0));
                if (band % 2 == 0) col = over(col, float3(1), 0.05);
                col = over(col, float3(1), cover(abs(p.y - (horizon + 2.0)) - 0.5, px) * 0.4);
                float2 radii = float2(w * 0.14, (h - horizon) * 0.15);
                float2 e = (p - float2(w * 0.5, horizon + (h - horizon) * 0.45)) / radii;
                float d = (length(e) - 1.0) * min(radii.x, radii.y);
                col = over(col, float3(1), cover(abs(d) - 0.5, px) * 0.32);
            }
            float2 lights[4] = { float2(w * 0.08, h * 0.1), float2(w * 0.92, h * 0.1), float2(w * 0.34, h * 0.2), float2(w * 0.66, h * 0.2) };
            for (int i = 0; i < 4; i++) {
                float2 light = lights[i];
                float flicker = 0.92 + 0.08 * sin(t * 0.7 + float(i) * 1.3);
                float2 target = float2(light.x + (w / 2 - light.x) * 0.7, h);
                float2 axis = target - light;
                float span = length(axis);
                float2 dir = axis / span;
                float2 q = p - light;
                float along = dot(q, dir);
                if (along > 0.0 && along < span) {
                    float across = abs(q.x * dir.y - q.y * dir.x);
                    float spread = along * 0.3 * (target.y - light.y) / span;
                    float beam = (1.0 - smoothstep(spread * 0.5, spread + m * 0.02, across)) * mix(0.12, 0.02, along / span) * flicker;
                    col = over(col, c4, beam);
                }
                col = glow(col, p, light, m * 0.25, c4, 0.2 * flicker);
                col = glow(col, p, light, m * 0.045, float3(1), 0.95 * flicker);
            }
            break;
        }
        case 21: { // palms
            float horizon = h * 0.74;
            col = glow(col, p, float2(w * 0.56, h * 0.6), m * 0.55, c3, 0.45);
            if (p.y < horizon) {
                float4 sun = stripedSun(p, float2(w * 0.56, h * 0.6), n * 0.22, c4, c2, t, px);
                col = over(col, sun.rgb, sun.a);
            } else {
                float f = (p.y - horizon) / (h - horizon);
                col = mix(mix(c1, float3(0), 0.25), mix(c0, float3(0), 0.4), f);
                for (int i = 0; i < 8; i++) {
                    float k = float(i);
                    float y = horizon + (h - horizon) * (0.08 + 0.11 * k);
                    float span = n * 0.3 * (1.2 - 0.1 * k) * (0.8 + 0.2 * sin(t * 0.9 + k * 1.7));
                    float thick = max(h * 0.006, 1.0);
                    float d = segment(p, float2(w * 0.56 - span / 2, y), float2(w * 0.56 + span / 2, y)) - thick / 2;
                    col = over(col, c3, cover(d, px) * (0.5 - 0.05 * k));
                }
            }
            float best = 1e6;
            for (int i = 0; i + 1 < count; i += 2) {
                float4 stroke = items[i];
                float reach = items[i + 1].x / 2 + px;
                // Most pixels are nowhere near a given stroke: skip the distance.
                if (p.x < min(stroke.x, stroke.z) - reach || p.x > max(stroke.x, stroke.z) + reach ||
                    p.y < min(stroke.y, stroke.w) - reach || p.y > max(stroke.y, stroke.w) + reach) continue;
                best = min(best, segment(p, stroke.xy, stroke.zw) - items[i + 1].x / 2);
            }
            col = over(col, mix(c0, float3(0), 0.65), cover(best, px));
            break;
        }
        case 22: { // smoke
            col = glow(col, p, float2(w * 0.5, h * 1.05), m * 0.7, c3, 0.3);
            for (int i = 0; i + 1 < count; i += 2) {
                float4 wisp = items[i];
                float rx = items[i + 1].x, ry = rx * 0.28;
                float2 d = p - wisp.xy;
                float ca = cos(wisp.z), sa = sin(wisp.z);
                float2 q = float2(ca * d.x + sa * d.y, -sa * d.x + ca * d.y) / float2(rx, ry);
                float r = length(q);
                if (r > 1.6) continue;
                col = over(col, accents[(i / 2) % 3], wisp.w * 0.6 * (1.0 - smoothstep(0.0, 1.2, r)));
            }
            break;
        }
        default:
            break;
        }
        return float4(col, 1.0);
    }
    """
}
