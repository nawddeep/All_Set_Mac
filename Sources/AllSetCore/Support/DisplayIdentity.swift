import Foundation

/// A connected display: its stable identifier (the system's display UUID,
/// the same for a monitor across reconnects and restarts, and different for
/// two monitors of the same model) and its name as macOS shows it.
public struct DisplayInfo: Equatable, Sendable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Which display a saved record (a widget, a window, a wallpaper, a screen's
/// widget size) belongs to. Records are saved with both the display's id and
/// its name; the id decides. The name is the fallback for records saved before
/// ids were, and for a display that's gone when one with its name is there (a
/// monitor swapped for the same model), which is how names always behaved.
/// Names alone collide: two identical monitors share one.
public enum DisplayIdentity {
    /// The index in `displays` the record belongs to, or nil if none fits.
    public static func index(id: String?, name: String?, in displays: [DisplayInfo]) -> Int? {
        if let id, let index = displays.firstIndex(where: { $0.id == id }) { return index }
        if let name, let index = displays.firstIndex(where: { $0.name == name }) { return index }
        return nil
    }

    /// A display's entry in a map keyed by id, or (saved before ids) by name.
    public static func value<Value>(in map: [String: Value], for display: DisplayInfo) -> Value? {
        map[display.id] ?? map[display.name]
    }
}
