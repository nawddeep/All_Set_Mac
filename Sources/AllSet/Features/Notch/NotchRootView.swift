import AllSetCore
import SwiftUI

/// What the island holds: the open panel, a live activity, or nothing. The
/// island's shape, its shadow and the clipping come from `IslandView`, in Core
/// Animation; this lays out once, at the size the shape is heading for, in a
/// frame that never changes (the panel's), so nothing reflows while it moves.
struct NotchRootView: View {
    let model: NotchViewModel
    let services: AppServices
    let expand: @MainActor () -> Void
    let openSettings: @MainActor () -> Void

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        if model.isExpanded {
            ExpandedPanel(model: model, services: services, openSettings: openSettings)
                .transition(.reveal())
        } else if let activity = model.activity {
            let size = model.shapeSize
            CollapsedActivityView(activity: activity, media: services.media,
                                  notchSize: model.geometry.notchRect.size, earInset: model.topCornerRadius)
                .frame(width: size.width, height: size.height)
                .id(activity.kind)
                .contentShape(Rectangle())
                .onTapGesture(perform: expand)
                .transition(.reveal(in: .smooth(duration: 0.25).delay(0.05), out: .easeIn(duration: 0.12)))
        } else {
            Color.clear
                .frame(width: model.shapeSize.width, height: model.shapeSize.height)
                .contentShape(Rectangle())
                .onTapGesture(perform: expand)
        }
    }
}
