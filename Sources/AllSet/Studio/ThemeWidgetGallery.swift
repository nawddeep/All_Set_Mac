import AllSetCore
import SwiftUI

/// Every theme's widgets, a rail per theme, to add one at a time. Rails and
/// cards are lazy: only what's on screen is ever built.
struct ThemeWidgetRails: View {
    let services: AppServices
    var query = ""
    /// Only the first few themes, for the gallery's overview.
    var limit: Int?

    private var groups: [(set: ThemeSet, widgets: [ThemeWidget])] {
        let sets = limit.map { Array(ThemeLibrary.all.prefix($0)) } ?? ThemeLibrary.all
        return sets.compactMap { set in
            let widgets = ThemeWidgetCatalog.widgets(in: set.id).filter {
                SearchMatch.normalize(query).isEmpty || SearchMatch.containsAll(query, in: $0.searchText)
            }
            return widgets.isEmpty ? nil : (set, widgets)
        }
    }

    var body: some View {
        let groups = groups
        if groups.isEmpty {
            EmptyState(symbol: "magnifyingglass", title: "No theme widgets match \u{201C}\(query)\u{201D}",
                       message: "Try another word, or a theme's name.")
        } else {
            LazyVStack(alignment: .leading, spacing: DS.Space.l) {
                ForEach(groups, id: \.set.id) { group in
                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        SectionHeader(title: group.set.name, subtitle: "\(group.widgets.count) widgets · \(group.set.tagline)",
                                      actionTitle: "Theme", action: { services.ui.page = .themeSet(group.set.id) })
                        MediaRail(items: group.widgets, cardWidth: 250) { widget in
                            ThemeWidgetCard(widget: widget, services: services)
                        }
                    }
                }
            }
        }
    }
}

/// One theme widget: its preview in the theme's look, and Add (or drag it out).
struct ThemeWidgetCard: View {
    let widget: ThemeWidget
    let services: AppServices

    var showThemeName = false

    @State private var added = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            ZStack {
                LinearGradient(colors: [Color(white: 0.16), Color(white: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)
                LibraryWidgetPreview(instance: widget.instance, services: services, fit: CGSize(width: 214, height: 150), live: isHovering)
                    // Still until pointed at: a rail of moving widgets would keep the Mac busy.
                    .environment(\.widgetIsVisible, isHovering)
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).strokeBorder(DS.Surface.hairline))
            .onHover { isHovering = $0 }
            .onDrag {
                services.ui.widgetDrop = widget.make()
                return NSItemProvider(object: "All Set widget: \(widget.title)" as NSString)
            }
            .help("Drag onto the desktop, or use Add")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Preview of \(widget.title) from \(widget.setName)")

            HStack(spacing: DS.Space.xs) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(widget.title).dsText(.headline).lineLimit(1)
                    Text(showThemeName ? "\(widget.setName) · \(widget.instance.size.title)" : widget.instance.size.title)
                        .dsText(.meta).lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    services.addWidget(widget.make())
                    withMotion(Motion.responsive) { added = true }
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withMotion(Motion.standard) { added = false }
                    }
                } label: {
                    Label(added ? "Added" : "Add", systemImage: added ? "checkmark" : "plus")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.pillProminent)
                .accessibilityLabel("Add \(widget.title) to the desktop")
            }
        }
    }
}
