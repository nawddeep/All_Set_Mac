// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import IOKit

/// Read-only power-state hint, backed up by the physical angle and display checks.
final class LidPlaneDisplay {
    private let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    private var lastPoll: TimeInterval = -.infinity
    private var closed: Bool?
    func lidClosed(now: TimeInterval) -> Bool? {
        if now - lastPoll >= 0.1 {
            lastPoll = now
            if root != 0 {
                closed = IORegistryEntryCreateCFProperty(root, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool
            }
        }
        return closed
    }
    static func usableBuiltInScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
            return CGDisplayIsBuiltin(id) != 0 && CGDisplayIsOnline(id) != 0
                && CGDisplayIsActive(id) != 0 && CGDisplayIsAsleep(id) == 0
                && CGDisplayIsInMirrorSet(id) == 0
        }
    }
    deinit { if root != 0 { IOObjectRelease(root) } }
}
