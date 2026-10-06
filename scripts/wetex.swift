// Reads a Wallpaper Engine texture (.tex) and writes what's inside it:
//
//     wetex <in.tex> <out-base>            → out-base.png | .jpg | .mp4, one JSON line
//     wetex <in.tex> <out-dir> --frames    → out-dir/frame-0001.png …, JSON with frame times
//
// The format, as documented by the open-source RePKG project:
//   "TEXV0005" "TEXI0001" header (format, flags, texture and image size),
//   "TEXB000n" images (mipmaps; data may be LZ4 compressed, may be a whole
//   PNG/JPEG file, or an MP4), then "TEXS000n" frame rectangles for GIFs.
// Compile once: xcrun swiftc -O scripts/wetex.swift -o wetex
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Reads the file front to back. Every read is checked against what's left:
/// a truncated or lying file ends with an error, never a read past its end.
struct Reader {
    let data: Data
    var offset = 0

    var remaining: Int { data.count - offset }

    private mutating func take(_ count: Int) -> Data {
        guard count >= 0, count <= remaining else { fail("truncated file (wanted \(count) bytes at \(offset), \(remaining) left)") }
        defer { offset += count }
        let start = data.startIndex + offset
        return data.subdata(in: start..<start + count)
    }

    mutating func int32() -> Int32 {
        take(4).withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
    }

    mutating func float32() -> Float {
        take(4).withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
    }

    /// A 9-byte tag like "TEXB0003\0".
    mutating func tag() -> String {
        String(decoding: take(9).prefix(8), as: UTF8.self)
    }

    mutating func bytes(_ count: Int) -> Data {
        take(count)
    }

    /// A count from the file, which must be between 0 and `limit`.
    mutating func count(_ what: String, limit: Int) -> Int {
        let value = Int(int32())
        guard (0...limit).contains(value) else { fail("implausible \(what): \(value)") }
        return value
    }
}

/// Far beyond any real wallpaper texture; a corrupt header can't ask for more.
let maxSide = 16_384
let maxDecodedBytes = 512 << 20

func fail(_ message: String) -> Never {
    print(#"{"error": "\#(message)"}"#)
    exit(1)
}

/// An LZ4 block (no frame header), as Wallpaper Engine stores it. Never
/// reads past the input or writes past `size`; a malformed block is an error.
func lz4(_ input: Data, size: Int) -> Data {
    guard (0...maxDecodedBytes).contains(size) else { fail("implausible decompressed size \(size)") }
    let source = [UInt8](input)
    var out = [UInt8]()
    out.reserveCapacity(size)
    var i = 0
    while i < source.count {
        let token = Int(source[i]); i += 1
        var literals = token >> 4
        if literals == 15 {
            while i < source.count { let b = Int(source[i]); i += 1; literals += b; if b != 255 { break } }
        }
        guard literals <= source.count - i, out.count + literals <= size else { fail("malformed LZ4 literals") }
        out.append(contentsOf: source[i..<i + literals]); i += literals
        if i >= source.count { break }
        guard i + 1 < source.count else { fail("malformed LZ4: match offset cut off") }
        let distance = Int(source[i]) | Int(source[i + 1]) << 8; i += 2
        var length = token & 15
        if length == 15 {
            while i < source.count { let b = Int(source[i]); i += 1; length += b; if b != 255 { break } }
        }
        length += 4
        let start = out.count - distance
        guard distance > 0, start >= 0, out.count + length <= size else { fail("malformed LZ4 match") }
        for k in 0..<length { out.append(out[start + k]) }
    }
    return Data(out)
}

func rgb565(_ c: UInt16) -> (UInt8, UInt8, UInt8) {
    let r = UInt8((Int(c >> 11) & 31) * 255 / 31), g = UInt8((Int(c >> 5) & 63) * 255 / 63), b = UInt8(Int(c & 31) * 255 / 31)
    return (r, g, b)
}

/// DXT1/3/5 to RGBA.
func decodeDXT(_ data: [UInt8], width: Int, height: Int, kind: Int) -> [UInt8] {
    var out = [UInt8](repeating: 0, count: width * height * 4)
    let blockSize = kind == 1 ? 8 : 16
    var p = 0
    for by in stride(from: 0, to: height, by: 4) {
        for bx in stride(from: 0, to: width, by: 4) {
            guard p + blockSize <= data.count else { return out }
            var alpha = [UInt8](repeating: 255, count: 16)
            var colorAt = p
            if kind == 3 {
                for k in 0..<16 {
                    let byte = data[p + k / 2]
                    let nibble = k % 2 == 0 ? byte & 15 : byte >> 4
                    alpha[k] = nibble * 17
                }
                colorAt = p + 8
            } else if kind == 5 {
                let a0 = Int(data[p]), a1 = Int(data[p + 1])
                var bits: UInt64 = 0
                for k in 0..<6 { bits |= UInt64(data[p + 2 + k]) << (8 * UInt64(k)) }
                var table = [a0, a1]
                if a0 > a1 {
                    for k in 1...6 { table.append(((7 - k) * a0 + k * a1) / 7) }
                } else {
                    for k in 1...4 { table.append(((5 - k) * a0 + k * a1) / 5) }
                    table += [0, 255]
                }
                for k in 0..<16 { alpha[k] = UInt8(table[Int((bits >> (3 * UInt64(k))) & 7)]) }
                colorAt = p + 8
            }
            let c0 = UInt16(data[colorAt]) | UInt16(data[colorAt + 1]) << 8
            let c1 = UInt16(data[colorAt + 2]) | UInt16(data[colorAt + 3]) << 8
            let (r0, g0, b0) = rgb565(c0), (r1, g1, b1) = rgb565(c1)
            var colors: [(Int, Int, Int, Int)] = [(Int(r0), Int(g0), Int(b0), 255), (Int(r1), Int(g1), Int(b1), 255)]
            if kind != 1 || c0 > c1 {
                colors.append(((2 * colors[0].0 + colors[1].0) / 3, (2 * colors[0].1 + colors[1].1) / 3, (2 * colors[0].2 + colors[1].2) / 3, 255))
                colors.append(((colors[0].0 + 2 * colors[1].0) / 3, (colors[0].1 + 2 * colors[1].1) / 3, (colors[0].2 + 2 * colors[1].2) / 3, 255))
            } else {
                colors.append(((colors[0].0 + colors[1].0) / 2, (colors[0].1 + colors[1].1) / 2, (colors[0].2 + colors[1].2) / 2, 255))
                colors.append((0, 0, 0, 0))
            }
            let indices = UInt32(data[colorAt + 4]) | UInt32(data[colorAt + 5]) << 8 | UInt32(data[colorAt + 6]) << 16 | UInt32(data[colorAt + 7]) << 24
            for k in 0..<16 {
                let x = bx + k % 4, y = by + k / 4
                guard x < width, y < height else { continue }
                let c = colors[Int((indices >> (2 * UInt32(k))) & 3)]
                let o = (y * width + x) * 4
                out[o] = UInt8(c.0); out[o + 1] = UInt8(c.1); out[o + 2] = UInt8(c.2)
                out[o + 3] = kind == 1 ? UInt8(c.3) : alpha[k]
            }
            p += blockSize
        }
    }
    return out
}

func writePNG(_ rgba: [UInt8], width: Int, height: Int, to url: URL) -> Bool {
    guard let provider = CGDataProvider(data: Data(rgba) as CFData),
          let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                              provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { return false }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}

/// RGBA pixels for a raw texture format; nil if unknown.
func pixels(_ data: Data, format: Int32, width: Int, height: Int) -> [UInt8]? {
    let bytes = [UInt8](data)
    switch format {
    case 0: // RGBA8888
        return bytes.count >= width * height * 4 ? Array(bytes.prefix(width * height * 4)) : nil
    case 4: return decodeDXT(bytes, width: width, height: height, kind: 5)
    case 6: return decodeDXT(bytes, width: width, height: height, kind: 3)
    case 7: return decodeDXT(bytes, width: width, height: height, kind: 1)
    case 8: // RG88: grey with alpha
        guard bytes.count >= width * height * 2 else { return nil }
        var out = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<width * height { out[i * 4] = bytes[i * 2]; out[i * 4 + 1] = bytes[i * 2]; out[i * 4 + 2] = bytes[i * 2]; out[i * 4 + 3] = bytes[i * 2 + 1] }
        return out
    case 9: // R8: grey
        guard bytes.count >= width * height else { return nil }
        var out = [UInt8](repeating: 255, count: width * height * 4)
        for i in 0..<width * height { out[i * 4] = bytes[i]; out[i * 4 + 1] = bytes[i]; out[i * 4 + 2] = bytes[i] }
        return out
    default:
        return nil
    }
}

/// Crops RGBA pixels to a rectangle.
func crop(_ rgba: [UInt8], width: Int, x: Int, y: Int, w: Int, h: Int) -> [UInt8] {
    var out = [UInt8](repeating: 0, count: w * h * 4)
    for row in 0..<h {
        let from = ((y + row) * width + x) * 4
        guard from >= 0, from + w * 4 <= rgba.count else { continue }
        out.replaceSubrange(row * w * 4..<(row + 1) * w * 4, with: rgba[from..<from + w * 4])
    }
    return out
}

let args = CommandLine.arguments
guard args.count >= 3, let data = FileManager.default.contents(atPath: args[1]) else { fail("usage: wetex in.tex out-base [--frames]") }
let wantsFrames = args.contains("--frames")
var reader = Reader(data: data)
guard reader.tag().hasPrefix("TEXV"), reader.tag().hasPrefix("TEXI") else { fail("not a TEX file") }
let format = reader.int32(), flags = reader.int32()
let textureWidth = reader.count("texture width", limit: maxSide), textureHeight = reader.count("texture height", limit: maxSide)
let imageWidth = reader.count("image width", limit: maxSide), imageHeight = reader.count("image height", limit: maxSide)
_ = reader.int32()
let container = reader.tag()
let imageCount = reader.count("image count", limit: 4096)
var freeImage: Int32 = -1
var isMP4 = false
if container == "TEXB0003" || container == "TEXB0004" { freeImage = reader.int32() }
if container == "TEXB0004" { isMP4 = reader.int32() == 1 }
var images: [(data: Data, width: Int, height: Int)] = []
for _ in 0..<imageCount {
    let mipmaps = reader.count("mipmap count", limit: 32)
    for level in 0..<mipmaps {
        let width = reader.count("width", limit: maxSide), height = reader.count("height", limit: maxSide)
        var compressed = false, decompressedSize = 0
        if container != "TEXB0001" {
            compressed = reader.int32() == 1
            decompressedSize = reader.count("decompressed size", limit: maxDecodedBytes)
        }
        let count = reader.count("image size", limit: reader.remaining)
        var bytes = reader.bytes(count)
        if level == 0 {
            if compressed { bytes = lz4(bytes, size: decompressedSize) }
            images.append((bytes, width, height))
        }
    }
}
guard let first = images.first else { fail("no images") }
let out = URL(fileURLWithPath: args[2])

// Video textures: flagged, or (often) only recognisable by the MP4 "ftyp" box.
if isMP4 || (first.data.count > 12 && first.data.subdata(in: 4..<8) == Data("ftyp".utf8)) {
    try? first.data.write(to: out.appendingPathExtension("mp4"))
    print(#"{"kind": "mp4", "file": "\#(out.appendingPathExtension("mp4").path)"}"#)
    exit(0)
}

// A whole image file inside (FreeImage format: 2 JPEG, 13 PNG, others by magic).
if freeImage != -1 {
    let isJPEG = first.data.starts(with: [0xFF, 0xD8])
    let file = out.appendingPathExtension(isJPEG ? "jpg" : "png")
    if !isJPEG, !first.data.starts(with: [0x89, 0x50]) {
        // Something ImageIO can read (GIF, BMP, TGA…): convert to PNG.
        guard let source = CGImageSourceCreateWithData(first.data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let destination = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { fail("unreadable embedded image (format \(freeImage))") }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    } else {
        try? first.data.write(to: file)
    }
    print(#"{"kind": "image", "file": "\#(file.path)", "width": \#(imageWidth), "height": \#(imageHeight), "animated": \#(flags & 4 != 0)}"#)
    exit(0)
}

guard first.width > 0, first.height > 0, first.width * first.height * 4 <= maxDecodedBytes else { fail("implausible image size") }
guard let rgba = pixels(first.data, format: format, width: first.width, height: first.height) else { fail("unsupported pixel format \(format)") }

if wantsFrames, flags & 4 != 0 {
    // GIF frames: rectangles on the sheet, each with how long it shows.
    let tag = reader.tag()
    let frameCount = reader.count("frame count", limit: 10_000)
    if tag == "TEXS0003" { _ = reader.int32(); _ = reader.int32() }
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    var times: [Float] = []
    for index in 0..<frameCount {
        _ = reader.int32()
        let time = reader.float32()
        let x = reader.float32(), y = reader.float32(), w = reader.float32()
        _ = reader.float32(); _ = reader.float32()
        let h = reader.float32()
        guard [x, y, w, h].allSatisfy({ $0.isFinite && abs($0) <= Float(maxSide) }), Int(abs(w)) > 0, Int(abs(h)) > 0 else {
            fail("implausible frame rectangle")
        }
        let frame = crop(rgba, width: first.width, x: Int(x), y: Int(y), w: Int(abs(w)), h: Int(abs(h)))
        _ = writePNG(frame, width: Int(abs(w)), height: Int(abs(h)), to: out.appendingPathComponent(String(format: "frame-%04d.png", index + 1)))
        times.append(time)
    }
    print(#"{"kind": "frames", "dir": "\#(out.path)", "count": \#(frameCount), "times": \#(times), "format": \#(format)}"#)
    exit(0)
}

// Textures are padded to a power of two; the picture is the top-left corner.
let width = min(imageWidth > 0 ? imageWidth : first.width, first.width)
let height = min(imageHeight > 0 ? imageHeight : first.height, first.height)
let picture = width == first.width && height == first.height ? rgba : crop(rgba, width: first.width, x: 0, y: 0, w: width, h: height)
let file = out.appendingPathExtension("png")
guard writePNG(picture, width: width, height: height, to: file) else { fail("couldn't write PNG") }
print(#"{"kind": "image", "file": "\#(file.path)", "width": \#(width), "height": \#(height), "animated": \#(flags & 4 != 0), "texture": [\#(textureWidth), \#(textureHeight)], "format": \#(format)}"#)
