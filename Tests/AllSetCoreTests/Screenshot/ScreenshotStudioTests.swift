import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import AllSetCore

/// Review R2: an AI answer belongs to the picture it was asked about. One that
/// arrives after New Screenshot or Open must not change the new document.
@Suite @MainActor struct ScreenshotStudioTests {
    private func picture(width: Int, height: Int = 64) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    /// Answers Claude after `delay`, with one crop to half the width (so the
    /// result shows which picture it was drawn on).
    private func slowClaude(delay: Duration, fails: Bool = false) -> ScreenshotAI {
        ScreenshotAI(
            key: { _ in "test-key" },
            claude: { _, session, _ in
                try await Task.sleep(for: delay)
                if fails { throw AIEditError("the server said no") }
                let plan = EditPlan(reply: "Cropped.", edits: [ScreenshotEdit(kind: .crop, x: 0, y: 0, width: 32, height: 64)])
                return (session, ClaudeReply(plan: plan, answer: "", usage: TokenUsage()))
            },
            openAI: { image, _, _ in image }
        )
    }

    private func settle(_ task: Task<Void, Never>) async { await task.value }

    @Test func anAnswerForThePreviousPictureLeavesTheNewOneAlone() async {
        let studio = ScreenshotStudio(ai: slowClaude(delay: .milliseconds(150)))
        studio.provider = .claude
        studio.load(picture(width: 64))
        let request = Task { await studio.ask("crop it") }
        try? await Task.sleep(for: .milliseconds(30))
        studio.load(picture(width: 128))          // New Screenshot while it's thinking
        await settle(request)

        #expect(studio.image?.width == 128)
        #expect(studio.versionCount == 1)
        #expect(studio.messages.isEmpty)
        #expect(!studio.isWorking)
    }

    @Test func aFailureForThePreviousPictureIsNotShownOnTheNewOne() async {
        let studio = ScreenshotStudio(ai: slowClaude(delay: .milliseconds(150), fails: true))
        studio.provider = .claude
        studio.load(picture(width: 64))
        let request = Task { await studio.ask("crop it") }
        try? await Task.sleep(for: .milliseconds(30))
        studio.load(picture(width: 128))
        await settle(request)
        #expect(studio.messages.isEmpty)
    }

    @Test func anAnswerForTheOpenPictureIsApplied() async {
        let studio = ScreenshotStudio(ai: slowClaude(delay: .milliseconds(10)))
        studio.provider = .claude
        studio.load(picture(width: 64))
        await studio.ask("crop it")
        #expect(studio.image?.width == 32)
        #expect(studio.versionCount == 2)
        #expect(studio.messages.map(\.role) == [.user, .assistant])
    }

    /// Review P2: undo history is bounded by bytes, not only by count; the original stays.
    @Test func undoHistoryStaysWithinItsByteBudget() async {
        let ai = ScreenshotAI(key: { _ in "k" }, claude: { _, s, _ in throw AIEditError("unused") },
                              openAI: { image, _, _ in
                                  let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                                          bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                                  context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                                  return context.makeImage()!
                              })
        let original = picture(width: 256, height: 256)   // 256 KB of pixels
        let studio = ScreenshotStudio(ai: ai, historyBudget: 4 * 256 * 256 * 4)
        studio.provider = .openAI
        studio.load(original)
        for _ in 0..<10 { await studio.ask("redraw it") }
        #expect(studio.historyBytes <= 4 * 256 * 256 * 4)
        #expect(studio.versionCount >= 2)
        // The original is never the one dropped: undoing all the way gets back to it.
        while studio.versionCount > 1 { studio.undo() }
        #expect(studio.image === original)
    }

    // MARK: Recheck S4: the studio owns its request

    /// Counts Claude calls and notes whether one was cancelled while waiting.
    private final class Calls: @unchecked Sendable {
        private let lock = NSLock()
        private var started = 0
        private var cancelled = 0
        var count: Int { lock.withLock { started } }
        var cancellations: Int { lock.withLock { cancelled } }
        func begin() { lock.withLock { started += 1 } }
        func wasCancelled() { lock.withLock { cancelled += 1 } }
    }

    /// Claude that never answers by itself: it waits until cancelled.
    private func waitingClaude(_ calls: Calls) -> ScreenshotAI {
        ScreenshotAI(
            key: { _ in "test-key" },
            claude: { _, session, _ in
                calls.begin()
                do { try await Task.sleep(for: .seconds(30)) } catch {
                    calls.wasCancelled()
                    throw error
                }
                return (session, ClaudeReply(plan: EditPlan(reply: "late", edits: []), answer: "", usage: TokenUsage()))
            },
            openAI: { image, _, _ in image }
        )
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<400 where !condition() { try? await Task.sleep(for: .milliseconds(5)) }
    }

    /// Replacing the picture only dropped the old request's answer; the request
    /// itself ran on, holding its picture and the provider, to the end.
    @Test func replacingThePictureStopsTheRequestForTheOldOne() async {
        let calls = Calls()
        let studio = ScreenshotStudio(ai: waitingClaude(calls))
        studio.provider = .claude
        studio.load(picture(width: 64))
        let start = Date()
        let request = Task { await studio.ask("crop it") }
        await waitUntil { calls.count == 1 }
        studio.load(picture(width: 128))
        await settle(request)

        #expect(calls.cancellations == 1)
        #expect(Date().timeIntervalSince(start) < 5)
        #expect(studio.image?.width == 128 && studio.messages.isEmpty && !studio.isWorking)
    }

    /// Holds preparation open until the test lets it go.
    private final class Gate: @unchecked Sendable {
        private let lock = NSLock()
        private var entered = false
        private var open = false
        var isEntered: Bool { lock.withLock { entered } }
        func release() { lock.withLock { open = true } }
        func pass() async {
            lock.withLock { entered = true }
            while !lock.withLock({ open }) { try? await Task.sleep(for: .milliseconds(2)) }
        }
    }

    /// Between preparing the picture for Claude and sending it there was no
    /// check: a picture replaced during preparation was still submitted.
    ///
    /// Preparation is held open by the test, the picture replaced, and only then
    /// is preparation allowed to finish. (An earlier version of this test raced
    /// the real preparation and lost about one run in eight: when preparation
    /// had already finished, sending was correct and the test was wrong.)
    @Test func nothingIsSentForAPictureReplacedWhileItWasBeingPrepared() async {
        let calls = Calls()
        let gate = Gate()
        var ai = waitingClaude(calls)
        ai.prepare = { image, pixelsPerPoint in
            await gate.pass()
            return ClaudeSession(image: image, pixelsPerPoint: pixelsPerPoint)
        }
        let studio = ScreenshotStudio(ai: ai)
        studio.provider = .claude
        studio.load(picture(width: 64))
        let request = Task { await studio.ask("crop it") }
        await waitUntil { gate.isEntered }
        studio.load(picture(width: 128))
        gate.release()
        await settle(request)
        try? await Task.sleep(for: .milliseconds(100))

        #expect(gate.isEntered)
        #expect(calls.count == 0)
        #expect(studio.image?.width == 128 && !studio.isWorking)
    }

    @Test func stopEndsTheRequestAndKeepsThePicture() async {
        let calls = Calls()
        let studio = ScreenshotStudio(ai: waitingClaude(calls))
        studio.provider = .claude
        studio.load(picture(width: 64))
        let request = Task { await studio.ask("crop it") }
        await waitUntil { calls.count == 1 }
        studio.cancel()
        await settle(request)

        #expect(calls.cancellations == 1)
        #expect(!studio.isWorking)
        #expect(studio.image?.width == 64 && studio.versionCount == 1)
        #expect(studio.messages.map(\.text) == ["crop it", "Stopped."])
        // And it can be asked again.
        let again = Task { await studio.ask("crop it") }
        await waitUntil { calls.count == 2 }
        studio.cancel()
        await settle(again)
        #expect(calls.count == 2)
    }

    @Test func closingTheWindowStopsWorkAndKeepsOnlyThePictureAsItIs() async {
        let studio = ScreenshotStudio(ai: slowClaude(delay: .milliseconds(5)))
        studio.provider = .claude
        studio.load(picture(width: 64))
        await studio.ask("crop it")
        #expect(studio.versionCount == 2 && studio.image?.width == 32)
        let edited = studio.image
        let before = studio.historyBytes

        studio.windowClosed()
        #expect(studio.versionCount == 1)
        #expect(studio.image === edited)
        // Only the picture as it is now is still held: the original went.
        #expect(studio.historyBytes == (edited?.bytesPerRow ?? 0) * (edited?.height ?? 0))
        #expect(studio.historyBytes < before)

        // A request in flight when it closes is stopped, not left running.
        let calls = Calls()
        let waiting = ScreenshotStudio(ai: waitingClaude(calls))
        waiting.provider = .claude
        waiting.load(picture(width: 64))
        let request = Task { await waiting.ask("crop it") }
        await waitUntil { calls.count == 1 }
        waiting.windowClosed()
        await settle(request)
        #expect(calls.cancellations == 1 && !waiting.isWorking && waiting.image?.width == 64)
    }

    @Test func aPictureLargerThanTheStudioEditsIsScaledAsItOpens() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetStudio-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        func write(_ image: CGImage, _ name: String) throws -> URL {
            let url = folder.appendingPathComponent(name)
            let output = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(output, image, nil)
            #expect(CGImageDestinationFinalize(output))
            return url
        }
        let wide = try write(picture(width: ScreenshotStudio.maxSide + 1808, height: 20), "wide.png")
        let small = try write(picture(width: 300, height: 200), "small.png")

        let reduced = try #require(ScreenshotStudio.picture(at: wide))
        #expect(reduced.image.width == ScreenshotStudio.maxSide)
        #expect(reduced.reducedFrom == CGSize(width: ScreenshotStudio.maxSide + 1808, height: 20))
        let untouched = try #require(ScreenshotStudio.picture(at: small))
        #expect(untouched.image.width == 300 && untouched.reducedFrom == nil)
        #expect(ScreenshotStudio.picture(at: folder.appendingPathComponent("missing.png")) == nil)

        let studio = ScreenshotStudio(ai: slowClaude(delay: .milliseconds(5)))
        studio.load(reduced.image, reducedFrom: reduced.reducedFrom)
        #expect(studio.messages.first?.text.contains("scaled") == true)
    }
}
