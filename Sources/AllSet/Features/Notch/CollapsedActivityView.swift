import AllSetCore
import SwiftUI

/// A live activity around the closed notch: one item on each side of the
/// camera housing, plus an optional caption underneath.
struct CollapsedActivityView: View {
    let activity: LiveActivity
    let media: MediaController
    let notchSize: CGSize
    /// Width of the flared top corners, which content must stay clear of.
    let earInset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                leading.frame(maxWidth: .infinity)
                Color.clear.frame(width: notchSize.width)
                trailing.frame(maxWidth: .infinity)
            }
            .frame(height: notchSize.height)

            if activity.captionHeight > 0 {
                caption
                    .frame(height: activity.captionHeight, alignment: .top)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.horizontal, earInset)
        .foregroundStyle(.white)
        .frame(width: notchSize.width + activity.sideWidth * 2,
               height: notchSize.height + activity.captionHeight, alignment: .top)
    }

    @ViewBuilder
    private var leading: some View {
        switch activity {
        case .nowPlaying:
            ArtworkView(image: media.artwork, size: 22, cornerRadius: 6)
        case .volume(let level, let muted):
            Image(systemName: Self.volumeSymbol(level: level, muted: muted))
                .font(.system(size: 13, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
        case .power(let percent, let pluggedIn):
            Image(systemName: pluggedIn ? "bolt.fill" : Self.batterySymbol(percent: percent))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pluggedIn ? Theme.charging : .white)
        case .lowBattery:
            Image(systemName: "battery.25percent")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.red)
        case .audioDevice(_, let kind):
            Image(systemName: kind.symbolName)
                .font(.system(size: 14, weight: .medium))
        case .knock(_, let symbol, let failed):
            Image(systemName: failed ? "exclamationmark.triangle.fill" : symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(failed ? .orange : .white)
                .symbolEffect(.bounce, value: symbol)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch activity {
        case .nowPlaying:
            AudioBars(isPlaying: media.info?.isPlaying ?? false,
                      color: media.accentColor.map { Color(nsColor: $0) } ?? .white)
        case .volume(let level, let muted):
            LevelBar(fraction: muted ? 0 : Double(level))
                .frame(width: 40, height: 5)
        case .power(let percent, let pluggedIn):
            Text("\(percent)%")
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(pluggedIn ? Theme.charging : .white)
        case .lowBattery(let percent):
            Text("\(percent)%")
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.red)
        case .audioDevice:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.charging)
        case .knock(let count, _, let failed):
            // One dot per knock.
            HStack(spacing: 3) {
                ForEach(0..<count.rawValue, id: \.self) { _ in
                    Circle().frame(width: 5, height: 5)
                }
            }
            .foregroundStyle(failed ? .orange : Theme.charging)
        }
    }

    @ViewBuilder
    private var caption: some View {
        if case .audioDevice(let name, _) = activity {
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
    }

    static func volumeSymbol(level: Float, muted: Bool) -> String {
        if muted || level <= 0 { return "speaker.slash.fill" }
        if level < 0.34 { return "speaker.wave.1.fill" }
        if level < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    static func batterySymbol(percent: Int) -> String {
        switch percent {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }
}
