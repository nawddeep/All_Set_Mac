import Foundation

/// `allset://` links, for Shortcuts, Raycast, scripts and widgets' own clicks.
///
///     allset://open/monitor        a page of the main window
///     allset://widget/<uuid>       a widget's settings
///     allset://arrange             arrange mode
///     allset://fit                 size and center the widgets to fill the screen
///     allset://theme/<id>          apply a design theme to every widget
///     allset://focus/start|pause|reset   the first Focus Timer on the desktop
public enum DeepLink: Equatable, Sendable {
    case page(String)
    case widget(UUID)
    case arrange
    case fit
    case theme(String)
    case focus(FocusAction)

    public enum FocusAction: String, Sendable { case start, pause, reset }

    public static let scheme = "allset"
    /// Longer links are ignored: none of ours comes close.
    public static let maximumLength = 512

    /// Any web page can open an `allset://` link, so everything in one is
    /// checked: its length, and that names are plain names.
    public init?(_ url: URL) {
        guard url.absoluteString.count <= Self.maximumLength,
              url.scheme?.lowercased() == Self.scheme, let host = url.host()?.lowercased() else { return nil }
        let argument = url.pathComponents.dropFirst().first
        if let argument, !Self.isPlainName(argument) { return nil }
        switch host {
        case "open":
            self = .page(argument?.lowercased() ?? "home")
        case "widget":
            guard let argument, let id = UUID(uuidString: argument) else { return nil }
            self = .widget(id)
        case "arrange":
            self = .arrange
        case "fit":
            self = .fit
        case "theme":
            guard let argument else { return nil }
            self = .theme(argument)
        case "focus":
            guard let action = argument.flatMap({ FocusAction(rawValue: $0.lowercased()) }) else { return nil }
            self = .focus(action)
        default:
            return nil
        }
    }

    /// Letters, digits, dots, dashes and underscores, 1 to 100 of them.
    static func isPlainName(_ text: String) -> Bool {
        (1...100).contains(text.count) && text.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) }
    }

    /// Links that change the desktop: they show Undo, are limited to one per
    /// `DeepLinkThrottle.interval`, and ask first when All Set isn't in front.
    public var changesDesktop: Bool {
        switch self {
        case .fit, .theme: true
        case .page, .widget, .arrange, .focus: false
        }
    }

    public var url: URL {
        let path: String = switch self {
        case .page(let page): "open/\(page)"
        case .widget(let id): "widget/\(id.uuidString)"
        case .arrange: "arrange"
        case .fit: "fit"
        case .theme(let id): "theme/\(id)"
        case .focus(let action): "focus/\(action.rawValue)"
        }
        return URL(string: "\(Self.scheme)://\(path)")!
    }
}

/// At most one desktop-changing link every `interval` seconds, so a page
/// that fires links in a loop can't keep restyling the desktop.
public struct DeepLinkThrottle: Sendable {
    public static let interval: TimeInterval = 2
    private var lastAccepted: Date?

    public init() {}

    /// Whether `link` may run now; a link that changes nothing always may.
    public mutating func allows(_ link: DeepLink, at now: Date = .now) -> Bool {
        guard link.changesDesktop else { return true }
        if let lastAccepted, now.timeIntervalSince(lastAccepted) < Self.interval { return false }
        lastAccepted = now
        return true
    }
}
