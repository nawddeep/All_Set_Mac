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

    public init?(_ url: URL) {
        guard url.scheme?.lowercased() == Self.scheme, let host = url.host()?.lowercased() else { return nil }
        let argument = url.pathComponents.dropFirst().first
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
