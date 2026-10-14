import AllSetCore
import SwiftUI

/// Widgets and Wallpaper borrow the actual Themes renderer and its cached
/// Midnight Aurora light, rather than maintaining separate page skins.
struct StudioAtmosphere: View {
    let services: AppServices
    @State private var atmosphere = ThemeAtmosphereState()

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                WindowBackdrop(paused: services.ui.performance.pausesDecorativeMotion)
                ThemeAtmosphere(state: atmosphere, services: services,
                                focusY: services.ui.page == .wallpaper ? 460 : 260,
                                panel: CGSize(width: geometry.size.width * 0.7, height: 420))
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
        .task {
            guard let set = ThemeLibrary.set("setup.midnightAurora") else { return }
            atmosphere.show(set, animation: nil)
            services.themePreviews.request(set, dark: set.isDark, variant: .backdrop, services: services)
            defer { services.themePreviews.cancel(set, dark: set.isDark, variant: .backdrop) }
            while !Task.isCancelled { try? await Task.sleep(for: .seconds(3600)) }
        }
    }
}

/// The solid, hairline-edged filter surface used by the Themes page.
struct StudioFilterSurface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(.horizontal, DS.Space.s).padding(.vertical, DS.Space.xs)
            .background(DS.Surface.canvasLift, in: RoundedRectangle(cornerRadius: DS.Radius.control))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.control).strokeBorder(DS.Surface.hairline))
    }
}

/// One moving selection surface, with independent geometry for each control.
struct StudioSegmentedControl<Value: Hashable>: View {
    let values: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    var horizontalPadding: CGFloat = 24
    let label: String
    @Namespace private var highlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(values, id: \.self) { value in
                Button {
                    withMotion(Motion.standard) { selection = value }
                } label: {
                    Text(title(value))
                        .font(.system(size: 12, weight: selection == value ? .semibold : .regular))
                        .foregroundStyle(selection == value ? .white : .white.opacity(0.78))
                        .padding(.horizontal, horizontalPadding).frame(height: 32)
                        .contentShape(Capsule())
                        .background {
                            if selection == value {
                                if reduceMotion {
                                    Capsule().fill(Color(red: 0.3, green: 0.36, blue: 0.52))
                                } else {
                                    Capsule().fill(Color(red: 0.3, green: 0.36, blue: 0.52))
                                        .matchedGeometryEffect(id: "selection", in: highlight)
                                }
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label): \(title(value))")
                .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
        .padding(2)
        .background(DS.Surface.raised, in: RoundedRectangle(cornerRadius: DS.Radius.control))
        .motion(Motion.standard, value: selection)
        .accessibilityElement(children: .contain).accessibilityLabel(label)
    }
}
