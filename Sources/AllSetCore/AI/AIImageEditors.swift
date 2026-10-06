import AppKit
import Foundation
import Security

/// Which AI edits the screenshot.
public enum AIProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Edits by instruction: crops, blurs, redactions, highlights, arrows, labels.
    case claude
    /// Redraws the picture as asked.
    case openAI

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .claude: "Claude"
        case .openAI: "ChatGPT"
        }
    }

    public var keyPageURL: URL {
        switch self {
        case .claude: URL(string: "https://console.anthropic.com/settings/keys")!
        case .openAI: URL(string: "https://platform.openai.com/api-keys")!
        }
    }

    public var keyPrefix: String {
        switch self {
        case .claude: "sk-ant-"
        case .openAI: "sk-"
        }
    }
}

/// API keys, kept in the login keychain.
public enum AIKeychain {
    private static let service = "com.pratik.allset.ai"

    public static func key(for provider: AIProvider) -> String? {
        var result: CFTypeRef?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
        ]
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Replaces the key (nil or empty removes it). A failed save keeps the previous key.
    @discardableResult
    public static func setKey(_ key: String?, for provider: AIProvider) -> Bool {
        KeychainItem.store(key, service: service, account: provider.rawValue)
    }
}

public struct AIEditError: Error, CustomStringConvertible {
    public let description: String

    public init(_ description: String) {
        self.description = description
    }
}

/// A picture made small enough to send, and how to scale answers back.
struct SendableImage: Sendable {
    let data: Data
    let mediaType: String
    let width: Int
    let height: Int
    /// Original size ÷ sent size.
    let scale: Double

    /// Pictures cost tokens by area (about one per 28×28 pixels), so they're
    /// sent no larger than Claude looks at them: at most `longestSide` pixels
    /// long, about `maxPixels` in all, and one pixel per screen point, since a
    /// Retina capture's extra detail doesn't help find things in it.
    init?(_ image: CGImage, longestSide: Int = 1568, maxPixels: Double = 1_150_000, pixelsPerPoint: Double = 1) {
        let area = Double(image.width * image.height)
        let factor = min(1, Double(longestSide) / Double(max(image.width, image.height)),
                         (maxPixels / max(area, 1)).squareRoot(), 1 / max(pixelsPerPoint, 1))
        let width = max(Int((Double(image.width) * factor).rounded()), 1)
        let height = max(Int((Double(image.height) * factor).rounded()), 1)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let small = context.makeImage() else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: small)
        if let png = bitmap.representation(using: .png, properties: [:]), png.count < 3_500_000 {
            data = png
            mediaType = "image/png"
        } else if let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
            data = jpeg
            mediaType = "image/jpeg"
        } else {
            return nil
        }
        self.width = width
        self.height = height
        scale = Double(image.width) / Double(width)
    }

    /// Roughly what the picture costs in input tokens.
    var estimatedTokens: Int { Int((Double(width * height) / 750).rounded()) }
}

/// What a request cost, from the response's `usage`.
public struct TokenUsage: Equatable, Sendable {
    public var input = 0
    /// Input read back from the prompt cache, at a tenth of the price.
    public var cacheRead = 0
    public var cacheWrite = 0
    public var output = 0

    public init(input: Int = 0, cacheRead: Int = 0, cacheWrite: Int = 0, output: Int = 0) {
        self.input = input
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
        self.output = output
    }

    init(_ json: [String: Any]?) {
        input = json?["input_tokens"] as? Int ?? 0
        cacheRead = json?["cache_read_input_tokens"] as? Int ?? 0
        cacheWrite = json?["cache_creation_input_tokens"] as? Int ?? 0
        output = json?["output_tokens"] as? Int ?? 0
    }

    public var total: Int { input + cacheRead + cacheWrite + output }

    /// "2.4K tokens, 1.9K from cache"
    public var summary: String {
        func short(_ count: Int) -> String {
            count >= 1000 ? String(format: "%.1fK", Double(count) / 1000) : "\(count)"
        }
        return cacheRead > 0 ? "\(short(total)) tokens, \(short(cacheRead)) from cache" : "\(short(total)) tokens"
    }
}

/// A conversation with Claude about one screenshot. The picture goes first
/// and stays byte-for-byte the same, with earlier turns after it, so every
/// follow-up reads the picture and the history from Claude's prompt cache
/// (a tenth of the price) and Claude remembers what it already did.
public struct ClaudeSession: Sendable {
    public struct Turn: Equatable, Sendable {
        public var instruction: String
        /// Claude's answer, exactly as it came back.
        public var answer: String
    }

    let image: SendableImage
    public internal(set) var turns: [Turn] = []

    /// `pixelsPerPoint` is 2 for a Retina screenshot.
    public init?(image: CGImage, pixelsPerPoint: Double = 1) {
        guard let sendable = SendableImage(image, pixelsPerPoint: pixelsPerPoint) else { return nil }
        self.image = sendable
    }

    init(sendable: SendableImage) {
        image = sendable
    }
}

/// An answer: the plan (in the full picture's pixels) and what it cost.
public struct ClaudeReply: Sendable {
    public var plan: EditPlan
    /// The answer as Claude wrote it, for the conversation history.
    public var answer: String
    public var usage: TokenUsage
}

/// Asks Claude how to edit a screenshot, getting the edits back as JSON.
public enum ClaudeImageEditor {
    public static let model = "claude-opus-5"

    static let system = """
    You help people edit and understand screenshots on a Mac. Each request has one picture and one instruction.

    To change the picture, list edits; they're drawn in order. Kinds: crop (keep only the rectangle), blur, redact \
    (solid black block, for anything private: emails, phone numbers, names, keys, passwords, faces), highlight \
    (translucent marker), box (outline), arrow (from x,y to toX,toY), text (a short label with its top-left at x,y). \
    Coordinates are pixels of the picture as sent, origin at the top-left. Cover text generously so nothing peeks out. \
    Fields an edit doesn't use should be 0 or empty.

    If the instruction is a question, answer it in reply and make no edits. Otherwise reply with one short sentence \
    saying what you changed, or why you couldn't.
    """

    static var schema: [String: Any] { [
        "type": "object",
        "properties": [
            "reply": ["type": "string"],
            "edits": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "kind": ["type": "string", "enum": ScreenshotEdit.Kind.allCases.map(\.rawValue)],
                        "x": ["type": "number"], "y": ["type": "number"],
                        "width": ["type": "number"], "height": ["type": "number"],
                        "toX": ["type": "number"], "toY": ["type": "number"],
                        "text": ["type": "string"],
                        "color": ["type": "string", "enum": ScreenshotEdit.Color.allCases.map(\.rawValue)],
                    ],
                    "required": ["kind", "x", "y", "width", "height", "toX", "toY", "text", "color"],
                    "additionalProperties": false,
                ],
            ],
        ],
        "required": ["reply", "edits"],
        "additionalProperties": false,
    ] }

    /// The request body; separate so it can be checked without the network.
    static func body(for session: ClaudeSession, instruction: String) -> [String: Any] {
        let cached: [String: Any] = ["type": "ephemeral"]
        var messages: [[String: Any]] = []
        func userContent(_ text: String, first: Bool) -> [[String: Any]] {
            guard first else { return [["type": "text", "text": text]] }
            return [
                // A cache breakpoint on the picture: every request in the
                // session starts with the same system prompt and picture.
                ["type": "image", "cache_control": cached,
                 "source": ["type": "base64", "media_type": session.image.mediaType,
                            "data": session.image.data.base64EncodedString()]],
                ["type": "text", "text": "The picture is \(session.image.width)×\(session.image.height) pixels.\n\n\(text)"],
            ]
        }
        for (index, turn) in session.turns.enumerated() {
            messages.append(["role": "user", "content": userContent(turn.instruction, first: index == 0)])
            messages.append(["role": "assistant", "content": [["type": "text", "text": turn.answer]]])
        }
        var last = userContent(instruction, first: session.turns.isEmpty)
        // And one at the end, so the next follow-up reads this whole exchange from the cache.
        last[last.count - 1]["cache_control"] = cached
        messages.append(["role": "user", "content": last])
        return [
            "model": model,
            // The answer is a short JSON list; this only stops a runaway.
            "max_tokens": 8192,
            "system": system,
            // A declined request is retried on the recommended fallback model.
            "fallbacks": "default",
            // Quick enough to feel interactive; screenshot edits rarely need more.
            "output_config": [
                "effort": "medium",
                "format": ["type": "json_schema", "schema": schema],
            ],
            "messages": messages,
        ]
    }

    static func body(for image: SendableImage, instruction: String) -> [String: Any] {
        body(for: ClaudeSession(sendable: image), instruction: instruction)
    }

    /// Reads the plan out of a Messages API response.
    static func plan(from data: Data, statusCode: Int) throws -> EditPlan {
        try reply(from: data, statusCode: statusCode).plan
    }

    static func reply(from data: Data, statusCode: Int) throws -> ClaudeReply {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard statusCode == 200 else {
            let message = ((json?["error"] as? [String: Any])?["message"] as? String) ?? "HTTP \(statusCode)"
            switch statusCode {
            case 401: throw AIEditError("Claude didn't accept the API key. Check it in the panel's settings.")
            case 429: throw AIEditError("Claude is busy or your usage limit was reached. Try again in a moment.")
            default: throw AIEditError("Claude: \(message)")
            }
        }
        switch json?["stop_reason"] as? String {
        case "refusal": throw AIEditError("Claude declined to edit this screenshot.")
        case "max_tokens": throw AIEditError("Claude's answer ran too long. Try a simpler request.")
        default: break
        }
        let blocks = json?["content"] as? [[String: Any]] ?? []
        guard let text = blocks.first(where: { $0["type"] as? String == "text" })?["text"] as? String,
              let plan = try? JSONDecoder().decode(EditPlan.self, from: Data(text.utf8)) else {
            throw AIEditError("Claude's answer couldn't be read.")
        }
        return ClaudeReply(plan: plan, answer: text, usage: TokenUsage(json?["usage"] as? [String: Any]))
    }

    /// Asks for edits in the session; they come back in the full picture's
    /// pixels, and the exchange joins the session's history.
    public static func ask(_ instruction: String, in session: inout ClaudeSession, key: String) async throws -> ClaudeReply {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        // Sorted keys: the cache matches bytes, so the same request must encode the same way.
        request.httpBody = try JSONSerialization.data(withJSONObject: body(for: session, instruction: instruction),
                                                      options: [.sortedKeys])
        let (data, response) = try await URLSession.shared.data(for: request)
        var reply = try reply(from: data, statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        session.turns.append(ClaudeSession.Turn(instruction: instruction, answer: reply.answer))
        reply.plan.edits = reply.plan.edits.map { $0.scaled(by: session.image.scale) }
        return reply
    }
}

/// Asks OpenAI's image model to redraw a screenshot as instructed.
public enum OpenAIImageEditor {
    public static let model = "gpt-image-1"

    public static func edit(_ image: CGImage, instruction: String, key: String) async throws -> CGImage {
        guard let sendable = SendableImage(image, longestSide: 1536) else { throw AIEditError("The screenshot couldn't be prepared.") }
        let boundary = "AllSet-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        field("model", model)
        field("prompt", instruction)
        let fileName = sendable.mediaType == "image/png" ? "screenshot.png" : "screenshot.jpg"
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"\(fileName)\"\r\nContent-Type: \(sendable.mediaType)\r\n\r\n".utf8))
        body.append(sendable.data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/edits")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 240
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard status == 200 else {
            let message = ((json?["error"] as? [String: Any])?["message"] as? String) ?? "HTTP \(status)"
            throw AIEditError(status == 401 ? "OpenAI didn't accept the API key." : "ChatGPT: \(message)")
        }
        guard let encoded = ((json?["data"] as? [[String: Any]])?.first?["b64_json"]) as? String,
              let imageData = Data(base64Encoded: encoded),
              let bitmap = NSBitmapImageRep(data: imageData), let result = bitmap.cgImage else {
            throw AIEditError("ChatGPT's picture couldn't be read.")
        }
        return result
    }
}
