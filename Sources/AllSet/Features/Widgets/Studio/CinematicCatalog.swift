import AllSetCore
import SwiftUI

/// Complete existing library in the page's single native scroll view.
/// Fixed rows let AppKit measure the document without constructing every preview.
struct CinematicCatalog: View {
    let services: AppServices
    let width: CGFloat
    let filter: StudioWidgetFilter
    let category: WidgetCategory?
    let query: String
    let themesOnly: Bool
    let favoriteIDs: Set<String>?
    @State private var customization: CatalogEntry?

    private struct Row: Identifiable {
        enum Content { case heading(String, String), catalog([CatalogEntry]), themes([ThemeWidget]) }
        let id: String
        let content: Content
    }
    private var catalog: [CatalogEntry] {
        guard !themesOnly else { return [] }
        return filter.entries(query: query).filter {
            (category == nil || $0.category == category) && (favoriteIDs == nil || favoriteIDs!.contains($0.id))
        }
    }
    private var themed: [ThemeWidget] {
        filter.themeWidgets(query: query).filter {
            (category == nil || $0.instance.kind.category == category) && (favoriteIDs == nil || favoriteIDs!.contains($0.id))
        }
    }
    private func rows(_ metrics: CardGridMetrics) -> [Row] {
        var result: [Row] = []
        let catalog = catalog, themed = themed
        for category in WidgetCategory.allCases {
            let items = catalog.filter { $0.category == category }
            guard !items.isEmpty else { continue }
            result.append(Row(id: "catalog-head-\(category.id)", content: .heading(category.title, "\(items.count) existing widgets")))
            for (index, chunk) in metrics.chunks(items).enumerated() {
                result.append(Row(id: "catalog-\(category.id)-\(index)", content: .catalog(chunk)))
            }
        }
        if !themed.isEmpty {
            result.append(Row(id: "theme-head-all", content: .heading("From Themes", "\(themed.count) existing theme widgets")))
            for (index, chunk) in metrics.chunks(themed).enumerated() {
                result.append(Row(id: "theme-\(index)", content: .themes(chunk)))
            }
        }
        return result
    }
    var body: some View {
        let metrics = CardGridMetrics(width: width, minimumWidth: 280, spacing: DS.Space.s)
        let rows = rows(metrics)
        LazyVStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text(themesOnly ? "From Themes" : "All widgets").dsText(.section)
                Text("\(catalog.count) catalog widgets · \(themed.count) theme widgets").dsText(.meta)
            }.frame(height: 66, alignment: .leading).id("studio.catalog.top")
            if rows.isEmpty {
                EmptyState(symbol: "magnifyingglass", title: "No widgets found", message: "Try another category or clear the search.")
            }
            ForEach(rows) { row in
                switch row.content {
                case .heading(let title, let subtitle):
                    HStack {
                        Image(systemName: "square.stack.3d.up").font(.system(size: 17, weight: .semibold))
                            .frame(width: 30, height: 30).background(DS.Surface.raised, in: RoundedRectangle(cornerRadius: DS.Radius.control))
                        Text(title).dsText(.section)
                        Spacer()
                        Text(subtitle).dsText(.meta)
                    }.frame(height: 42).id(row.id)
                case .catalog(let entries):
                    HStack(alignment: .top, spacing: metrics.spacing) {
                        ForEach(entries) { entry in
                            CatalogLibraryCard(entry: entry, services: services, width: metrics.cardWidth) { customization = entry }
                                .frame(width: metrics.cardWidth, height: 220)
                                .accessibilityIdentifier("studio.catalog.\(entry.id)")
                        }
                    }.frame(height: 220, alignment: .top)
                case .themes(let widgets):
                    HStack(alignment: .top, spacing: metrics.spacing) {
                        ForEach(widgets) { widget in
                            ThemeWidgetCard(widget: widget, services: services, showThemeName: true)
                                .frame(width: metrics.cardWidth, height: 220)
                                .accessibilityIdentifier("studio.theme-widget.\(widget.id)")
                        }
                    }.frame(height: 220, alignment: .top)
                }
            }
        }
        .accessibilityIdentifier("studio.catalog")
        .sheet(item: $customization) { entry in
            VStack(spacing: 20) {
                HStack { Text("Customize \(entry.title)").font(.title2); Spacer(); Button("Done") { customization = nil } }
                GalleryCard(entry: entry, services: services).frame(width: 360, height: GalleryCard.height)
            }.padding(28).frame(width: 500).preferredColorScheme(.dark)
        }
    }
}

private struct CatalogLibraryCard: View {
    let entry: CatalogEntry
    let services: AppServices
    let width: CGFloat
    let customize: () -> Void
    @State private var hovering = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: customize) {
                LibraryWidgetPreview(instance: entry.make(), services: services, fit: CGSize(width: width - 24, height: 150), live: hovering)
                    .frame(width: width, height: 170)
                    .background(DS.Surface.canvasLift, in: RoundedRectangle(cornerRadius: DS.Radius.card))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).strokeBorder(.white.opacity(hovering ? 0.25 : 0.08)))
            }.buttonStyle(.plain).accessibilityLabel("Customize \(entry.title)")
                .onHover { value in withMotion(Motion.quick) { hovering = value } }
                .onDrag { services.ui.widgetDrop = entry.make(); return NSItemProvider(object: entry.title as NSString) }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title).dsText(.headline).lineLimit(1)
                    Text(entry.summary).dsText(.meta).lineLimit(1)
                }
                Spacer(minLength: 2)
                Button {
                    services.addWidget(entry.make())
                    services.ui.toast = Toast(message: "\(entry.title) added to desktop", symbol: "plus")
                } label: { Image(systemName: "plus") }
                .buttonStyle(FloatingButtonStyle(diameter: 28)).accessibilityLabel("Add \(entry.title) to Desktop")
            }
        }.frame(width: width, height: 220, alignment: .top)
    }
}
