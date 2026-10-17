import AllSetCore
import AppKit
import Observation
import SwiftUI

#if DEBUG

/// Draws widgets to PNG files, for looking at designs without a screen.
@MainActor
enum WidgetRenderHarness {
    /// Each art style drawn by SwiftUI (left) and the GPU (right) at the same moment.
    static func renderGPUArt(to folder: URL) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            try ArtGPU.compileNow()
        } catch {
            print("Shader error: \(error)")
            return
        }
        guard let gpu = ArtGPU.shared else { return }
        // In place: clipped to a widget's corners, and drawn at half size then
        // doubled, as the wallpaper does.
        let piece = ArtPiece(style: .aurora, palette: .aurora)
        let layouts = HStack(spacing: 10) {
            ArtView(piece: piece, animated: true)
                .frame(width: 240, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            ArtView(piece: piece, animated: true)
                .frame(width: 120, height: 75)
                .scaleEffect(2, anchor: .topLeading)
                .frame(width: 240, height: 150, alignment: .topLeading)
                .clipped()
        }
        .padding(10)
        .background(Color.red)
        let layoutHost = NSHostingView(rootView: layouts)
        layoutHost.frame = CGRect(x: 0, y: 0, width: 510, height: 170)
        let layoutWindow = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 510, height: 170),
                                    styleMask: [.borderless], backing: .buffered, defer: false)
        layoutWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
        layoutWindow.isReleasedWhenClosed = false
        layoutWindow.ignoresMouseEvents = true
        layoutWindow.contentView = layoutHost
        layoutWindow.orderFrontRegardless()
        try? await Task.sleep(for: .milliseconds(800))
        if let image = captureOwnWindow(layoutWindow),
           let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            try? png.write(to: folder.appendingPathComponent("layout.png"))
        }
        layoutWindow.close()

        let size = CGSize(width: 300, height: 170)
        let time = 37.0
        let palettes = ArtPalette.allCases
        for (index, style) in ArtStyle.allCases.enumerated() {
            let showcase: [ArtStyle: ArtPalette] = [.stadium: .floodlit, .palms: .americana, .smoke: .rage]
            let piece = ArtPiece(style: style, palette: showcase[style] ?? palettes[index % palettes.count])
            let pair = HStack(spacing: 6) {
                Canvas { context, canvasSize in
                    ArtRenderer.draw(piece, in: context, size: canvasSize, time: time)
                }
                .frame(width: size.width, height: size.height)
                MetalArtView(gpu: gpu, piece: piece, fixedTime: time)
                    .frame(width: size.width, height: size.height)
            }
            .padding(6)
            .background(Color.gray)
            let host = NSHostingView(rootView: pair)
            host.frame = CGRect(x: 0, y: 0, width: size.width * 2 + 18, height: size.height + 12)
            let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: 100, y: 100), size: host.frame.size),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderFrontRegardless()
            try? await Task.sleep(for: .milliseconds(700))
            if let image = captureOwnWindow(window),
               let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try? png.write(to: folder.appendingPathComponent("gpu-\(String(format: "%02d", index))-\(style.rawValue).png"))
            }
            window.close()
        }
    }

    /// Moments of a drifting mesh, drawn from Core Animation's live state, in
    /// a window placed off every screen.
    static func renderDrift(to folder: URL) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let size = CGSize(width: 352, height: 168)
        let host = NSHostingView(rootView: MeshBackground(palette: .aurora, speed: 3)
            .environment(\.widgetIsVisible, true)
            .frame(width: size.width, height: size.height))
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -4000, y: -4000), size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        // And a pointer spinning, to check it turns clockwise and stops in place.
        let arrow = ImageRenderer(content: Image(systemName: "arrow.up").font(.system(size: 60, weight: .bold))
            .foregroundStyle(.white).frame(width: 120, height: 120).background(Color.blue)).cgImage
        let spinner = SpinProbe(image: arrow)
        let spinHost = NSHostingView(rootView: spinner.frame(width: 120, height: 120))
        spinHost.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
        let spinWindow = NSWindow(contentRect: CGRect(x: -4000, y: -3000, width: 120, height: 120),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
        spinWindow.isReleasedWhenClosed = false
        spinWindow.contentView = spinHost
        spinWindow.orderFrontRegardless()
        for index in 0..<6 {
            try? await Task.sleep(for: .seconds(index == 0 ? 1.5 : 1.5))
            if index == 3 { spinner.state.spinning = false }
            if let layer = spinHost.layer?.presentation() ?? spinHost.layer,
               let context = CGContext(data: nil, width: 120, height: 120, bitsPerComponent: 8, bytesPerRow: 0,
                                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                layer.render(in: context)
                if let image = context.makeImage(),
                   let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                    try? png.write(to: folder.appendingPathComponent("spin-\(index).png"))
                }
            }
            guard let layer = host.layer?.presentation() ?? host.layer,
                  let context = CGContext(data: nil, width: Int(size.width) * 2, height: Int(size.height) * 2, bitsPerComponent: 8,
                                          bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
            context.scaleBy(x: 2, y: 2)
            layer.render(in: context)
            guard let image = context.makeImage(),
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: folder.appendingPathComponent("drift-\(index).png"))
        }
        window.close()
        spinWindow.close()

        // The same, as the window server shows them: a window of our own
        // tucked behind the desktop, captured by its number alone.
        spinner.state.spinning = true
        let probe = NSHostingView(rootView: HStack(spacing: 0) {
            SpinProbe(image: arrow, state: spinner.state).frame(width: 120, height: 120)
            RingGauge(fraction: 0.25, color: .orange, lineWidth: 12).frame(width: 120, height: 120)
        }.background(Color.black))
        probe.frame = CGRect(x: 0, y: 0, width: 240, height: 120)
        let shown = NSWindow(contentRect: CGRect(x: 200, y: 200, width: 240, height: 120),
                             styleMask: [.borderless], backing: .buffered, defer: false)
        shown.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
        shown.ignoresMouseEvents = true
        shown.isReleasedWhenClosed = false
        shown.contentView = probe
        shown.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(1))
        for index in 0..<4 {
            if let image = captureOwnWindow(shown),
               let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try? png.write(to: folder.appendingPathComponent("shown-\(index).png"))
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        shown.close()
    }

    @Observable final class SpinState {
        var spinning = true
    }

    private struct SpinProbe: View {
        let image: CGImage?
        var state = SpinState()

        var body: some View {
            SpinningImage(image: image, isSpinning: state.spinning, secondsPerTurn: 2.4)
        }
    }

    static func render(to folder: URL, services: AppServices) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var samples: [(String, WidgetInstance)] = []
        for kind in WidgetKind.allCases {
            for size in kind.supportedSizes {
                samples.append(("\(kind.rawValue)-\(size.rawValue)", WidgetInstance(kind: kind, size: size)))
            }
        }
        for (index, material) in [WidgetMaterial.photo, .mesh, .art, .tinted].enumerated() {
            for kind in [WidgetKind.clock, .calendar, .weather, .quote, .countdown, .system] {
                var instance = WidgetInstance(kind: kind, size: .medium)
                instance.material = material
                instance.options.background = .web(CuratedBackgrounds.suggestion(index * 13 + kind.rawValue.count * 5))
                instance.options.art = ArtPiece(style: .aurora, palette: [.midnight, .sunset, .lavender, .ocean][index])
                samples.append(("look-\(material.rawValue)-\(kind.rawValue)", instance))
            }
        }
        for face in ClockFace.allCases {
            for size in WidgetSize.allCases {
                var instance = WidgetInstance(kind: .clock, size: size)
                instance.options.clockFace = face
                samples.append(("clock-\(face.rawValue)-\(size.rawValue)", instance))
            }
        }
        // Every card style on the new kinds, and each theme's own look.
        for material in [WidgetMaterial.paper, .frosted, .clear] {
            for kind in [WidgetKind.todo, .focus, .stopwatch, .shortcuts, .quote] {
                var instance = WidgetTheme.all[material == .paper ? 0 : 1].styled(WidgetInstance(kind: kind, size: kind == .todo ? .large : .medium))
                instance.material = material
                if material == .clear { instance.options.ink = WidgetColor(red: 1, green: 1, blue: 1) }
                samples.append(("card-\(material.rawValue)-\(kind.rawValue)", instance))
            }
        }
        for finish in StickerFinish.allCases {
            var sticker = WidgetInstance(kind: .sticker, size: .small)
            sticker.options.stickerFinish = finish
            sticker.options.sticker = [.star, .heart, .sparkles, .crown, .spiral][StickerFinish.allCases.firstIndex(of: finish)!]
            samples.append(("sticker-\(finish.rawValue)", sticker))
        }
        for (index, style) in [TextStyle.poster, .chunky, .editorial].enumerated() {
            var quote = WidgetInstance(kind: .quote, size: [.large, .small, .medium][index])
            quote.options.quoteSource = .custom
            quote.options.customText = ["Good things\nare coming.", "it comes in waves", "Success comes from what you do consistently."][index]
            quote.options.caption = index == 0 ? "Daily Reminder" : ""
            quote.options.textStyle = style
            quote = WidgetTheme.goodThings.styled(quote)
            quote.options.textStyle = style
            samples.append(("quote-\(style.rawValue)", quote))
        }
        var collage = WidgetInstance(kind: .photo, size: .large)
        collage.material = .paper
        collage.options.photoFrame = .collage
        collage.options.images = (0..<9).map { .web(CuratedBackgrounds.suggestion($0 * 17)) }
        samples.append(("photo-collage", collage))
        for size in WidgetSize.allCases {
            var strip = WidgetInstance(kind: .photo, size: size)
            strip.options.photoFrame = .filmStrip
            strip.options.photoFilter = .vintage
            strip.options.images = (0..<4).map { .web(CuratedBackgrounds.suggestion($0 * 23 + 5)) }
            samples.append(("photo-strip-\(size.rawValue)", strip))
        }
        for kind in [WidgetKind.clock, .terminal, .dots, .nowPlaying] {
            var outlined = WidgetTheme.vigilante.styled(WidgetInstance(kind: kind, size: .medium))
            outlined.material = .outline
            samples.append(("card-outline-\(kind.rawValue)", outlined))
        }
        // The sky through a midsummer day in Pune.
        var skies: [(String, Date)] = []
        let iso = ISO8601DateFormatter()
        for time in ["05:35", "06:05", "06:40", "09:30", "13:00", "18:40", "19:10", "19:30", "19:50", "23:30"] {
            if let date = iso.date(from: "2025-06-21T\(time):00+05:30") { skies.append((time, date)) }
        }
        // Photos first, so the pictures are there when drawn.
        for (_, instance) in samples {
            for image in instance.options.images { _ = await services.images.image(for: image) }
            let background = instance.options.background ?? .web(CuratedBackgrounds.suggestion(0))
            if instance.material == .photo { _ = await services.images.image(for: background) }
            if instance.kind == .lockScreen {
                _ = await SubjectCutout.cutout(for: background, library: services.images)
            }
        }
        for (name, instance) in samples {
            // Still frames: moving backgrounds are Core Animation layers, which
            // an image renderer can't draw.
            let view = WidgetBody(instance: instance, services: services)
                .environment(\.widgetIsPreview, true)
                .environment(\.widgetIsVisible, false)
                .background(Color(white: 0.2))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: folder.appendingPathComponent("\(name).png"))
        }
        // Each theme's whole setup, as the Themes page shows it.
        for theme in WidgetTheme.all {
            for widget in theme.kitWidgets(screenName: nil, bounds: CGSize(width: 1136, height: 768)) {
                for image in widget.options.images { _ = await services.images.image(for: image) }
            }
            if case .photo(let source) = theme.wallpaper { _ = await services.images.image(for: source) }
            guard let set = ThemeLibrary.set("setup.\(theme.id)") else { continue }
            let view = ThemeComposition(set: set, widgets: ThemeComposition.widgets(for: set, dark: set.isDark, services: services),
                                        services: services, dark: set.isDark)
                .frame(width: 1136, height: 768)
                .environment(\.widgetSnapshot, true)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: folder.appendingPathComponent("theme-\(theme.id).png"))
        }
        for size in WidgetSize.allCases {
            for (time, date) in skies where size == .medium || time == "06:05" || time == "19:10" || time == "23:30" {
                var instance = WidgetInstance(kind: .daylight, size: size)
                instance.options.location = WeatherLocation(name: "Pune", latitude: 18.52, longitude: 73.86)
                let view = WidgetBody(instance: instance, services: services)
                    .environment(\.widgetIsPreview, true)
                    .environment(\.widgetDate, date)
                    .environment(\.timeZone, TimeZone(identifier: "Asia/Kolkata")!)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                guard let image = renderer.cgImage,
                      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { continue }
                try? png.write(to: folder.appendingPathComponent("sky-\(size.rawValue)-\(time.replacingOccurrences(of: ":", with: "")).png"))
            }
        }
    }
}
#endif
