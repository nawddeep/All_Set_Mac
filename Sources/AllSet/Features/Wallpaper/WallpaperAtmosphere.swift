import SwiftUI

/// Wallpaper uses the same atmosphere as Widgets and the Themes reference.
/// Its actual wallpaper still fills the hero behind the floating navigation.
struct WallpaperAtmosphere: View {
    let services: AppServices
    var body: some View { StudioAtmosphere(services: services).ignoresSafeArea() }
}
