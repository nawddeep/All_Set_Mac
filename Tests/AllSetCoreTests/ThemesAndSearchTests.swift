import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite struct TimerTests {
    let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test func focusSessionRunsPausesAndMovesToABreak() {
        var session = FocusSession()
        #expect(session.remaining(at: start, focusMinutes: 25, breakMinutes: 5) == 1500)
        session.start(at: start, focusMinutes: 25, breakMinutes: 5)
        #expect(session.isRunning)
        #expect(session.remaining(at: start.addingTimeInterval(600), focusMinutes: 25, breakMinutes: 5) == 900)
        session.pause(at: start.addingTimeInterval(600))
        // Paused time doesn't count.
        #expect(session.remaining(at: start.addingTimeInterval(5000), focusMinutes: 25, breakMinutes: 5) == 900)
        session.start(at: start.addingTimeInterval(5000), focusMinutes: 25, breakMinutes: 5)
        #expect(session.progress(at: start.addingTimeInterval(5000), focusMinutes: 25, breakMinutes: 5) == 0.4)
        session.finishPhase()
        #expect(session.isBreak && !session.isRunning && session.completed == 1)
        #expect(session.remaining(at: start, focusMinutes: 25, breakMinutes: 5) == 300)
        session.finishPhase(counting: false)
        #expect(!session.isBreak && session.completed == 1)
        session.reset()
        #expect(session == FocusSession())
        #expect(FocusSession.clock(1500) == "25:00")
        #expect(FocusSession.clock(59.2) == "01:00")
        #expect(FocusSession.clock(3900) == "1:05:00")
    }

    @Test func stopwatchKeepsTimeAcrossStops() {
        var watch = StopwatchState()
        watch.start(at: start)
        watch.lap(at: start.addingTimeInterval(1.5))
        watch.stop(at: start.addingTimeInterval(2.25))
        #expect(watch.elapsed(at: start.addingTimeInterval(100)) == 2.25)
        watch.start(at: start.addingTimeInterval(200))
        #expect(watch.elapsed(at: start.addingTimeInterval(201)) == 3.25)
        #expect(watch.laps == [1.5])
        #expect(StopwatchState.clock(0) == "00:00.00")
        #expect(StopwatchState.clock(83.456) == "01:23.45")
        #expect(StopwatchState.clock(3723.5) == "1:02:03.50")
        watch.reset()
        #expect(!watch.isRunning && watch.elapsed(at: start) == 0)
    }
}

@Suite struct AestheticSearchTests {
    @Test func aestheticsBecomeConcreteSearches() {
        #expect(AestheticSearch.searches(for: "Coquette").first == "pink bow")
        #expect(AestheticSearch.searches(for: "coquette wallpaper") == AestheticSearch.searches(for: "coquette"))
        #expect(AestheticSearch.searches(for: "Lo-Fi") == AestheticSearch.searches(for: "lofi"))
        #expect(AestheticSearch.searches(for: "cottage core").first == "cottage garden")
        #expect(AestheticSearch.searches(for: "Dark Academia aesthetic").first == "library books")
        // Plain searches pass through, minus filler.
        #expect(AestheticSearch.searches(for: "  Neon   city wallpaper ") == ["neon city"])
        #expect(AestheticSearch.searches(for: "mountains") == ["mountains"])
        #expect(AestheticSearch.explanation(for: "mountains") == nil)
        #expect(AestheticSearch.explanation(for: "y2k")?.hasPrefix("butterfly") == true)
    }

    @Test func pagesTakeTurnsThroughSearches() {
        let searches = ["a", "b", "c"]
        #expect(AestheticSearch.request(forPage: 1, of: searches)! == ("a", 1))
        #expect(AestheticSearch.request(forPage: 3, of: searches)! == ("c", 1))
        #expect(AestheticSearch.request(forPage: 4, of: searches)! == ("a", 2))
        #expect(AestheticSearch.request(forPage: 1, of: []) == nil)
    }

    @Test func typosAreFixed() {
        #expect(AestheticSearch.correctedSpelling(of: "mountians") == "mountains")
        #expect(AestheticSearch.correctedSpelling(of: "sunest") == "sunset")
        #expect(AestheticSearch.correctedSpelling(of: "Butterfy garden") == "butterfly garden")
        // Known words, short words and numbers stay.
        #expect(AestheticSearch.correctedSpelling(of: "neon city") == nil)
        #expect(AestheticSearch.correctedSpelling(of: "cat 2024") == nil)
        #expect(AestheticSearch.editDistance("teh", "the", limit: 2) == 1)
        #expect(AestheticSearch.editDistance("kitten", "sitting", limit: 5) == 3)
    }

    @Test func artMatchesFitTheWords() {
        let coquette = AestheticSearch.art(matching: "coquette")
        #expect(!coquette.isEmpty)
        #expect(coquette.first?.palette == .coquette)
        let clouds = AestheticSearch.art(matching: "clouds sky")
        #expect(clouds.first == ArtPiece(style: .clouds, palette: .sky))
        #expect(AestheticSearch.art(matching: "wallpaper").isEmpty)
        #expect(AestheticSearch.art(matching: "zzqx").isEmpty)
    }

    @Test func pacerKeepsUnderTheLimit() {
        var pacer = SearchPacer(limit: 3, window: 60)
        let now = Date(timeIntervalSinceReferenceDate: 0)
        #expect(pacer.delay(at: now) == 0)
        #expect(pacer.delay(at: now) == 0)
        #expect(pacer.delay(at: now.addingTimeInterval(10)) == 0)
        #expect(pacer.delay(at: now.addingTimeInterval(20)) == 40)
        #expect(pacer.delay(at: now.addingTimeInterval(20)) == 40)
        #expect(pacer.delay(at: now.addingTimeInterval(20)) == 50)
        // A burst of seven never puts more than three in any minute.
        #expect(pacer.delay(at: now.addingTimeInterval(20)) == 100)
        #expect(pacer.delay(at: now.addingTimeInterval(200)) == 0)
    }
}

@Suite struct ThemeTests {
    @Test func kitsFitAndDontOverlap() {
        let bounds = CGSize(width: 1136, height: 768)
        for theme in WidgetTheme.all {
            let widgets = theme.kitWidgets(screenName: nil, bounds: bounds)
            #expect(widgets.count == theme.kit.count)
            let rects = widgets.map { CGRect(origin: $0.offset, size: $0.size.dimensions) }
            for rect in rects {
                #expect(CGRect(origin: .zero, size: bounds).contains(rect), "\(theme.id) spills off the screen")
            }
            for (i, a) in rects.enumerated() {
                for b in rects[(i + 1)...] {
                    #expect(!a.insetBy(dx: 1, dy: 1).intersects(b), "\(theme.id) overlaps")
                }
            }
            for widget in widgets {
                #expect(widget.kind.supportedSizes.contains(widget.size), "\(theme.id): \(widget.kind) can't be \(widget.size)")
            }
        }
        #expect(Set(WidgetTheme.all.map(\.id)).count == WidgetTheme.all.count)
    }

    @Test func stylingDressesCardsAndLeavesTheRest() {
        let theme = WidgetTheme.cloudNine
        let clock = theme.styled(WidgetInstance(kind: .clock))
        #expect(clock.material == .paper && clock.tint == theme.card && clock.options.ink == theme.ink)
        var bare = WidgetInstance(kind: .quote)
        bare.material = .clear
        let styledBare = theme.styled(bare)
        #expect(styledBare.material == .clear && styledBare.options.ink == theme.wallpaperInk)
        let vinyl = theme.styled(WidgetInstance(kind: .vinyl))
        #expect(vinyl.material == WidgetInstance(kind: .vinyl).material)
        let shortcuts = theme.styled(WidgetInstance(kind: .shortcuts))
        #expect(shortcuts.options.shortcuts.allSatisfy { $0.symbol == theme.iconSymbol })
        let sticker = WidgetTheme.coquette.styled(WidgetInstance(kind: .sticker))
        #expect(sticker.options.sticker == .heart && sticker.tint == WidgetTheme.coquette.stickerColor)
    }

    @Test func layoutsFromBeforeTheNewOptionsStillLoad() throws {
        let old = #"{"clockFace":"flip","noteText":"hi"}"#
        let options = try JSONDecoder().decode(WidgetOptions.self, from: Data(old.utf8))
        #expect(options.clockFace == .flip && options.noteText == "hi")
        #expect(options.shortcuts.count == ShortcutItem.starters.count)
        #expect(options.focus == FocusSession() && options.ink == nil)
        var widget = WidgetInstance(kind: .focus)
        widget.options.focus.start(at: .now, focusMinutes: 25, breakMinutes: 5)
        widget.options.shortcuts[0].target = "https://example.com"
        let copy = try JSONDecoder().decode(WidgetInstance.self, from: JSONEncoder().encode(widget))
        #expect(copy == widget)
        #expect(copy.options.shortcuts[0].isLink && !copy.options.shortcuts[1].isLink)
    }
}

@Suite struct DarkThemeTests {
    @Test func darkThemesAreDarkAndLightOnesLight() {
        let dark = Set(WidgetTheme.all.filter(\.isDark).map(\.id))
        for id in ["vigilante", "neonNights", "darkAcademia", "midnightLofi", "goth", "goodThings", "diva", "luxeNoir"] {
            #expect(dark.contains(id), "\(id) should count as dark")
        }
        for id in ["cloudNine", "pinkLatte", "coquette"] {
            #expect(!dark.contains(id), "\(id) should count as light")
        }
    }

    @Test func darkCardsUseLightInk() {
        for theme in WidgetTheme.all where theme.isDark && !theme.card.isLight {
            #expect(theme.ink.isLight, "\(theme.id): dark card needs light text")
            #expect(theme.wallpaperInk.luminance > 0.5, "\(theme.id): text on a dark wallpaper needs to be light")
        }
    }

    @Test func neonSignsGlowInTheThemeColor() {
        let theme = WidgetTheme.vigilante
        let neon = theme.kitWidgets(screenName: nil, bounds: CGSize(width: 1136, height: 768)).first { $0.kind == .neon }
        #expect(neon?.material == .clear)
        #expect(neon?.tint == theme.wallpaperAccent)
        #expect(neon?.options.customText == "rise")
        #expect(neon?.options.textStyle == .poster)
    }

    @Test func darkSearchesAreUnderstood() {
        #expect(AestheticSearch.searches(for: "gotham").first == "city night rain")
        #expect(AestheticSearch.searches(for: "dark aesthetic wallpaper").first == "night city")
        #expect(AestheticSearch.art(matching: "batman").first?.style == .skyline)
        #expect(AestheticSearch.art(matching: "embers").first?.style == .embers)
    }
}
