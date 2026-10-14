import AppKit
import Foundation
import Testing
@testable import AllSetCore

@Suite struct ScreenshotAITests {
    /// A white picture with a red square in its top-left quarter.
    private func picture(width: Int = 400, height: Int = 200) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        // Core Graphics counts from the bottom: this is the top-left quarter.
        context.fill(CGRect(x: 0, y: height / 2, width: width / 2, height: height / 2))
        return try #require(context.makeImage())
    }

    /// The colour at a pixel, counted from the top-left.
    private func pixel(_ image: CGImage, _ x: Int, _ y: Int) throws -> (Int, Int, Int) {
        let bitmap = NSBitmapImageRep(cgImage: image)
        let color = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        return (Int((color.redComponent * 255).rounded()), Int((color.greenComponent * 255).rounded()), Int((color.blueComponent * 255).rounded()))
    }

    /// The test's red is defined in generic RGB, so it lands a little off pure sRGB red.
    private func isRed(_ color: (Int, Int, Int)) -> Bool {
        color.0 > 220 && color.1 < 70 && color.2 < 70
    }

    @Test func drawsRedactionsInTopLeftCoordinates() throws {
        let image = try picture()
        let result = try #require(ScreenshotRenderer.apply([ScreenshotEdit(kind: .redact, x: 250, y: 20, width: 100, height: 60)], to: image))
        #expect(try pixel(result, 300, 50) == (0, 0, 0))
        #expect(try pixel(result, 300, 150) == (255, 255, 255))
        let red = try pixel(result, 50, 50)
        #expect(isRed(red), "\(red)")
    }

    @Test func cropsLastAndKeepsOtherEdits() throws {
        let image = try picture()
        let edits = [
            ScreenshotEdit(kind: .crop, x: 0, y: 0, width: 200, height: 100),
            ScreenshotEdit(kind: .box, x: 10, y: 10, width: 50, height: 50, color: .blue),
        ]
        let result = try #require(ScreenshotRenderer.apply(edits, to: image))
        #expect(result.width == 200 && result.height == 100)
        let red = try pixel(result, 100, 80)
        #expect(isRed(red), "\(red)")
        // Anything else draws without trouble.
        let everything = ScreenshotEdit.Kind.allCases.filter { $0 != .crop }.map {
            ScreenshotEdit(kind: $0, x: 20, y: 20, width: 120, height: 60, toX: 300, toY: 150, text: "Look", color: .yellow)
        }
        #expect(ScreenshotRenderer.apply(everything, to: image) != nil)
    }

    /// Review R1: edits from every request are drawn again in order, and a blur
    /// from a later one used to be made from the original picture, uncovering
    /// whatever an earlier redaction hid.
    @Test func aLaterBlurNeverUncoversARedaction() throws {
        let image = try picture()
        let edits = [
            ScreenshotEdit(kind: .redact, x: 20, y: 20, width: 120, height: 60),   // over the red square
            ScreenshotEdit(kind: .blur, x: 0, y: 0, width: 200, height: 100),       // a later request
        ]
        let result = try #require(ScreenshotRenderer.apply(edits, to: image))
        for (x, y) in [(80, 50), (21, 21), (139, 79)] {
            #expect(try pixel(result, x, y) == (0, 0, 0), "redacted at \(x),\(y)")
        }
    }

    @Test func nothingDrawnLaterCoversARedaction() throws {
        let image = try picture()
        let edits = [
            ScreenshotEdit(kind: .redact, x: 250, y: 20, width: 100, height: 60),
            ScreenshotEdit(kind: .highlight, x: 200, y: 0, width: 200, height: 200, color: .yellow),
            ScreenshotEdit(kind: .text, x: 260, y: 30, text: "SECRET", color: .white),
        ]
        let result = try #require(ScreenshotRenderer.apply(edits, to: image))
        #expect(try pixel(result, 300, 50) == (0, 0, 0))
        #expect(try pixel(result, 270, 40) == (0, 0, 0))
    }

    @Test func blurSoftensOnlyItsArea() throws {
        let image = try picture()
        // Across the red square's right edge.
        let result = try #require(ScreenshotRenderer.apply([ScreenshotEdit(kind: .blur, x: 150, y: 0, width: 100, height: 100)], to: image))
        let edge = try pixel(result, 200, 50)
        #expect(edge.0 > 200 && edge.1 > 40 && edge.1 < 230, "red and white mix at the edge")
        let red = try pixel(result, 20, 20)
        #expect(isRed(red), "\(red)")
    }

    @Test func requestAsksForJSONWithTheImage() throws {
        let sendable = try #require(SendableImage(try picture(width: 3136, height: 1000)))
        #expect(sendable.width == 1568 && sendable.height == 500)
        #expect(sendable.scale == 2)
        let body = ClaudeImageEditor.body(for: sendable, instruction: "Blur the email")
        #expect(body["model"] as? String == "claude-opus-5")
        #expect(body["fallbacks"] as? String == "default")
        let format = (body["output_config"] as? [String: Any])?["format"] as? [String: Any]
        #expect(format?["type"] as? String == "json_schema")
        let content = try #require(((body["messages"] as? [[String: Any]])?.first?["content"]) as? [[String: Any]])
        #expect(content.first?["type"] as? String == "image")
        #expect((content.last?["text"] as? String)?.contains("1568×500") == true)
        #expect(JSONSerialization.isValidJSONObject(body))
    }

    @Test func readsPlansAndProblems() throws {
        let plan = #"{"reply":"Blurred the email.","edits":[{"kind":"blur","x":1,"y":2,"width":3,"height":4,"toX":0,"toY":0,"text":"","color":"red"}]}"#
        let response = try JSONSerialization.data(withJSONObject: [
            "stop_reason": "end_turn",
            "content": [["type": "thinking", "thinking": ""], ["type": "text", "text": plan]],
        ])
        let read = try ClaudeImageEditor.plan(from: response, statusCode: 200)
        #expect(read.reply == "Blurred the email.")
        #expect(read.edits == [ScreenshotEdit(kind: .blur, x: 1, y: 2, width: 3, height: 4)])
        #expect(read.edits[0].scaled(by: 2).width == 6)

        let refusal = try JSONSerialization.data(withJSONObject: ["stop_reason": "refusal", "content": []])
        #expect(throws: AIEditError.self) { try ClaudeImageEditor.plan(from: refusal, statusCode: 200) }
        let badKey = try JSONSerialization.data(withJSONObject: ["error": ["message": "invalid x-api-key"]])
        #expect(throws: AIEditError.self) { try ClaudeImageEditor.plan(from: badKey, statusCode: 401) }
    }

    @Test func picturesAreSentNoBiggerThanNeeded() throws {
        // A Retina capture goes at one pixel per point.
        let retina = try #require(SendableImage(try picture(width: 1200, height: 800), pixelsPerPoint: 2))
        #expect(retina.width == 600 && retina.height == 400 && retina.scale == 2)
        // A huge picture is held to about 1.15 megapixels.
        let big = try #require(SendableImage(try picture(width: 1500, height: 1500)))
        #expect(big.width * big.height <= 1_150_000)
        #expect(big.estimatedTokens < 1600)
    }

    @Test func followUpsKeepThePictureFirstAndCached() throws {
        var session = ClaudeSession(sendable: try #require(SendableImage(try picture(width: 800, height: 600))))
        session.turns = [.init(instruction: "Blur the email", answer: #"{"reply":"Blurred.","edits":[]}"#)]
        let body = ClaudeImageEditor.body(for: session, instruction: "Now box the title")
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.map { $0["role"] as? String } == ["user", "assistant", "user"])
        let first = try #require(messages[0]["content"] as? [[String: Any]])
        #expect(first[0]["type"] as? String == "image" && first[0]["cache_control"] != nil)
        #expect(first[1]["cache_control"] == nil)
        let last = try #require(messages[2]["content"] as? [[String: Any]])
        #expect(last.count == 1 && last[0]["text"] as? String == "Now box the title" && last[0]["cache_control"] != nil)
        // The same request always encodes to the same bytes, which the cache needs.
        let once = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let again = try JSONSerialization.data(withJSONObject: ClaudeImageEditor.body(for: session, instruction: "Now box the title"),
                                               options: [.sortedKeys])
        #expect(once == again)
    }

    @Test func readsUsage() throws {
        let response = try JSONSerialization.data(withJSONObject: [
            "stop_reason": "end_turn",
            "content": [["type": "text", "text": #"{"reply":"Hi","edits":[]}"#]],
            "usage": ["input_tokens": 40, "cache_read_input_tokens": 1900, "cache_creation_input_tokens": 0, "output_tokens": 120],
        ])
        let reply = try ClaudeImageEditor.reply(from: response, statusCode: 200)
        #expect(reply.usage.total == 2060 && reply.usage.cacheRead == 1900)
        #expect(reply.usage.summary == "2.1K tokens, 1.9K from cache")
        let cutShort = try JSONSerialization.data(withJSONObject: ["stop_reason": "max_tokens", "content": []])
        #expect(throws: AIEditError.self) { try ClaudeImageEditor.reply(from: cutShort, statusCode: 200) }
    }

    @Test func cropsFromSeveralRequestsNarrowDown() throws {
        let image = try picture(width: 400, height: 300)
        let result = try #require(ScreenshotRenderer.apply([
            ScreenshotEdit(kind: .crop, x: 0, y: 0, width: 300, height: 300),
            ScreenshotEdit(kind: .box, x: 10, y: 10, width: 50, height: 50),
            ScreenshotEdit(kind: .crop, x: 100, y: 0, width: 300, height: 200),
        ], to: image))
        #expect(result.width == 200 && result.height == 200)
    }
}
