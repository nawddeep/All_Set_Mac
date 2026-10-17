import AllSetCore
import AppKit
import SwiftUI

/// Photos, prints and the football widgets' shirt, card, portrait and match.
extension WidgetOptionsEditor {
    @ViewBuilder
    func photoSections(_ instance: WidgetInstance) -> some View {
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
    func polaroidSections(_ instance: WidgetInstance) -> some View {
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
    func shirtSection(_ instance: WidgetInstance) -> some View {
        Section("Player") {
            TextField("Name on the back", text: binding(\.options.player.name, instance))
            Stepper("Number: \(instance.options.player.number)", value: binding(\.options.player.number, instance), in: 0...99)
            TextField("A line below, like HOME GROWN or SINCE 2003", text: binding(\.options.player.tagline, instance))
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
    func cardSection(_ instance: WidgetInstance) -> some View {
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
    func portraitSection(_ instance: WidgetInstance) -> some View {
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

    func importPortrait() {
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
    func matchSection(_ instance: WidgetInstance) -> some View {
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
}
