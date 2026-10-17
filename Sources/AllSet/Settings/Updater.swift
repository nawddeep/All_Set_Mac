import AllSetCore
import AppKit
import Sparkle

/// Updates through Sparkle: an appcast on the repository's GitHub Releases,
/// every update checked against the EdDSA public key in Info.plist.
///
/// Until the owner generates that key (`SUPublicEDKey` still the placeholder)
/// the updater is never created: no checks, no network, nothing in the menu.
@MainActor
final class Updater {
    static let shared = Updater()

    private var controller: SPUStandardUpdaterController?

    /// A real public key and an https feed, in a packaged app.
    static func isConfigured() -> Bool {
        UpdateConfiguration.isConfigured(info: Bundle.main.infoDictionary, isPackaged: Bundle.main.bundleURL.pathExtension == "app")
    }

    var isAvailable: Bool { controller != nil }

    func start() {
        guard controller == nil, Self.isConfigured() else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
