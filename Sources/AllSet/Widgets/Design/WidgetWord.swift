import AllSetCore
import SwiftUI

extension EnvironmentValues {
    /// The widget's built-in words, renamed by the person (original → shown).
    @Entry var widgetRenames: [String: String] = [:]
}

/// The built-in words a widget is showing right now, in order, so the editor
/// can offer to rename exactly what's on it.
struct WidgetWordsKey: PreferenceKey {
    static let defaultValue: [String] = []

    static func reduce(value: inout [String], nextValue: () -> [String]) {
        for word in nextValue() where !value.contains(word) {
            value.append(word)
        }
    }
}

/// One of a widget's own words ("CPU", "Up Next", "laps"): shown as the
/// person renamed it, and reported so the editor can list it.
struct WidgetWord: View {
    let text: String
    @Environment(\.widgetRenames) private var renames

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(Self.shown(text, renames: renames))
            .preference(key: WidgetWordsKey.self, value: [text])
    }

    static func shown(_ text: String, renames: [String: String]) -> String {
        guard let renamed = renames[text], !renamed.trimmingCharacters(in: .whitespaces).isEmpty else { return text }
        return renamed
    }
}

extension WidgetTextCase {
    var swiftUI: Text.Case? {
        switch self {
        case .asWritten: nil
        case .uppercase: .uppercase
        case .lowercase: .lowercase
        }
    }
}

extension FootnoteStyle.Alignment {
    var swiftUI: HorizontalAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

/// The person's own line under a widget.
struct WidgetFootnote: View {
    let text: String
    let style: FootnoteStyle

    var body: some View {
        let font = style.font ?? .standard
        Text(text)
            .font(.system(size: style.size.points, weight: style.bold ? .semibold : .regular))
            .fontDesign(font.design)
            .fontWidth(font.width)
            .foregroundStyle(style.color.map { Color($0) } ?? .white)
            .shadow(color: .black.opacity(style.color == nil ? 0.55 : 0.25), radius: 2, y: 1)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
