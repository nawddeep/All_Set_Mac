import AllSetCore
import AppKit
import SwiftUI

struct EndpointsEditor: View {
    let id: UUID
    let services: AppServices

    var body: some View {
        if let instance = services.widgets.instance(id) {
            Section {
                ForEach(instance.options.endpoints) { endpoint in
                    HStack(spacing: 8) {
                        TextField("Name", text: field(endpoint.id, \.name, endpoint.name)).frame(width: 110)
                        TextField("https://…", text: field(endpoint.id, \.url, endpoint.url))
                        Button { services.widgets.update(id) { $0.options.endpoints.removeAll { $0.id == endpoint.id } } } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove Site")
                        .help("Remove Site")
                        .accessibilityLabel("Remove Site")
                    }
                }
                Button("Add Site or API") {
                    services.widgets.update(id) { $0.options.endpoints.append(StatusEndpoint(name: "My API", url: "https://")) }
                }
                .disabled(instance.options.endpoints.count >= 7)
            } header: {
                Text("Watching")
            } footer: {
                Text("Each is checked with a quick request while the widget is on screen. Statuspage feeds (…/api/v2/status.json) show their own summary.")
            }
        }
    }

    private func field(_ endpointID: UUID, _ keyPath: WritableKeyPath<StatusEndpoint, String>, _ fallback: String) -> Binding<String> {
        Binding(
            get: { services.widgets.instance(id)?.options.endpoints.first { $0.id == endpointID }?[keyPath: keyPath] ?? fallback },
            set: { value in services.widgets.update(id) { widget in
                guard let index = widget.options.endpoints.firstIndex(where: { $0.id == endpointID }) else { return }
                widget.options.endpoints[index][keyPath: keyPath] = value
            } }
        )
    }
}

/// A color that can be left automatic.
struct OptionalColorRow: View {
    let title: String
    @Binding var selection: WidgetColor?

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                if selection != nil {
                    ColorPicker("", selection: Binding(
                        get: { Color(selection ?? WidgetColor(red: 1, green: 1, blue: 1)) },
                        set: { if let color = WidgetColor($0) { selection = color } }
                    ), supportsOpacity: false)
                    .labelsHidden()
                }
                Toggle("Automatic", isOn: Binding(
                    get: { selection == nil },
                    set: { selection = $0 ? nil : WidgetColor(red: 0.2, green: 0.2, blue: 0.2) }
                ))
                .toggleStyle(.checkbox)
            }
        }
    }
}

/// Every sticker shape, drawn in the current finish.
struct StickerShapePicker: View {
    @Binding var selection: StickerShape
    let finish: StickerFinish
    let color: Color

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
            ForEach(StickerShape.allCases) { shape in
                Button {
                    selection = shape
                } label: {
                    StickerArt(shape: shape, finish: finish == .soft ? .solid : finish, color: color, side: 30)
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(shape == selection ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .help(shape.title)
            }
        }
        .padding(.vertical, 4)
    }
}

/// The icons of a Shortcuts widget: what each looks like, says and opens.
struct ShortcutsEditor: View {
    let id: UUID
    let services: AppServices

    static let symbols = ["star.fill", "heart.fill", "sparkles", "moon.stars.fill", "cloud.fill", "bolt.fill", "camera.macro",
                          "crown.fill", "circle.fill", "eye.fill", "music.note", "camera.fill", "book.fill", "envelope.fill",
                          "globe", "bag.fill", "gamecontroller.fill", "paintbrush.fill", "leaf.fill", "flame.fill", "cat.fill"]

    var body: some View {
        if let instance = services.widgets.instance(id) {
            Section {
                ForEach(instance.options.shortcuts) { item in
                    HStack(spacing: 10) {
                        Picker("Icon", selection: itemBinding(item.id, \.symbol, item.symbol)) {
                            ForEach(Self.symbols, id: \.self) { symbol in
                                Image(systemName: symbol).tag(symbol)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 58)
                        TextField("Label", text: itemBinding(item.id, \.title, item.title))
                            .frame(width: 110)
                        TextField("App or website", text: itemBinding(item.id, \.target, item.target))
                            .foregroundStyle(.secondary)
                        Button {
                            services.widgets.update(id) { $0.options.shortcuts.removeAll { $0.id == item.id } }
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove")
                        .help("Remove")
                    }
                }
                HStack {
                    Button {
                        addApps()
                    } label: {
                        Label("Add Apps…", systemImage: "plus.app")
                    }
                    Button {
                        services.widgets.update(id) {
                            $0.options.shortcuts.append(ShortcutItem(symbol: $0.options.shortcuts.last?.symbol ?? "star.fill",
                                                                     title: "website", target: "https://"))
                        }
                    } label: {
                        Label("Add Website", systemImage: "link")
                    }
                    Spacer()
                    Menu("All Icons") {
                        ForEach(Self.symbols, id: \.self) { symbol in
                            Button {
                                services.widgets.update(id) { widget in
                                    for index in widget.options.shortcuts.indices { widget.options.shortcuts[index].symbol = symbol }
                                }
                            } label: {
                                Label(symbol, systemImage: symbol)
                            }
                        }
                    }
                    .fixedSize()
                }
                Toggle("Show labels", isOn: Binding(
                    get: { services.widgets.instance(id)?.options.showLabels ?? true },
                    set: { value in services.widgets.update(id) { $0.options.showLabels = value } }
                ))
            } header: {
                Text("Shortcuts")
            } footer: {
                let fits = switch instance.size {
                case .small: 4
                case .medium: 8
                case .large, .extraLarge: 9
                }
                Text("A \(instance.size.title.lowercased()) widget shows the first \(fits). Type a website (pinterest.com), a link, or pick an app.")
            }
        }
    }

    private func itemBinding(_ itemID: UUID, _ keyPath: WritableKeyPath<ShortcutItem, String>, _ fallback: String) -> Binding<String> {
        Binding(
            get: { services.widgets.instance(id)?.options.shortcuts.first { $0.id == itemID }?[keyPath: keyPath] ?? fallback },
            set: { value in
                services.widgets.update(id) { widget in
                    guard let index = widget.options.shortcuts.firstIndex(where: { $0.id == itemID }) else { return }
                    widget.options.shortcuts[index][keyPath: keyPath] = value
                }
            }
        )
    }

    private func addApps() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        services.widgets.update(id) { widget in
            let symbol = widget.options.shortcuts.last?.symbol ?? "star.fill"
            for url in panel.urls {
                let target = Bundle(url: url)?.bundleIdentifier ?? url.path
                widget.options.shortcuts.append(ShortcutItem(symbol: symbol, title: url.deletingPathExtension().lastPathComponent.lowercased(),
                                                             target: target))
            }
        }
    }
}

/// Palettes as swatches.
struct PalettePicker: View {
    @Binding var selection: ArtPalette

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
            ForEach(ArtPalette.allCases) { palette in
                Button {
                    selection = palette
                } label: {
                    Circle()
                        .fill(AngularGradient(colors: palette.colors.map { Color($0) } + [Color(palette.colors[0])], center: .center))
                        .frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: selection == palette ? 3 : 0).padding(-4))
                        .contentShape(Circle())
                }
                .buttonStyle(PressableStyle())
                .help(palette.title)
            }
        }
        .padding(.vertical, 4)
    }
}
