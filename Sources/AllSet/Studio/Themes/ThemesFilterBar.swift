import SwiftUI

/// One quiet surface for browsing and search, fixed above the scrolling gallery.
struct ThemesFilterBar: View {
    @Binding var selection: String
    @Binding var query: String
    let reduced: Bool
    let availableWidth: CGFloat
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: DS.Space.s) {
            CategoryRail(selection: $selection, reduced: reduced)
                .mask(alignment: .trailing) {
                    HStack(spacing: 0) {
                        Color.black
                        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 16)
                    }
                }
            if availableWidth < 1220 {
                Menu {
                    ForEach(ThemeDiscovery.allCases) { item in
                        Button { selection = item.rawValue } label: {
                            Label(item.title, systemImage: selection == item.rawValue ? "checkmark" : item.symbol)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(DS.Ink.secondary)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help("All theme categories").accessibilityLabel("All theme categories")
            }
            Rectangle().fill(DS.Surface.hairline).frame(width: 1, height: 18)
            HStack(spacing: DS.Space.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(searchFocused ? DS.Ink.primary : DS.Ink.tertiary)
                TextField("Search themes…", text: $query)
                    .textFieldStyle(.plain).focused($searchFocused)
                    .foregroundStyle(DS.Ink.primary)
                    .accessibilityLabel("Search themes")
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(DS.Ink.secondary)
                            .frame(width: 24, height: 24).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("Clear search")
                }
            }
            .font(.system(size: 12))
            .frame(width: availableWidth < 1000 ? 164 : 190, height: 32)
        }
        .padding(.horizontal, DS.Space.s)
        .padding(.vertical, DS.Space.xs)
        .background(DS.Surface.canvasLift, in: RoundedRectangle(cornerRadius: DS.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.control)
            .strokeBorder(Color.white.opacity(searchFocused ? 0.16 : 0.08)))
    }
}
