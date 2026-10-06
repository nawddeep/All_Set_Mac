import CoreWLAN
import Foundation

/// The Wi-Fi link right now. The network's name needs Location permission on
/// recent macOS, so it's often missing; strength and speed never are.
public struct WiFiStatus: Equatable, Sendable {
    public var isPoweredOn: Bool
    public var networkName: String?
    /// dBm, e.g. -55.
    public var signal: Int?
    public var noise: Int?
    /// Mbps.
    public var transmitRate: Double?
    public var channel: Int?
    /// 2.4, 5 or 6 (GHz).
    public var band: String?

    /// 0...4 bars, the way the menu bar shows them.
    public var bars: Int {
        guard let signal, isPoweredOn else { return 0 }
        if signal >= -55 { return 4 }
        if signal >= -67 { return 3 }
        if signal >= -75 { return 2 }
        if signal >= -85 { return 1 }
        return 0
    }

    public var quality: String {
        switch bars {
        case 4: "Excellent"
        case 3: "Good"
        case 2: "Fair"
        case 1: "Weak"
        default: isPoweredOn ? "No signal" : "Off"
        }
    }
}

public enum WiFiReader {
    public static func read() -> WiFiStatus {
        guard let interface = CWWiFiClient.shared().interface() else {
            return WiFiStatus(isPoweredOn: false)
        }
        let powered = interface.powerOn()
        let rssi = interface.rssiValue()
        let noise = interface.noiseMeasurement()
        let channel = interface.wlanChannel()
        let band: String? = switch channel?.channelBand {
        case .band2GHz: "2.4"
        case .band5GHz: "5"
        case .band6GHz: "6"
        default: nil
        }
        return WiFiStatus(isPoweredOn: powered, networkName: interface.ssid(),
                          signal: powered && rssi != 0 ? rssi : nil, noise: powered && noise != 0 ? noise : nil,
                          transmitRate: powered && interface.transmitRate() > 0 ? interface.transmitRate() : nil,
                          channel: channel?.channelNumber, band: band)
    }
}

extension WiFiStatus {
    public init(isPoweredOn: Bool) {
        self.init(isPoweredOn: isPoweredOn, networkName: nil, signal: nil, noise: nil, transmitRate: nil, channel: nil, band: nil)
    }
}
