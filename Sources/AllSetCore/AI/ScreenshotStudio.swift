import CoreGraphics
import Foundation
import ImageIO
import Observation

/// The AI calls the screenshot studio makes, injectable so tests can answer
/// slowly, fail, or answer after the document has changed.
public struct ScreenshotAI: Sendable {
    public var key: @Sendable (AIProvider) -> String?
    /// Claude: the instruction, the session so far and the key; the session after it and the reply.
    public var claude: @Sendable (String, ClaudeSession, String) async throws -> (ClaudeSession, ClaudeReply)
    /// ChatGPT: the picture, the instruction and the key; the new picture.
    public var openAI: @Sendable (CGImage, String, String) async throws -> CGImage
    /// Getting a picture ready for Claude (scaled and encoded, off the main
    /// actor): the picture and its pixels per point; the session, or nil if it
    /// couldn't be prepared. Takes a moment, in which the document can change.
    public var prepare: @Sendable (CGImage, Double) async -> ClaudeSession?

    public init(key: @escaping @Sendable (AIProvider) -> String?,
                claude: @escaping @Sendable (String, ClaudeSession, String) async throws -> (ClaudeSession, ClaudeReply),
                openAI: @escaping @Sendable (CGImage, String, String) async throws -> CGImage,
                prepare: @escaping @Sendable (CGImage, Double) async -> ClaudeSession? = { image, pixelsPerPoint in
                    await Task.detached { ClaudeSession(image: image, pixelsPerPoint: pixelsPerPoint) }.value
                }) {
        self.key = key
        self.claude = claude
        self.openAI = openAI
        self.prepare = prepare
    }

    public static let live = ScreenshotAI(
        key: { AIKeychain.key(for: $0) },
        claude: { instruction, session, key in
            var session = session
            let reply = try await ClaudeImageEditor.ask(instruction, in: &session, key: key)
            return (session, reply)
        },
        openAI: { image, instruction, key in try await OpenAIImageEditor.edit(image, instruction: instruction, key: key) }
    )
}

/// A screenshot being edited, with each version kept for undo and the
/// conversation with the AI.
///
/// Claude always sees the picture as it started (or as ChatGPT last redrew
/// it), with the conversation so far. Its edits all refer to that picture and
/// are drawn onto it together, so the picture and history can come from
/// Claude's prompt cache on every follow-up instead of being sent afresh.
///
/// Each loaded picture is a new document (`generation`): an AI answer that
/// arrives after New Screenshot or Open is dropped, never applied to the new one.
@Observable @MainActor
public final class ScreenshotStudio {
    public struct Message: Identifiable, Equatable {
        public enum Role: Sendable { case user, assistant, problem }
        public let id = UUID()
        public let role: Role
        public let text: String
        /// Small print under a reply, like what it cost.
        public var detail: String?

        public init(role: Role, text: String, detail: String? = nil) {
            self.role = role
            self.text = text
            self.detail = detail
        }
    }

    /// One step, for undo.
    private struct State {
        var image: CGImage
        /// What Claude's edits are drawn on.
        var base: CGImage
        var edits: [ScreenshotEdit] = []
        var session: ClaudeSession?
    }

    private var states: [State] = []
    /// Versions kept for undo besides the original, by count and by size: each is
    /// a full-size picture (about 60 MB for a 5K screenshot). The oldest edits go
    /// first; the original never does.
    ///
    /// The byte figure is a budget for undo history, not a ceiling on memory:
    /// the original and the current picture are always kept, whatever they
    /// weigh. What bounds those is `maxSide`, applied when a picture is opened.
    private static let undoDepth = 24
    public nonisolated static let historyByteBudget = 600 << 20

    /// The longest side, in pixels, of a picture the studio edits: an 8K
    /// screenshot fits; anything larger is scaled down as it's decoded. At
    /// most 256 MB a version, so the two always kept stay bounded.
    public nonisolated static let maxSide = 8192

    /// The picture in a file, scaled down while decoding if its longer side is
    /// over `maxSide` (the full-size pixels are never held). `reducedFrom` is
    /// its original size when that happened. Nil if the file isn't a picture.
    public nonisolated static func picture(at url: URL) -> (image: CGImage, reducedFrom: CGSize?)? {
        // Esc during a capture leaves no file; opening it anyway logs an error.
        guard FileManager.default.fileExists(atPath: url.path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        guard max(width, height) > maxSide else {
            return CGImageSourceCreateImageAtIndex(source, 0, nil).map { ($0, nil) }
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: false,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            .map { ($0, CGSize(width: width, height: height)) }
    }

    private func push(_ state: State) {
        states.append(state)
        if states.count > Self.undoDepth + 1 { states.remove(at: 1) }
        while states.count > 2, historyBytes > historyBudget { states.remove(at: 1) }
    }

    /// Pixel bytes the kept versions hold (shared pictures counted once).
    public var historyBytes: Int {
        var seen = Set<ObjectIdentifier>()
        return states.flatMap { [$0.image, $0.base] }.reduce(0) { total, image in
            seen.insert(ObjectIdentifier(image)).inserted ? total + image.bytesPerRow * image.height : total
        }
    }

    public private(set) var messages: [Message] = []
    public private(set) var isWorking = false
    /// Goes up with every picture loaded; work started for an older one is dropped.
    public private(set) var generation = 0
    /// 2 for a Retina screenshot: Claude gets one pixel per point, which is plenty.
    private var pixelsPerPoint = 1.0
    private let ai: ScreenshotAI
    private let historyBudget: Int
    public var provider: AIProvider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: "screenshot.provider") }
    }

    public init(ai: ScreenshotAI = .live, historyBudget: Int = ScreenshotStudio.historyByteBudget) {
        self.ai = ai
        self.historyBudget = historyBudget
        provider = UserDefaults.standard.string(forKey: "screenshot.provider").flatMap(AIProvider.init) ?? .claude
    }

    public var image: CGImage? { states.last?.image }
    public var versionCount: Int { states.count }

    /// The request in flight. Owned here, not by whichever view asked, so that
    /// replacing the document, Stop, or closing the window can stop it: its
    /// network call is cancelled and nothing more is prepared or sent for it.
    /// (A request the provider already received may still be processed there.)
    @ObservationIgnored private var request: Task<Void, Never>?

    private func cancelRequest() {
        request?.cancel()
        request = nil
    }

    /// A new document: the request for the previous one is cancelled, and any
    /// answer still on its way for it is dropped. `reducedFrom` is the picture's
    /// size before it was scaled down to fit (see `picture(at:)`), to say so.
    public func load(_ image: CGImage, pixelsPerPoint: Double = 1, reducedFrom: CGSize? = nil) {
        cancelRequest()
        generation += 1
        isWorking = false
        self.pixelsPerPoint = pixelsPerPoint
        states = [State(image: image, base: image)]
        messages = reducedFrom.map {
            [Message(role: .assistant, text: "This picture was \(Int($0.width)) × \(Int($0.height)), larger than All Set edits. "
                        + "It's been scaled to \(image.width) × \(image.height).")]
        } ?? []
    }

    /// Stops the request in flight, if any. The picture and its history stay.
    public func cancel() {
        guard isWorking else { return }
        cancelRequest()
        isWorking = false
        messages.append(Message(role: .assistant, text: "Stopped."))
    }

    /// The studio's window closed: the request in flight is stopped, and only
    /// the picture as it is now is kept, so reopening the window shows it. The
    /// earlier versions (undo) and the AI session, which hold most of the
    /// memory, are let go.
    public func windowClosed() {
        cancelRequest()
        isWorking = false
        // Work still unwinding for this picture must not land on the trimmed history.
        generation += 1
        if let current = states.last?.image { states = [State(image: current, base: current)] }
    }

    public func undo() {
        guard states.count > 1 else { return }
        states.removeLast()
        messages.append(Message(role: .assistant, text: "Undone."))
    }

    /// Asks the AI to change the open picture, and returns when it has answered,
    /// failed, or been stopped. One request at a time.
    public func ask(_ instruction: String) async {
        let instruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty, let state = states.last, !isWorking else { return }
        guard let key = ai.key(provider) else {
            messages.append(Message(role: .problem, text: "Add your \(provider.title) API key first."))
            return
        }
        let document = generation
        messages.append(Message(role: .user, text: instruction))
        isWorking = true
        let task = Task { await answer(instruction, from: state, key: key, document: document) }
        request = task
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        if request == task {
            request = nil
            isWorking = false
        }
    }

    private func answer(_ instruction: String, from state: State, key: String, document: Int) async {
        var state = state
        /// Whether this request should go on: its picture is still the one open
        /// and nobody stopped it.
        func stillCurrent() -> Bool { generation == document && !Task.isCancelled }
        do {
            switch provider {
            case .claude:
                let ratio = pixelsPerPoint
                var session: ClaudeSession
                if let existing = state.session {
                    session = existing
                } else {
                    guard let fresh = await ai.prepare(state.base, ratio) else {
                        throw AIEditError("The screenshot couldn't be prepared.")
                    }
                    session = fresh
                }
                // Preparing took a moment: nothing is sent for a picture that was
                // replaced, or a request that was stopped, meanwhile.
                guard stillCurrent() else { return }
                let (answered, reply) = try await ai.claude(instruction, session, key)
                guard stillCurrent() else { return }
                state.session = answered
                if !reply.plan.edits.isEmpty {
                    state.edits += reply.plan.edits
                    let edits = state.edits
                    let base = state.base
                    let edited = await Task.detached(operation: { ScreenshotRenderer.apply(edits, to: base) }).value
                    guard stillCurrent() else { return }
                    if let edited { state.image = edited }
                }
                push(state)
                messages.append(Message(role: .assistant, text: reply.plan.reply.isEmpty ? "Done." : reply.plan.reply,
                                        detail: reply.usage.total > 0 ? reply.usage.summary : nil))
            case .openAI:
                let edited = try await ai.openAI(state.image, instruction, key)
                guard stillCurrent() else { return }
                // A new picture: Claude starts afresh on it.
                push(State(image: edited, base: edited))
                messages.append(Message(role: .assistant, text: "Here's the new version."))
            }
        } catch {
            // A failure for a picture that's no longer open belongs to nobody.
            guard stillCurrent() else { return }
            let text = (error as? AIEditError)?.description ?? error.localizedDescription
            messages.append(Message(role: .problem, text: text))
        }
    }
}
