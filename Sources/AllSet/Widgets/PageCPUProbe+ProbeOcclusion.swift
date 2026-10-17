import AllSetCore
import AppKit
import SwiftUI

#if DEBUG

@Observable @MainActor
final class ProbeOcclusion {
    var isOccluded = false
}

struct ProbeOccludedWidget: View {
    let instance: WidgetInstance
    let services: AppServices
    let state: ProbeOcclusion

    var body: some View {
        WidgetBody(instance: instance, services: services)
            .environment(\.widgetIsVisible, !state.isOccluded)
            .environment(\.widgetIsOnScreen, !state.isOccluded)
    }
}
#endif
