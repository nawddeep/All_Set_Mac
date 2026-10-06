import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite struct ThemeCarouselLayoutTests {
    private static let viewports = [CGSize(width: 900, height: 463), CGSize(width: 1120, height: 623),
                                    CGSize(width: 1400, height: 763), CGSize(width: 1728, height: 943)]
    private static func layout(_ viewport: CGSize) -> ThemeCarouselLayout {
        ThemeCarouselLayout(viewport: viewport, margin: viewport.width < 1000 ? 24 : 32, chrome: 128, footer: 104)
    }

    @Test func spotlightFitsTheWindowAndLeavesBrowsingInSight() {
        for viewport in Self.viewports {
            let layout = Self.layout(viewport)
            #expect(layout.cardSize.width <= layout.panelSize.width * 0.4)
            #expect(layout.cardSize.height > 150)
            #expect(layout.panelSize.height < viewport.height - 100)
            #expect(layout.cardSize.height + 100 <= layout.panelSize.height)
            #expect(layout.cardSize.width / layout.cardSize.height > 1.4)
            #expect(layout.size(at: 1).width / layout.size(at: 1).height < 0.8)
        }
    }

    @Test func adjacentCardsKeepTheirLabelsClearDuringASwipe() {
        for viewport in Self.viewports {
            let layout = Self.layout(viewport)
            for flat in [false, true] {
                for tick in 0...40 {
                    let position = CGFloat(tick) / 40
                    func edge(_ distance: CGFloat, sign: CGFloat) -> CGFloat {
                        let depth = ThemeCarouselDepth(distance: distance, flat: flat)
                        let half = layout.size(at: distance).width * depth.scale / 2 * cos(depth.tilt * .pi / 180)
                        return layout.offset(at: distance, flat: flat) + half * sign
                    }
                    #expect(edge(-position, sign: 1) <= edge(1 - position, sign: -1),
                            "\(viewport), position \(position), flat \(flat)")
                }
            }
        }
    }

    @Test func fiveCardsAreVisibleInAWideWindow() {
        let layout = Self.layout(CGSize(width: 1400, height: 763))
        let outer = layout.offset(at: 2) + layout.size(at: 2).width * ThemeCarouselDepth(distance: 2).scale / 2
        #expect(outer <= layout.panelSize.width / 2)
        #expect(layout.offset(at: 1) > layout.cardSize.width / 2)
    }

    @Test func cardsWidenContinuouslyAndTheRowIsSymmetric() {
        let layout = Self.layout(Self.viewports[2])
        var lastSize = layout.size(at: 0), lastOffset: CGFloat = 0
        for tick in 1...100 {
            let distance = CGFloat(tick) / 50
            let size = layout.size(at: distance), offset = layout.offset(at: distance)
            #expect(size.width <= lastSize.width)
            #expect(abs(size.width - lastSize.width) < 10)
            #expect(offset > lastOffset && offset - lastOffset < 10)
            #expect(layout.offset(at: -distance) == -offset)
            #expect(layout.size(at: -distance) == size)
            lastSize = size
            lastOffset = offset
        }
        #expect(layout.step() == layout.offset(at: 1))
    }

    @Test func sideCardsRemainLegibleAndDepthChangesContinuously() {
        let center = ThemeCarouselDepth(distance: 0), outer = ThemeCarouselDepth(distance: 2)
        #expect(center.scale == 1 && center.glow == 1 && center.dim == 0 && center.tilt == 0)
        #expect(outer.scale >= 0.8 && outer.dim <= 0.25 && outer.opacity == 1)
        #expect(ThemeCarouselDepth(distance: 2.5).opacity == 0)
        var previous = center
        for tick in 1...80 {
            let depth = ThemeCarouselDepth(distance: CGFloat(tick) / 20)
            #expect(depth.scale <= previous.scale && depth.dim >= previous.dim)
            #expect(depth.opacity <= previous.opacity && depth.dip >= previous.dip)
            #expect(abs(depth.scale - previous.scale) <= 0.01)
            #expect(abs(depth.opacity - previous.opacity) <= 0.100001)
            #expect(abs(depth.tilt - previous.tilt) <= 1)
            previous = depth
        }
    }

    @Test func reduceMotionKeepsTheContentAndFlattensPerspective() {
        for distance in [CGFloat(-2), -0.4, 0, 1, 1.7, 3] {
            let turned = ThemeCarouselDepth(distance: distance), flat = ThemeCarouselDepth(distance: distance, flat: true)
            #expect(flat.tilt == 0)
            #expect(flat.scale == turned.scale && flat.dim == turned.dim && flat.opacity == turned.opacity)
            #expect(flat.dip == turned.dip && flat.glow == turned.glow)
        }
        #expect(ThemeCarouselDepth(distance: 1, reach: 1).opacity == 1)
        #expect(ThemeCarouselDepth(distance: 1.25, reach: 1).opacity == 0.5)
        #expect(ThemeCarouselDepth(distance: 2, reach: 1).opacity == 0)
    }
}

@Suite struct ThemeCardArtTests {
    private typealias Widget = (kind: WidgetKind, size: WidgetSize)

    private static let football: [Widget] = [
        (.jersey, .large), (.wordArt, .medium), (.clock, .small), (.photo, .small), (.playerCard, .large), (.milestone, .medium),
        (.scoreboard, .medium), (.photo, .medium), (.quote, .medium), (.focus, .medium), (.calendar, .small), (.photo, .small),
    ]

    private static func frame(_ piece: ThemeCardArt.Piece, _ widgets: [Widget]) -> CGRect {
        let size = widgets[piece.widget].size.dimensions
        return CGRect(x: piece.origin.x, y: piece.origin.y, width: size.width * piece.scale, height: size.height * piece.scale)
    }

    @Test func theCanvasIsTheCardsShape() {
        #expect(ThemeCardArt.canvas.width / ThemeCardArt.canvas.height == ThemeCarouselLayout.sideAspect)
    }

    @Test func picksTheWordTheFirstLargeWidgetAndSmallOnesOfDifferentKinds() throws {
        let picks = try #require(ThemeCardArt.picks(from: Self.football))
        #expect(picks.title == 1)
        #expect(picks.hero == 0)
        // A clock, a photo and a calendar before the second photo.
        #expect(picks.flankers == [2, 3, 10, 11])
    }

    @Test func makesDoWithWhatAThemeHas() throws {
        // No word art, nothing large: the first medium leads.
        let quiet: [Widget] = [(.photo, .small), (.nowPlaying, .medium), (.battery, .small), (.photo, .medium)]
        let picks = try #require(ThemeCardArt.picks(from: quiet))
        #expect(picks.title == nil)
        #expect(picks.hero == 1)
        #expect(picks.flankers == [0, 2])
        // One widget is still a card; none isn't.
        #expect(ThemeCardArt.picks(from: [(.wordArt, .medium)])?.hero == 0)
        #expect(ThemeCardArt.picks(from: [(.wordArt, .medium)])?.title == nil)
        #expect(ThemeCardArt.picks(from: []) == nil)
    }

    @Test func piecesSitInTheUpperPartWithoutCoveringEachOther() throws {
        for widgets in [Self.football, Array(Self.football.dropFirst(2))] {
            let picks = try #require(ThemeCardArt.picks(from: widgets))
            let pieces = ThemeCardArt.pieces(picks, sizes: widgets.map(\.size))
            let expected: Int = picks.flankers.count + (picks.title == nil ? 1 : 2)
            #expect(pieces.count == expected)
            let frames = pieces.map { Self.frame($0, widgets) }
            for frame in frames {
                #expect(CGRect(origin: .zero, size: ThemeCardArt.canvas).contains(frame))
                // The lower quarter stays clear for metadata over the portrait.
                #expect(frame.maxY <= ThemeCardArt.canvas.height * 0.75)
            }
            for (index, frame) in frames.enumerated() {
                for other in frames.dropFirst(index + 1) { #expect(!frame.intersects(other)) }
            }
            // Back to front: the small ones, the hero, then the word above it.
            let hero = try #require(pieces.firstIndex { $0.widget == picks.hero })
            #expect(hero == picks.flankers.count)
            #expect(abs(frames[hero].midX - ThemeCardArt.canvas.width / 2) < 0.001)
            if let title = picks.title {
                #expect(pieces.last?.widget == title)
                #expect(frames[frames.count - 1].maxY <= frames[hero].minY)
            }
        }
    }

    @Test func picksPastTheEndOfTheLayoutAreLeftOut() {
        let pieces = ThemeCardArt.pieces(ThemeCardArt.Picks(hero: 0, title: 9, flankers: [1, 7]), sizes: [.large, .small])
        #expect(pieces.map(\.widget) == [1, 0])
    }

    @Test func handPickedCardsPointAtWidgetsTheirThemesHave() throws {
        for (id, picks) in ThemeCardArt.curated {
            let set = try #require(ThemeLibrary.set(id), "\(id)")
            let widgets = set.widgets(screenName: nil, bounds: CGSize(width: 1136, height: 768))
            var used: [Int] = [picks.hero] + picks.flankers
            if let title = picks.title { used.append(title) }
            for widget in used {
                #expect(widgets.indices.contains(widget), "\(id) has no widget \(widget)")
            }
            #expect(Set(used).count == used.count, "\(id) uses a widget twice")
        }
    }
}

@Suite struct ThemeAccentTests {
    private static func saturation(_ color: WidgetColor) -> Double {
        let brightest = max(color.red, color.green, color.blue)
        return brightest == 0 ? 0 : (brightest - min(color.red, color.green, color.blue)) / brightest
    }

    @Test func aLightChosenForTheThemeWins() throws {
        // Seven's look has a gold accent; its light is neon crimson over that gold.
        let seven = try #require(ThemeLibrary.set("setup.seven"))
        #expect(seven.accent?.primary == WidgetColor(hex: 0xFF2D4A))
        #expect(seven.lighting() == ThemeAccent(primary: WidgetColor(hex: 0xFF2D4A), secondary: WidgetColor(hex: 0xFFB347)))
        #expect(seven.setup?.accent == WidgetColor(hex: 0xE8C15A))
        // Whatever its wallpaper measures as.
        #expect(seven.lighting(wallpaper: WidgetColor(hex: 0x00FF00)) == seven.lighting())
    }

    @Test func everyLightChosenByHandIsForAThemeThatExists() {
        for id in ThemeLibrary.accents.keys {
            #expect(ThemeLibrary.set("setup.\(id)")?.accent != nil, "\(id)")
        }
        // The black-and-white themes that can lead the carousel each have one.
        for id in ["leopardNoir", "cityNoir", "angelic", "hypnotic", "afterDark"] {
            #expect(ThemeLibrary.accents[id] != nil, "\(id)")
        }
    }

    @Test func otherwiseTheLooksOwnAccentBrightEnoughToGlow() throws {
        // Deep crimson, lifted; its second accent is the same red, so the haze is that red paled.
        let crimson = try #require(ThemeLibrary.set("setup.crimsonNights"))
        #expect(crimson.accent == nil)
        let light = crimson.lighting()
        #expect(abs(max(light.primary.red, light.primary.green, light.primary.blue) - 0.94) < 0.001)
        #expect(light.primary.red > light.primary.blue && light.primary.blue > light.primary.green)
        #expect(light.secondary.green > light.primary.green)
        // Magenta with a cyan second accent: two colors, both kept.
        let neon = try #require(ThemeLibrary.set("setup.neonNights")).lighting()
        #expect(neon.primary.red > neon.primary.green)
        #expect(neon.secondary.blue > neon.secondary.red)
    }

    @Test func aLookWithNoColorFallsThroughToItsWallpaperThenGold() throws {
        // White on black and white: nothing in the look to light a panel with.
        let grunge = try #require(ThemeLibrary.set("setup.grunge"))
        #expect(grunge.accent == nil)
        #expect(grunge.lighting() == .neutral)
        // Its wallpaper's color, when that has one.
        let blue = grunge.lighting(wallpaper: WidgetColor(hex: 0x2255AA))
        #expect(blue.primary.blue > blue.primary.red)
        #expect(abs(blue.primary.blue - 0.94) < 0.001)
        // A gray wallpaper is no better than a white accent.
        #expect(grunge.lighting(wallpaper: WidgetColor(hex: 0x808080)) == .neutral)
        #expect(grunge.lighting(wallpaper: WidgetColor(hex: 0x050505)) == .neutral)
    }

    @Test func everyThemeIsLitInAColor() {
        for set in ThemeLibrary.all {
            let light = set.lighting()
            #expect(max(light.primary.red, light.primary.green, light.primary.blue) > 0.3, "\(set.id) is too dark to glow")
            #expect(Self.saturation(light.primary) >= 0.18, "\(set.id) would glow gray")
            #expect((0.6...1).contains(light.glowIntensity), "\(set.id)")
        }
    }

    @Test func brightThemesGlowLess() throws {
        let peach = try #require(ThemeLibrary.set("setup.peachFizz")), seven = try #require(ThemeLibrary.set("setup.seven"))
        #expect(peach.lighting().glowIntensity < seven.lighting().glowIntensity)
        // Out of range is brought back in.
        #expect(ThemeAccent(primary: .init(hex: 0xFF0000), secondary: .init(hex: 0xFF0000), glowIntensity: 0.1).glowIntensity == 0.6)
        // A light theme with no chosen light glows less than a dark one.
        let light = try #require(ThemeLibrary.all.first { $0.accent == nil && !$0.isDark })
        let dark = try #require(ThemeLibrary.all.first { $0.accent == nil && $0.isDark })
        #expect(light.lighting().glowIntensity < dark.lighting().glowIntensity)
    }
}
