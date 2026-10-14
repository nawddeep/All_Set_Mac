import AllSetCore
import AppKit
import SwiftUI

/// The Lid Plane tab: turn the effect on, choose when it starts and how it
/// looks, and see what it does before the lid moves.
struct LidPlanePage: View {
    let services: AppServices

    private var lid: LidPlaneController { services.lidPlane }
    private var settings: LidPlaneSettings { services.lidPlane.settings }

    var body: some View {
        FormPage(eyebrow: "System", title: "Lid Plane",
                 subtitle: "Hold the desktop at one angle and blur it as the lid closes, like a screen folding away.",
                 lead: { lead }) {
            statusSection
            activationSection
            if !settings.angleMode { movementSection }
            lookSection
            testSection
            creditSection
        }
        .onAppear { lid.readoutAppeared() }
        .onDisappear {
            lid.readoutDisappeared()
            lid.releasePreview()
        }
    }

    // MARK: Lead

    private var lead: some View {
        HStack(alignment: .top, spacing: DS.Space.l) {
            LidPlanePreview(lid: lid)

            VStack(alignment: .leading, spacing: DS.Space.s) {
                LidAngleReadout(lid: lid)
                Button {
                    withMotion(Motion.responsive) { lid.toggleEnabled() }
                } label: {
                    Label(settings.isEnabled ? "Turn Off" : "Turn On", systemImage: settings.isEnabled ? "pause.fill" : "play.fill")
                        .frame(minWidth: 110)
                }
                .buttonStyle(.pillProminent)
                if lid.shortcutAvailable, settings.shortcutEnabled {
                    Text("⌃⌘L from any app").dsText(.meta)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Sections

    private var statusSection: some View {
        Section {
            Toggle("Lid Plane", isOn: Binding(get: { settings.isEnabled }, set: { lid.setEnabled($0) }))
            LabeledContent("Status") { LidStatusText(lid: lid) }
            if !lid.hasScreenAccess {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Label("Screen Recording isn\u{2019}t allowed yet", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("The effect re-draws your desktop, so All Set needs Screen & System Audio Recording. The picture stays in memory and is never saved or sent anywhere.")
                        .dsText(.meta)
                    Button("Allow Screen Recording…") { lid.requestScreenAccess() }
                        .buttonStyle(.pill)
                }
            }
            if let problem = lid.lastProblem {
                Text(problem).dsText(.meta).foregroundStyle(.red)
            }
            Toggle("Turn on and off with ⌃⌘L", isOn: Binding(get: { settings.shortcutEnabled }, set: {
                settings.shortcutEnabled = $0
                lid.applyShortcut()
            }))
            if settings.shortcutEnabled, !lid.shortcutAvailable {
                Text("Another app already uses ⌃⌘L.").dsText(.meta).foregroundStyle(.red)
            }
        } header: {
            Text("Effect")
        } footer: {
            Text("Starts off each time unless you leave it on. Closing the lid, an external-only display, mirroring or a missing sensor always pauses it.")
        }
    }

    private var activationSection: some View {
        Section {
            Toggle("Start at a lid angle", isOn: Binding(get: { settings.angleMode }, set: { settings.angleMode = $0 }))
            if settings.angleMode {
                LabeledContent("Activate at or below") {
                    HStack {
                        Slider(value: Binding(get: { settings.activationAngle }, set: { settings.activationAngle = $0 }),
                               in: LidPlaneSettings.activationRange, step: 1)
                            .frame(width: 220)
                        Text("\(Int(settings.activationAngle))°").monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                }
            }
            LabeledContent("Jitter tolerance") {
                HStack {
                    Slider(value: Binding(get: { settings.jitterTolerance }, set: { settings.jitterTolerance = $0 }),
                           in: LidPlaneSettings.jitterRange, step: 0.5)
                        .frame(width: 220)
                    Text(settings.jitterTolerance.formatted(.number.precision(.fractionLength(0...1))) + "°")
                        .monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }
        } header: {
            Text("When")
        } footer: {
            Text(settings.angleMode
                 ? "Above the angle the desktop is untouched; at it the picture lines up, and closing further builds the effect. Jitter tolerance ignores small hinge movements."
                 : "The effect follows how far the lid moves from where you last anchored. Jitter tolerance ignores small hinge movements.")
        }
    }

    private var movementSection: some View {
        Section {
            Toggle("Settle back when the lid stops", isOn: Binding(get: { settings.autoAnchor }, set: { settings.autoAnchor = $0 }))
            if settings.autoAnchor {
                Picker("Pause before settling", selection: Binding(get: { settings.anchorDelay }, set: { settings.anchorDelay = $0 })) {
                    ForEach(LidPlaneSettings.anchorDelays, id: \.self) { seconds in
                        Text("\(seconds.formatted()) s").tag(seconds)
                    }
                }
            }
            Button("Anchor Here") { lid.anchorHere() }
                .disabled(!settings.isEnabled)
        } header: {
            Text("Movement")
        }
    }

    private var lookSection: some View {
        Section {
            Toggle("Progressive blur", isOn: Binding(get: { settings.blur }, set: { settings.blur = $0 }))
            Toggle("Hold content angle", isOn: Binding(get: { settings.holdAngle }, set: { settings.holdAngle = $0 }))
            Toggle("Perspective taper", isOn: Binding(get: { settings.perspective }, set: { settings.perspective = $0 }))
                .disabled(!settings.holdAngle)
        } header: {
            Text("Look")
        } footer: {
            Text("Blur grows toward the top as the lid closes. Holding the angle keeps the picture where it was; the taper adds depth, and turning it off is gentler.")
        }
    }

    private var testSection: some View {
        Section {
            Button(lid.isSimulating ? "Stop Simulating" : "Simulate a Fold") { lid.toggleSimulation() }
                .disabled(!settings.isEnabled)
            Button("Reset to Recommended") { settings.resetBehaviour() }
        } header: {
            Text("Try it")
        } footer: {
            Text("Simulate a Fold shows the effect without moving the lid. It needs the effect turned on.")
        }
    }

    private var creditSection: some View {
        Section {
        } footer: {
            Text("Lid Plane is by Jhey (github.com/jh3y/lid-plane), under GPL-3.0-or-later, built into All Set. Only the built-in display is changed, and only your own screen is read.")
        }
    }
}

// The live parts of the page are their own views, so a new picture, angle or
// status redraws just that piece instead of the whole form.

/// The effect on generated artwork. Blur levels are kept between renders, so a
/// new picture is cheap enough to draw on every slider step and toggle.
private struct LidPlanePreview: View {
    let lid: LidPlaneController

    @State private var fold = 35.0
    @State private var image: CGImage?

    private var settings: LidPlaneSettings { lid.settings }

    var body: some View {
        PreviewCanvas(height: 250) {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(DS.Space.s)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: 420)
        .overlay(alignment: .bottom) {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: "angle")
                Slider(value: $fold, in: 0...60, step: 1)
                Text("\(Int(fold))° fold").dsText(.meta).monospacedDigit().frame(width: 62, alignment: .trailing)
            }
            .padding(.horizontal, DS.Space.s)
            .padding(.bottom, DS.Space.xs)
            .help("How far the lid has closed, in the preview")
        }
        .onChange(of: Key(fold: fold, blur: settings.blur, hold: settings.holdAngle, perspective: settings.perspective), initial: true) {
            image = lid.previewImage(degrees: fold)
        }
    }

    private struct Key: Equatable {
        var fold: Double, blur: Bool, hold: Bool, perspective: Bool
    }
}

private struct LidAngleReadout: View {
    let lid: LidPlaneController

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.xxs) {
            Text(lid.angle.map { "\(Int($0.rounded()))°" } ?? "—°")
                .font(.system(size: 54, weight: .semibold, design: .rounded)).monospacedDigit()
            Text("lid angle").dsText(.meta)
        }
        Text(lid.hasSensor ? "Live from the hinge sensor." : "No lid angle sensor reading yet.")
            .dsText(.meta)
    }
}

private struct LidStatusText: View {
    let lid: LidPlaneController

    var body: some View {
        Text(lid.settings.isEnabled ? lid.status : "Off")
    }
}
