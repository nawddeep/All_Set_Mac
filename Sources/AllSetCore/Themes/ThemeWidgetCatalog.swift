import CoreGraphics
import Foundation

/// One widget from a theme set, to add on its own, dressed as the theme has it.
public struct ThemeWidget: Identifiable, Sendable {
    /// "<set id>/<position>".
    public let id: String
    public let setID: String
    public let setName: String
    public let title: String
    public let symbol: String
    /// Ready to add: the theme's look, no place yet.
    public let instance: WidgetInstance

    public var searchText: String { "\(title) \(setName) \(instance.kind.title)" }
}

/// Every widget from every theme set, so any of them can be added alone from
/// the gallery. A set's repeats (the same widget, styled the same) appear once.
public enum ThemeWidgetCatalog {
    public static let all: [ThemeWidget] = ThemeLibrary.all.flatMap(widgets(of:))

    public static func widgets(in setID: String) -> [ThemeWidget] {
        all.filter { $0.setID == setID }
    }

    static func widgets(of set: ThemeSet) -> [ThemeWidget] {
        let layout = set.widgets(screenName: nil, bounds: CGSize(width: 10_000, height: 10_000))
        let names = set.includedWidgets
        var seen = Set<String>()
        var result: [ThemeWidget] = []
        for (index, var widget) in layout.enumerated() {
            widget.offset = .zero
            widget.screenName = nil
            // A setup theme's font and corners are desktop-wide settings; a
            // widget taken out alone carries them itself.
            if let setup = set.setup {
                widget.options.font = setup.font
                if !widget.kind.isFreeform { widget.options.cornerRadius = setup.cornerRadius }
            }
            guard seen.insert(fingerprint(widget)).inserted else { continue }
            let name: (title: String, symbol: String) = index < names.count ? (names[index].title, names[index].symbol) : (widget.kind.title, widget.kind.symbol)
            result.append(ThemeWidget(id: "\(set.id)/\(index)", setID: set.id, setName: set.name,
                                      title: name.title, symbol: name.symbol, instance: widget))
        }
        return result
    }

    /// The widget's look and content, without its identity.
    private static func fingerprint(_ widget: WidgetInstance) -> String {
        var copy = widget
        copy.id = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(copy)).map { String(decoding: $0, as: UTF8.self) } ?? copy.id.uuidString + "\(widget.kind)"
    }
}

extension ThemeWidget {
    /// A fresh widget to put on the desktop.
    public func make() -> WidgetInstance {
        var widget = instance
        widget.id = UUID()
        return widget
    }
}
