import AllSetCore
import AppKit
import SwiftUI

/// The notch's Tray: files parked on the shelf, and what was copied recently.
struct TrayTab: View {
    let services: AppServices

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ShelfPane(shelf: services.shelf)
                .frame(width: 330)
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 4)
            RecentClipboardPane(services: services)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct ShelfPane: View {
    let shelf: ShelfStore
    @State private var isTargeted = false
    @State private var pdfStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Shelf", systemImage: "tray.fill")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let pdfStatus {
                    Text(pdfStatus)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.charging)
                        .lineLimit(1)
                        .transition(.opacity)
                }
                if !shelf.items.isEmpty {
                    if ShelfActions.canMakePDF(shelf) {
                        Button {
                            Task {
                                let status = await ShelfActions.makePDF(shelf)
                                withMotion(Motion.standard) { pdfStatus = status }
                                try? await Task.sleep(for: .seconds(3))
                                withMotion(Motion.standard) { pdfStatus = nil }
                            }
                        } label: {
                            Image(systemName: "doc.richtext")
                        }
                        .help("Make one PDF from the pictures and PDFs here")
                    }
                    Button {
                        ShelfActions.airDrop(shelf.items.map(\.url))
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("AirDrop everything")
                    Button {
                        withMotion(Motion.standard) { shelf.clear() }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Clear the shelf")
                }
            }
            .buttonStyle(NotchIconButtonStyle())
            .font(.system(size: 11, weight: .semibold))

            Group {
                if shelf.items.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(isTargeted ? 0.9 : 0.5))
                            .symbolEffect(.bounce, value: isTargeted)
                        Text("Drop files here to keep them handy")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(isTargeted ? 0.6 : 0.2), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(shelf.items) { item in
                                ShelfTile(item: item, shelf: shelf)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(isTargeted ? 0.12 : 0.05)))
                }
            }
            .frame(height: 118)
            .motion(Motion.quick, value: isTargeted)
        }
        .onDrop(of: ShelfDrop.types, isTargeted: $isTargeted) { providers in
            ShelfDrop.accept(providers, into: shelf)
        }
    }
}

/// A file on the shelf: drag it out anywhere, or right-click for more.
struct ShelfTile: View {
    let item: ShelfItem
    let shelf: ShelfStore
    var iconSize: CGFloat = 48

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 5) {
            Image(nsImage: AppIconCache.icon(forPath: item.url.path))
                .resizable()
                .frame(width: iconSize, height: iconSize)
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: iconSize + 26)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10).fill(.primary.opacity(isHovering ? 0.1 : 0)))
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button {
                    withMotion(Motion.standard) { shelf.remove(item.id) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Remove from the shelf")
                .accessibilityLabel("Remove \(item.name) from the shelf")
                .offset(x: 4, y: -4)
            }
        }
        .onHover { isHovering = $0 }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider(object: item.url as NSURL) }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(item.url) }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(item.url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Button("AirDrop") { ShelfActions.airDrop([item.url]) }
            Divider()
            Button("Remove from Shelf") { shelf.remove(item.id) }
        }
        .help(item.url.path)
    }
}

enum ShelfActions {
    @MainActor
    static func airDrop(_ urls: [URL]) {
        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: urls)
    }

    @MainActor
    static func canMakePDF(_ shelf: ShelfStore) -> Bool {
        shelf.items.contains { PDFMaker.canInclude($0.url) }
    }

    /// Combines the shelf's pictures and PDFs, in shelf order, into a new PDF
    /// in Downloads, which joins the shelf. Returns what happened, briefly.
    @MainActor
    static func makePDF(_ shelf: ShelfStore) async -> String {
        let urls = shelf.items.map(\.url).filter(PDFMaker.canInclude)
        let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let destination = PDFMaker.destination(in: folder)
        let result = await Task.detached { () -> Result<Int, Error> in
            Result { try PDFMaker.make(from: urls, to: destination) }
        }.value
        switch result {
        case .success(let pages):
            shelf.add([destination])
            return pages == 1 ? "PDF saved to Downloads" : "\(pages)-page PDF in Downloads"
        case .failure(let error):
            return (error as? PDFMaker.Failure)?.description ?? error.localizedDescription
        }
    }
}

private struct RecentClipboardPane: View {
    let services: AppServices
    @State private var confirmation: String?

    var body: some View {
        let items = Array(services.clipboard.search("").prefix(4))
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Clipboard", systemImage: "doc.on.clipboard.fill")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let confirmation {
                    Text(confirmation)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.charging)
                        .transition(.opacity)
                } else if let shortcut = services.clipboard.settings.pickerShortcut {
                    Text("\(shortcut.display) for all")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            if items.isEmpty {
                Text(services.clipboard.settings.isEnabled ? "Things you copy show up here." : "Clipboard history is off.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 2) {
                    ForEach(items) { item in
                        ClipboardRow(item: item, services: services, compact: true)
                            .contentShape(Rectangle())
                            .onTapGesture { use(item) }
                            .help("Click to paste")
                    }
                }
            }
        }
        .motion(Motion.quick, value: confirmation)
    }

    private func use(_ item: ClipboardItem) {
        services.clipboardMonitor.paste(item)
        confirmation = services.clipboard.settings.pasteOnSelect && Accessibility.isTrusted ? "Pasted" : "Copied"
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            confirmation = nil
        }
    }
}
