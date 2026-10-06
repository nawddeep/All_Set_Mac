// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MetalKit

/// Generated pixels only: a bright rectangle makes clipped blur unmistakable.
enum LidPlaneRenderChecks {
    static func run(_ renderer: LidPlaneRenderer) throws {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 1600, height: 1000, mipmapped: false)
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        let source = renderer.gpu.makeTexture(descriptor: descriptor)!
        let pixels = [UInt8](repeating: 255, count: 1600 * 1000 * 4)
        pixels.withUnsafeBytes {
            source.replace(region: MTLRegionMake2D(0, 0, 1600, 1000), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 6400)
        }
        let oldSettings = (renderer.blur, renderer.warp, renderer.perspective)
        defer { (renderer.blur, renderer.warp, renderer.perspective) = oldSettings }
        renderer.warp = true; renderer.perspective = true; renderer.blur = true
        let angle: Float = 0.6
        let blurred = NSBitmapImageRep(cgImage: try renderer.preview(to: nil, angle: angle, sourceTexture: source))
        renderer.blur = false
        let sharp = NSBitmapImageRep(cgImage: try renderer.preview(to: nil, angle: angle, sourceTexture: source))
        func brightness(_ image: NSBitmapImageRep, _ x: Int, _ y: Int) -> CGFloat {
            image.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!.redComponent
        }
        func leftEdge(at y: Int) -> Int {
            let height = 1 - (Double(y) + 0.5) / 625
            return Int(1000 * height * sin(Double(angle)) / 3.2)
        }
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "LidPlane.LidPlaneRenderChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let top = 125, bottom = 500
        let left = leftEdge(at: top), right = 999 - left
        try require(brightness(blurred, left - 8, top) > 0.1, "Top-left blur was clipped outside the image")
        try require(brightness(blurred, right + 8, top) > 0.1, "Top-right blur was clipped outside the image")
        try require(brightness(blurred, left + 8, top) < 0.95, "Image boundary did not soften inward")
        try require(brightness(sharp, left - 8, top) < 0.04, "Blur-off unexpectedly feathers the border")
        try require(brightness(blurred, leftEdge(at: bottom) - 8, bottom) < 0.04, "Blur is not tighter near the hinge")
        try require(brightness(blurred, 500, top) > 0.99, "Edge treatment changed the image interior")
        print("PASS: blur crosses both borders, softens inward, tightens near the hinge, and respects blur-off")
    }
}
