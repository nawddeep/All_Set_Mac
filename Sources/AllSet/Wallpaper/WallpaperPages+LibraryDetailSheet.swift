import AllSetCore
import AppKit
import AVFoundation
import SwiftUI

/// A bigger look at one wallpaper, sliding up over the grid: a real
/// preview (fetching it if it isn't local — tapping is deliberate, unlike
/// a hover) plus every detail the tile's small footer has no room for.
struct LibraryDetailSheet: View {
    let video: LibraryVideo
    let store: WallpaperStore
    let images: ImageLibrary
    let deleteActions: WallpaperLibraryTile.DeleteActions
    let onUse: () -> Void
    let onClose: () -> Void

    @State private var thumbnail: NSImage?
    /// A local still, decoded off the main thread at a size the sheet can
    /// use: the original is 3840 px, and drawing it straight from the file
    /// decoded all of it on the main thread as the sheet slid in.
    @State private var still: NSImage?
    @State private var confirmingDelete = false
    @State private var deleteProblem: String?

    var body: some View {
        let isFetching = store.isFetching(video.id)
        let url = store.libraryURL(video.id)
        VStack(spacing: 0) {
            ZStack {
                Rectangle().fill(.quaternary)
                if let thumbnail { Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fill) }
                if let url {
                    if video.kind == .image {
                        if let still { Image(nsImage: still).resizable().aspectRatio(contentMode: .fill) }
                    } else {
                        LoopingVideo(url: url, isPlaying: true)
                    }
                } else if isFetching {
                    VStack(spacing: 10) {
                        ProgressView().controlSize(.large).tint(.white)
                        Button("Cancel Download") { store.cancelFetch(video.id) }
                            .buttonStyle(.bordered)
                    }
                } else if store.cancelledFetches.contains(video.id) {
                    Button("Download Again", systemImage: "arrow.down.circle") {
                        store.allowFetch(video.id)
                        Task { await store.fetchLibraryVideoRetrying(video.id, delays: [.seconds(2)]) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(height: 320)
            .clipped()
            .overlay(alignment: .topTrailing) {
                // Always in view, over the preview, and Esc does the same.
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.55), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.25)))
                }
                .buttonStyle(PressableStyle())
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close the preview (Esc)")
                .help("Close the preview (Esc)")
                .accessibilityLabel("Close preview")
                .padding(12)
            }
            .task(id: url) {
                guard video.kind == .image, let url else { return }
                still = images.cachedThumbnail(at: url, maxPixels: 1600)
                if still == nil { still = await images.thumbnail(at: url, maxPixels: 1600) }
            }
            .task(id: video.id) {
                guard url == nil, let file = store.libraryThumbnailURL(video) else { return }
                if let cached = images.cachedThumbnail(at: file, maxPixels: 1024) {
                    thumbnail = cached
                } else {
                    thumbnail = await images.thumbnail(at: file, maxPixels: 1024)
                }
            }
            .task(id: video.id) {
                guard url == nil, store.config.libraryServerURL != nil else { return }
                // Opening the preview is asking for it, even after a cancel.
                store.allowFetch(video.id)
                await store.fetchLibraryVideoRetrying(video.id, delays: [.seconds(2)])
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title).font(.title2.bold())
                        Text(video.category.title).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], alignment: .leading, spacing: 8) {
                    detail("Resolution", video.resolutionLabel)
                    if let size = video.size { detail("Size", Self.size(size)) }
                    if let duration = video.duration { detail("Length", String(format: "%.0fs", duration)) }
                    if let fps = video.fps { detail("Frame rate", String(format: "%.0f fps", fps)) }
                    detail("Kind", video.kind == .image ? "Still" : "Live")
                }
                if let reason = video.statusReason {
                    Label(reason, systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Button(action: onUse) {
                        Label(store.config.source == .library(video.id) ? "Current" : "Set as Wallpaper", systemImage: "photo.artframe")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.config.source == .library(video.id))
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("Delete…", systemImage: "trash")
                    }
                    Spacer()
                }
            }
            .padding(20)
        }
        .frame(maxWidth: 640)
        .background(DS.Surface.canvasLift, in: RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous).strokeBorder(DS.Surface.hairline))
        .background(CardHalo(spread: .shadow).foregroundStyle(.black).opacity(0.35))
        .padding(24)
        .confirmationDialog("Delete “\(video.title)”?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            if store.canPlay(video) {
                Button("Remove Download") { runDelete(everywhere: false) }
            }
            Button("Delete Everywhere…", role: .destructive) { runDelete(everywhere: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(WallpaperLibraryTile.deleteMessage(downloaded: store.canPlay(video)))
        }
        .alert("Couldn't finish deleting “\(video.title)”", isPresented: .init(get: { deleteProblem != nil }, set: { if !$0 { deleteProblem = nil } })) {
            Button("OK") {}
        } message: {
            Text(deleteProblem ?? "")
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.medium))
        }
    }

    private static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func runDelete(everywhere: Bool) {
        guard everywhere else {
            Task { _ = await deleteActions.removeDownload(); onClose() }
            return
        }
        Task {
            guard await AdminGate.authorize(reason: "delete “\(video.title)” everywhere") else { return }
            switch await deleteActions.deleteEverywhere() {
            case .success, nil: onClose()
            case .notDeleted(let reason):
                    deleteProblem = reason + " Nothing was deleted: it's still on this Mac and in your library. Delete it again once that's fixed."
                case .deletedOnServer(let reason):
                    deleteProblem = "It's gone from your server, but this Mac's copy couldn't be fully removed (" + reason + "). Delete it again to finish."
            }
        }
    }
}

/// Look, motion and energy settings for the live wallpaper.
struct WallpaperOptionsPage: View {
    let services: AppServices

    var body: some View {
        let store = services.wallpaper
        FormPage(eyebrow: "Desktop", title: "Wallpaper Options",
                 subtitle: "How the live wallpaper looks, moves and saves energy.") {
            Section {
                Toggle("Live wallpaper", isOn: binding(\.isEnabled))
                LabeledContent("Dim") {
                    Slider(value: binding(\.dim), in: 0...0.6)
                        .frame(width: 220)
                }
            } footer: {
                Text("Dimming helps desktop icons and widgets stand out.")
            }

            Section("Art") {
                LabeledContent("Speed") {
                    Slider(value: binding(\.speed), in: 0.25...3)
                        .frame(width: 220)
                }
                Picker("Quality", selection: binding(\.sharpArt)) {
                    Text("Balanced: soft styles look the same, much less work").tag(false)
                    Text("Sharp: full resolution").tag(true)
                }
                Picker("Frame rate", selection: binding(\.frameRate)) {
                    Text("15 fps: calm, least energy").tag(15)
                    Text("30 fps: smooth").tag(30)
                    Text("60 fps: silky").tag(60)
                }
            }

            Section("Photos") {
                Picker("Motion", selection: binding(\.motion)) {
                    ForEach(WallpaperMotion.allCases) { motion in
                        Text(motion.title).tag(motion)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("Pause while windows cover the desktop", isOn: binding(\.pauseWhenCovered))
                Toggle("Pause on battery power", isOn: binding(\.pauseOnBattery))
            } header: {
                Text("Energy")
            } footer: {
                Text("The wallpaper always pauses while an app is full screen, when the screen is locked or asleep, and in Low Power Mode.")
            }

            Section {
                Toggle("Match the system wallpaper", isOn: binding(\.matchSystemWallpaper))
            } footer: {
                Text("Sets a still of your live wallpaper as the macOS wallpaper, so Mission Control, Spaces and the lock screen match. Your previous wallpaper comes back when you turn the live wallpaper off.")
            }

            Section {
                Button("Choose a Wallpaper…") { services.openWindow(.wallpaper) }
            }
        }
        .motion(Motion.standard, value: store.config)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<WallpaperConfig, Value>) -> Binding<Value> {
        Binding(get: { services.wallpaper.config[keyPath: keyPath] },
                set: { services.wallpaper.config[keyPath: keyPath] = $0 })
    }
}
