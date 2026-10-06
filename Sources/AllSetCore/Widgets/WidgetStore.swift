import Foundation
import Observation
import OSLog

/// The desktop widgets and their settings, saved as JSON in Application Support.
@Observable @MainActor
public final class WidgetStore {
    public private(set) var widgets: [WidgetInstance] = [] {
        didSet { syncBoxes(from: oldValue) }
    }
    /// Bumped only when widgets come or go, so a widget reading itself isn't
    /// redrawn because another one changed.
    private var membership = 0
    /// One observable box per widget: views that read one widget track only it.
    @ObservationIgnored private var boxes: [UUID: Box] = [:]

    @Observable @MainActor
    final class Box {
        var instance: WidgetInstance
        init(_ instance: WidgetInstance) { self.instance = instance }
    }
    /// False until a layout has been saved, so the app can add a starter set.
    public private(set) var hasSavedLayout = false
    /// Why the last save failed (a full or read-only disk); nil once one works.
    public private(set) var saveError: String?
    /// Saved widgets this version couldn't read (say, a kind from a newer version).
    /// They aren't shown, but they're kept exactly as they were and written back
    /// with every save, so a downgrade or a schema change never erases them.
    public private(set) var unreadableCount = 0
    @ObservationIgnored private var unreadableRecords: [Any] = []

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "widgets")

    public nonisolated static var defaultFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("AllSet", isDirectory: true).appendingPathComponent("widgets.json")
    }

    public init(fileURL: URL = WidgetStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    /// The widget with this id. Tracks only that widget (and whether it
    /// still exists), not the whole list.
    public func instance(_ id: UUID) -> WidgetInstance? {
        _ = membership
        return boxes[id]?.instance
    }

    private func syncBoxes(from old: [WidgetInstance]) {
        var seen = Set<UUID>()
        var changedMembership = old.count != widgets.count
        for widget in widgets {
            seen.insert(widget.id)
            if let box = boxes[widget.id] {
                if box.instance != widget { box.instance = widget }
            } else {
                boxes[widget.id] = Box(widget)
                changedMembership = true
            }
        }
        for id in boxes.keys where !seen.contains(id) {
            boxes[id] = nil
            changedMembership = true
        }
        if changedMembership { membership &+= 1 }
    }

    @discardableResult
    public func add(_ instance: WidgetInstance) -> WidgetInstance {
        widgets.append(instance)
        scheduleSave()
        return instance
    }

    public func add(contentsOf instances: [WidgetInstance]) {
        widgets.append(contentsOf: instances)
        scheduleSave()
    }

    public func update(_ id: UUID, _ change: (inout WidgetInstance) -> Void) {
        guard let index = widgets.firstIndex(where: { $0.id == id }) else { return }
        var instance = widgets[index]
        change(&instance)
        guard instance != widgets[index] else { return }
        widgets[index] = instance
        scheduleSave()
    }

    /// Swaps the whole layout, e.g. for a theme's starter set.
    public func replaceAll(with instances: [WidgetInstance]) {
        widgets = instances
        scheduleSave()
    }

    /// Puts a widget back where it was, e.g. to undo removing it.
    public func insert(_ instance: WidgetInstance, at index: Int) {
        widgets.insert(instance, at: min(max(index, 0), widgets.count))
        scheduleSave()
    }

    public func remove(_ id: UUID) {
        widgets.removeAll { $0.id == id }
        scheduleSave()
    }

    /// Writes immediately, e.g. before the app quits.
    /// True when the layout is on disk; on failure `saveError` says why.
    @discardableResult
    public func saveNow() -> Bool {
        pendingSave?.cancel()
        pendingSave = nil
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encodedLayout(encoder).write(to: fileURL, options: .atomic)
            hasSavedLayout = true
            if saveError != nil { saveError = nil }
            return true
        } catch {
            log.error("Couldn't save widgets: \(error.localizedDescription, privacy: .public)")
            saveError = error.localizedDescription
            return false
        }
    }

    /// Typing in a note changes the store on every keystroke; batch the writes.
    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    /// The widgets, then any records this version couldn't read, unchanged.
    private func encodedLayout(_ encoder: JSONEncoder) throws -> Data {
        guard !unreadableRecords.isEmpty else { return try encoder.encode(widgets) }
        let known = try JSONSerialization.jsonObject(with: encoder.encode(widgets)) as? [Any] ?? []
        return try JSONSerialization.data(withJSONObject: known + unreadableRecords, options: [.prettyPrinted, .sortedKeys])
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        hasSavedLayout = true
        do {
            guard let records = try JSONSerialization.jsonObject(with: data) as? [Any] else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let decoder = JSONDecoder()
            var readable: [WidgetInstance] = []
            for record in records {
                if JSONSerialization.isValidJSONObject(record),
                   let widget = try? decoder.decode(WidgetInstance.self, from: JSONSerialization.data(withJSONObject: record)) {
                    readable.append(widget)
                } else {
                    unreadableRecords.append(record)
                }
            }
            widgets = readable
            unreadableCount = unreadableRecords.count
            if unreadableCount > 0 {
                // A copy of the file as it was, as well as keeping the records themselves.
                let kept = StoreFile.preserve(fileURL)
                log.error("\(self.unreadableCount) widget(s) couldn't be read and are kept as they were. Copy: \(kept?.lastPathComponent ?? "none", privacy: .public)")
            }
        } catch {
            // Keep the unreadable file, or the next save would replace the only copy.
            let kept = StoreFile.preserve(fileURL)
            log.error("Couldn't read widgets: \(error.localizedDescription, privacy: .public). Kept \(kept?.lastPathComponent ?? "nothing", privacy: .public)")
        }
    }
}

/// Decodes the elements it can and skips the rest, so one widget of a kind an
/// older version doesn't know can't wipe out the whole layout.
struct LossyList<Element: Decodable>: Decodable {
    var elements: [Element] = []

    private struct Skip: Decodable {}

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else if (try? container.decode(Skip.self)) == nil {
                break // Not even an object; nothing sensible left to read.
            }
        }
    }
}
