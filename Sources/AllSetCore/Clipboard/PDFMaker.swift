import AppKit
import PDFKit
import UniformTypeIdentifiers

/// Combines pictures and PDFs into one PDF, in the order given.
public enum PDFMaker {
    public enum Failure: Error, CustomStringConvertible {
        case nothingUsable
        case cannotWrite

        public var description: String {
            switch self {
            case .nothingUsable: "Add some pictures or PDFs first"
            case .cannotWrite: "The PDF couldn't be saved"
            }
        }
    }

    /// A4 in points. Each picture gets a page the right way round and is
    /// scaled to fit it with a margin, never enlarged past its own size.
    static let pageSize = CGSize(width: 595, height: 842)
    static let margin: CGFloat = 24

    /// Whether a file can go into a PDF.
    public static func canInclude(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .pdf) || type.conforms(to: .image)
    }

    /// Writes the PDF to `destination`; returns the number of pages.
    @discardableResult
    public static func make(from urls: [URL], to destination: URL) throws -> Int {
        let document = PDFDocument()
        for url in urls where canInclude(url) {
            if UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true {
                guard let source = PDFDocument(url: url) else { continue }
                for index in 0..<source.pageCount {
                    if let page = source.page(at: index) {
                        document.insert(page, at: document.pageCount)
                    }
                }
            } else if let image = NSImage(contentsOf: url), let page = page(for: image) {
                document.insert(page, at: document.pageCount)
            }
        }
        guard document.pageCount > 0 else { throw Failure.nothingUsable }
        guard document.write(to: destination) else { throw Failure.cannotWrite }
        return document.pageCount
    }

    /// A free file name like "All Set PDF 24 Sep 2026 at 14.05.pdf" in `folder`.
    public static func destination(in folder: URL, date: Date = .now) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy 'at' HH.mm"
        let base = "All Set PDF \(formatter.string(from: date))"
        var url = folder.appendingPathComponent(base + ".pdf")
        var number = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base) \(number).pdf")
            number += 1
        }
        return url
    }

    private static func page(for image: NSImage) -> PDFPage? {
        // Pixel size, so screenshots aren't shrunk to half by their scale.
        let pixels = image.representations.first.map { CGSize(width: $0.pixelsWide, height: $0.pixelsHigh) } ?? image.size
        let size = pixels.width > 0 && pixels.height > 0 ? pixels : image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let landscape = size.width > size.height
        let paper = landscape ? CGSize(width: pageSize.height, height: pageSize.width) : pageSize
        let room = CGSize(width: paper.width - margin * 2, height: paper.height - margin * 2)
        let scale = min(room.width / size.width, room.height / size.height, 1)
        let drawn = CGSize(width: size.width * scale, height: size.height * scale)
        let frame = CGRect(x: (paper.width - drawn.width) / 2, y: (paper.height - drawn.height) / 2,
                           width: drawn.width, height: drawn.height)

        let pageImage = NSImage(size: paper, flipped: false) { _ in
            NSColor.white.setFill()
            CGRect(origin: .zero, size: paper).fill()
            image.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        return PDFPage(image: pageImage, options: [.mediaBox: CGRect(origin: .zero, size: paper), .compressionQuality: 0.85])
    }
}
