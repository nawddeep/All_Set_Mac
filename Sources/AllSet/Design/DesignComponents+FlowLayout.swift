import SwiftUI

/// Lays views out in rows, wrapping to the next row when one is full: for
/// rows of pills and actions that must fit a narrow window.
struct FlowLayout: Layout {
    var spacing: CGFloat = DS.Space.s
    var lineSpacing: CGFloat = DS.Space.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// Columns and card width for a grid of fixed-size cards in `width` points.
struct CardGridMetrics {
    let columns: Int
    let cardWidth: CGFloat
    let spacing: CGFloat

    init(width: CGFloat, minimumWidth: CGFloat, spacing: CGFloat) {
        columns = max(Int((width + spacing) / (minimumWidth + spacing)), 1)
        cardWidth = max(((width - spacing * CGFloat(columns - 1)) / CGFloat(columns)).rounded(.down), 1)
        self.spacing = spacing
    }

    /// `items` cut into rows of `columns`.
    func chunks<Item>(_ items: [Item]) -> [[Item]] {
        stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
    }
}

/// Content below the fold, built a moment after the page appears instead of
/// in the same frame as the switch. The page shows at once (its hero and
/// first rows), and the rest arrives under `PageVeil`'s fade, which runs in
/// Core Animation and so keeps moving while the main thread builds it.
struct Deferred<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var isReady = false

    var body: some View {
        if isReady {
            content
        } else {
            Color.clear
                .frame(height: 1)
                .task { isReady = true }
        }
    }
}

/// A setting's switch: its name, with a line explaining it underneath.
/// VoiceOver reads the name as the setting and the explanation as a hint;
/// a two-line label alone was read out as the explanation, so "Keep
/// clipboard history" was announced as "Stored only on this Mac".
struct SettingToggle: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    init(_ title: String, detail: String, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
            Text(detail)
        }
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}
