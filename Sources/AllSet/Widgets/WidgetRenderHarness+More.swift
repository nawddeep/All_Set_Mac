import AllSetCore
import AppKit
import Observation
import SwiftUI

#if DEBUG

extension WidgetRenderHarness {
    /// `-renderThemeCards folder [-cardThemes americana,floodlightGold,leopardNoir]`:
    /// the Themes carousel's card for each theme, selected (top row) and as a
    /// neighbour (bottom row), side by side in `theme-cards.png`. For judging
    /// the card art without paging through the carousel.
    static func renderThemeCards(to folder: URL, services: AppServices) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? ArtGPU.compileNow()
        let names = (UserDefaults.standard.string(forKey: "cardThemes") ?? "americana,floodlightGold,leopardNoir").split(separator: ",")
        let sets = names.compactMap { ThemeLibrary.set("setup.\($0)") }
        let cache = services.themePreviews
        for set in sets {
            cache.request(set, dark: set.isDark, variant: .card, services: services)
            for _ in 0..<300 where cache.image(for: set, dark: set.isDark, variant: .card) == nil {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        let sheet = VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 28) {
                ForEach(sets) { set in
                    ThemePreviewCard(set: set, services: services, isSelected: true).frame(width: 360, height: 480)
                }
            }
            HStack(spacing: 28) {
                ForEach(sets) { set in
                    ThemePreviewCard(set: set, services: services, isSelected: false).frame(width: 240, height: 320)
                }
            }
        }
        .padding(36)
        .background(DS.Surface.canvasLift)
        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2
        if let image = renderer.cgImage,
           let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            try? png.write(to: folder.appendingPathComponent("theme-cards.png"))
        }
    }
}

/// A window AppKit doesn't pull back onto a small screen, so a CI machine's
/// display doesn't crop the larger sizes.
final class UnconstrainedWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// A picture of one of our own windows, as the window server shows it. The
/// old call is looked up at run time: it's deprecated, but it needs no screen
/// recording permission for the app's own windows, which is all this is for.
@MainActor
func captureOwnWindow(_ window: NSWindow) -> CGImage? {
    typealias Capture = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
    guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return nil }
    let capture = unsafeBitCast(symbol, to: Capture.self)
    return capture(.null, CGWindowListOption.optionIncludingWindow.rawValue, UInt32(window.windowNumber),
                   CGWindowImageOption.boundsIgnoreFraming.rawValue)?.takeRetainedValue()
}

extension WidgetRenderHarness {
    /// `-renderOnboarding folder`: each step of the first-run welcome, as a PNG.
    /// Changes nothing: the extras step's switches are only drawn.
    static func renderOnboarding(to folder: URL, services: AppServices) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for step in OnboardingView.Step.allCases {
            OnboardingController.shared.show(services: services, step: step)
            try? await Task.sleep(for: .milliseconds(900))
            guard let window = OnboardingController.shared.currentWindow, let image = captureOwnWindow(window) else { continue }
            let file = folder.appendingPathComponent("onboarding-\(step.rawValue)-\(step).png")
            try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: file)
            window.delegate = nil
            window.close()
            OnboardingController.shared.forget()
        }
    }
}
#endif
