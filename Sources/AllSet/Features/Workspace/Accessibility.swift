import AllSetCore
import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Accessibility permission, which moving other apps' windows requires.
@MainActor
enum Accessibility {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows macOS's own prompt, which leads to the Accessibility settings.
    static func requestAccess() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

/// macOS 15+ tiles windows dragged to screen edges by itself; two tilers
/// fighting over one drag would make a mess.
enum NativeTiling {
    static var isEnabled: Bool {
        WindowLayout.nativeTilingIsOn(
            preference: UserDefaults(suiteName: "com.apple.WindowManager")?.object(forKey: "EnableTilingByEdgeDrag") as? Bool,
            osMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
    }

    static func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")!)
    }
}

/// Another app's window, through the Accessibility API. Frames are in the API's
/// own coordinates: origin at the top-left of the main screen, y down.
@MainActor
struct AXWindow {
    let element: AXUIElement
    let pid: pid_t

    static func focused() -> AXWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 1)
        guard let window = element(appElement, kAXFocusedWindowAttribute) else { return nil }
        return AXWindow(element: window, pid: app.processIdentifier)
    }

    static func windows(of pid: pid_t) -> [AXWindow] {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 1)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let list = value as? [AXUIElement] else { return [] }
        // Each window answers within a second or is skipped: a hung app can't
        // hold the main thread for long.
        return list.map { element in
            AXUIElementSetMessagingTimeout(element, 1)
            return AXWindow(element: element, pid: pid)
        }
    }

    /// The window under a point, in Accessibility coordinates.
    static func at(_ point: CGPoint) -> AXWindow? {
        let systemWide = AXUIElementCreateSystemWide()
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hit) == .success,
              let hit else { return nil }
        var pid: pid_t = 0
        AXUIElementGetPid(hit, &pid)
        if string(hit, kAXRoleAttribute) == kAXWindowRole { return AXWindow(element: hit, pid: pid) }
        return element(hit, kAXWindowAttribute).map { AXWindow(element: $0, pid: pid) }
    }

    var frame: CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }

    /// Size, then position, then size again: some apps limit a window's size to
    /// the screen it's on, so the second resize finishes the job after a move.
    /// False when the app refused the move or the resize (read `frame` back to
    /// see where it really is: an accepted request can still be limited).
    @discardableResult
    func setFrame(_ frame: CGRect) -> Bool {
        var size = frame.size
        var origin = frame.origin
        guard let sizeValue = AXValueCreate(.cgSize, &size), let originValue = AXValueCreate(.cgPoint, &origin) else { return false }
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        let moved = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, originValue)
        let sized = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        return moved == .success && sized == .success
    }

    var title: String? { Self.string(element, kAXTitleAttribute) }

    /// Real document windows, not panels, sheets or palettes.
    var isStandard: Bool { Self.string(element, kAXSubroleAttribute) == kAXStandardWindowSubrole }

    var isMinimized: Bool {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value)
        return (value as? Bool) ?? false
    }

    func raise() {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }

    func isSame(as other: AXWindow) -> Bool {
        CFEqual(element, other.element)
    }

    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value as? String
    }
}

/// System-wide keyboard shortcuts through Carbon's hot keys, which work in any
/// app and need no permission.
@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var references: [UInt32: EventHotKeyRef] = [:]
    private var groups: [UInt32: String] = [:]
    private var handlers: [UInt32: @MainActor () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var isInstalled = false

    /// False when the shortcut is already taken by another app.
    /// `group` lets a feature drop only its own shortcuts: window snapping
    /// re-registers its keys whenever they change.
    @discardableResult
    func register(_ shortcut: Shortcut, group: String = "windows", handler: @escaping @MainActor () -> Void) -> Bool {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x414C_5354), id: id) // "ALST"
        let status = RegisterEventHotKey(shortcut.keyCode, Self.carbonModifiers(shortcut.modifiers), hotKeyID,
                                         GetApplicationEventTarget(), 0, &reference)
        guard status == noErr, let reference else { return false }
        references[id] = reference
        handlers[id] = handler
        groups[id] = group
        return true
    }

    func unregisterAll(group: String = "windows") {
        for id in groups.filter({ $0.value == group }).keys {
            if let reference = references.removeValue(forKey: id) { UnregisterEventHotKey(reference) }
            handlers[id] = nil
            groups[id] = nil
        }
    }

    fileprivate func fire(_ id: UInt32) {
        handlers[id]?()
    }

    private func installHandlerIfNeeded() {
        guard !isInstalled else { return }
        isInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            // Carbon delivers application events on the main thread.
            MainActor.assumeIsolated { HotKeyCenter.shared.fire(hotKeyID.id) }
            return noErr
        }, 1, &spec, nil, nil)
    }

    private static func carbonModifiers(_ modifiers: KeyModifiers) -> UInt32 {
        var flags = 0
        if modifiers.contains(.command) { flags |= cmdKey }
        if modifiers.contains(.option) { flags |= optionKey }
        if modifiers.contains(.control) { flags |= controlKey }
        if modifiers.contains(.shift) { flags |= shiftKey }
        return UInt32(flags)
    }
}
