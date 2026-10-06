// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MetalKit
import MetalPerformanceShaders
import OSLog

/// Everything here runs on the main thread except the GPU completion handler,
/// which only signals a semaphore and hops back to main.
/// Keeps a capture frame alive until the GPU has finished reading it.
private struct RetainedFrame: @unchecked Sendable {
    let buffer: CVPixelBuffer?
    let texture: CVMetalTexture?
}

final class LidPlaneRenderer: NSObject, MTKViewDelegate, @unchecked Sendable {
    let gpu: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    let texture: MTLTexture
    private var desktopTexture: CVMetalTexture?
    private var desktopBuffer: CVPixelBuffer?
    private var textureCache: CVMetalTextureCache?
    private var blurLevels: [MTLTexture] = []
    /// Each level's input: the previous level (or the source) at half its size.
    private var blurInputs: [MTLTexture] = []
    private var blurFilters: [MPSImageGaussianBlur] = []
    private var blurScale: MPSImageBilinearScale?
    private var blurDirty = true
    /// What the blur levels were last built from, so an unchanged picture
    /// (the preview artwork) is never blurred twice.
    private var blurredSource: ObjectIdentifier?
    private let inFlight = DispatchSemaphore(value: 2)
    var delta: Float = 0
    var blur = true
    var warp = true
    var perspective = false
    private var projectionMode: Float { warp ? (perspective ? 2 : 1) : 0 }
    var tick: (() -> Void)?
    var didDraw = false
    private(set) var completedDraws = 0
    var onRenderComplete: ((Bool) -> Void)?
    private let logger = Logger(subsystem: "com.pratik.allset", category: "Renderer")
    private(set) var attemptedDraws = 0
    private(set) var missingDrawables = 0

    init(gpu: MTLDevice) throws {
        self.gpu = gpu
        queue = gpu.makeCommandQueue()!
        let library = try gpu.makeLibrary(source: Self.shader, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertexMain")
        descriptor.fragmentFunction = library.makeFunction(name: "fragmentMain")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try gpu.makeRenderPipelineState(descriptor: descriptor)
        texture = try MTKTextureLoader(device: gpu).newTexture(cgImage: Self.artwork(), options: [.SRGB: false])
        super.init()
        CVMetalTextureCacheCreate(nil, nil, gpu, nil, &textureCache)
    }

    func setDesktopFrame(_ pixelBuffer: CVPixelBuffer) -> Bool {
        guard let textureCache else { return false }
        var wrapped: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, .bgra8Unorm,
            CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer), 0, &wrapped)
        guard result == kCVReturnSuccess, let wrapped else { return false }
        desktopTexture = wrapped
        desktopBuffer = pixelBuffer
        blurDirty = true
        return true
    }

    func useArtwork() {
        desktopTexture = nil
        desktopBuffer = nil
        blurDirty = true
    }

    private var source: MTLTexture { desktopTexture.flatMap(CVMetalTextureGetTexture) ?? texture }

    /// Four Gaussian levels (σ 2, 6, 16 and 40 per 1000 px of height), each at
    /// half the size of the one before and built from it. A blurred picture
    /// carries no fine detail, so the small levels look the same as full-size
    /// ones at a fraction of the GPU time, which leaves room for 120 Hz.
    private func prepareBlur(_ command: MTLCommandBuffer, source: MTLTexture) {
        let sigmas: [Float] = [2, 6, 16, 40].map { $0 * Float(source.height) / 1000 }
        if blurSize != (source.width, source.height) {
            blurInputs = []; blurLevels = []
            for level in 0..<4 {
                let divisor = 2 << level
                let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
                    width: max(1, source.width / divisor), height: max(1, source.height / divisor), mipmapped: false)
                desc.usage = [.shaderRead, .shaderWrite]
                desc.storageMode = .private
                blurInputs.append(gpu.makeTexture(descriptor: desc)!)
                blurLevels.append(gpu.makeTexture(descriptor: desc)!)
            }
            // Each level adds only the blur the previous one doesn't already
            // have, measured in its own (smaller) pixels.
            blurFilters = sigmas.indices.map { level in
                let previous = level == 0 ? 0 : sigmas[level - 1]
                let extra = (sigmas[level] * sigmas[level] - previous * previous).squareRoot()
                let filter = MPSImageGaussianBlur(device: gpu, sigma: max(0.5, extra / Float(2 << level)))
                filter.edgeMode = .clamp
                return filter
            }
            blurScale = MPSImageBilinearScale(device: gpu)
            blurSize = (source.width, source.height)
            blurDirty = true
        }
        let identity = ObjectIdentifier(source)
        guard blurDirty || blurredSource != identity, let blurScale else { return }
        var input = source
        for level in 0..<4 {
            blurScale.encode(commandBuffer: command, sourceTexture: input, destinationTexture: blurInputs[level])
            blurFilters[level].encode(commandBuffer: command, sourceTexture: blurInputs[level], destinationTexture: blurLevels[level])
            input = blurLevels[level]
        }
        blurDirty = false
        blurredSource = identity
    }

    private var blurSize = (0, 0)
    private var previewOutput: MTLTexture?

    private func bindTextures(_ encoder: MTLRenderCommandEncoder, source: MTLTexture) {
        encoder.setFragmentTexture(source, index: 0)
        for index in 0..<4 { encoder.setFragmentTexture(blurLevels.indices.contains(index) ? blurLevels[index] : source, index: index+1) }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    /// GPU milliseconds for one live frame at `width`×`height`: a new desktop
    /// frame (so the blur levels are rebuilt) drawn at full size.
    func frameCost(width: Int, height: Int, angle: Float) -> Double {
        let sourceDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        sourceDesc.usage = .shaderRead
        sourceDesc.storageMode = .private
        let outputDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        outputDesc.usage = .renderTarget
        outputDesc.storageMode = .private
        guard let source = gpu.makeTexture(descriptor: sourceDesc), let output = gpu.makeTexture(descriptor: outputDesc) else { return .nan }
        var samples: [Double] = []
        for _ in 0..<12 {
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = output
            pass.colorAttachments[0].loadAction = .dontCare
            pass.colorAttachments[0].storeAction = .store
            let command = queue.makeCommandBuffer()!
            blurDirty = true
            prepareBlur(command, source: source)
            let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
            var params = SIMD4<Float>(angle, Float(width) / Float(height), 1, projectionMode)
            encoder.setRenderPipelineState(pipeline)
            bindTextures(encoder, source: source)
            encoder.setFragmentBytes(&params, length: MemoryLayout.size(ofValue: params), index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            command.commit(); command.waitUntilCompleted()
            samples.append((command.gpuEndTime - command.gpuStartTime) * 1000)
        }
        return samples.dropFirst(2).sorted()[samples.count / 2 - 1]
    }

    @discardableResult
    func preview(to url: URL?, angle: Float, sourceTexture: MTLTexture? = nil) throws -> CGImage {
        let previewSource = sourceTexture ?? texture
        // Reused: each render waits for the GPU and copies the pixels out.
        let output = previewOutput ?? {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 1000, height: 625, mipmapped: false)
            descriptor.usage = [.renderTarget]
            descriptor.storageMode = .shared
            return gpu.makeTexture(descriptor: descriptor)!
        }()
        previewOutput = output
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let command = queue.makeCommandBuffer()!
        // Blur levels are rebuilt only when the picture itself changes.
        prepareBlur(command, source: previewSource)
        let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
        var params = SIMD4<Float>(angle, 1.6, blur ? 1 : 0, projectionMode)
        encoder.setRenderPipelineState(pipeline)
        bindTextures(encoder, source: previewSource)
        encoder.setFragmentBytes(&params, length: MemoryLayout.size(ofValue: params), index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        command.commit(); command.waitUntilCompleted()
        if let error = command.error { throw error }
        var data = Data(count: 1000*625*4)
        data.withUnsafeMutableBytes {
            output.getBytes($0.baseAddress!, bytesPerRow: 4000, from: MTLRegionMake2D(0, 0, 1000, 625), mipmapLevel: 0)
        }
        let image = CGImage(width: 1000, height: 625, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4000,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                            provider: CGDataProvider(data: data as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
        if let url { try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: url) }
        return image
    }

    func draw(in view: MTKView) {
        attemptedDraws += 1
        tick?()
        guard inFlight.wait(timeout: .now()) == .success else { return }
        guard let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let command = queue.makeCommandBuffer() else { missingDrawables += 1; inFlight.signal(); return }
        let source = self.source
        let retained = RetainedFrame(buffer: desktopBuffer, texture: desktopTexture)
        if blur && abs(delta) > 0.003 { prepareBlur(command, source: source) }
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { inFlight.signal(); return }
        var params = SIMD4<Float>(delta, Float(view.drawableSize.width / max(1, view.drawableSize.height)), blur ? 1 : 0, projectionMode)
        encoder.setRenderPipelineState(pipeline)
        bindTextures(encoder, source: source)
        encoder.setFragmentBytes(&params, length: MemoryLayout.size(ofValue: params), index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        command.present(drawable)
        command.addCompletedHandler { [weak self, inFlight] buffer in
            // Capture surfaces must remain alive until the GPU finishes reading them.
            withExtendedLifetime(retained) {}
            inFlight.signal()
            let failure = buffer.error
            if let failure { self?.logger.error("GPU command failed: \(failure.localizedDescription, privacy: .public)") }
            DispatchQueue.main.async {
                if failure == nil { self?.completedDraws += 1 }
                self?.onRenderComplete?(failure == nil)
            }
        }
        command.commit()
        didDraw = true
    }

    static func artwork() -> CGImage {
        let width = 1600, height = 1000
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
            NSColor(red: 0.035, green: 0.09, blue: 0.17, alpha: 1).cgColor,
            NSColor(red: 0.09, green: 0.24, blue: 0.31, alpha: 1).cgColor
        ] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.09).cgColor)
        ctx.setLineWidth(1)
        for x in stride(from: 0, through: width, by: 50) {
            ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: height))
        }
        for y in stride(from: 0, through: height, by: 50) {
            ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: width, y: y))
        }
        ctx.strokePath()
        func text(_ string: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ color: NSColor = .white, _ weight: NSFont.Weight = .regular) {
            (string as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [
                .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color
            ])
        }
        let mint = NSColor(red: 0.7, green: 1, blue: 0.8, alpha: 1)
        text("A SMALL EXPERIMENT IN PHYSICAL INTERFACES", 110, 867, 20, mint, .medium)
        text("Stay right here.", 100, 710, 116, .white, .semibold)
        text("Move the lid. Let the image hold its ground.", 110, 650, 28, .white.withAlphaComponent(0.7))
        let cards: [(CGFloat, String, String, NSColor)] = [
            (110, "01", "A fixed plane", mint),
            (580, "02", "A moving surface", NSColor(red: 0.72, green: 0.79, blue: 1, alpha: 1)),
            (1050, "03", "A little disbelief", NSColor(red: 1, green: 0.75, blue: 0.55, alpha: 1))
        ]
        for (x, number, title, color) in cards {
            color.withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: 230, width: 440, height: 320), xRadius: 28, yRadius: 28).fill()
            text(number, x + 28, 485, 22, color, .medium)
            color.setStroke()
            let circle = NSBezierPath(ovalIn: NSRect(x: x + 150, y: 335, width: 120, height: 120))
            circle.lineWidth = 3; circle.stroke()
            let line = NSBezierPath()
            line.move(to: CGPoint(x: x + 125, y: 395)); line.line(to: CGPoint(x: x + 295, y: 395))
            line.move(to: CGPoint(x: x + 210, y: 310)); line.line(to: CGPoint(x: x + 210, y: 480))
            line.lineWidth = 1; line.stroke()
            text(title, x + 28, 265, 29, .white, .medium)
        }
        text("HINGE / ANCHOR", 110, 133, 17, mint, .medium)
        ctx.setStrokeColor(mint.cgColor); ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: 110, y: 110)); ctx.addLine(to: CGPoint(x: 1490, y: 110)); ctx.strokePath()
        return ctx.makeImage()!
    }

    // Default: parallel projection onto the reference plane, compensating tilt
    // without keystone taper. Optional perspective mode uses a finite eye position.
    // Both assume a stationary viewer; units are screen heights and hinge is y=0.
    static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexOut { float4 position [[position]]; float2 uv; };
    vertex VertexOut vertexMain(uint id [[vertex_id]]) {
        float2 p = float2((id << 1) & 2, id & 2);
        return {float4(p * 2.0 - 1.0, 0, 1), float2(p.x, 1.0-p.y)};
    }
    fragment float4 fragmentMain(VertexOut in [[stage_in]], texture2d<float> art [[texture(0)]],
        texture2d<float> b1 [[texture(1)]], texture2d<float> b2 [[texture(2)]],
        texture2d<float> b3 [[texture(3)]], texture2d<float> b4 [[texture(4)]],
        constant float4 &p [[buffer(0)]]) {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        float2 uv = in.uv;
        float height = 1.0 - uv.y;
        float a = clamp(p.x, -0.65, 1.25);
        float depth = height * sin(a);
        if (p.w > 0.5) {
            float3 eye = float3(0, 0.65, 1.6);
            float3 physical = float3((uv.x-0.5)*p.y, height*cos(a), depth);
            float t = p.w > 1.5 ? eye.z / max(0.25, eye.z-physical.z) : 1.0;
            float3 hit = eye + t * (physical-eye);
            uv = float2(hit.x/p.y+0.5, 1.0-hit.y);
        }
        // Radius varies across the surface, not just over time. Gaussian levels
        // avoid the repeated edges / speckling from sparse disc sampling.
        float radius = p.z * smoothstep(0.08, 1.0, height) * abs(sin(a)) * 65.0;
        float3 color;
        if (radius < 2.0) color = mix(art.sample(s, uv).rgb, b1.sample(s, uv).rgb, radius/2.0);
        else if (radius < 6.0) color = mix(b1.sample(s, uv).rgb, b2.sample(s, uv).rgb, (radius-2.0)/4.0);
        else if (radius < 16.0) color = mix(b2.sample(s, uv).rgb, b3.sample(s, uv).rgb, (radius-6.0)/10.0);
        else color = mix(b3.sample(s, uv).rgb, b4.sample(s, uv).rgb, clamp((radius-16.0)/24.0, 0.0, 1.0));
        // Blur the image boundary too, instead of clipping the already-blurred
        // content to a razor-sharp UV rectangle. Extend the edge colour outward
        // and feather its coverage over the same progressive source-space radius.
        // Three sigma on either side approximates the Gaussian edge falloff.
        float2 sourceSize = float2(art.get_width(), art.get_height());
        float sigmaPixels = radius * sourceSize.y / 1000.0;
        // Half a pixel of antialiasing on tilted edges; an unfolded picture
        // keeps its outermost pixels at full strength, with no dark rim.
        float2 feather = max(3.0 * sigmaPixels / sourceSize, 0.5 * fwidth(uv));
        float2 coverage = smoothstep(-feather, feather, uv)
                        * (1.0 - smoothstep(1.0 - feather, 1.0 + feather, uv));
        float mask = coverage.x * coverage.y;
        return float4(mix(float3(0.02, 0.035, 0.05), color, mask), 1);
    }
    """
}
