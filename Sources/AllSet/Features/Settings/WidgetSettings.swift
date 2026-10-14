import AllSetCore
import AppKit
import SwiftUI

struct WidgetSettings: View {
    @Bindable var settings: AppSettings
    let services: AppServices

    /// The size on the main display (each display keeps its own after a theme); moving it sets every display.
    private var shownScale: Binding<Double> {
        Binding(get: { services.widgetScale(on: NSScreen.screens.first) }, set: { settings.widgetScale = $0 })
    }

    var body: some View {
        Section {
            Toggle("Show widgets on the desktop", isOn: $settings.showWidgets)
            LabeledContent("Layout") {
                Button(services.ui.isArrangingWidgets ? "Done Arranging" : "Arrange Widgets") {
                    services.ui.isArrangingWidgets.toggle()
                }
            }
            .disabled(!settings.showWidgets)
            LabeledContent("Size") {
                HStack(spacing: 10) {
                    Slider(value: shownScale, in: AppSettings.widgetScaleRange, step: 0.05)
                        .frame(width: 160)
                    Text(shownScale.wrappedValue, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                    Button("Fit to Screen") { services.fitWidgetsToScreen() }
                        .help("Resize and center your widgets so they fill the screen")
                }
            }
            .disabled(!settings.showWidgets)
        } footer: {
            Text("While arranging, widgets float above your windows so you can drag them anywhere. They snap into line when you let go. Applying a theme sizes it to fill your screen.")
        }

        Section {
            Picker("Font", selection: $settings.widgetFont) {
                ForEach(WidgetFont.allCases) { font in
                    Text(font.title).tag(font)
                }
            }
            .pickerStyle(.segmented)
            LabeledContent("Corner roundness") {
                Slider(value: $settings.widgetCornerRadius, in: 8...32, step: 1)
                    .frame(width: 200)
            }
        } header: {
            Text("All widgets")
        } footer: {
            Text("Weather by Open-Meteo.com. Photos by Unsplash photographers, via Picsum.")
        }
    }
}
