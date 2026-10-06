import AppKit
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import AllSetCore

/// Review P3: imports run off the main thread with progress and cancellation,
/// and a small copy is decoded straight from the file.
@Suite @MainActor struct ImageImportTests {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetImport-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Drawn and encoded off the main actor: dozens of pictures made here would
    /// hold it long enough to starve tests in other suites that sample on it.
    private func writePictures(_ count: Int, side: Int, in folder: URL) async throws {
        let written = await Task.detached { () -> Bool in
            let space = CGColorSpace(name: CGColorSpace.sRGB)!
            var allWritten = true
            for index in 0..<count {
                let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.setFillColor(CGColor(red: Double(index % 7) / 7, green: 0.4, blue: 0.6, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: side, height: side))
                let file = folder.appendingPathComponent(String(format: "pic%03d.png", index))
                let output = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)!
                CGImageDestinationAddImage(output, context.makeImage()!, nil)
                allWritten = CGImageDestinationFinalize(output) && allWritten
            }
            return allWritten
        }.value
        #expect(written)
    }

    private func library(_ root: URL) -> ImageLibrary {
        ImageLibrary(userDirectory: root.appendingPathComponent("Images"), cacheDirectory: root.appendingPathComponent("Photos"))
    }

    @Test func aFolderImportsInTheBackgroundWithProgress() async throws {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try await writePictures(6, side: 64, in: source)
        try Data("not a picture".utf8).write(to: source.appendingPathComponent("notes.txt"))
        let images = library(root)

        var sawProgress = false
        let watcher = Task { @MainActor in
            while !Task.isCancelled {
                if images.importProgress?.total == 6 { sawProgress = true }
                await Task.yield()
            }
        }
        let names = await images.importImages(from: [source])
        watcher.cancel()

        #expect(names.count == 6)
        #expect(Set(images.userImages) == Set(names))
        #expect(sawProgress)
        #expect(images.importProgress == nil)
    }

    @Test func cancellingStopsAnImportAndKeepsWhatWasDone() async throws {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try await writePictures(60, side: 900, in: source)
        let images = library(root)

        let task = Task { await images.importImages(from: [source]) }
        for _ in 0..<500 where (images.importProgress?.done ?? 0) == 0 { try await Task.sleep(for: .milliseconds(5)) }
        images.cancelImports()
        let names = await task.value

        #expect(!names.isEmpty && names.count < 60)
        // Nothing half-written or orphaned: exactly the returned files are there.
        let onDisk = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Images").path)
        #expect(Set(onDisk) == Set(names))
        #expect(images.importProgress == nil)
    }

    @Test func aSmallCopyNeverDecodesTheWholePhoto() async throws {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try await writePictures(1, side: 1200, in: source)
        let images = library(root)
        let name = try #require(await images.importImages(from: [source]).first)

        let small = await images.image(for: .file(name), maxPixels: 256)
        #expect(small != nil)
        #expect((small?.size.width ?? .infinity) <= 256)
        #expect(images.fullDecodes == 0)
    }

    // MARK: The downloaded-photo cache has a limit

    /// Three cached photos of 400 bytes each, used an hour apart, oldest first.
    private func cachedPhotos(in root: URL) throws -> [WebPhoto] {
        let cache = root.appendingPathComponent("Photos")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        return try (0..<3).map { index in
            let photo = WebPhoto(id: "p\(index)", author: "a", width: 10, height: 10)
            let file = cache.appendingPathComponent(photo.cacheName)
            try Data(count: 400).write(to: file)
            try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(Double(index - 3) * 3600)],
                                                  ofItemAtPath: file.path)
            return photo
        }
    }

    private func cached(_ root: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Photos").path)) ?? []).sorted()
    }

    @Test func theLeastRecentlyUsedPhotosGoWhenTheCacheIsOverItsLimit() async throws {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        let photos = try cachedPhotos(in: root)
        let images = ImageLibrary(userDirectory: root.appendingPathComponent("Images"),
                                  cacheDirectory: root.appendingPathComponent("Photos"), photoCacheLimit: 900)
        images.photosInUse = { [] }
        let result = await images.trimDownloadedPhotos()
        #expect(result.removed == 1 && result.freedBytes == 400)
        #expect(cached(root) == [photos[1].cacheName, photos[2].cacheName])
        // Under the limit now: nothing more goes.
        #expect(await images.trimDownloadedPhotos().removed == 0)
    }

    /// The system wallpaper and widgets read these files directly: one in use
    /// is never the one removed, however long ago it was used.
    @Test func aPhotoInUseIsNeverEvicted() async throws {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        let photos = try cachedPhotos(in: root)
        let images = ImageLibrary(userDirectory: root.appendingPathComponent("Images"),
                                  cacheDirectory: root.appendingPathComponent("Photos"), photoCacheLimit: 900)
        images.photosInUse = { [.web(photos[0])] }   // the oldest is the wallpaper
        await images.trimDownloadedPhotos()
        #expect(cached(root) == [photos[0].cacheName, photos[2].cacheName])

        // Even when what's in use is itself over the limit, it stays.
        images.photosInUse = { photos.map { .web($0) } }
        let tight = ImageLibrary(userDirectory: root.appendingPathComponent("Images"),
                                 cacheDirectory: root.appendingPathComponent("Photos"), photoCacheLimit: 100)
        tight.photosInUse = { [.web(photos[0]), .web(photos[2])] }
        #expect(await tight.trimDownloadedPhotos().removed == 0)
        #expect(cached(root).count == 2)
    }

    @Test func nothingIsEvictedUntilTheAppSaysWhatIsInUse() async throws {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try cachedPhotos(in: root)
        let images = ImageLibrary(userDirectory: root.appendingPathComponent("Images"),
                                  cacheDirectory: root.appendingPathComponent("Photos"), photoCacheLimit: 100)
        #expect(await images.trimDownloadedPhotos().removed == 0)
        #expect(cached(root).count == 3)
    }
}
