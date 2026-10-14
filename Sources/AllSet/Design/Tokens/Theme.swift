import AllSetCore
import SwiftUI

/// Metric colors, tuned to read on the black notch.
enum Theme {
    static let cpu = Color(red: 0.40, green: 0.66, blue: 1.00)
    static let efficiencyCore = Color(red: 0.36, green: 0.86, blue: 0.84)
    static let gpu = Color(red: 0.76, green: 0.52, blue: 1.00)
    static let memory = Color(red: 0.42, green: 0.87, blue: 0.60)
    static let download = Color(red: 0.36, green: 0.80, blue: 1.00)
    static let upload = Color(red: 1.00, green: 0.56, blue: 0.46)
    static let disk = Color(red: 1.00, green: 0.78, blue: 0.36)
    static let temperature = Color(red: 1.00, green: 0.62, blue: 0.38)
    static let charging = Color(red: 0.35, green: 0.88, blue: 0.45)

    static func battery(percent: Int, charging: Bool) -> Color {
        if charging { return Theme.charging }
        if percent <= 10 { return .red }
        if percent <= 20 { return .orange }
        return Theme.charging
    }

    /// Bars for the energy list warm from yellow to orange-red as they fill.
    static func energy(_ fraction: Double) -> Color {
        let t = min(max(fraction, 0), 1)
        return Color(red: 1.0, green: 0.82 - 0.4 * t, blue: 0.35 - 0.1 * t)
    }

    /// Sticky-note paper, slightly deeper toward the bottom.
    static func paper(_ color: NoteColor) -> LinearGradient {
        let base = switch color {
        case .yellow: WidgetColor(red: 1.00, green: 0.90, blue: 0.50)
        case .pink: WidgetColor(red: 1.00, green: 0.74, blue: 0.80)
        case .blue: WidgetColor(red: 0.68, green: 0.85, blue: 1.00)
        case .green: WidgetColor(red: 0.73, green: 0.94, blue: 0.76)
        case .purple: WidgetColor(red: 0.86, green: 0.78, blue: 1.00)
        }
        return LinearGradient(colors: [Color(base), blend(base, toward: 0, by: 0.06)], startPoint: .top, endPoint: .bottom)
    }

    /// A widget's "Solid" style: flat, with the faintest light from above.
    static func paperCard(_ tint: WidgetColor) -> LinearGradient {
        LinearGradient(colors: [blend(tint, toward: 1, by: 0.05), blend(tint, toward: 0, by: 0.03)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// A widget's "Color" style: its tint, lighter at the top-left.
    static func tintGradient(_ tint: WidgetColor) -> LinearGradient {
        LinearGradient(colors: [blend(tint, toward: 1, by: 0.18), blend(tint, toward: 0, by: 0.28)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Moves each channel `amount` of the way to `target` (1 for white, 0 for
    /// black). `Color.mix` would do this but needs macOS 15.
    private static func blend(_ color: WidgetColor, toward target: Double, by amount: Double) -> Color {
        Color(.sRGB,
              red: color.red + (target - color.red) * amount,
              green: color.green + (target - color.green) * amount,
              blue: color.blue + (target - color.blue) * amount)
    }

    static func pressure(_ pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: memory
        case .warning: .yellow
        case .critical: .red
        }
    }

    static func thermal(_ level: ThermalLevel) -> Color {
        switch level {
        case .nominal: .secondary
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        }
    }
}
