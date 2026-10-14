import AllSetCore
import SwiftUI

extension AppServices {
    /// The light a theme casts in the Themes hero: the one chosen for it, or
    /// one worked out from its look and, once its backdrop picture is in,
    /// the color of its wallpaper.
    func lighting(of set: ThemeSet) -> ThemeAccent {
        set.lighting(wallpaper: themePreviews.wallpaperColors[set.id])
    }
}

/// Which themes the Themes page's atmosphere is showing. Two slots: the one
/// out of view takes the incoming theme, then the two swap, so one theme's
/// light fades in over the other's and only their opacities ever animate.
@MainActor
@Observable
final class ThemeAtmosphereState {
    private(set) var first: ThemeSet?
    private(set) var second: ThemeSet?
    /// Which slot is in view.
    private(set) var showsSecond = false

    var current: ThemeSet? { showsSecond ? second : first }

    func show(_ set: ThemeSet, animation: Animation?) {
        guard current?.id != set.id else { return }
        // The page opening: nothing to fade from.
        guard current != nil else {
            first = set
            return
        }
        if showsSecond { first = set } else { second = set }
        withAnimation(animation) { showsSecond.toggle() }
    }
}

/// The light of the Themes page: the canvas, lit from behind the selected
/// card in that theme's own colors, with its wallpaper blurred to a haze
/// over it, darker toward the edges, and all of it gone into the window's
/// own backdrop by the time the page has scrolled `height` down.
///
/// Every layer is still: gradients, and pictures made ahead of time
/// (`ThemePreviewVariant.backdrop`, already blurred and faded). A new theme
/// arrives as a change of opacity between the two slots, nothing more.
/// The page draws this twice with the same numbers: once behind the top of
/// its content, scrolling with it, and once more, cut to the navigation's
/// height and held still under it, so what scrolls beneath the navigation
/// stays out of sight while its backdrop is still this light.
struct ThemeAtmosphere: View {
    let state: ThemeAtmosphereState
    let services: AppServices
    /// How far down the middle of the selected card is, from this view's top.
    let focusY: CGFloat
    /// The hero panel's size: the light is scaled to it.
    let panel: CGSize

    /// How far down the page it reaches.
    static let height: CGFloat = 900

    var body: some View {
        GeometryReader { geometry in
            let focus = CGPoint(x: geometry.size.width / 2, y: focusY)
            ZStack(alignment: .topLeading) {
                base(focus)
                slot(state.first, focus).opacity(state.showsSecond ? 0 : 1)
                slot(state.second, focus).opacity(state.showsSecond ? 1 : 0)
                if let vignette = Self.vignette {
                    Image(decorative: vignette, scale: 1).resizable().interpolation(.high)
                }
                // Darker under the navigation, for its words.
                LinearGradient(colors: [.black.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: max(focusY * 0.6, 1))
            }
        }
        .frame(height: Self.height, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The canvas, solid over the hero and fading out below it: the deep
    /// navy every theme's own color is laid on. No light of its own, or a
    /// warm theme's gold would turn to mud over it.
    private func base(_ focus: CGPoint) -> some View {
        LinearGradient(stops: [.init(color: DS.Surface.canvasLift, location: 0),
                               .init(color: DS.Surface.canvas, location: 0.7),
                               .init(color: DS.Surface.canvas.opacity(0), location: 1)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// One theme's light: its wallpaper as haze, its first color pooled
    /// behind the selected card and its second low on the right.
    @ViewBuilder
    private func slot(_ set: ThemeSet?, _ focus: CGPoint) -> some View {
        if let set {
            let lighting = services.lighting(of: set)
            let picture = services.themePreviews.image(for: set, dark: set.isDark, variant: .backdrop)
            // A wallpaper with no color of its own (a black-and-white photo)
            // would only lay gray over the theme's light: it's kept faint.
            let hasColor = services.themePreviews.wallpaperColors[set.id] != nil
            light(lighting, picture: picture, hasColor: hasColor, focus: focus)
        }
    }

    @ViewBuilder
    private func light(_ light: ThemeAccent, picture: NSImage?, hasColor: Bool, focus: CGPoint) -> some View {
        let glow = light.glowIntensity
        // A white second color is light in the theme's art, but fog as
        // haze on a dark page: half way to the first color instead, so
        // the corner glows in the theme's hue rather than graying.
        let haze = light.secondary.hsvSaturation < 0.12 ? light.secondary.blended(toward: light.primary, by: 0.5) : light.secondary
        ZStack(alignment: .topLeading) {
            if let picture {
                // Stretched to the frame, not cropped: it's a blur, and
                // its own fade has to end where the frame does.
                Image(nsImage: picture).resizable().interpolation(.high)
                    .opacity(hasColor ? 0.24 : 0.09)
                    .transition(.opacity)
            }
            // Pooled behind the selected card, with a long faint skirt
            // that carries the color out across the panel.
            EllipticalGradient(stops: [.init(color: Color(light.primary).opacity(0.38 * glow), location: 0),
                                       .init(color: Color(light.primary).opacity(0.17 * glow), location: 0.38),
                                       .init(color: Color(light.primary).opacity(0.05 * glow), location: 0.72),
                                       .init(color: .clear, location: 1)],
                               center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
                // No taller than fits above the frame's lower edge, so it ends in nothing.
                .frame(width: panel.width * 1.3, height: min(panel.height * 1.7, (Self.height - focus.y - 12) * 2))
                .position(focus)
            EllipticalGradient(colors: [Color(haze).opacity(0.17 * glow), .clear],
                               center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
                .frame(width: panel.width * 0.8, height: panel.height * 0.9)
                .position(x: focus.x + panel.width * 0.32, y: focus.y + panel.height * 0.3)
        }
    }

    /// Black toward the left, right and top edges, clear in the middle and
    /// fading out toward the bottom: drawn once, small, and stretched.
    private static let vignette: CGImage? = {
        let width = 256, height = 160
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        func smooth(_ from: Double, _ to: Double, _ value: Double) -> Double {
            let t = min(max((value - from) / (to - from), 0), 1)
            return t * t * (3 - 2 * t)
        }
        for y in 0..<height {
            for x in 0..<width {
                let u = (Double(x) + 0.5) / Double(width), v = (Double(y) + 0.5) / Double(height)
                // An ellipse around the hero's middle, a little above the frame's own.
                let away = ((u - 0.5) / 0.5) * ((u - 0.5) / 0.5) + ((v - 0.36) / 0.62) * ((v - 0.36) / 0.62)
                let alpha = 0.45 * smooth(0.42, 1.1, away.squareRoot()) * (1 - smooth(0.6, 0.98, v))
                pixels[(y * width + x) * 4 + 3] = UInt8((alpha * 255).rounded())
            }
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
                       decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }()
}
