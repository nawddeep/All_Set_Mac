import AppKit
import Foundation
import PDFKit
import Testing
@testable import AllSetCore

@Suite @MainActor struct NotesTests {
    private func store() -> (NotesStore, URL) {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetNotes-\(UUID().uuidString).json")
        return (NotesStore(fileURL: file), file)
    }

    @Test func addsPointsNewestFirst() {
        let (notes, file) = store()
        defer { try? FileManager.default.removeItem(at: file) }
        notes.add("Buy milk")
        notes.add("   ")
        notes.add("- Call mom\n• Book tickets\n\n")
        #expect(notes.notes.map(\.text) == ["Call mom", "Book tickets", "Buy milk"])
    }

    @Test func ticksEditsAndRemoves() throws {
        let (notes, file) = store()
        defer { try? FileManager.default.removeItem(at: file) }
        notes.add("One\nTwo\nThree")
        let two = try #require(notes.notes.first { $0.text == "Two" })
        notes.toggle(two.id)
        #expect(notes.asText == "• One\n✓ Two\n• Three")
        notes.removeDone()
        #expect(notes.notes.map(\.text) == ["One", "Three"])
        let one = try #require(notes.notes.first)
        notes.update(one.id, text: "  One, changed ")
        #expect(notes.notes.first?.text == "One, changed")
        notes.update(one.id, text: "")
        #expect(notes.notes.map(\.text) == ["Three"])
    }

    @Test func movesAndRemembers() {
        let (notes, file) = store()
        defer { try? FileManager.default.removeItem(at: file) }
        notes.add("A\nB\nC")
        notes.move(from: [0], to: 3)
        #expect(notes.notes.map(\.text) == ["B", "C", "A"])
        notes.save()
        #expect(NotesStore(fileURL: file).notes.map(\.text) == ["B", "C", "A"])
    }
}

@Suite struct PDFMakerTests {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetPDF-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writePNG(width: Int, height: Int, to url: URL) throws {
        let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                                                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                                bytesPerRow: 0, bitsPerPixel: 0))
        try #require(rep.representation(using: .png, properties: [:])).write(to: url)
    }

    @Test func combinesPicturesAndPDFsInOrder() throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let tall = dir.appendingPathComponent("tall.png")
        let wide = dir.appendingPathComponent("wide.png")
        try writePNG(width: 300, height: 600, to: tall)
        try writePNG(width: 3000, height: 1000, to: wide)
        let first = dir.appendingPathComponent("first.pdf")
        #expect(try PDFMaker.make(from: [tall, wide], to: first) == 2)

        let pages = try #require(PDFDocument(url: first))
        let portrait = try #require(pages.page(at: 0)).bounds(for: .mediaBox)
        let landscape = try #require(pages.page(at: 1)).bounds(for: .mediaBox)
        #expect(portrait.size == CGSize(width: 595, height: 842))
        #expect(landscape.size == CGSize(width: 842, height: 595))

        // A PDF's pages go in whole; files that aren't pictures or PDFs are skipped.
        let text = dir.appendingPathComponent("notes.txt")
        try Data("hi".utf8).write(to: text)
        #expect(!PDFMaker.canInclude(text))
        #expect(try PDFMaker.make(from: [first, text, tall], to: dir.appendingPathComponent("second.pdf")) == 3)
        #expect(throws: PDFMaker.Failure.self) { try PDFMaker.make(from: [text], to: dir.appendingPathComponent("none.pdf")) }
    }

    @Test func picksAFreeName() throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let first = PDFMaker.destination(in: dir, date: date)
        try Data().write(to: first)
        let second = PDFMaker.destination(in: dir, date: date)
        #expect(first != second)
        #expect(second.lastPathComponent.hasSuffix(" 2.pdf"))
    }
}

@Suite struct MemoryAppsTests {
    @Test func listsAppsByMemory() {
        let reader = ProcessEnergyReader()
        let apps = reader.read(limit: 5).memory
        #expect(!apps.isEmpty && apps.count <= 5)
        #expect(zip(apps, apps.dropFirst()).allSatisfy { $0.bytes >= $1.bytes })
        #expect(MemoryUsage.current().total > 0)
    }
}
