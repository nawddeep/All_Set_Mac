import AllSetCore
import SwiftUI

extension EnvironmentValues {
    /// False while the widget's window is covered, which pauses animations.
    @Entry var widgetIsVisible = true
    /// The most frames a second drawn art may use; widgets lower it on battery.
    @Entry var artFrameLimit: Int?
}

/// Draws an `ArtPiece`, still or animated. Animation runs at 30 fps and stops
/// when the widget can't be seen.
struct ArtView: View {
    let piece: ArtPiece
    var animated = false
    var speed = 1.0
    var frameRate = 30
    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.artFrameLimit) private var frameLimit

    var body: some View {
        let rate = max(min(frameRate, frameLimit ?? frameRate), 1)
        // Hidden or paused: a still frame, drawn once. Moving: on the GPU
        // when it's ready, which costs a fraction of drawing with SwiftUI.
        if animated, isVisible, let gpu = ArtGPU.shared {
            MetalArtView(gpu: gpu, piece: piece, speed: speed, frameRate: rate)
        } else if animated, isVisible {
            TimelineView(.animation(minimumInterval: 1.0 / Double(rate))) { context in
                canvas(time: context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000) * speed)
            }
        } else {
            // A moment where every style looks settled.
            canvas(time: 20)
        }
    }

    private func canvas(time: Double) -> some View {
        Canvas { context, size in
            ArtRenderer.draw(piece, in: context, size: size, time: time)
        }
    }
}
