import AllSetCore
import SwiftUI

/// One big number, counted up when it appears, with a trophy that glows.
struct MilestoneWidget: View {
    let instance: WidgetInstance

    @Environment(\.widgetAccent) private var accent
    @Environment(\.widgetSnapshot) private var snapshot
    @State private var shown = 0

    private var milestone: MilestoneDetails { instance.options.milestone }

    var body: some View {
        let small = instance.size == .small
        HStack(spacing: 14) {
            if !small {
                ZStack {
                    PulsingGlow(color: accent, period: 3)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(LinearGradient(colors: [accent.mix(.white, 0.5), accent], startPoint: .top, endPoint: .bottom))
                        .shadow(color: accent.opacity(0.7), radius: 8)
                }
                .frame(width: 110)
            }
            VStack(alignment: small ? .center : .leading, spacing: 2) {
                if small {
                    Image(systemName: "trophy.fill").font(.system(size: 16)).foregroundStyle(accent)
                        .shadow(color: accent.opacity(0.7), radius: 5)
                }
                Text(milestone.label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .opacity(0.7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(snapshot ? milestone.value : shown)\(milestone.suffix)")
                    .font(.system(size: small ? 44 : 56, weight: .black).width(.condensed))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(shown)))
                    .foregroundStyle(LinearGradient(colors: [accent.mix(.white, 0.55), accent], startPoint: .top, endPoint: .bottom))
                    .shadow(color: accent.opacity(0.5), radius: 8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                if !milestone.caption.isEmpty {
                    Text(milestone.caption)
                        .font(.system(size: 11, weight: .medium))
                        .opacity(0.6)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: small ? .center : .leading)
        }
        .padding(small ? 12 : 16)
        .task(id: milestone.value) {
            // Counts up in a few steps rather than every frame.
            let target = milestone.value
            guard !snapshot, shown != target else { return }
            for step in 1...8 {
                withMotion(Motion.quick) { shown = target * step / 8 }
                try? await Task.sleep(for: .milliseconds(90))
            }
        }
    }
}

extension Color {
    /// How vivid the color is, 0 for grays.
    var saturationValue: Double {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return 0 }
        return color.saturationComponent
    }
}
