import AllSetCore
import AppKit
import SwiftUI

/// Every option for one widget. Reads through the store each time so edits
/// made elsewhere (like dragging) never get overwritten with stale values.
struct WidgetOptionsEditor: View {
    let id: UUID
    let services: AppServices
    /// The built-in words the preview is showing, offered for renaming.
    var words: [String] = []

    @State var isPickingImages = false
    @State var isPickingBackground = false

    var body: some View {
        if let instance = services.widgets.instance(id) {
            Section("Size & Style") {
                Picker("Size", selection: binding(\.size, instance)) {
                    ForEach(instance.kind.supportedSizes) { size in
                        Text(size.title).tag(size)
                    }
                }
                .pickerStyle(.segmented)

                scaleSlider("Width", instance, \.scale)
                scaleSlider("Height", instance, \.stretch)
                if instance.scale != 1 || instance.stretch != 1 {
                    Button("Reset to \(instance.size.title) Size") {
                        services.resizeWidget(id, to: WidgetResize.Result(size: instance.size, scale: 1))
                    }
                }

                if instance.kind == .note {
                    Picker("Paper", selection: binding(\.options.noteColor, instance)) {
                        ForEach(NoteColor.allCases) { color in
                            Text(color.title).tag(color)
                        }
                    }
                } else if showsStylePicker(instance), instance.designTheme == nil {
                    Picker("Card", selection: binding(\.material, instance)) {
                        ForEach(WidgetMaterial.allCases) { material in
                            Text(material.title).tag(material)
                        }
                    }
                    if ![.art, .photo, .mesh].contains(instance.material), instance.kind != .neon {
                        TintPicker(title: [.tinted, .paper, .frosted].contains(instance.material) ? "Card color" : "Accent color",
                                   selection: binding(\.tint, instance))
                    }
                    OptionalColorRow(title: "Text color", selection: binding(\.options.ink, instance))
                    OptionalColorRow(title: "Highlight", selection: binding(\.options.accent, instance))
                }
            }

            themeSections(instance)
            textSections(instance)

            if instance.options.cinematicStyle {
                Section("Appearance") {
                    Toggle("Cinematic card", isOn: binding(\.options.cinematicStyle, instance))
                }
            }
            if instance.material == .photo, showsStylePicker(instance), instance.designTheme == nil {
                Section("Background Photo") {
                    BackgroundPhotoPicker(selection: Binding(
                        get: { services.widgets.instance(id)?.options.background },
                        set: { source in services.widgets.update(id) { $0.options.background = source } }
                    ), library: services.images)
                    Button {
                        isPickingBackground = true
                    } label: {
                        Label("Choose Any Photo…", systemImage: "photo.on.rectangle.angled")
                    }
                    .sheet(isPresented: $isPickingBackground) {
                        LibraryPicker(services: services) { sources in
                            if let first = sources.first {
                                services.widgets.update(id) { $0.options.background = first }
                            }
                        }
                    }
                    LabeledContent("Softness") {
                        Slider(value: binding(\.options.backgroundBlur, instance), in: 0...1)
                            .frame(width: 200)
                    }
                }
            }

            if instance.material == .mesh, showsStylePicker(instance), instance.designTheme == nil {
                Section("Colors") {
                    PalettePicker(selection: Binding(
                        get: { services.widgets.instance(id)?.options.art.palette ?? .aurora },
                        set: { palette in services.widgets.update(id) { $0.options.art.palette = palette } }
                    ))
                    Toggle("Drift", isOn: binding(\.options.animateArt, instance))
                    if instance.options.animateArt {
                        LabeledContent("Speed") {
                            Slider(value: binding(\.options.artSpeed, instance), in: 0.25...3)
                                .frame(width: 200)
                        }
                    }
                }
            }

            if instance.material == .art && instance.kind != .note && instance.kind != .photo && instance.designTheme == nil {
                Section("Artwork") {
                    ArtPicker(piece: binding(\.options.art, instance))
                    Toggle("Animate", isOn: binding(\.options.animateArt, instance))
                    if instance.options.animateArt {
                        LabeledContent("Speed") {
                            Slider(value: binding(\.options.artSpeed, instance), in: 0.25...3)
                                .frame(width: 200)
                        }
                    }
                }
            }

            kindSections(instance)

            Section {
                Button("Remove from Desktop", role: .destructive) {
                    services.removeWidget(id)
                }
            }
        }
    }

    /// Font, letters, corners, the widget's own words and a caption under it.
    @ViewBuilder
    func textSections(_ instance: WidgetInstance) -> some View {
        Section {
            Picker("Font", selection: binding(\.options.font, instance)) {
                Text("Desktop\u{2019}s").tag(WidgetFont?.none)
                ForEach(WidgetFont.allCases) { font in
                    Text(font.title).tag(Optional(font))
                }
            }
            Picker("Letters", selection: binding(\.options.textCase, instance)) {
                ForEach(WidgetTextCase.allCases) { textCase in
                    Text(textCase.title).tag(textCase)
                }
            }
            if instance.designTheme == nil, !instance.kind.isFreeform {
                Toggle("Own corner roundness", isOn: Binding(
                    get: { services.widgets.instance(id)?.options.cornerRadius != nil },
                    set: { own in
                        services.widgets.update(id) { $0.options.cornerRadius = own ? services.settings.widgetCornerRadius : nil }
                    }
                ))
                if let radius = instance.options.cornerRadius {
                    LabeledContent("Corners") {
                        Slider(value: Binding(
                            get: { services.widgets.instance(id)?.options.cornerRadius ?? radius },
                            set: { value in services.widgets.update(id) { $0.options.cornerRadius = value } }
                        ), in: 0...40)
                        .frame(width: 200)
                    }
                }
            }
            ForEach(words, id: \.self) { word in
                LabeledContent(word) {
                    TextField("", text: renameBinding(word, instance), prompt: Text("Rename"))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 200)
                }
            }
        } header: {
            Text("Text")
        } footer: {
            Text(words.isEmpty
                 ? "Its words come from your own data, like events or song titles."
                 : "Rename any of the widget\u{2019}s own words; leave one empty to keep it.")
        }

        Section("Caption Below") {
            TextField("Caption", text: binding(\.options.footnote, instance), prompt: Text("A line of your own under the widget"))
            if !instance.options.footnote.trimmingCharacters(in: .whitespaces).isEmpty {
                Picker("Size", selection: binding(\.options.footnoteStyle.size, instance)) {
                    ForEach(FootnoteStyle.Size.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Align", selection: binding(\.options.footnoteStyle.alignment, instance)) {
                    ForEach(FootnoteStyle.Alignment.allCases) { alignment in
                        Text(alignment.title).tag(alignment)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Bold", isOn: binding(\.options.footnoteStyle.bold, instance))
                Picker("Font", selection: binding(\.options.footnoteStyle.font, instance)) {
                    Text("Default").tag(WidgetFont?.none)
                    ForEach(WidgetFont.allCases) { font in
                        Text(font.title).tag(Optional(font))
                    }
                }
                OptionalColorRow(title: "Color", selection: binding(\.options.footnoteStyle.color, instance))
            }
        }
    }

    func renameBinding(_ word: String, _ instance: WidgetInstance) -> Binding<String> {
        Binding(
            get: { services.widgets.instance(id)?.options.renamedText[word] ?? "" },
            set: { text in
                services.widgets.update(id) { widget in
                    if text.isEmpty {
                        widget.options.renamedText[word] = nil
                    } else {
                        widget.options.renamedText[word] = text
                    }
                }
            }
        )
    }

    /// Photos cover their background unless framed; Live Scenes are always art.
    func showsStylePicker(_ instance: WidgetInstance) -> Bool {
        switch instance.kind {
        case .ambient, .vinyl, .moon, .daylight, .polaroids, .sticker, .jersey, .playerCard, .pitch, .scoreboard,
             .cassette, .vhs, .visualizer, .ticket, .wordArt,
             .spiral, .charm, .label, .aura, .tarot, .zodiac, .eightBall, .candle: false
        case .photo: instance.options.photoFrame == .inset || instance.options.photoFrame == .collage
        default: true
        }
    }

    /// Theme, appearance, transparency and accent; then how often it updates.
    @ViewBuilder
    func themeSections(_ instance: WidgetInstance) -> some View {
        if !instance.kind.isFreeform, !instance.kind.paintsOwnBackground {
            Section {
                Picker("Theme", selection: binding(\.options.designTheme, instance)) {
                    Text("Classic Card").tag(String?.none)
                    Divider()
                    ForEach(DesignTheme.all) { theme in
                        Label(theme.title, systemImage: theme.symbol).tag(Optional(theme.id))
                    }
                }
                if let theme = instance.designTheme {
                    Picker("Appearance", selection: binding(\.options.appearance, instance)) {
                        ForEach(WidgetAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!theme.followsAppearance)
                    LabeledContent("Transparency") {
                        Slider(value: binding(\.options.transparency, instance), in: 0...1)
                            .frame(width: 200)
                    }
                    OptionalColorRow(title: "Accent", selection: binding(\.options.accent, instance))
                }
            } header: {
                Text("Theme")
            } footer: {
                if let theme = instance.designTheme {
                    Text(theme.followsAppearance ? theme.summary
                         : "\(theme.summary) It has one look, so it ignores the appearance setting.")
                } else {
                    Text("Classic cards use the style, colors and font below. Pick a theme to let it draw the whole widget.")
                }
            }
        }
        if Self.refreshes(instance) {
            Section {
                Picker("Updates", selection: binding(\.options.refresh, instance)) {
                    ForEach(RefreshPolicy.allCases) { policy in
                        Text(policy.title).tag(policy)
                    }
                }
            } footer: {
                Text("Nothing updates while the widget is covered. Live is quickest; Relaxed saves the most battery and data.")
            }
        }
    }

    private static func refreshes(_ instance: WidgetInstance) -> Bool {
        switch instance.kind {
        case .weather, .airQuality, .github, .status, .system, .battery, .terminal: true
        case .metric: instance.options.metric != .uptime
        default: false
        }
    }


    func colorRow(_ title: String, _ selection: Binding<WidgetColor>) -> some View {
        LabeledContent(title) { colorWell(selection) }
    }

    func colorWell(_ selection: Binding<WidgetColor>) -> some View {
        ColorPicker("", selection: Binding(
            get: { Color(selection.wrappedValue) },
            set: { if let color = WidgetColor($0) { selection.wrappedValue = color } }
        ), supportsOpacity: false)
        .labelsHidden()
    }

    func importFromMac() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.image, .folder]
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task {
            let names = await services.images.importImages(from: urls)
            guard !names.isEmpty else { return }
            services.widgets.update(id) { $0.options.images += names.map { ImageSource.file($0) } }
        }
    }

    /// Width or height as a percentage of the layout's own size (height is `stretch` of the width).
    func scaleSlider(_ title: String, _ instance: WidgetInstance, _ keyPath: KeyPath<WidgetInstance, Double>) -> some View {
        let isWidth = keyPath == \WidgetInstance.scale
        let range = isWidth ? WidgetInstance.scaleRange : 0.2...WidgetInstance.scaleRange.upperBound
        let current: () -> WidgetInstance = { services.widgets.instance(id) ?? instance }
        return LabeledContent(title) {
            HStack {
                Slider(value: Binding(
                    get: { isWidth ? current().scale : current().scale * current().stretch },
                    set: { value in
                        let now = current()
                        let width = isWidth ? value : now.scale
                        let height = isWidth ? now.scale * now.stretch : value
                        services.resizeWidget(id, to: WidgetResize.Result(size: now.size, scale: width, stretch: height / width))
                    }
                ), in: range)
                Text("\(Int(((isWidth ? current().scale : current().scale * current().stretch) * 100).rounded()))%")
                    .monospacedDigit().frame(width: 44, alignment: .trailing)
            }
        }
    }

    func binding<Value>(_ keyPath: WritableKeyPath<WidgetInstance, Value>, _ fallback: WidgetInstance) -> Binding<Value> {
        Binding(
            get: { services.widgets.instance(id)?[keyPath: keyPath] ?? fallback[keyPath: keyPath] },
            set: { value in services.widgets.update(id) {
                $0[keyPath: keyPath] = value
                if keyPath == \WidgetInstance.options.clockFace || keyPath == \WidgetInstance.options.designTheme || (keyPath == \WidgetInstance.material && ($0.material == .art || $0.material == .clear)) {
                    $0.options.cinematicClock = false
                    $0.options.cinematicStyle = false
                }
            } }
        )
    }
}
