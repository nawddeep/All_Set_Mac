import Foundation
import Observation
import OSLog

/// One short note: a point in a list.
public struct QuickNote: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var text: String
    public var isDone = false
    public var created = Date()

    public init(text: String, isDone: Bool = false, created: Date = .now) {
        self.text = text
        self.isDone = isDone
        self.created = created
    }
}

/// Quick notes, newest first, saved to Application Support.
@Observable @MainActor
public final class NotesStore {
    public private(set) var notes: [QuickNote] = []
    /// The last notes removed (by hand, by Clear Done, or edited to nothing),
    /// until they're brought back or something else is removed.
    public private(set) var lastRemoval: Removal?

    public struct Removal: Equatable, Sendable {
        /// Each note with the place it had, in order.
        public var notes: [Placed]
        public var count: Int { notes.count }

        public struct Placed: Equatable, Sendable {
            public var index: Int
            public var note: QuickNote
        }
    }

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "notes")

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AllSet/notes.json")
        notes = StoreFile.load([QuickNote].self, from: self.fileURL) ?? []
    }

    /// Adds a note at the top. Several lines become several notes, and a
    /// leading "- " or "• " is dropped, so a pasted list stays a list.
    public func add(_ text: String) {
        let points = text.split(whereSeparator: \.isNewline)
            .map { Self.clean(String($0)) }
            .filter { !$0.isEmpty }
        guard !points.isEmpty else { return }
        notes.insert(contentsOf: points.map { QuickNote(text: $0) }, at: 0)
        scheduleSave()
    }

    public func update(_ id: UUID, text: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let cleaned = Self.clean(text)
        if cleaned.isEmpty {
            lastRemoval = Removal(notes: [.init(index: index, note: notes[index])])
            notes.remove(at: index)
        } else {
            notes[index].text = cleaned
        }
        scheduleSave()
    }

    public func toggle(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isDone.toggle()
        scheduleSave()
    }

    public func remove(_ id: UUID) {
        remove { $0.id == id }
    }

    public func removeDone() {
        remove(where: \.isDone)
    }

    public var doneCount: Int { notes.count(where: \.isDone) }

    private func remove(where shouldRemove: (QuickNote) -> Bool) {
        let removed = notes.enumerated().filter { shouldRemove($0.element) }.map { Removal.Placed(index: $0.offset, note: $0.element) }
        guard !removed.isEmpty else { return }
        lastRemoval = Removal(notes: removed)
        notes.removeAll(where: shouldRemove)
        scheduleSave()
    }

    /// Puts the last removed notes back where they were.
    public func undoRemoval() {
        guard let removal = lastRemoval else { return }
        lastRemoval = nil
        for placed in removal.notes where !notes.contains(where: { $0.id == placed.note.id }) {
            notes.insert(placed.note, at: min(placed.index, notes.count))
        }
        scheduleSave()
    }

    /// Lets the last removal go for good (the Undo offer is dismissed).
    public func forgetRemoval() {
        lastRemoval = nil
    }

    public func move(from source: IndexSet, to destination: Int) {
        let moving = source.sorted().map { notes[$0] }
        var remaining = notes.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let before = source.filter { $0 < destination }.count
        remaining.insert(contentsOf: moving, at: min(max(destination - before, 0), remaining.count))
        notes = remaining
        scheduleSave()
    }

    /// Every note as a bulleted list, for copying elsewhere.
    public var asText: String {
        notes.map { ($0.isDone ? "✓ " : "• ") + $0.text }.joined(separator: "\n")
    }

    private static func clean(_ text: String) -> String {
        var line = text.trimmingCharacters(in: .whitespaces)
        for bullet in ["- ", "• ", "* ", "✓ "] where line.hasPrefix(bullet) {
            line.removeFirst(bullet.count)
        }
        return line.trimmingCharacters(in: .whitespaces)
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    /// Why the last save failed; nil once one works. Shown on the Notes page.
    public private(set) var saveError: String?

    /// True when the notes are on disk.
    @discardableResult
    public func save() -> Bool {
        pendingSave?.cancel()
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(notes).write(to: fileURL, options: .atomic)
            if saveError != nil { saveError = nil }
            return true
        } catch {
            log.error("Couldn't save notes: \(error.localizedDescription, privacy: .public)")
            saveError = error.localizedDescription
            return false
        }
    }
}
