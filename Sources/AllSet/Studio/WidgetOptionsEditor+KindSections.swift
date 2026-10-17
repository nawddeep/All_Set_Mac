import AllSetCore
import AppKit
import SwiftUI

/// The options each kind of widget has of its own.
extension WidgetOptionsEditor {
    @ViewBuilder
    func kindSections(_ instance: WidgetInstance) -> some View {
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
}
