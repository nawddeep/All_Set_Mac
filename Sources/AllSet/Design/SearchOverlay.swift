import AllSetCore
import SwiftUI

/// ⌘K: one glass field over the window that finds themes, widgets and pages
/// and goes straight to them. Opened from `MainView`; nothing here keeps state
/// but the query.
struct SearchOverlay: View {
    let services: AppServices
    @Bindable var ui: UIState

    @State private var query = ""
    @FocusState private var focused: Bool

    private struct Hit: Identifiable {
        let id: String
        let group: String
        let title: String
        let symbol: String
        let page: AppPage
    }

    private var hits: [Hit] {
        // Every page, including the ones opened from another page rather than a pill.
        let pages = NavSection.allCases.flatMap { NavItem.items(in: $0, services: services) + NavItem.secondary(in: $0) }
            .map { Hit(id: "p-\($0.title)", group: "Pages", title: $0.title, symbol: $0.symbol, page: $0.page) }
        guard !SearchMatch.normalize(query).isEmpty else { return Array(pages.prefix(8)) }
        let themes = ThemeLibrary.search(query).prefix(5)
            .map { Hit(id: "t-\($0.id)", group: "Themes", title: $0.name, symbol: "wand.and.stars", page: .themeSet($0.id)) }
        let widgets = SearchMatch.rank(WidgetCatalog.entries, by: query, name: \.title).prefix(5)
            .map { Hit(id: "w-\($0.id)", group: "Widgets", title: $0.title, symbol: "square.grid.2x2.fill", page: .gallery(nil)) }
        let matched = pages.filter { SearchMatch.containsAll(query, in: $0.title) }
        return themes + widgets + matched
    }

    var body: some View {
        let hits = self.hits
        ZStack(alignment: .top) {
            Color.black.opacity(0.4)
                .contentShape(Rectangle())
                .onTapGesture(perform: close)
            GlassPanel(cornerRadius: DS.Radius.panel, padding: DS.Space.m) {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    SearchField(text: $query, prompt: "Search themes, widgets, pages…")
                        .focused($focused)
                        .onSubmit { if let first = hits.first { go(first) } }
                    if hits.isEmpty {
                        Text("Nothing matches “\(query)”.").dsText(.meta).padding(DS.Space.s)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(hits.enumerated()), id: \.element.id) { index, hit in
                                    if index == 0 || hits[index - 1].group != hit.group {
                                        Text(hit.group).dsText(.eyebrow).padding(.top, index == 0 ? 0 : DS.Space.s).padding(.leading, DS.Space.xs)
                                    }
                                    Row(hit: hit.title, symbol: hit.symbol) { go(hit) }
                                }
                            }
                        }
                        .frame(maxHeight: 340)
                    }
                }
            }
            .frame(width: 520)
            .dsElevated()
            .padding(.top, 120)
        }
        .onAppear { focused = true }
        .onExitCommand(perform: close)
        .transition(.opacity)
    }

    private func close() { withMotion(Motion.quick) { ui.isSearching = false } }

    private func go(_ hit: Hit) {
        ui.page = hit.page
        close()
    }

    private struct Row: View {
        let hit: String
        let symbol: String
        let action: () -> Void
        @State private var hovering = false

        var body: some View {
            Button(action: action) {
                HStack(spacing: DS.Space.s) {
                    Image(systemName: symbol).frame(width: 20).foregroundStyle(DS.Ink.secondary)
                    Text(hit).dsText(.body)
                    Spacer()
                }
                .padding(.horizontal, DS.Space.xs)
                .frame(height: 32)
                .background(RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous).fill(hovering ? DS.Surface.hover : .clear))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
        }
    }
}

/// A short confirmation that floats at the top of the window and leaves by itself.
struct Toast: Equatable {
    let message: String
    var symbol = "checkmark.circle.fill"
    let id = UUID()
}

struct ToastView: View {
    let toast: Toast
    @Bindable var ui: UIState

    var body: some View {
        GlassPanel(cornerRadius: 22, padding: 0) {
            Label(toast.message, systemImage: toast.symbol)
                .dsText(.body)
                .padding(.horizontal, DS.Space.m)
                .frame(height: 40)
        }
        .dsElevated()
        .transition(.move(edge: .top).combined(with: .opacity))
        .task(id: toast.id) {
            try? await Task.sleep(for: .seconds(2.5))
            if ui.toast?.id == toast.id { withMotion(Motion.quick) { ui.toast = nil } }
        }
    }
}
