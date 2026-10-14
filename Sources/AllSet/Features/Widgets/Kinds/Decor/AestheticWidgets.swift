import AllSetCore
import AppKit
import SwiftUI

extension TextStyle {
    func font(size: CGFloat) -> Font {
        switch self {
        case .classic: .system(size: size, weight: .regular, design: .serif).italic()
        case .modern: .custom("Futura", size: size)
        case .bold: .system(size: size, weight: .heavy)
        case .elegant: .custom("Didot", size: size)
        case .script: .custom("Snell Roundhand", size: size * 1.25)
        case .handwritten: .custom("Bradley Hand", size: size * 1.1)
        case .typewriter: .custom("American Typewriter", size: size * 0.95)
        case .poster: .system(size: size * 1.2, weight: .black).width(.compressed)
        case .chunky: .system(size: size * 1.05, weight: .black, design: .serif)
        case .editorial: .system(size: size * 0.72, weight: .regular, design: .serif)
        case .gothic: .custom("Luminari", size: size * 1.05)
        case .luxe: .custom("Bodoni 72", size: size * 0.9)
        }
    }
}

extension TextStyle {
    /// Styles set in a named typeface rather than the system font.
    var usesTypeface: Bool {
        switch self {
        case .modern, .elegant, .script, .handwritten, .typewriter, .gothic, .luxe: true
        case .classic, .bold, .poster, .chunky, .editorial: false
        }
    }
}

extension View {
    /// Sets text in a style, with the capitals and letter spacing some styles need.
    func textStyle(_ style: TextStyle, size: CGFloat) -> some View {
        font(style.font(size: size))
            .tracking(style == .editorial || style == .luxe ? size * 0.14 : style == .poster ? -size * 0.01 : 0)
            .textCase(style.isUppercased ? .uppercase : nil)
            .modifier(Typeface(isNamed: style.usesTypeface))
    }

    /// A named typeface, kept even inside widgets: their `fontDesign`
    /// (Rounded, Serif…) otherwise swaps every custom font for the system one.
    func typeface(_ name: String, size: CGFloat) -> some View {
        font(.custom(name, size: size)).fontDesign(nil)
    }
}

private struct Typeface: ViewModifier {
    let isNamed: Bool

    func body(content: Content) -> some View {
        if isNamed {
            content.fontDesign(nil)
        } else {
            content
        }
    }
}

// MARK: Photo

struct PhotoWidget: View {
    let instance: WidgetInstance
    let library: ImageLibrary

    private var options: WidgetOptions { instance.options }

    var body: some View {
        let sources = options.images.isEmpty ? [ImageSource.art(options.art)] : options.images
        let interval = options.slideshowInterval
        WidgetTimeline(.periodic(from: .now, by: interval > 0 ? interval : 3600)) { context in
            let index = interval > 0 ? Int(context.date.timeIntervalSince1970 / interval) % sources.count : 0
            Group {
                if options.photoFrame == .collage {
                    collage(sources, shift: index)
                } else if options.photoFrame == .filmStrip {
                    filmStrip(sources, shift: index)
                } else {
                    framed(sources[index])
                }
            }
            .id(index)
            .transition(.opacity)
            .motion(Motion.gentle, value: index)
        }
    }

    @ViewBuilder
    private func framed(_ source: ImageSource) -> some View {
        let photo = PhotoContent(source: source, filter: options.photoFilter, tint: Color(instance.tint),
                                 animated: options.animateArt, library: library, maxPixels: 768)
        switch options.photoFrame {
        case .fullBleed:
            photo.overlay(alignment: .bottomLeading) {
                if !options.caption.isEmpty {
                    Text(options.caption)
                        .textStyle(options.textStyle, size: instance.size == .small ? 14 : 17)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 6, y: 1)
                        .lineLimit(2)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom))
                }
            }
        case .polaroid:
            VStack(spacing: 0) {
                photo
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .padding([.top, .horizontal], 10)
                Text(options.caption)
                    .typeface("Bradley Hand", size: instance.size == .small ? 14 : 17)
                    .foregroundStyle(.black.opacity(0.75))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: instance.size == .small ? 30 : 38)
            }
            .background(Color(white: 0.97))
        case .inset:
            VStack(spacing: 8) {
                photo.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                if !options.caption.isEmpty {
                    Text(options.caption)
                        .textStyle(options.textStyle, size: 13)
                        .lineLimit(1)
                }
            }
            .padding(10)
        case .collage, .filmStrip:
            // Handled in `body`, which lays out several pictures.
            photo
        }
    }

    /// Frames on a strip of film, with sprocket holes and edge numbers:
    /// small one frame, medium three, large two strips of two.
    private func filmStrip(_ sources: [ImageSource], shift: Int) -> some View {
        let (frames, strips) = switch instance.size {
        case .small: (1, 1)
        case .medium: (3, 1)
        case .large, .extraLarge: (2, 2)
        }
        return VStack(spacing: 10) {
            ForEach(0..<strips, id: \.self) { strip in
                VStack(spacing: 3) {
                    Sprockets()
                    HStack(spacing: 5) {
                        ForEach(0..<frames, id: \.self) { frame in
                            let index = strip * frames + frame + shift
                            PhotoContent(source: sources[index % sources.count], filter: options.photoFilter, tint: Color(instance.tint),
                                         animated: false, library: library, maxPixels: 512)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                    }
                    .padding(.horizontal, 6)
                    HStack {
                        ForEach(0..<frames, id: \.self) { frame in
                            Text("\(strip * frames + frame + 12)  \u{25B8}  \(strip * frames + frame + 12)A")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 1, green: 0.62, blue: 0.2).opacity(0.85))
                    Sprockets()
                }
                .padding(.vertical, 4)
                .background(Color(white: 0.07))
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(white: 0.04))
        .environment(\.colorScheme, .dark)
    }

    /// A mosaic: small 2×2, medium 3×2, large 3×3, filled round-robin.
    private func collage(_ sources: [ImageSource], shift: Int) -> some View {
        let (columns, rows) = switch instance.size {
        case .small: (2, 2)
        case .medium: (3, 2)
        case .large, .extraLarge: (3, 3)
        }
        return Grid(horizontalSpacing: 5, verticalSpacing: 5) {
            ForEach(0..<rows, id: \.self) { row in
                GridRow {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = (row * columns + column + shift) % sources.count
                        PhotoContent(source: sources[index], filter: options.photoFilter, tint: Color(instance.tint),
                                     animated: false, library: library, maxPixels: 384)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                }
            }
        }
        .padding(7)
    }
}

/// A row of film's sprocket holes.
private struct Sprockets: View {
    var body: some View {
        Canvas { context, size in
            let hole = CGSize(width: 5, height: 4)
            var x: CGFloat = 3
            while x + hole.width < size.width {
                context.fill(Path(roundedRect: CGRect(origin: CGPoint(x: x, y: (size.height - hole.height) / 2), size: hole), cornerRadius: 1),
                             with: .color(Color(white: 0.78)))
                x += 11
            }
        }
        .frame(height: 6)
    }
}

/// One image, loaded lazily and run through the chosen filter.
struct PhotoContent: View {
    let source: ImageSource
    let filter: PhotoFilter
    let tint: Color
    let animated: Bool
    let library: ImageLibrary
    /// The most pixels it will be shown at, when that's small: it then loads
    /// a small copy instead of holding the whole photo in memory.
    var maxPixels: Int?

    @State private var image: NSImage?

    init(source: ImageSource, filter: PhotoFilter, tint: Color, animated: Bool, library: ImageLibrary, maxPixels: Int? = nil) {
        self.source = source
        self.filter = filter
        self.tint = tint
        self.animated = animated
        self.library = library
        self.maxPixels = maxPixels
        // Already loaded: show it now instead of fading it in again.
        _image = State(initialValue: library.cachedImage(for: source, maxPixels: maxPixels))
    }

    var body: some View {
        ZStack {
            switch source {
            case .art(let piece):
                ArtView(piece: piece, animated: animated)
            case .web, .file, .bundled:
                if let image {
                    // Filling inside an overlay keeps the photo's own (larger)
                    // size out of layout; otherwise it spills past the widget.
                    Color.clear
                        .overlay {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .transition(.opacity)
                } else {
                    Rectangle()
                        .fill(.primary.opacity(0.06))
                        .overlay(ProgressView().controlSize(.small))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .photoFilter(filter, tint: tint)
        .motion(Motion.gentle, value: image)
        .task(id: source) {
            let loaded = if let maxPixels {
                await library.image(for: source, maxPixels: maxPixels)
            } else {
                await library.image(for: source)
            }
            if loaded !== image { image = loaded }
        }
    }
}

extension View {
    @ViewBuilder
    func photoFilter(_ filter: PhotoFilter, tint: Color) -> some View {
        switch filter {
        case .none:
            self
        case .mono:
            grayscale(1)
        case .noir:
            grayscale(1).contrast(1.35).brightness(-0.04)
        case .warm:
            colorMultiply(Color(red: 1, green: 0.9, blue: 0.78)).saturation(1.15)
        case .cool:
            colorMultiply(Color(red: 0.84, green: 0.93, blue: 1)).saturation(0.95)
        case .vintage:
            saturation(0.55).contrast(0.9).colorMultiply(Color(red: 1, green: 0.9, blue: 0.74))
                .overlay(Color(red: 0.45, green: 0.25, blue: 0.05).opacity(0.08))
        case .fade:
            saturation(0.75).contrast(0.85).overlay(Color.white.opacity(0.14))
        case .dreamy:
            saturation(1.25).brightness(0.04).blur(radius: 0.8)
                .overlay(RadialGradient(colors: [.white.opacity(0.18), .clear], center: .top, startRadius: 0, endRadius: 300))
        case .duotone:
            grayscale(1).contrast(1.2)
                .overlay(Rectangle().fill(LinearGradient(colors: [tint, Color(red: 1, green: 0.45, blue: 0.55)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing)).blendMode(.color))
        }
    }
}

// MARK: Live Scene

/// The art comes from the widget's "Art" background; this adds what floats on top.
struct AmbientWidget: View {
    let instance: WidgetInstance

    private var options: WidgetOptions { instance.options }
    private var large: Bool { instance.size != .small }

    var body: some View {
        WidgetTimeline(.everyMinute) { context in
            overlay(context.date)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 2)
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func overlay(_ date: Date) -> some View {
        switch options.sceneOverlay {
        case .none:
            Color.clear
        case .time:
            VStack(spacing: 2) {
                Text(WidgetDateFormat.string(date, format: options.use24Hour ? "HH:mm" : "h:mm"))
                    .font(.system(size: large ? 68 : 44, weight: .thin))
                    .monospacedDigit()
                Text(WidgetDateFormat.string(date, template: "EEEEdMMMM"))
                    .font(.system(size: large ? 14 : 11, weight: .medium))
                    .opacity(0.85)
            }
        case .date:
            VStack(spacing: 0) {
                Text(WidgetDateFormat.string(date, template: "EEEE").uppercased())
                    .font(.system(size: large ? 13 : 11, weight: .bold))
                    .tracking(2)
                Text(WidgetDateFormat.string(date, template: "d"))
                    .font(.system(size: large ? 80 : 56, weight: .ultraLight))
                Text(WidgetDateFormat.string(date, template: "MMMM"))
                    .font(.system(size: large ? 14 : 11, weight: .medium))
                    .opacity(0.85)
            }
        case .text:
            Text(options.customText.isEmpty ? Affirmations.line(at: date) : options.customText)
                .textStyle(options.textStyle, size: large ? 26 : 18)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
        }
    }
}

// MARK: Quote

struct QuoteWidget: View {
    let instance: WidgetInstance
    @Environment(\.widgetAccent) private var accent

    private var options: WidgetOptions { instance.options }

    var body: some View {
        WidgetTimeline(.everyMinute) { context in
            let text = options.quoteSource == .custom && !options.customText.isEmpty
                ? options.customText
                : Affirmations.line(at: context.date)
            let size: CGFloat = switch instance.size {
            case .small: 17
            case .medium: 23
            case .large, .extraLarge: 32
            }
            Group {
                switch options.textStyle {
                case .poster: poster(text, size: size)
                case .chunky, .editorial: plain(text, size: size)
                default: quoted(text, size: size)
                }
            }
            .motion(Motion.gentle, value: text)
            .padding(instance.size == .small ? 16 : 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func quoted(_ text: String, size: CGFloat) -> some View {
        VStack(spacing: size * 0.5) {
            kicker(size: size)
            // A word or a name isn't a quotation.
            if options.quoteSource != .custom || text.count > 24 {
                Image(systemName: "quote.opening")
                    .font(.system(size: size * 0.7, weight: .bold))
                .foregroundStyle(accent)
            }
            Text(text)
                .textStyle(options.textStyle, size: size)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .minimumScaleFactor(0.45)
                .contentTransition(.opacity)
        }
    }

    /// No quote marks: the words are the design.
    private func plain(_ text: String, size: CGFloat) -> some View {
        let editorial = options.textStyle == .editorial
        return VStack(alignment: editorial ? .center : .leading, spacing: size * 0.4) {
            kicker(size: size)
            Text(text)
                .textStyle(options.textStyle, size: editorial ? size : size * 1.25)
                .multilineTextAlignment(editorial ? .center : .leading)
                .lineSpacing(editorial ? size * 0.35 : -size * 0.1)
                .minimumScaleFactor(0.4)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: editorial ? .center : .leading)
    }

    /// "Daily Reminder / GOOD THINGS / are coming.": the first line huge,
    /// the rest in a quiet italic.
    private func poster(_ text: String, size: CGFloat) -> some View {
        let lines = text.split(separator: "\n", maxSplits: 1).map(String.init)
        let (headline, tail) = lines.count > 1
            ? (lines[0], lines[1])
            : Self.splitForPoster(text)
        return VStack(spacing: size * 0.08) {
            kicker(size: size)
            Text(headline)
                .textStyle(.poster, size: size * 1.9)
                .lineSpacing(-size * 0.5)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.3)
            if let tail, !tail.isEmpty {
                Text(tail)
                    .font(.system(size: size * 0.95, weight: .regular, design: .serif).italic())
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    @ViewBuilder
    private func kicker(size: CGFloat) -> some View {
        if !options.caption.isEmpty {
            Text(options.caption)
                .font(.system(size: max(size * 0.5, 11), weight: .regular, design: .serif).italic())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    /// Without a line break, the last word or two become the quiet tail:
    /// "Good things are coming." → "GOOD THINGS" / "are coming."
    static func splitForPoster(_ text: String) -> (String, String?) {
        let words = text.split(separator: " ")
        guard words.count >= 3 else { return (text, nil) }
        let tailCount = words.count >= 5 ? 2 : 1
        let tailStart = words.count - tailCount
        // Keep small linking words ("are", "is", "the") with the tail.
        let linking: Set<String> = ["are", "is", "the", "a", "to", "you", "your", "of", "in", "and", "be"]
        var start = tailStart
        if start > 1, linking.contains(words[start - 1].lowercased()) { start -= 1 }
        return (words[..<start].joined(separator: " "), words[start...].joined(separator: " "))
    }
}

// MARK: Countdown

struct CountdownWidget: View {
    let instance: WidgetInstance
    @Environment(\.widgetAccent) private var accent

    private var options: WidgetOptions { instance.options }

    var body: some View {
        WidgetTimeline(.everyMinute) { context in
            let calendar = Calendar.current
            let target = options.countdownDate ?? context.date
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: context.date),
                                               to: calendar.startOfDay(for: target)).day ?? 0
            let numberSize: CGFloat = instance.size == .small ? 58 : 80

            VStack(alignment: .leading, spacing: 0) {
                Text(options.countdownTitle.isEmpty ? "Countdown" : options.countdownTitle)
                    .textStyle(options.textStyle, size: instance.size == .small ? 15 : 19)
                    .foregroundStyle(accent)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if days == 0 {
                    WidgetWord("Today!")
                        .font(.system(size: numberSize * 0.6, weight: .bold, design: .rounded))
                } else {
                    Text("\(abs(days))")
                        .font(.system(size: numberSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(days > 0 ? (days == 1 ? "day to go" : "days to go") : (days == -1 ? "day ago" : "days ago"))
                        .font(.system(size: 13, weight: .semibold))
                        .opacity(0.85)
                }
                Text(WidgetDateFormat.string(target, template: "EEEdMMMMy"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(18)
        }
    }
}
