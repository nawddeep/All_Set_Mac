import AppKit

extension NSImage {
    /// What the image holds in memory once decoded, for weighing it in a
    /// cache. Read from its bitmap where there is one, since a 16-bit picture
    /// (what `ImageRenderer` makes) takes twice the bytes of an 8-bit one.
    public var decodedByteCount: Int {
        var largest = 0
        for representation in representations {
            if let bitmap = representation as? NSBitmapImageRep {
                largest = max(largest, bitmap.bytesPerRow * bitmap.pixelsHigh)
            } else if let cgImage = representation.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                largest = max(largest, cgImage.bytesPerRow * cgImage.height)
            }
        }
        return largest > 0 ? largest : Int(size.width * size.height * 4)
    }
}
