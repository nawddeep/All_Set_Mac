import Foundation

public enum TemperatureUnit: String, CaseIterable, Identifiable, Sendable {
    case celsius
    case fahrenheit

    public var id: String { rawValue }
    public var title: String { self == .celsius ? "Celsius" : "Fahrenheit" }
}

/// Compact, fixed-style strings for the notch and menu bar, where space is tight.
public enum Format {
    public static func percent(_ fraction: Double) -> String {
        guard fraction.isFinite else { return "–" }
        return "\(Int((min(max(fraction, 0), 1) * 100).rounded()))%"
    }

    /// Decimal units (1 KB = 1000 B), as Activity Monitor uses for network and disk.
    public static func bytes(_ value: Double) -> String {
        scaled(value, base: 1000)
    }

    public static func rate(_ bytesPerSecond: Double) -> String {
        bytes(bytesPerSecond) + "/s"
    }

    /// Binary units (1 GB = 1024³ B), as macOS reports memory.
    public static func memory(_ value: UInt64) -> String {
        scaled(Double(value), base: 1024)
    }

    public static func temperature(_ celsius: Double, unit: TemperatureUnit) -> String {
        let value = unit == .celsius ? celsius : celsius * 9 / 5 + 32
        return "\(Int(value.rounded()))°"
    }

    /// `3:07`, or `1:02:03` past an hour.
    public static func clock(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "–:––" }
        let total = max(Int(seconds.rounded(.down)), 0)
        let (hours, minutes, secs) = (total / 3600, total % 3600 / 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    /// `3h 12m`, or `45m` under an hour.
    public static func duration(minutes: Int) -> String {
        let hours = minutes / 60
        return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"
    }

    public static func watts(_ watts: Double) -> String {
        String(format: "%.1f W", abs(watts))
    }

    /// Per-app power, which is usually well under a watt: `45 mW`, `1.2 W`.
    public static func power(_ watts: Double) -> String {
        let value = abs(watts)
        if value >= 0.9995 { return String(format: "%.1f W", value) }
        return "\(Int((value * 1000).rounded())) mW"
    }

    private static func scaled(_ value: Double, base: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var amount = max(value, 0)
        var index = 0
        while amount >= base, index < units.count - 1 {
            amount /= base
            index += 1
        }
        // Rounding can land exactly on the base, e.g. 999.7 KB -> "1000 KB".
        if amount.rounded() >= base, index < units.count - 1 {
            amount /= base
            index += 1
        }
        if index == 0 { return "\(Int(amount)) B" }
        return amount < 10
            ? String(format: "%.1f %@", amount, units[index])
            : "\(Int(amount.rounded())) \(units[index])"
    }
}
