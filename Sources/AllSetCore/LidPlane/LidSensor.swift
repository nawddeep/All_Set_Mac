// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import IOKit.hid

// Apple sensor HID reports are undocumented. Read only, without seizing the device.
public final class LidSensor {
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
    private var device: IOHIDDevice?
    public private(set) var diagnostic = "No readable lid sensor"

    public init() {
        IOHIDManagerSetDeviceMatching(manager, [
            "VendorID": 0x05ac, "ProductID": 0x8104,
            "PrimaryUsagePage": 0x20, "PrimaryUsage": 0x8a
        ] as CFDictionary)
        let result = IOHIDManagerOpen(manager, 0)
        guard result == kIOReturnSuccess else {
            diagnostic = "HID access failed: \(result)"
            return
        }
        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        for candidate in devices {
            guard IOHIDDeviceOpen(candidate, 0) == kIOReturnSuccess else { continue }
            device = candidate
            if let angle = read() {
                diagnostic = "Lid sensor connected: \(Int(angle))°"
                return
            }
            IOHIDDeviceClose(candidate, 0)
            device = nil
        }
        diagnostic = "Found \(devices.count) matching HID device(s), no readable angle"
    }

    public func read() -> Double? {
        guard let device else { return nil }
        var report = [UInt8](repeating: 0, count: 8)
        var length = report.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)
        guard result == kIOReturnSuccess, length >= 3 else { return nil }
        let angle = Double(UInt16(report[1]) | UInt16(report[2]) << 8)
        return (0...180).contains(angle) ? angle : nil
    }

    deinit {
        if let device { IOHIDDeviceClose(device, 0) }
        IOHIDManagerClose(manager, 0)
    }
}
