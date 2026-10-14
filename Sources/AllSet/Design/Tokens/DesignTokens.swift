import SwiftUI

/// The main window's design language: a dark, calm canvas where content leads
/// and chrome frames it. Every page draws its spacing, corners, type and
/// surfaces from here rather than from literals, so the app reads as one
/// product. (Desktop widgets have their own system: `DesignTheme`.)
enum DS {
    // MARK: Spacing

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        /// Between the sections of a page.
        static let section: CGFloat = 40

        /// The page's side margin: a little tighter in small windows.
        static func pageMargin(for width: CGFloat) -> CGFloat { width < 1000 ? 24 : 32 }

        /// Normal windows retain their measurements. Larger, taller windows
        /// enlarge the main-window UI by at most 25%, retaining room to scroll.
        static func windowScale(for size: CGSize) -> CGFloat {
            min(1.25, max(1, min(size.width / 1280, size.height / 800)))
        }
    }

    // MARK: Corners

    /// One radius per kind of thing; controls that are pills use `Capsule`.
    enum Radius {
        /// Text fields, small buttons, list rows.
        static let control: CGFloat = 10
        /// Cards holding controls or text.
        static let card: CGFloat = 16
        /// Media cards: wallpapers, themes, widgets, art.
        static let media: CGFloat = 20
        /// Floating panels and sheets.
        static let panel: CGFloat = 20
        /// Page heroes and large previews.
        static let hero: CGFloat = 28
    }

    // MARK: Colour

    /// Text on the dark canvas.
    enum Ink {
        static let primary = Color.white.opacity(0.95)
        static let secondary = Color.white.opacity(0.62)
        static let tertiary = Color.white.opacity(0.40)
    }

    /// What content sits on. Depth comes from light, not from boxes.
    enum Surface {
        /// The canvas: a deep navy, never pure black, so the backdrop's blue
        /// light has something to glow in.
        static let canvas = Color(red: 0.027, green: 0.035, blue: 0.059)
        /// The top of the canvas, faintly lifted.
        static let canvasLift = Color(red: 0.051, green: 0.067, blue: 0.106)
        /// A quiet raised area (a grouped setting, an idle card).
        static let raised = Color.white.opacity(0.05)
        static let hover = Color.white.opacity(0.08)
        static let pressed = Color.white.opacity(0.11)
        /// The one border allowed, and only where an edge would otherwise vanish.
        static let hairline = Color.white.opacity(0.08)
    }

    // MARK: Type

    enum TextRole {
        /// A hero's title: one per page at most.
        case hero
        /// A page title.
        case title
        /// A section heading.
        case section
        /// A card's title.
        case headline
        case body
        /// Secondary facts: size, resolution, counts.
        case meta
        /// A small uppercase label above a title ("FEATURED").
        case eyebrow

        var font: Font {
            switch self {
            case .hero: .system(size: 52, weight: .bold)
            case .title: .system(size: 28, weight: .semibold)
            case .section: .system(size: 20, weight: .semibold)
            case .headline: .system(size: 14, weight: .semibold)
            case .body: .system(size: 13)
            case .meta: .system(size: 11, weight: .medium)
            case .eyebrow: .system(size: 11, weight: .semibold)
            }
        }

        var color: Color {
            switch self {
            case .hero, .title, .section, .headline, .body: Ink.primary
            case .meta: Ink.secondary
            case .eyebrow: Ink.tertiary
            }
        }

        var tracking: CGFloat {
            switch self {
            case .hero: -1.0
            case .title: -0.3
            case .eyebrow: 1.2
            default: 0
            }
        }
    }

    // MARK: Depth

    /// The one shadow for anything lifted off the canvas. Never animated:
    /// a moving shadow redraws its blur every frame.
    enum Elevation {
        static let color = Color.black.opacity(0.35)
        static let radius: CGFloat = 18
        static let y: CGFloat = 8
    }
}

extension View {
    /// Text in one of the design system's roles, in its colour unless given one.
    func dsText(_ role: DS.TextRole, color: Color? = nil) -> some View {
        font(role.font)
            .foregroundStyle(color ?? role.color)
            .tracking(role.tracking)
            .textCase(role == .eyebrow ? .uppercase : nil)
    }

    /// The system's single lifted-shadow style.
    func dsElevated() -> some View {
        shadow(color: DS.Elevation.color, radius: DS.Elevation.radius, y: DS.Elevation.y)
    }

    /// A grouped settings form on the dark canvas: the same sections and
    /// controls, without the form's own grey backdrop.
    func dsFormStyle() -> some View {
        formStyle(.grouped)
            .scrollContentBackground(.hidden)
            // Native forms otherwise draw scrolled rows into the persistent
            // navigation's safe-area inset, obscuring its labels and controls.
            .clipped()
    }
}
