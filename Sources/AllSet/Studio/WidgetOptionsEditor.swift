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

    @State private var isPickingImages = false
    @State private var isPickingBackground = false

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
    private func textSections(_ instance: WidgetInstance) -> some View {
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

    private func renameBinding(_ word: String, _ instance: WidgetInstance) -> Binding<String> {
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
    private func showsStylePicker(_ instance: WidgetInstance) -> Bool {
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
    private func themeSections(_ instance: WidgetInstance) -> some View {
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

    @ViewBuilder
    private func kindSections(_ instance: WidgetInstance) -> some View {
        switch instance.kind {
        case .clock:
            Section("Clock") {
                Picker("Face", selection: binding(\.options.clockFace, instance)) {
                    ForEach(ClockFace.allCases) { face in
                        Text(face.title).tag(face)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Cinematic clock", isOn: binding(\.options.cinematicClock, instance))
                Toggle("24-hour time", isOn: binding(\.options.use24Hour, instance))
                if instance.options.clockFace != .world, instance.options.clockFace != .minimal {
                    Toggle("Show seconds", isOn: binding(\.options.showSeconds, instance))
                }
                if instance.options.clockFace != .world {
                    TimeZonePicker(selection: binding(\.options.timeZoneID, instance))
                }
            }
            if instance.options.clockFace == .world {
                Section {
                    ForEach(Array(instance.options.worldZones.enumerated()), id: \.offset) { index, _ in
                        HStack {
                            TimeZonePicker(selection: Binding(
                                get: { services.widgets.instance(id)?.options.worldZones.dropFirst(index).first },
                                set: { zone in services.widgets.update(id) { widget in
                                    guard let zone, widget.options.worldZones.indices.contains(index) else { return }
                                    widget.options.worldZones[index] = zone
                                } }
                            ))
                            Button { services.widgets.update(id) { $0.options.worldZones.remove(at: index) } } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove City")
                            .accessibilityLabel("Remove City")
                        }
                    }
                    Button("Add City") {
                        services.widgets.update(id) { $0.options.worldZones.append("Australia/Sydney") }
                    }
                    .disabled(instance.options.worldZones.count >= 5)
                } header: {
                    Text("Cities")
                } footer: {
                    Text("This Mac's own time comes first.")
                }
            }
        case .calendar:
            Section("Calendar") {
                Toggle("Show upcoming events", isOn: binding(\.options.showEvents, instance))
                if instance.options.showEvents {
                    CalendarAccessRow(calendar: services.calendar)
                }
            }
        case .weather:
            Section("Weather") {
                CitySearch(id: id, services: services)
            }
        case .photo:
            photoSections(instance)
        case .ambient:
            Section("Scene") {
                ArtPicker(piece: binding(\.options.art, instance))
                Toggle("Animate", isOn: binding(\.options.animateArt, instance))
                if instance.options.animateArt {
                    LabeledContent("Speed") {
                        Slider(value: binding(\.options.artSpeed, instance), in: 0.25...3)
                            .frame(width: 200)
                    }
                }
            }
            Section("On top") {
                Picker("Show", selection: binding(\.options.sceneOverlay, instance)) {
                    ForEach(SceneOverlay.allCases) { overlay in
                        Text(overlay.title).tag(overlay)
                    }
                }
                .pickerStyle(.segmented)
                switch instance.options.sceneOverlay {
                case .time:
                    Toggle("24-hour time", isOn: binding(\.options.use24Hour, instance))
                case .text:
                    TextField("Your words (blank for rotating lines)", text: binding(\.options.customText, instance), axis: .vertical)
                    TextStylePicker(selection: binding(\.options.textStyle, instance))
                default:
                    EmptyView()
                }
            }
        case .quote:
            Section("Words") {
                Picker("Show", selection: binding(\.options.quoteSource, instance)) {
                    ForEach(QuoteSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                if instance.options.quoteSource == .custom {
                    TextField("Type anything", text: binding(\.options.customText, instance), axis: .vertical)
                        .lineLimit(2...5)
                }
                TextField("Small line above, like \"Daily Reminder\"", text: binding(\.options.caption, instance))
                TextStylePicker(selection: binding(\.options.textStyle, instance))
                if instance.options.textStyle == .poster {
                    Text("Poster sets the first line huge. Put the rest on a new line to keep it small and italic.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        case .lockScreen:
            Section("Clock") {
                Picker("Numbers", selection: binding(\.options.clockFace, instance)) {
                    Text("Side by side").tag(ClockFace.digital)
                    Text("Stacked").tag(ClockFace.stacked)
                }
                .pickerStyle(.segmented)
                Toggle("24-hour time", isOn: binding(\.options.use24Hour, instance))
                SettingToggle("Depth effect",
                              detail: "When the photo has a clear subject, like a person or a pet, it stands in front of the time.",
                              isOn: binding(\.options.depthEffect, instance))
            }
        case .daylight:
            Section {
                CitySearch(id: id, services: services)
                Toggle("24-hour time", isOn: binding(\.options.use24Hour, instance))
            } header: {
                Text("Daylight")
            } footer: {
                if instance.options.location == nil {
                    Text("Until you choose a city, sunrise and sunset are worked out for \(TimeZonePlace.guess().name), from your time zone.")
                }
            }
        case .polaroids:
            polaroidSections(instance)
        case .todo:
            Section {
                TextField("Title", text: binding(\.options.listTitle, instance))
                Toggle("Show finished items", isOn: binding(\.options.showDone, instance))
                Button("Clear Finished Items") { services.notes.removeDone() }
                    .disabled(!services.notes.notes.contains(where: \.isDone))
            } header: {
                Text("To-Do")
            } footer: {
                Text("The same list as the Notes tab in the notch and the Notes page, so ticking one off ticks it everywhere.")
            }
        case .focus:
            Section("Focus Timer") {
                Stepper("Focus: \(Int(instance.options.focusMinutes)) minutes", value: binding(\.options.focusMinutes, instance), in: 5...120, step: 5)
                Stepper("Break: \(Int(instance.options.breakMinutes)) minutes", value: binding(\.options.breakMinutes, instance), in: 1...30)
                Button("Start Over") { services.widgets.update(id) { $0.options.focus.reset() } }
            }
        case .metric:
            Section("Shows") {
                Picker("Reading", selection: binding(\.options.metric, instance)) {
                    ForEach(SystemMetric.allCases) { metric in
                        Label(metric.title, systemImage: metric.symbol).tag(metric)
                    }
                }
                if instance.options.metric == .wifi {
                    Text("The network's name needs Location access for All Set in System Settings. Signal and speed don't.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        case .goals:
            GoalsEditor(id: id, services: services)
        case .habits:
            HabitsEditor(id: id, services: services)
        case .reading:
            Section("Book") {
                TextField("Title", text: binding(\.options.book.title, instance))
                TextField("Author", text: binding(\.options.book.author, instance))
                Stepper("Page \(instance.options.book.page)", value: binding(\.options.book.page, instance), in: 0...max(instance.options.book.pages, 1))
                Stepper("\(instance.options.book.pages) pages", value: binding(\.options.book.pages, instance), in: 1...5000, step: 10)
                ColorPicker("Cover", selection: Binding(
                    get: { Color(services.widgets.instance(id)?.options.book.color ?? instance.options.book.color) },
                    set: { color in if let value = WidgetColor(color) { services.widgets.update(id) { $0.options.book.color = value } } }
                ), supportsOpacity: false)
            }
        case .github:
            GitHubEditor(id: id, services: services)
        case .status:
            EndpointsEditor(id: id, services: services)
        case .airQuality:
            Section("Air Quality") {
                CitySearch(id: id, services: services)
            }
        case .magazine:
            Section("Magazine") {
                TextField("Masthead (blank for ALL SET)", text: binding(\.options.customText, instance))
            }
        case .retroWindow:
            Section("Clock") {
                Toggle("24-hour time", isOn: binding(\.options.use24Hour, instance))
            }
        case .neon:
            Section("Neon") {
                TextField("Words", text: binding(\.options.customText, instance), axis: .vertical)
                    .lineLimit(1...3)
                TextStylePicker(selection: binding(\.options.textStyle, instance))
                TintPicker(title: "Glow", selection: binding(\.tint, instance))
                Toggle("Flicker now and then", isOn: binding(\.options.neonFlicker, instance))
            }
        case .terminal:
            Section {
                Text("Shows CPU, memory, battery and more, updating every couple of seconds while it's in view.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Terminal")
            } footer: {
                Text("Tip: Solid card in black with green or amber text looks most like a real terminal.")
            }
        case .stopwatch:
            Section("Stopwatch") {
                Button("Reset") { services.widgets.update(id) { $0.options.stopwatch.reset() } }
            }
        case .shortcuts:
            ShortcutsEditor(id: id, services: services)
        case .sticker:
            Section("Sticker") {
                StickerShapePicker(selection: binding(\.options.sticker, instance), finish: instance.options.stickerFinish,
                                   color: Color(instance.tint))
                Picker("Finish", selection: binding(\.options.stickerFinish, instance)) {
                    ForEach(StickerFinish.allCases) { finish in
                        Text(finish.title).tag(finish)
                    }
                }
                .pickerStyle(.segmented)
                TintPicker(title: "Color", selection: binding(\.tint, instance))
                TextField("Or type an emoji or a word", text: binding(\.options.stickerText, instance))
                LabeledContent("Tilt") {
                    Slider(value: binding(\.options.stickerTilt, instance), in: -30...30, step: 1)
                        .frame(width: 200)
                }
            }
        case .countdown:
            Section("Countdown") {
                TextField("What are you counting down to?", text: binding(\.options.countdownTitle, instance))
                DatePicker("Date", selection: Binding(
                    get: { services.widgets.instance(id)?.options.countdownDate ?? .now },
                    set: { date in services.widgets.update(id) { $0.options.countdownDate = date } }
                ), displayedComponents: .date)
                TextStylePicker(selection: binding(\.options.textStyle, instance))
            }
        case .jersey:
            shirtSection(instance)
        case .playerCard:
            shirtSection(instance)
            cardSection(instance)
            portraitSection(instance)
        case .pitch, .scoreboard:
            matchSection(instance)
        case .milestone:
            Section("Milestone") {
                TextField("What it counts", text: binding(\.options.milestone.label, instance))
                Stepper(value: binding(\.options.milestone.value, instance), in: 0...9_999_999) {
                    TextField("Number", value: binding(\.options.milestone.value, instance), format: .number)
                }
                TextField("After the number, like +", text: binding(\.options.milestone.suffix, instance))
                TextField("A line below", text: binding(\.options.milestone.caption, instance))
            }
        case .cassette:
            Section {
                TextField("Label, when nothing's playing", text: binding(\.options.customText, instance))
                TintPicker(title: "Glow", selection: binding(\.tint, instance))
            } header: {
                Text("Cassette")
            } footer: {
                Text("While music plays, the label shows the song and the reels turn.")
            }
        case .vhs:
            Section("Tape") {
                TextField("Caption, like SUMMER 1996", text: binding(\.options.caption, instance))
            }
            photoSections(instance)
        case .visualizer:
            Section("Visualizer") {
                Picker("Style", selection: binding(\.options.visualizer, instance)) {
                    ForEach(VisualizerStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                TintPicker(title: "Glow", selection: binding(\.tint, instance))
            }
        case .ticket:
            Section("Ticket") {
                TextField("Headline", text: binding(\.options.ticket.headline, instance))
                TextField("Line below", text: binding(\.options.ticket.subtitle, instance))
                TextField("Venue", text: binding(\.options.ticket.venue, instance))
                TextField("Seat", text: binding(\.options.ticket.seat, instance))
                DatePicker("Date", selection: Binding(
                    get: { services.widgets.instance(id)?.options.ticket.date ?? .now },
                    set: { date in services.widgets.update(id) { $0.options.ticket.date = date } }
                ), displayedComponents: [.date, .hourAndMinute])
                TintPicker(title: "Stripe", selection: binding(\.tint, instance))
            }
        case .wordArt:
            Section("Word Art") {
                TextField("Your words", text: binding(\.options.customText, instance), axis: .vertical)
                    .lineLimit(1...3)
                Picker("Finish", selection: binding(\.options.wordArt, instance)) {
                    ForEach(WordArtFinish.allCases) { finish in
                        Text(finish.title).tag(finish)
                    }
                }
                TextStylePicker(selection: binding(\.options.textStyle, instance))
                if [.neon, .glitter].contains(instance.options.wordArt) {
                    TintPicker(title: "Color", selection: binding(\.tint, instance))
                }
            }
        case .spiral:
            Section("Spiral") {
                TintPicker(title: "Background", selection: binding(\.tint, instance))
                OptionalColorRow(title: "Stripes", selection: binding(\.options.ink, instance))
            }
        case .charm:
            Section("Charm") {
                Picker("Shape", selection: binding(\.options.charm, instance)) {
                    ForEach(CharmShape.allCases) { Text($0.title).tag($0) }
                }
                TintPicker(title: "Metal tint", selection: binding(\.tint, instance))
            }
        case .label:
            Section("Label") {
                TextField("Name", text: binding(\.options.customText, instance))
                TextField("Line below, like Nº 07 · EAU DE NUIT", text: binding(\.options.caption, instance))
                TintPicker(title: "Paper", selection: binding(\.tint, instance))
                OptionalColorRow(title: "Ink", selection: binding(\.options.ink, instance))
            }
        case .zodiac:
            Section("Star Sign") {
                Picker("Sign", selection: binding(\.options.zodiac, instance)) {
                    ForEach(ZodiacSign.allCases) { Text("\($0.glyph) \($0.title)").tag($0) }
                }
                OptionalColorRow(title: "Stars", selection: binding(\.options.accent, instance))
            }
        case .tarot, .eightBall:
            Section {
                TintPicker(title: "Background", selection: binding(\.tint, instance))
                OptionalColorRow(title: instance.kind == .tarot ? "Gold" : "Window", selection: binding(\.options.accent, instance))
            } header: {
                Text(instance.kind == .tarot ? "Card" : "Magic Ball")
            } footer: {
                Text(instance.kind == .tarot ? "A new card is drawn each day." : "Think of a question, then tap the ball on your desktop.")
            }
        case .aura:
            Section {
                TintPicker(title: "Background", selection: binding(\.tint, instance))
            } header: {
                Text("Aura")
            } footer: {
                Text("Your aura changes every day.")
            }
        case .candle:
            Section("Candle") {
                TextField("Words beside the flame", text: binding(\.options.customText, instance))
                TintPicker(title: "Background", selection: binding(\.tint, instance))
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func photoSections(_ instance: WidgetInstance) -> some View {
        Section {
            ImageStrip(sources: instance.options.images, library: services.images) { source in
                services.widgets.update(id) { $0.options.images.removeAll { $0 == source } }
            }
            HStack {
                Button {
                    isPickingImages = true
                } label: {
                    Label("Choose from Library…", systemImage: "photo.on.rectangle.angled")
                }
                Button {
                    importFromMac()
                } label: {
                    Label("Import from Mac…", systemImage: "square.and.arrow.down")
                }
            }
            .sheet(isPresented: $isPickingImages) {
                LibraryPicker(services: services) { sources in
                    services.widgets.update(id) { widget in
                        widget.options.images += sources.filter { !widget.options.images.contains($0) }
                    }
                }
            }
            Picker("Slideshow", selection: binding(\.options.slideshowInterval, instance)) {
                Text("Off").tag(0.0)
                Text("Every 10 seconds").tag(10.0)
                Text("Every minute").tag(60.0)
                Text("Every 10 minutes").tag(600.0)
                Text("Every hour").tag(3600.0)
                Text("Every day").tag(86_400.0)
            }
            .disabled(instance.options.images.count < 2)
        } header: {
            Text("Pictures")
        } footer: {
            Text(instance.options.images.count < 2 ? "Add two or more pictures to make a slideshow." : "\(instance.options.images.count) pictures")
        }

        Section("Look") {
            Picker("Filter", selection: binding(\.options.photoFilter, instance)) {
                ForEach(PhotoFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            Picker("Frame", selection: binding(\.options.photoFrame, instance)) {
                ForEach(PhotoFrame.allCases) { frame in
                    Text(frame.title).tag(frame)
                }
            }
            .pickerStyle(.segmented)
            TextField("Caption", text: binding(\.options.caption, instance))
            if instance.options.photoFrame != .polaroid, !instance.options.caption.isEmpty {
                TextStylePicker(selection: binding(\.options.textStyle, instance))
            }
            if instance.options.images.contains(where: { if case .art = $0 { true } else { false } }) || instance.options.images.isEmpty {
                Toggle("Animate art", isOn: binding(\.options.animateArt, instance))
            }
        }
    }

    @ViewBuilder
    private func polaroidSections(_ instance: WidgetInstance) -> some View {
        Section {
            ImageStrip(sources: instance.options.images, library: services.images) { source in
                services.widgets.update(id) { $0.options.images.removeAll { $0 == source } }
            }
            HStack {
                Button {
                    isPickingImages = true
                } label: {
                    Label("Choose from Library…", systemImage: "photo.on.rectangle.angled")
                }
                Button {
                    importFromMac()
                } label: {
                    Label("Import from Mac…", systemImage: "square.and.arrow.down")
                }
            }
            .sheet(isPresented: $isPickingImages) {
                LibraryPicker(services: services) { sources in
                    services.widgets.update(id) { widget in
                        widget.options.images += sources.filter { !widget.options.images.contains($0) }
                    }
                }
            }
            Picker("Next print", selection: binding(\.options.slideshowInterval, instance)) {
                Text("When clicked").tag(0.0)
                Text("Every 10 seconds").tag(10.0)
                Text("Every minute").tag(60.0)
                Text("Every 10 minutes").tag(600.0)
                Text("Every hour").tag(3600.0)
            }
        } header: {
            Text("Prints")
        } footer: {
            Text(instance.options.images.isEmpty ? "Showing a few favourites. Add your own photos above."
                 : "\(instance.options.images.count) photos in the pile. Click the widget to deal the next one.")
        }
        Section("Look") {
            Picker("Film", selection: binding(\.options.photoFilter, instance)) {
                ForEach(PhotoFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            TextField("Handwritten caption", text: binding(\.options.caption, instance))
        }
    }

    // MARK: Football

    @ViewBuilder
    private func shirtSection(_ instance: WidgetInstance) -> some View {
        Section("Player") {
            TextField("Name on the back", text: binding(\.options.player.name, instance))
            Stepper("Number: \(instance.options.player.number)", value: binding(\.options.player.number, instance), in: 0...99)
            TextField("A line below, like PORTUGAL or SINCE 2003", text: binding(\.options.player.tagline, instance))
        }
        Section("Kit") {
            Menu("Start from Colors…") {
                ForEach(KitPreset.all) { kit in
                    Button(kit.title) { services.widgets.update(id) { $0.options.player.apply(kit) } }
                }
            }
            Picker("Pattern", selection: binding(\.options.player.pattern, instance)) {
                ForEach(KitPattern.allCases) { pattern in
                    Text(pattern.title).tag(pattern)
                }
            }
            colorRow("Shirt", binding(\.options.player.primary, instance))
            colorRow("Pattern", binding(\.options.player.secondary, instance))
            colorRow("Name & number", binding(\.options.player.trim, instance))
        }
    }

    @ViewBuilder
    private func cardSection(_ instance: WidgetInstance) -> some View {
        Section("Card") {
            Picker("Finish", selection: binding(\.options.player.finish, instance)) {
                ForEach(CardFinish.allCases) { finish in
                    Text(finish.title).tag(finish)
                }
            }
            .pickerStyle(.segmented)
            Stepper("Rating: \(instance.options.player.rating)", value: binding(\.options.player.rating, instance), in: 1...99)
            TextField("Position, like ST or CAM", text: binding(\.options.player.position, instance))
            ForEach(Array(PlayerDetails.statNames.enumerated()), id: \.offset) { index, name in
                LabeledContent(name) {
                    Slider(value: Binding(
                        get: { Double(services.widgets.instance(id)?.options.player.stats[index] ?? 50) },
                        set: { value in services.widgets.update(id) { $0.options.player.stats[index] = Int(value.rounded()) } }
                    ), in: 1...99, step: 1)
                    .frame(width: 200)
                    Text("\(instance.options.player.stats[index])").monospacedDigit().frame(width: 24, alignment: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private func portraitSection(_ instance: WidgetInstance) -> some View {
        Section {
            ImageStrip(sources: Array(instance.options.images.prefix(1)), library: services.images) { _ in
                services.widgets.update(id) { $0.options.images = [] }
            }
            HStack {
                Button {
                    isPickingImages = true
                } label: {
                    Label("Choose from Library…", systemImage: "photo.on.rectangle.angled")
                }
                Button {
                    importPortrait()
                } label: {
                    Label("Import from Mac…", systemImage: "square.and.arrow.down")
                }
            }
            .sheet(isPresented: $isPickingImages) {
                LibraryPicker(services: services) { sources in
                    if let first = sources.first { services.widgets.update(id) { $0.options.images = [first] } }
                }
            }
        } header: {
            Text("Portrait")
        } footer: {
            Text("A photo with the subject in the middle works best. Without one, the card shows a player silhouette.")
        }
    }

    private func importPortrait() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.prompt = "Use"
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task {
            let names = await services.images.importImages(from: urls)
            if let name = names.first { services.widgets.update(id) { $0.options.images = [.file(name)] } }
        }
    }

    @ViewBuilder
    private func matchSection(_ instance: WidgetInstance) -> some View {
        let match = instance.options.match
        Section("Match") {
            TextField("Competition", text: binding(\.options.match.competition, instance))
            HStack {
                TextField("Home", text: binding(\.options.match.home, instance))
                colorWell(binding(\.options.match.homeColor, instance))
                Text("vs").foregroundStyle(.secondary)
                TextField("Away", text: binding(\.options.match.away, instance))
                colorWell(binding(\.options.match.awayColor, instance))
            }
            Toggle("Kickoff time", isOn: Binding(
                get: { services.widgets.instance(id)?.options.match.kickoff != nil },
                set: { on in services.widgets.update(id) { $0.options.match.kickoff = on ? .now.addingTimeInterval(3 * 86_400) : nil } }
            ))
            if match.kickoff != nil {
                DatePicker("Kickoff", selection: Binding(
                    get: { services.widgets.instance(id)?.options.match.kickoff ?? .now },
                    set: { date in services.widgets.update(id) { $0.options.match.kickoff = date } }
                ))
            }
            Toggle("Show a score", isOn: Binding(
                get: { services.widgets.instance(id)?.options.match.hasScore ?? false },
                set: { on in services.widgets.update(id) {
                    $0.options.match.homeScore = on ? 0 : nil
                    $0.options.match.awayScore = on ? 0 : nil
                } }
            ))
            if match.hasScore {
                Stepper("\(match.home): \(match.homeScore ?? 0)", value: Binding(
                    get: { services.widgets.instance(id)?.options.match.homeScore ?? 0 },
                    set: { value in services.widgets.update(id) { $0.options.match.homeScore = value } }
                ), in: 0...20)
                Stepper("\(match.away): \(match.awayScore ?? 0)", value: Binding(
                    get: { services.widgets.instance(id)?.options.match.awayScore ?? 0 },
                    set: { value in services.widgets.update(id) { $0.options.match.awayScore = value } }
                ), in: 0...20)
            }
            if instance.kind == .pitch {
                Picker("Formation", selection: binding(\.options.match.formation, instance)) {
                    ForEach(Formation.allCases) { formation in
                        Text(formation.title).tag(formation)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func colorRow(_ title: String, _ selection: Binding<WidgetColor>) -> some View {
        LabeledContent(title) { colorWell(selection) }
    }

    private func colorWell(_ selection: Binding<WidgetColor>) -> some View {
        ColorPicker("", selection: Binding(
            get: { Color(selection.wrappedValue) },
            set: { if let color = WidgetColor($0) { selection.wrappedValue = color } }
        ), supportsOpacity: false)
        .labelsHidden()
    }

    private func importFromMac() {
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
    private func scaleSlider(_ title: String, _ instance: WidgetInstance, _ keyPath: KeyPath<WidgetInstance, Double>) -> some View {
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

    private func binding<Value>(_ keyPath: WritableKeyPath<WidgetInstance, Value>, _ fallback: WidgetInstance) -> Binding<Value> {
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

/// Thumbnails of a photo widget's pictures, each removable.
private struct ImageStrip: View {
    let sources: [ImageSource]
    let library: ImageLibrary
    let onRemove: (ImageSource) -> Void

    var body: some View {
        if sources.isEmpty {
            Text("Showing the default art. Add your own pictures below.")
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sources, id: \.self) { source in
                        PhotoContent(source: source, filter: .none, tint: .accentColor, animated: false, library: library,
                                     maxPixels: 256)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    onRemove(source)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .help("Remove Photo")
                                .accessibilityLabel("Remove Photo")
                                .padding(3)
                            }
                    }
                }
            }
        }
    }
}

/// Style thumbnails drawn in the current palette, then palette swatches.
struct ArtPicker: View {
    @Binding var piece: ArtPiece

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(ArtStyle.allCases) { style in
                    ArtView(piece: ArtPiece(style: style, palette: piece.palette))
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.accentColor, lineWidth: style == piece.style ? 3 : 0)
                        }
                        .onTapGesture { piece.style = style }
                        .help(style.title)
                }
            }
            HStack(spacing: 7) {
                ForEach(ArtPalette.allCases) { palette in
                    Circle()
                        .fill(LinearGradient(colors: palette.colors[1...4].map { Color($0) },
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 22, height: 22)
                        .overlay {
                            if palette == piece.palette {
                                Circle().strokeBorder(Color.accentColor, lineWidth: 2.5).padding(-4)
                            }
                        }
                        .onTapGesture { piece.palette = palette }
                        .help(palette.title)
                }
            }
            Text(piece.title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Each style's name written in that style.
private struct TextStylePicker: View {
    @Binding var selection: TextStyle

    var body: some View {
        LabeledContent("Text style") {
            Picker("Text style", selection: $selection) {
                ForEach(TextStyle.allCases) { style in
                    Text(style.title).font(style.font(size: 13)).tag(style)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}

private struct TimeZonePicker: View {
    @Binding var selection: String?

    var body: some View {
        Picker("Time zone", selection: $selection) {
            Text("This Mac's").tag(String?.none)
            Divider()
            ForEach(TimeZone.knownTimeZoneIdentifiers.sorted(), id: \.self) { identifier in
                Text(identifier.replacingOccurrences(of: "_", with: " ")).tag(Optional(identifier))
            }
        }
    }
}

/// Preset swatches plus the system color picker.
private struct TintPicker: View {
    let title: String
    @Binding var selection: WidgetColor

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                ForEach(WidgetColor.presets, id: \.self) { preset in
                    Button {
                        selection = preset
                    } label: {
                        Circle()
                            .fill(Color(preset))
                            .frame(width: 18, height: 18)
                            .overlay {
                                if preset == selection {
                                    Circle().strokeBorder(.white, lineWidth: 2).padding(-1)
                                    Circle().strokeBorder(Color(preset), lineWidth: 1.5).padding(-4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
                ColorPicker("", selection: Binding(
                    get: { Color(selection) },
                    set: { if let color = WidgetColor($0) { selection = color } }
                ), supportsOpacity: false)
                .labelsHidden()
            }
        }
    }
}

private struct CalendarAccessRow: View {
    let calendar: CalendarService

    var body: some View {
        switch calendar.access {
        case .granted:
            LabeledContent("Calendar access") {
                Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            }
        case .notDetermined:
            LabeledContent("Calendar access") {
                Button("Allow Access…") {
                    Task { await calendar.requestAccess() }
                }
            }
        case .denied:
            LabeledContent("Calendar access") {
                Button("Open Privacy Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            Text("Turn on All Set under Calendars to show events.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .unavailable:
            Text("Events need the packaged app (`make open`); a development build can't ask for calendar access.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CitySearch: View {
    let id: UUID
    let services: AppServices

    @State private var query = ""
    @State private var results: [WeatherLocation] = []
    @State private var isSearching = false
    @State private var message: String?

    var body: some View {
        LabeledContent("City") {
            Text(services.widgets.instance(id)?.options.location?.fullName ?? "Not set")
                .foregroundStyle(.secondary)
        }
        HStack {
            TextField("Search for a city", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit(search)
            Button("Search", action: search)
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
        }
        if isSearching {
            ProgressView().controlSize(.small)
        }
        ForEach(results, id: \.self) { location in
            Button {
                services.widgets.update(id) { $0.options.location = location }
                results = []
                query = ""
            } label: {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                    Text(location.fullName)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
        if let message {
            Text(message).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func search() {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSearching = true
        message = nil
        Task {
            defer { isSearching = false }
            do {
                results = try await services.weather.searchLocations(text)
                if results.isEmpty { message = "No places match “\(text)”." }
            } catch {
                message = "Search failed: \(error.localizedDescription)"
            }
        }
    }
}


/// The curated background photos, by theme, as a grid of thumbnails.
struct BackgroundPhotoPicker: View {
    @Binding var selection: ImageSource?
    let library: ImageLibrary

    @State private var collection = CuratedBackgrounds.collections[0].id

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(CuratedBackgrounds.collections) { group in
                        Button {
                            withMotion(Motion.quick) { collection = group.id }
                        } label: {
                            Label(group.title, systemImage: group.symbol)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(collection == group.id ? Color.white : .primary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(collection == group.id ? Color.accentColor : Color.primary.opacity(0.07)))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            let photos = CuratedBackgrounds.collections.first { $0.id == collection }?.photos ?? []
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 6)], spacing: 6) {
                ForEach(photos) { photo in
                    let source = ImageSource.web(photo)
                    Button {
                        selection = source
                    } label: {
                        Color.clear
                            .aspectRatio(1.4, contentMode: .fit)
                            .overlay {
                                AsyncImage(url: photo.thumbnailURL(side: 200), transaction: Transaction(animation: .easeOut(duration: 0.3))) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Rectangle().fill(.quaternary)
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(Color.accentColor, lineWidth: selection == source ? 3 : 0)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .help("Photo by \(photo.author)")
                }
            }
        }
    }
}

/// Symbols for goals and habits.
private let lifeSymbols = ["drop.fill", "figure.walk", "figure.run", "book.fill", "leaf.fill", "moon.zzz.fill", "pencil.line",
                           "dumbbell.fill", "fork.knife", "cup.and.saucer.fill", "brain.head.profile", "heart.fill", "pills.fill",
                           "music.note", "paintbrush.fill", "laptopcomputer", "sun.max.fill", "bed.double.fill", "figure.mind.and.body"]

private struct GoalsEditor: View {
    let id: UUID
    let services: AppServices

    var body: some View {
        if let instance = services.widgets.instance(id) {
            Section {
                ForEach(instance.options.goals) { goal in
                    HStack(spacing: 8) {
                        SymbolMenu(selection: field(goal.id, \.symbol, goal.symbol))
                        TextField("Goal", text: field(goal.id, \.title, goal.title)).frame(width: 110)
                        Stepper("\(goal.target)", value: field(goal.id, \.target, goal.target), in: 1...10_000)
                        TextField("unit", text: field(goal.id, \.unit, goal.unit)).frame(width: 64)
                        Button { services.widgets.update(id) { $0.options.goals.removeAll { $0.id == goal.id } } } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove Goal")
                        .accessibilityLabel("Remove Goal")
                    }
                }
                Button("Add Goal") {
                    services.widgets.update(id) { $0.options.goals.append(DailyGoal(title: "Stretch", symbol: "figure.mind.and.body", unit: "min", target: 10)) }
                }
                .disabled(instance.options.goals.count >= 5)
            } header: {
                Text("Goals")
            } footer: {
                Text("Click a goal on the widget to count it; right-click to take one back. Progress starts again each morning.")
            }
        }
    }

    private func field<Value>(_ goalID: UUID, _ keyPath: WritableKeyPath<DailyGoal, Value>, _ fallback: Value) -> Binding<Value> {
        Binding(
            get: { services.widgets.instance(id)?.options.goals.first { $0.id == goalID }?[keyPath: keyPath] ?? fallback },
            set: { value in services.widgets.update(id) { widget in
                guard let index = widget.options.goals.firstIndex(where: { $0.id == goalID }) else { return }
                widget.options.goals[index][keyPath: keyPath] = value
            } }
        )
    }
}

private struct HabitsEditor: View {
    let id: UUID
    let services: AppServices

    var body: some View {
        if let instance = services.widgets.instance(id) {
            Section {
                ForEach(instance.options.habits) { habit in
                    HStack(spacing: 8) {
                        SymbolMenu(selection: field(habit.id, \.symbol, habit.symbol))
                        TextField("Habit", text: field(habit.id, \.title, habit.title))
                        Text("\(habit.streak(until: .now))-day streak").font(.caption).foregroundStyle(.secondary)
                        Button { services.widgets.update(id) { $0.options.habits.removeAll { $0.id == habit.id } } } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove Habit")
                        .accessibilityLabel("Remove Habit")
                    }
                }
                Button("Add Habit") {
                    services.widgets.update(id) { $0.options.habits.append(Habit(title: "Drink water", symbol: "drop.fill")) }
                }
                .disabled(instance.options.habits.count >= 7)
            } header: {
                Text("Habits")
            } footer: {
                Text("Click today's square on the widget to tick a habit off.")
            }
        }
    }

    private func field<Value>(_ habitID: UUID, _ keyPath: WritableKeyPath<Habit, Value>, _ fallback: Value) -> Binding<Value> {
        Binding(
            get: { services.widgets.instance(id)?.options.habits.first { $0.id == habitID }?[keyPath: keyPath] ?? fallback },
            set: { value in services.widgets.update(id) { widget in
                guard let index = widget.options.habits.firstIndex(where: { $0.id == habitID }) else { return }
                widget.options.habits[index][keyPath: keyPath] = value
            } }
        )
    }
}

private struct SymbolMenu: View {
    @Binding var selection: String

    var body: some View {
        Menu {
            ForEach(lifeSymbols, id: \.self) { symbol in
                Button { selection = symbol } label: { Label(symbol, systemImage: symbol) }
            }
        } label: {
            Image(systemName: selection)
        }
        .help("Symbol")
        .accessibilityLabel("Symbol")
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

private struct GitHubEditor: View {
    let id: UUID
    let services: AppServices

    @State private var token = ""
    @State private var hasToken = GitHubKeychain.token != nil
    @State private var tokenProblem: String?

    var body: some View {
        if let instance = services.widgets.instance(id) {
            let config = instance.options.github
            Section {
                Picker("Shows", selection: binding(\.mode, config.mode)) {
                    ForEach(GitHubMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                if !config.mode.needsRepository {
                    TextField("GitHub username", text: binding(\.user, config.user))
                }
                if config.mode.needsRepository || config.mode == .pullRequests || config.mode == .issues {
                    TextField(config.mode.needsRepository ? "Repository (owner/name)" : "Repository (optional, owner/name)",
                              text: binding(\.repository, config.repository))
                }
                if let error = services.github.error(config) {
                    Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                }
            } header: {
                Text("GitHub")
            } footer: {
                Text("Public data works without signing in (60 requests an hour, cached so widgets rarely need more).")
            }
            Section {
                if hasToken {
                    LabeledContent("Personal access token") {
                        Button("Remove") {
                            GitHubKeychain.setToken(nil)
                            services.github.purgeCache()
                            hasToken = GitHubKeychain.token != nil
                        }
                    }
                } else {
                    SecureField("Personal access token (optional)", text: $token)
                        .onSubmit(saveToken)
                    Button("Save Token", action: saveToken).disabled(token.isEmpty)
                    if let tokenProblem {
                        Text(tokenProblem).foregroundStyle(.red)
                    }
                }
            } footer: {
                Text("A token raises the limit to 5,000 an hour. It's kept in your keychain, and a read-only public token is enough.")
            }
        }
    }

    private func saveToken() {
        guard !token.isEmpty else { return }
        let saved = GitHubKeychain.setToken(token)
        if saved { services.github.purgeCache() }
        hasToken = GitHubKeychain.token != nil
        tokenProblem = saved ? nil : "Couldn't save the token in your keychain. The previous one, if any, is unchanged."
        if saved { token = "" }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<GitHubConfig, Value>, _ fallback: Value) -> Binding<Value> {
        Binding(
            get: { services.widgets.instance(id)?.options.github[keyPath: keyPath] ?? fallback },
            set: { value in services.widgets.update(id) { $0.options.github[keyPath: keyPath] = value } }
        )
    }
}

private struct EndpointsEditor: View {
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
private struct OptionalColorRow: View {
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
private struct StickerShapePicker: View {
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
private struct ShortcutsEditor: View {
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
