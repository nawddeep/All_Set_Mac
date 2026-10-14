import AllSetCore
import SwiftUI

// MARK: Air Quality

/// US AQI for the weather city, with the band named in words (color is only
/// a second cue), the pollutants behind it and the rest of the day.
struct AirQualityWidget: View {
    let instance: WidgetInstance
    let weather: WeatherService
    let onConfigure: @MainActor () -> Void
    @Environment(\.widgetRefreshScale) private var refreshScale

    @Environment(\.widgetStyle) private var style

    var body: some View {
        if let location = instance.options.location {
            let interval = instance.options.refresh.interval(for: .weather).map { $0 * refreshScale }
            Group {
                if let report = weather.airQuality[location] {
                    content(report, location: location)
                        .overlay(alignment: .bottomTrailing) {
                            WidgetStaleBadge(updated: report.fetchedAt, problem: weather.airQualityFailures[location], interval: interval)
                        }
                } else if let failure = weather.airQualityFailures[location] {
                    WidgetStateView(kind: .error, symbol: "aqi.medium", title: "Air quality unavailable", message: failure)
                } else {
                    WidgetStateView(kind: .loading, symbol: "", title: "Checking the air…")
                }
            }
            .widgetRefresh(every: interval, id: location) {
                await weather.refreshAirQuality(location, maxAge: interval ?? WeatherService.refreshInterval)
            }
            .contextMenu {
                Button("Refresh Now") { Task { await weather.refreshNow(location) } }
                Divider()
                WidgetMenuItems()
            }
        } else {
            WidgetStateView(kind: .empty, symbol: "aqi.medium", title: "Choose a city", actionTitle: "Set City…", action: onConfigure)
        }
    }

    private func content(_ report: AirQualityReport, location: WeatherLocation) -> some View {
        let level = report.level
        let color = Color(WidgetColor(hex: level.color))
        return Group {
            if instance.size == .small {
                VStack(alignment: .leading, spacing: 6) {
                    WidgetHeader(title: location.name, symbol: "aqi.medium")
                    Spacer(minLength: 0)
                    WidgetMetric(value: "\(report.usAQI)", unit: "AQI", size: 40)
                    AQIScale(value: report.usAQI, color: color)
                    Text(level.shortTitle).font(style.title(13))
                }
            } else {
                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        WidgetHeader(title: location.name, symbol: "aqi.medium")
                        Spacer(minLength: 0)
                        WidgetMetric(value: "\(report.usAQI)", unit: "US AQI", size: 44)
                        Text(level.title).font(style.title(13)).lineLimit(1).minimumScaleFactor(0.7)
                        AQIScale(value: report.usAQI, color: color)
                    }
                    .frame(width: 150, alignment: .leading)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(level.advice).font(style.body(12)).lineLimit(2)
                        Spacer(minLength: 0)
                        pollutant("PM2.5", report.pm25)
                        pollutant("PM10", report.pm10)
                        pollutant("Ozone", report.ozone)
                        pollutant("NO₂", report.nitrogenDioxide)
                    }
                }
            }
        }
        .padding(WidgetMetrics.padding(instance.size))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Air quality in \(location.name): \(report.usAQI), \(level.title)")
    }

    private func pollutant(_ name: String, _ value: Double?) -> some View {
        HStack {
            Text(name).foregroundStyle(style.secondary)
            Spacer()
            Text(value.map { String(format: "%.0f µg/m³", $0) } ?? "—").monospacedDigit()
        }
        .font(style.body(11))
    }
}

/// The AQI range as a quiet track with a marker where today sits.
private struct AQIScale: View {
    let value: Int
    let color: Color
    @Environment(\.widgetStyle) private var style

    var body: some View {
        GeometryReader { geometry in
            let fraction = min(Double(value) / 300, 1)
            ZStack(alignment: .leading) {
                Capsule().fill(style.ink.opacity(0.1))
                Capsule().fill(color).frame(width: max(geometry.size.width * fraction, 6))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

// MARK: Classic Mac

/// The time in a 1984 window: the theme draws the window, this draws a
/// title bar, the clock in a chunky mono face, and a progress bar for the day.
struct RetroWindowWidget: View {
    let instance: WidgetInstance
    @Environment(\.widgetStyle) private var style

    var body: some View {
        WidgetTimeline(.everyMinute) { context in
            let date = context.date
            let calendar = Calendar.current
            let fraction = date.timeIntervalSince(calendar.startOfDay(for: date)) / 86_400
            VStack(alignment: .leading, spacing: instance.size == .small ? 8 : 10) {
                WidgetHeader(title: instance.size == .small ? "Clock" : "Alarm Clock")
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(WidgetDateFormat.string(date, format: instance.options.use24Hour ? "HH:mm" : "h:mm"))
                        .font(.system(size: instance.size == .small ? 38 : 54, weight: .bold, design: .monospaced))
                    if !instance.options.use24Hour {
                        Text(WidgetDateFormat.string(date, format: "a"))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                Text(WidgetDateFormat.string(date, template: instance.size == .small ? "EEEdMMM" : "EEEEdMMMMy"))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                Spacer(minLength: 0)
                // A 1-bit progress bar: the day, so far.
                VStack(alignment: .leading, spacing: 3) {
                    Text("Today: \(Int(fraction * 100))% complete")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle().strokeBorder(style.ink, lineWidth: 1)
                            Rectangle().fill(style.ink)
                                .frame(width: max((geometry.size.width - 4) * fraction, 0))
                                .padding(2)
                        }
                    }
                    .frame(height: 10)
                }
            }
            .padding(instance.size == .small ? 10 : 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: Ensō

/// A brush circle, drawn in one stroke, that closes as the day goes by, with
/// the date set quietly beside it. Redrawn every ten minutes.
struct EnsoWidget: View {
    let instance: WidgetInstance
    @Environment(\.widgetStyle) private var style

    var body: some View {
        WidgetTimeline(.periodic(from: .now, by: 600)) { context in
            let date = context.date
            let fraction = date.timeIntervalSince(Calendar.current.startOfDay(for: date)) / 86_400
            Group {
                if instance.size == .medium {
                    HStack(spacing: 20) {
                        EnsoStroke(fraction: fraction, ink: style.ink, seal: style.accent).frame(width: 118, height: 118)
                        caption(date, fraction: fraction)
                    }
                } else {
                    VStack(spacing: instance.size == .small ? 6 : 14) {
                        EnsoStroke(fraction: fraction, ink: style.ink, seal: style.accent)
                        if instance.size == .large { caption(date, fraction: fraction) }
                    }
                }
            }
            .padding(WidgetMetrics.padding(instance.size) + 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(Int(fraction * 100)) percent of the day has passed")
        }
    }

    private func caption(_ date: Date, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WidgetDateFormat.string(date, template: "EEEE"))
                .font(style.title(16))
            Text(WidgetDateFormat.string(date, template: "dMMMM"))
                .font(style.body(12))
                .foregroundStyle(style.secondary)
            Text("\(Int((1 - fraction) * 24)) hours remain")
                .font(style.body(11))
                .foregroundStyle(style.secondary)
                .padding(.top, 6)
        }
    }
}

/// One brush stroke: thick where it starts, thinning and breaking up toward
/// the end, with a small red seal in the corner.
private struct EnsoStroke: View {
    let fraction: Double
    let ink: Color
    let seal: Color

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = side * 0.4
            let start = -Double.pi * 0.62
            let sweep = max(fraction, 0.02) * 2 * .pi * 0.94
            let steps = max(Int(sweep / 0.02), 2)
            for step in 0..<steps {
                let t: Double = Double(step) / Double(steps)
                let angle: Double = start + sweep * t
                // Heavy at the start, dry and thin at the end.
                let taper: Double = 0.085 - 0.06 * t
                let texture: Double = 1 + 0.12 * sin(t * 23)
                let width: Double = side * taper * texture
                let wobble: Double = radius * (1 + 0.025 * sin(t * 9 + 1))
                let point = CGPoint(x: center.x + cos(angle) * wobble, y: center.y + sin(angle) * wobble)
                let opacity: Double = t > 0.85 ? (1 - (t - 0.85) / 0.15) * 0.8 + 0.2 : 1
                context.fill(Path(ellipseIn: CGRect(x: point.x - width / 2, y: point.y - width / 2, width: width, height: width)),
                             with: .color(ink.opacity(0.9 * opacity)))
            }
            let stamp = side * 0.1
            context.fill(Path(roundedRect: CGRect(x: size.width - stamp * 1.4, y: size.height - stamp * 1.4, width: stamp, height: stamp),
                              cornerRadius: stamp * 0.15), with: .color(seal))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: Magazine Cover

/// Today as the cover of a magazine: a masthead, a huge date, a coverline
/// from the affirmations and an issue number that counts the days.
struct MagazineWidget: View {
    let instance: WidgetInstance
    @Environment(\.widgetStyle) private var style

    var body: some View {
        WidgetTimeline(.periodic(from: Calendar.current.startOfDay(for: .now), by: 3600)) { context in
            let date = context.date
            let issue = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
            let large = instance.size == .large
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(instance.options.customText.isEmpty ? "ALL SET" : instance.options.customText.uppercased())
                        .font(.system(size: large ? 44 : 24, weight: .black, design: .serif))
                        .tracking(large ? -1 : -0.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer(minLength: 4)
                }
                HStack {
                    Text("NO. \(issue)")
                    Spacer()
                    Text(WidgetDateFormat.string(date, template: "MMMMy").uppercased())
                }
                .font(.system(size: large ? 9 : 7, weight: .semibold, design: .serif))
                .tracking(1.5)
                .padding(.vertical, large ? 5 : 3)
                .overlay(alignment: .top) { Rectangle().fill(style.ink).frame(height: 1) }
                .overlay(alignment: .bottom) { Rectangle().fill(style.ink).frame(height: 1) }
                Spacer(minLength: 0)
                Text(WidgetDateFormat.string(date, template: "d"))
                    .font(.system(size: large ? 150 : 66, weight: .bold, design: .serif))
                    .foregroundStyle(style.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.bottom, large ? -18 : -8)
                Text(WidgetDateFormat.string(date, template: "EEEE").uppercased())
                    .font(.system(size: large ? 16 : 9, weight: .bold, design: .serif))
                    .tracking(3)
                Spacer(minLength: 0)
                Text(Affirmations.line(at: date))
                    .font(.system(size: large ? 19 : 10, weight: .regular, design: .serif).italic())
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .padding(large ? 22 : 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
        }
    }
}
