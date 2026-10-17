import CoreGraphics
import Foundation

/// Settings for every kind of widget. Each kind reads only its own fields.
public struct WidgetOptions: Codable, Equatable, Sendable {
    public var clockFace: ClockFace = .digital
    public var use24Hour = false
    public var showSeconds = false
    /// The scenic clock offered by the cinematic Widgets studio.
    public var cinematicClock = false
    public var cinematicStyle = false
    /// Nil for the Mac's own time zone.
    public var timeZoneID: String?
    public var location: WeatherLocation?
    public var showEvents = true
    public var noteText = ""
    public var noteColor: NoteColor = .yellow
    // Photo
    public var images: [ImageSource] = []
    /// Seconds between photos; 0 shows only the first.
    public var slideshowInterval: Double = 0
    public var photoFilter: PhotoFilter = .none
    public var photoFrame: PhotoFrame = .fullBleed
    public var caption = ""
    // Art backgrounds and Live Scenes
    public var art = ArtPiece(style: .blobs, palette: .sunset)
    public var animateArt = true
    public var artSpeed = 1.0
    public var sceneOverlay: SceneOverlay = .time
    // Quote, Live Scene text, Countdown
    public var quoteSource: QuoteSource = .affirmations
    public var customText = ""
    public var textStyle: TextStyle = .classic
    public var countdownTitle = "Something good"
    public var countdownDate: Date?
    // Photo and mesh backgrounds
    /// The photo behind a widget with the Photo background.
    public var background: ImageSource?
    /// 0...1: from sharp to dreamily soft.
    public var backgroundBlur = 0.0
    /// Lock Screen: the photo's subject stands in front of the time.
    public var depthEffect = true
    // Theme colors
    /// Text color on the card; nil for black or white, whichever reads.
    public var ink: WidgetColor?
    /// Highlight color; nil for the tint (or the art's own accent).
    public var accent: WidgetColor?
    // To-Do
    public var listTitle = "to-do"
    public var showDone = true
    // Focus Timer and Stopwatch
    public var focusMinutes = 25.0
    public var breakMinutes = 5.0
    public var focus = FocusSession()
    public var stopwatch = StopwatchState()
    // Shortcuts
    public var shortcuts: [ShortcutItem] = ShortcutItem.starters
    /// Words under each icon.
    public var showLabels = true
    // Sticker
    public var sticker: StickerShape = .star
    public var stickerFinish: StickerFinish = .soft
    /// Emoji or a word to show instead of the shape.
    public var stickerText = ""
    /// Degrees; stickers look best a little crooked.
    public var stickerTilt = 0.0
    /// Neon Sign: now and then the tubes stutter.
    public var neonFlicker = true
    // Theme engine
    /// A `DesignTheme` id. When set, it draws the card, colors and type, and
    /// `material`, `tint` and `ink` are ignored.
    public var designTheme: String?
    public var appearance: WidgetAppearance = .auto
    /// 0 as the theme designs it, up to 1 for as see-through as it allows.
    public var transparency = 0.0
    public var refresh: RefreshPolicy = .balanced
    /// How much the theme's accent follows the wallpaper; nil for the theme's own choice.
    public var accentMode: WallpaperAdaptation?
    // System Metric
    public var metric: SystemMetric = .cpu
    // World clock
    public var worldZones: [String] = ["America/New_York", "Europe/London", "Asia/Tokyo"]
    // Daily Goals and Habit Tracker
    public var goals: [DailyGoal] = DailyGoal.starters
    /// The day the goals' progress belongs to ("2026-09-25"); older progress reads as zero.
    public var goalsDay = ""
    public var habits: [Habit] = Habit.starters
    // Reading Progress
    public var book = ReadingBook()
    // Developer
    public var github = GitHubConfig()
    public var endpoints: [StatusEndpoint] = StatusEndpoint.starters
    // Football and music
    public var player = PlayerDetails()
    public var match = MatchDetails()
    public var ticket = TicketDetails()
    public var milestone = MilestoneDetails()
    public var visualizer: VisualizerStyle = .bars
    public var wordArt: WordArtFinish = .chrome
    public var charm: CharmShape = .heart
    public var zodiac: ZodiacSign = .leo
    // Text and shape, for every widget
    /// This widget's own typeface; nil follows the desktop's (or its design theme's).
    public var font: WidgetFont?
    /// This widget's own corner roundness; nil follows the desktop's.
    public var cornerRadius: Double?
    public var textCase: WidgetTextCase = .asWritten
    /// The widget's built-in words renamed: its own text → what to show instead.
    public var renamedText: [String: String] = [:]
    /// A line of the person's own under the widget.
    public var footnote = ""
    public var footnoteStyle = FootnoteStyle()

    public init() {}

    /// What to show for one of the widget's built-in words.
    public func text(_ original: String) -> String {
        guard let renamed = renamedText[original], !renamed.trimmingCharacters(in: .whitespaces).isEmpty else { return original }
        return renamed
    }

    // Missing keys fall back to defaults, so saved layouts survive new options.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = WidgetOptions()
        clockFace = (try? container.decodeIfPresent(ClockFace.self, forKey: .clockFace)) ?? defaults.clockFace
        use24Hour = (try? container.decodeIfPresent(Bool.self, forKey: .use24Hour)) ?? defaults.use24Hour
        showSeconds = (try? container.decodeIfPresent(Bool.self, forKey: .showSeconds)) ?? defaults.showSeconds
        cinematicClock = (try? container.decodeIfPresent(Bool.self, forKey: .cinematicClock)) ?? defaults.cinematicClock
        cinematicStyle = (try? container.decodeIfPresent(Bool.self, forKey: .cinematicStyle)) ?? defaults.cinematicStyle
        timeZoneID = try? container.decodeIfPresent(String.self, forKey: .timeZoneID)
        location = try? container.decodeIfPresent(WeatherLocation.self, forKey: .location)
        showEvents = (try? container.decodeIfPresent(Bool.self, forKey: .showEvents)) ?? defaults.showEvents
        noteText = (try? container.decodeIfPresent(String.self, forKey: .noteText)) ?? defaults.noteText
        noteColor = (try? container.decodeIfPresent(NoteColor.self, forKey: .noteColor)) ?? defaults.noteColor
        images = (try? container.decodeIfPresent(LossyList<ImageSource>.self, forKey: .images))?.elements ?? defaults.images
        slideshowInterval = (try? container.decodeIfPresent(Double.self, forKey: .slideshowInterval)) ?? defaults.slideshowInterval
        photoFilter = (try? container.decodeIfPresent(PhotoFilter.self, forKey: .photoFilter)) ?? defaults.photoFilter
        photoFrame = (try? container.decodeIfPresent(PhotoFrame.self, forKey: .photoFrame)) ?? defaults.photoFrame
        caption = (try? container.decodeIfPresent(String.self, forKey: .caption)) ?? defaults.caption
        art = (try? container.decodeIfPresent(ArtPiece.self, forKey: .art)) ?? defaults.art
        animateArt = (try? container.decodeIfPresent(Bool.self, forKey: .animateArt)) ?? defaults.animateArt
        artSpeed = (try? container.decodeIfPresent(Double.self, forKey: .artSpeed)) ?? defaults.artSpeed
        sceneOverlay = (try? container.decodeIfPresent(SceneOverlay.self, forKey: .sceneOverlay)) ?? defaults.sceneOverlay
        quoteSource = (try? container.decodeIfPresent(QuoteSource.self, forKey: .quoteSource)) ?? defaults.quoteSource
        customText = (try? container.decodeIfPresent(String.self, forKey: .customText)) ?? defaults.customText
        textStyle = (try? container.decodeIfPresent(TextStyle.self, forKey: .textStyle)) ?? defaults.textStyle
        countdownTitle = (try? container.decodeIfPresent(String.self, forKey: .countdownTitle)) ?? defaults.countdownTitle
        countdownDate = try? container.decodeIfPresent(Date.self, forKey: .countdownDate)
        background = try? container.decodeIfPresent(ImageSource.self, forKey: .background)
        backgroundBlur = (try? container.decodeIfPresent(Double.self, forKey: .backgroundBlur)) ?? defaults.backgroundBlur
        depthEffect = (try? container.decodeIfPresent(Bool.self, forKey: .depthEffect)) ?? defaults.depthEffect
        ink = try? container.decodeIfPresent(WidgetColor.self, forKey: .ink)
        accent = try? container.decodeIfPresent(WidgetColor.self, forKey: .accent)
        listTitle = (try? container.decodeIfPresent(String.self, forKey: .listTitle)) ?? defaults.listTitle
        showDone = (try? container.decodeIfPresent(Bool.self, forKey: .showDone)) ?? defaults.showDone
        focusMinutes = (try? container.decodeIfPresent(Double.self, forKey: .focusMinutes)) ?? defaults.focusMinutes
        breakMinutes = (try? container.decodeIfPresent(Double.self, forKey: .breakMinutes)) ?? defaults.breakMinutes
        focus = (try? container.decodeIfPresent(FocusSession.self, forKey: .focus)) ?? defaults.focus
        stopwatch = (try? container.decodeIfPresent(StopwatchState.self, forKey: .stopwatch)) ?? defaults.stopwatch
        shortcuts = (try? container.decodeIfPresent(LossyList<ShortcutItem>.self, forKey: .shortcuts))?.elements ?? defaults.shortcuts
        showLabels = (try? container.decodeIfPresent(Bool.self, forKey: .showLabels)) ?? defaults.showLabels
        sticker = (try? container.decodeIfPresent(StickerShape.self, forKey: .sticker)) ?? defaults.sticker
        stickerFinish = (try? container.decodeIfPresent(StickerFinish.self, forKey: .stickerFinish)) ?? defaults.stickerFinish
        stickerText = (try? container.decodeIfPresent(String.self, forKey: .stickerText)) ?? defaults.stickerText
        stickerTilt = (try? container.decodeIfPresent(Double.self, forKey: .stickerTilt)) ?? defaults.stickerTilt
        neonFlicker = (try? container.decodeIfPresent(Bool.self, forKey: .neonFlicker)) ?? defaults.neonFlicker
        designTheme = try? container.decodeIfPresent(String.self, forKey: .designTheme)
        appearance = (try? container.decodeIfPresent(WidgetAppearance.self, forKey: .appearance)) ?? defaults.appearance
        transparency = (try? container.decodeIfPresent(Double.self, forKey: .transparency)) ?? defaults.transparency
        refresh = (try? container.decodeIfPresent(RefreshPolicy.self, forKey: .refresh)) ?? defaults.refresh
        accentMode = try? container.decodeIfPresent(WallpaperAdaptation.self, forKey: .accentMode)
        metric = (try? container.decodeIfPresent(SystemMetric.self, forKey: .metric)) ?? defaults.metric
        worldZones = (try? container.decodeIfPresent([String].self, forKey: .worldZones)) ?? defaults.worldZones
        goals = (try? container.decodeIfPresent(LossyList<DailyGoal>.self, forKey: .goals))?.elements ?? defaults.goals
        goalsDay = (try? container.decodeIfPresent(String.self, forKey: .goalsDay)) ?? defaults.goalsDay
        habits = (try? container.decodeIfPresent(LossyList<Habit>.self, forKey: .habits))?.elements ?? defaults.habits
        book = (try? container.decodeIfPresent(ReadingBook.self, forKey: .book)) ?? defaults.book
        github = (try? container.decodeIfPresent(GitHubConfig.self, forKey: .github)) ?? defaults.github
        endpoints = (try? container.decodeIfPresent(LossyList<StatusEndpoint>.self, forKey: .endpoints))?.elements ?? defaults.endpoints
        player = (try? container.decodeIfPresent(PlayerDetails.self, forKey: .player)) ?? defaults.player
        match = (try? container.decodeIfPresent(MatchDetails.self, forKey: .match)) ?? defaults.match
        ticket = (try? container.decodeIfPresent(TicketDetails.self, forKey: .ticket)) ?? defaults.ticket
        milestone = (try? container.decodeIfPresent(MilestoneDetails.self, forKey: .milestone)) ?? defaults.milestone
        visualizer = (try? container.decodeIfPresent(VisualizerStyle.self, forKey: .visualizer)) ?? defaults.visualizer
        wordArt = (try? container.decodeIfPresent(WordArtFinish.self, forKey: .wordArt)) ?? defaults.wordArt
        charm = (try? container.decodeIfPresent(CharmShape.self, forKey: .charm)) ?? defaults.charm
        zodiac = (try? container.decodeIfPresent(ZodiacSign.self, forKey: .zodiac)) ?? defaults.zodiac
        font = try? container.decodeIfPresent(WidgetFont.self, forKey: .font)
        cornerRadius = try? container.decodeIfPresent(Double.self, forKey: .cornerRadius)
        textCase = (try? container.decodeIfPresent(WidgetTextCase.self, forKey: .textCase)) ?? defaults.textCase
        renamedText = (try? container.decodeIfPresent([String: String].self, forKey: .renamedText)) ?? defaults.renamedText
        footnote = (try? container.decodeIfPresent(String.self, forKey: .footnote)) ?? defaults.footnote
        footnoteStyle = (try? container.decodeIfPresent(FootnoteStyle.self, forKey: .footnoteStyle)) ?? defaults.footnoteStyle
    }
}

/// How a widget's words are cased.
public enum WidgetTextCase: String, Codable, CaseIterable, Identifiable, Sendable {
    case asWritten, uppercase, lowercase

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .asWritten: "As Written"
        case .uppercase: "UPPERCASE"
        case .lowercase: "lowercase"
        }
    }
}

/// How the line under a widget looks.
public struct FootnoteStyle: Codable, Equatable, Sendable {
    public enum Size: String, Codable, CaseIterable, Identifiable, Sendable {
        case small, medium, large
        public var id: String { rawValue }
        public var title: String { rawValue.capitalized }
        public var points: Double {
            switch self {
            case .small: 10
            case .medium: 11.5
            case .large: 13
            }
        }
    }

    public enum Alignment: String, Codable, CaseIterable, Identifiable, Sendable {
        case leading, center, trailing
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .leading: "Left"
            case .center: "Center"
            case .trailing: "Right"
            }
        }
    }

    public var size: Size = .medium
    public var alignment: Alignment = .center
    public var bold = true
    /// Nil is white with a soft shadow, readable on most wallpapers.
    public var color: WidgetColor?
    /// Nil follows the widget's own font.
    public var font: WidgetFont?

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = FootnoteStyle()
        size = (try? container.decodeIfPresent(Size.self, forKey: .size)) ?? defaults.size
        alignment = (try? container.decodeIfPresent(Alignment.self, forKey: .alignment)) ?? defaults.alignment
        bold = (try? container.decodeIfPresent(Bool.self, forKey: .bold)) ?? defaults.bold
        color = try? container.decodeIfPresent(WidgetColor.self, forKey: .color)
        font = try? container.decodeIfPresent(WidgetFont.self, forKey: .font)
    }
}

public struct WidgetInstance: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var kind: WidgetKind
    public var size: WidgetSize
    public var material: WidgetMaterial
    public var tint: WidgetColor
    /// The display it's on: its stable id, which decides (see `DisplayIdentity`),
    /// and its name, the fallback for layouts saved before ids and for older
    /// versions. Widgets whose display is disconnected show on the primary
    /// screen until it's back.
    public var screenID: String?
    public var screenName: String?
    /// Top-left corner, measured from the top-left of the screen's visible area.
    public var offset: CGPoint
    public var options: WidgetOptions
    /// How much larger or smaller than its size's own dimensions it's drawn,
    /// from dragging its corner on the desktop. Its layout stays the one that
    /// size was designed with; 1 for a widget never resized.
    public var scale: Double
    /// Height relative to width once scaled: 1 keeps the layout's own shape,
    /// other values stretch it taller or shorter (a free-form resize).
    public var stretch: Double

    public static let scaleRange: ClosedRange<Double> = 0.4...3
    public static let stretchRange: ClosedRange<Double> = 0.1...6

    /// What it covers on the desktop, in layout points.
    public var footprint: CGSize {
        CGSize(width: size.dimensions.width * scale, height: size.dimensions.height * scale * stretch)
    }

    public init(kind: WidgetKind, size: WidgetSize? = nil, screenName: String? = nil, offset: CGPoint = .zero) {
        id = UUID()
        self.kind = kind
        self.size = size ?? kind.defaultSize
        tint = WidgetColor.presets[0]
        self.screenName = screenName
        self.offset = offset
        options = WidgetOptions()
        scale = 1
        stretch = 1
        // Every kind's own look and starting options: its definition (Widgets/Kinds).
        material = .glass
        WidgetKindDefinition.of(kind).defaults(&self)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(WidgetKind.self, forKey: .kind)
        size = (try? container.decode(WidgetSize.self, forKey: .size)) ?? kind.defaultSize
        material = (try? container.decode(WidgetMaterial.self, forKey: .material)) ?? .glass
        tint = (try? container.decode(WidgetColor.self, forKey: .tint)) ?? WidgetColor.presets[0]
        screenID = try? container.decodeIfPresent(String.self, forKey: .screenID)
        screenName = try? container.decodeIfPresent(String.self, forKey: .screenName)
        offset = (try? container.decode(CGPoint.self, forKey: .offset)) ?? .zero
        options = (try? container.decode(WidgetOptions.self, forKey: .options)) ?? WidgetOptions()
        // Layouts saved before resizing existed have none: their own size.
        let saved = (try? container.decodeIfPresent(Double.self, forKey: .scale)) ?? 1
        scale = saved.isFinite ? min(max(saved, Self.scaleRange.lowerBound), Self.scaleRange.upperBound) : 1
        let stretched = (try? container.decodeIfPresent(Double.self, forKey: .stretch)) ?? 1
        stretch = stretched.isFinite ? min(max(stretched, Self.stretchRange.lowerBound), Self.stretchRange.upperBound) : 1
    }
}

/// Placement math, in the coordinates `WidgetInstance.offset` uses: origin at
/// the top-left of the screen's visible area, y growing downward.
public enum WidgetLayout {
    /// Gap between widgets, as on macOS.
    public static let spacing: CGFloat = 16
    /// Distance from the edges of the visible area.
    public static let margin: CGFloat = 8
    public static let grid: CGFloat = 8

    /// Keeps a widget of `size` fully inside `bounds`, without moving it otherwise.
    public static func clamp(_ offset: CGPoint, size: CGSize, within bounds: CGSize) -> CGPoint {
        CGPoint(x: min(max(offset.x, 0), max(bounds.width - size.width, 0)),
                y: min(max(offset.y, 0), max(bounds.height - size.height, 0)))
    }

    /// Widgets moved and sized so their arrangement fills `bounds` (inside the
    /// margins, as far as `range` allows) and sits centered, keeping every gap
    /// in proportion. Offsets stay in layout points; `scale` is how much larger
    /// than that to draw everything (position and size alike).
    public static func fitted(_ widgets: [WidgetInstance], in bounds: CGSize,
                              range: ClosedRange<Double>) -> (widgets: [WidgetInstance], scale: Double) {
        guard let first = widgets.first else { return (widgets, 1) }
        let box = widgets.dropFirst().reduce(CGRect(origin: first.offset, size: first.footprint)) {
            $0.union(CGRect(origin: $1.offset, size: $1.footprint))
        }
        guard box.width > 0, box.height > 0 else { return (widgets, 1) }
        let fits = Double(min((bounds.width - 2 * margin) / box.width, (bounds.height - 2 * margin) / box.height))
        let scale = min(max(fits, range.lowerBound), range.upperBound)
        // Centered on screen, in screen points; then back into layout points.
        let factor = CGFloat(scale)
        let origin = CGPoint(x: max((bounds.width - box.width * factor) / 2, 0) / factor,
                             y: max((bounds.height - box.height * factor) / 2, 0) / factor)
        let moved = widgets.map { widget in
            var widget = widget
            widget.offset = CGPoint(x: widget.offset.x - box.minX + origin.x, y: widget.offset.y - box.minY + origin.y)
            return widget
        }
        return (moved, scale)
    }

    /// Rounds to the grid and keeps the widget fully inside `bounds`.
    public static func snap(_ offset: CGPoint, size: CGSize, within bounds: CGSize) -> CGPoint {
        func place(_ value: CGFloat, length: CGFloat, limit: CGFloat) -> CGFloat {
            let snapped = (value / grid).rounded() * grid
            return min(max(snapped, 0), max(limit - length, 0))
        }
        return CGPoint(x: place(offset.x, length: size.width, limit: bounds.width),
                       y: place(offset.y, length: size.height, limit: bounds.height))
    }

    /// The first spot that keeps `spacing` clear of every occupied rect,
    /// filling columns from the left as macOS does, which keeps widgets away
    /// from desktop icons in the top-right. Falls back to the top-left corner.
    public static func freeOffset(for size: CGSize, avoiding occupied: [CGRect], within bounds: CGSize) -> CGPoint {
        let clearance = spacing - 0.5
        var x = margin
        while x + size.width <= bounds.width - margin {
            var y = margin
            while y + size.height <= bounds.height - margin {
                let candidate = CGRect(origin: CGPoint(x: x, y: y), size: size)
                if !occupied.contains(where: { $0.insetBy(dx: -clearance, dy: -clearance).intersects(candidate) }) {
                    return candidate.origin
                }
                y += grid
            }
            x += grid
        }
        return CGPoint(x: margin, y: margin)
    }

    /// What a new user sees: a clock with a calendar and system stats below it.
    public static func starterSet(screenName: String?) -> [WidgetInstance] {
        let medium = WidgetSize.medium.dimensions
        let small = WidgetSize.small.dimensions
        let secondRow = margin + medium.height + spacing
        return [
            WidgetInstance(kind: .clock, size: .medium, screenName: screenName,
                           offset: CGPoint(x: margin, y: margin)),
            WidgetInstance(kind: .calendar, size: .small, screenName: screenName,
                           offset: CGPoint(x: margin, y: secondRow)),
            WidgetInstance(kind: .system, size: .small, screenName: screenName,
                           offset: CGPoint(x: margin + small.width + spacing, y: secondRow)),
        ]
    }
}

/// What a System Metric widget shows.
public enum SystemMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    case cpu, memory, disk, storage, network, wifi, battery, batteryHealth, uptime, status

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .disk: "Disk Activity"
        case .storage: "Storage"
        case .network: "Network"
        case .wifi: "Wi-Fi"
        case .battery: "Battery"
        case .batteryHealth: "Battery Health"
        case .uptime: "Uptime"
        case .status: "System Status"
        }
    }

    public var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .disk: "internaldrive"
        case .storage: "externaldrive.fill"
        case .network: "arrow.up.arrow.down"
        case .wifi: "wifi"
        case .battery: "battery.75percent"
        case .batteryHealth: "heart.text.square"
        case .uptime: "clock.arrow.circlepath"
        case .status: "checkmark.shield"
        }
    }
}

/// One of a few counts to reach today: glasses of water, pages, minutes.
public struct DailyGoal: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var symbol: String
    public var unit: String
    public var target: Int
    public var progress: Int

    public init(id: UUID = UUID(), title: String, symbol: String, unit: String, target: Int, progress: Int = 0) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.unit = unit
        self.target = target
        self.progress = progress
    }

    public var fraction: Double { target > 0 ? min(Double(progress) / Double(target), 1) : 0 }

    /// Fixed ids, so default options always compare equal.
    public static let starters: [DailyGoal] = [
        ("Water", "drop.fill", "glasses", 8), ("Move", "figure.walk", "min", 30), ("Read", "book.fill", "pages", 20),
    ].enumerated().map { index, goal in
        DailyGoal(id: UUID(uuidString: String(format: "60A10000-0000-4000-8000-%012d", index))!,
                  title: goal.0, symbol: goal.1, unit: goal.2, target: goal.3)
    }
}
