import AllSetCore
import AppKit
import SwiftUI

/// A borderless, transparent panel that floats above the menu bar on every
/// Space. It becomes key only while the Notes tab wants typing, so clicking
/// the notch otherwise doesn't pull keyboard focus from the app being used.
final class NotchPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        // Above the menu bar and its status items, below menus opened from them.
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
        acceptsMouseMovedEvents = true
        // NotchController turns this off only while the pointer is over the notch.
        ignoresMouseEvents = true
    }

    /// Set while the Notes tab is showing.
    var acceptsKeyboard = false

    override var canBecomeKey: Bool { acceptsKeyboard }
    override var canBecomeMain: Bool { false }
}

/// Lets clicks land on the first try in panels that are never (or rarely) key.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    var isBuiltIn: Bool {
        displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false
    }

    /// The display's UUID: the same for a monitor across reconnects and
    /// restarts, different for two monitors of the same model (which share a
    /// `localizedName`). Saved with records to say which display they're on.
    var stableID: String {
        guard let displayID, let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
              let string = CFUUIDCreateString(nil, uuid) as String? else {
            return "display-\(displayID ?? 0)"
        }
        return string
    }

    var displayInfo: DisplayInfo { DisplayInfo(id: stableID, name: localizedName) }

    /// The connected screen a record saved with this id and name belongs to.
    static func matching(id: String?, name: String?) -> NSScreen? {
        let screens = NSScreen.screens
        return DisplayIdentity.index(id: id, name: name, in: screens.map(\.displayInfo)).map { screens[$0] }
    }
}

extension WidgetInstance {
    /// On `screen`, by id and by name; unchanged for nil.
    mutating func place(on screen: NSScreen?) {
        guard let screen else { return }
        screenID = screen.stableID
        screenName = screen.localizedName
    }

    func placed(on screen: NSScreen?) -> WidgetInstance {
        var copy = self
        copy.place(on: screen)
        return copy
    }
}
