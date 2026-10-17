import AllSetCore
import AppKit
import SwiftUI

/// Thumbnails of a photo widget's pictures, each removable.
struct ImageStrip: View {
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
struct TextStylePicker: View {
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

struct TimeZonePicker: View {
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
struct TintPicker: View {
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

struct CalendarAccessRow: View {
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

struct CitySearch: View {
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
let lifeSymbols = ["drop.fill", "figure.walk", "figure.run", "book.fill", "leaf.fill", "moon.zzz.fill", "pencil.line",
                           "dumbbell.fill", "fork.knife", "cup.and.saucer.fill", "brain.head.profile", "heart.fill", "pills.fill",
                           "music.note", "paintbrush.fill", "laptopcomputer", "sun.max.fill", "bed.double.fill", "figure.mind.and.body"]

struct GoalsEditor: View {
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

struct HabitsEditor: View {
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

struct SymbolMenu: View {
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

struct GitHubEditor: View {
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
