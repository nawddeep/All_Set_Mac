import AllSetCore
import SwiftUI

struct WeatherWidget: View {
    let instance: WidgetInstance
    let weather: WeatherService
    let unit: TemperatureUnit
    let onConfigure: @MainActor () -> Void
    @Environment(\.widgetRefreshScale) private var refreshScale

    @Environment(\.widgetStyle) private var style

    var body: some View {
        if let location = instance.options.location {
            let report = weather.reports[location]
            let interval = instance.options.refresh.interval(for: .weather).map { $0 * refreshScale }
            ZStack {
                if instance.material == .tinted, instance.designTheme == nil {
                    SkyBackground(code: report?.current.code ?? 1, isDay: report?.current.isDay ?? true)
                }
                if let report {
                    forecast(report, location: location)
                        .padding(WidgetMetrics.padding(instance.size))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .overlay(alignment: .bottomTrailing) {
                            WidgetStaleBadge(updated: report.fetchedAt, problem: weather.forecastFailures[location], interval: interval)
                        }
                } else {
                    status(location)
                }
            }
            // Only while it can be seen; the service fetches when the report is stale.
            .widgetRefresh(every: interval, id: location) {
                await weather.refresh(location, maxAge: interval ?? WeatherService.refreshInterval)
            }
            .contextMenu {
                Button("Refresh Now") { Task { await weather.refreshNow(location) } }
                Divider()
                WidgetMenuItems()
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(report.map { "\(location.name), \(temperature($0.current.temperature)), \(WeatherCondition.description(code: $0.current.code))" } ?? location.name)
        } else {
            WidgetStateView(kind: .empty, symbol: "cloud.sun.fill", title: "Choose a city", actionTitle: "Set City…", action: onConfigure)
        }
    }

    @ViewBuilder
    private func forecast(_ report: WeatherReport, location: WeatherLocation) -> some View {
        switch instance.size {
        case .small:
            VStack(alignment: .leading, spacing: 0) {
                place(location)
                WidgetMetric(value: temperature(report.current.temperature), size: 46, animated: true)
                Spacer(minLength: 0)
                conditionSymbol(report.current.code, isDay: report.current.isDay, size: 18)
                Text(WeatherCondition.description(code: report.current.code))
                    .font(style.body(12, weight: .semibold))
                    .padding(.top, 3)
                highLow(report)
                    .font(style.body(11))
                    .foregroundStyle(style.secondary)
            }
        case .medium:
            VStack(spacing: 0) {
                header(report, location: location)
                Spacer(minLength: 0)
                hourly(report, count: 6)
            }
        case .large:
            VStack(spacing: 12) {
                header(report, location: location)
                hourly(report, count: 6)
                WidgetDivider()
                daily(report, count: 5)
                Spacer(minLength: 0)
                details(report, columns: 3)
            }
        case .extraLarge:
            HStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    header(report, location: location)
                    if let today = report.days.first, let precipitation = today.precipitation, precipitation >= 20 {
                        Label("\(precipitation)% chance of rain today", systemImage: "umbrella.fill")
                            .font(style.body(12))
                            .foregroundStyle(style.secondary)
                    }
                    Spacer(minLength: 0)
                    details(report, columns: 2)
                }
                .frame(width: 300)
                VStack(spacing: 12) {
                    TemperatureCurve(hours: Array(report.hours.prefix(12)), unit: unit, timeZone: report.timeZone)
                        .frame(height: 118)
                    WidgetDivider()
                    daily(report, count: 6)
                }
            }
        }
    }

    private func place(_ location: WeatherLocation) -> some View {
        HStack(spacing: 4) {
            Text(location.name).font(style.title(13)).lineLimit(1)
            Image(systemName: "location.fill").font(.system(size: 8)).foregroundStyle(style.secondary)
        }
    }

    private func header(_ report: WeatherReport, location: WeatherLocation) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                place(location)
                WidgetMetric(value: temperature(report.current.temperature), size: 42, animated: true)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                conditionSymbol(report.current.code, isDay: report.current.isDay, size: 20)
                Text(WeatherCondition.description(code: report.current.code))
                    .font(style.body(12, weight: .semibold))
                highLow(report)
                    .font(style.body(11))
                    .foregroundStyle(style.secondary)
            }
        }
    }

    private func hourly(_ report: WeatherReport, count: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(report.hours.prefix(count).enumerated()), id: \.element.id) { index, hour in
                VStack(spacing: 4) {
                    Text(index == 0 ? "Now" : WidgetDateFormat.string(hour.date, template: "j", timeZone: report.timeZone))
                        .font(style.label(10))
                        .foregroundStyle(style.secondary)
                    conditionSymbol(hour.code, isDay: hour.isDay, size: 15)
                        .frame(height: 18)
                    Text((hour.precipitation ?? 0) >= 20 ? "\(hour.precipitation ?? 0)%" : " ")
                        .font(style.body(9, weight: .semibold))
                        .foregroundStyle(Color(red: 0.35, green: 0.7, blue: 1))
                    Text(temperature(hour.temperature))
                        .font(style.body(12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// Humidity, wind, UV, feels-like and the sun, as small tiles.
    private func details(_ report: WeatherReport, columns: Int) -> some View {
        let today = report.days.first
        var items: [(String, String, String)] = [
            ("humidity.fill", "Humidity", "\(report.current.humidity)%"),
            ("wind", "Wind", "\(Int(report.current.windSpeed.rounded())) km/h"),
            ("thermometer.medium", "Feels like", temperature(report.current.feelsLike)),
        ]
        if let uv = today?.uvIndex { items.append(("sun.max.fill", "UV index", "\(Int(uv.rounded())) \(Self.uvWord(uv))")) }
        if let sunrise = today?.sunrise { items.append(("sunrise.fill", "Sunrise", WidgetDateFormat.string(sunrise, template: "jmm", timeZone: report.timeZone))) }
        if let sunset = today?.sunset { items.append(("sunset.fill", "Sunset", WidgetDateFormat.string(sunset, template: "jmm", timeZone: report.timeZone))) }
        let shown = Array(items.prefix(columns == 3 ? 3 : 6))
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .leading), count: columns), spacing: 10) {
            ForEach(shown, id: \.1) { symbol, title, value in
                VStack(alignment: .leading, spacing: 2) {
                    Label { WidgetWord(title) } icon: { Image(systemName: symbol) }
                        .font(style.label(10))
                        .foregroundStyle(style.secondary)
                    Text(value).font(style.body(14, weight: .semibold))
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private static func uvWord(_ uv: Double) -> String {
        switch uv {
        case ..<3: "Low"
        case ..<6: "Moderate"
        case ..<8: "High"
        case ..<11: "Very high"
        default: "Extreme"
        }
    }

    private func daily(_ report: WeatherReport, count: Int) -> some View {
        let days = Array(report.days.prefix(count))
        let coldest = days.map(\.low).min() ?? 0
        let warmest = days.map(\.high).max() ?? 1
        return VStack(spacing: 9) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                HStack(spacing: 8) {
                    Text(index == 0 ? "Today" : WidgetDateFormat.string(day.date, template: "EEE", timeZone: report.timeZone))
                        .frame(width: 46, alignment: .leading)
                    conditionSymbol(day.code, isDay: true, size: 14)
                        .frame(width: 22)
                    Text((day.precipitation ?? 0) >= 30 ? "\(day.precipitation ?? 0)%" : "")
                        .font(style.body(9, weight: .semibold))
                        .foregroundStyle(Color(red: 0.35, green: 0.7, blue: 1))
                        .frame(width: 26, alignment: .leading)
                    Text(temperature(day.low))
                        .foregroundStyle(style.secondary)
                        .frame(width: 32, alignment: .trailing)
                    TemperatureRange(low: day.low, high: day.high, coldest: coldest, warmest: warmest)
                        .frame(height: 5)
                    Text(temperature(day.high))
                        .frame(width: 32, alignment: .trailing)
                }
                .font(style.body(12, weight: .semibold))
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private func status(_ location: WeatherLocation) -> some View {
        VStack(spacing: 6) {
            if weather.forecastFailures[location] != nil {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 22))
                Text("Couldn't load weather for \(location.name)")
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
            } else {
                ProgressView().controlSize(.small)
                Text(location.name).font(.system(size: 12, weight: .semibold))
            }
        }
        .foregroundStyle(.secondary)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func highLow(_ report: WeatherReport) -> Text {
        guard let today = report.days.first else { return Text("") }
        return Text("H:\(temperature(today.high)) L:\(temperature(today.low))")
    }

    private func conditionSymbol(_ code: Int, isDay: Bool, size: CGFloat) -> some View {
        WeatherSymbol(code: code, isDay: isDay, size: size)
    }

    private func temperature(_ celsius: Double) -> String {
        Format.temperature(celsius, unit: unit)
    }
}

/// The next hours' temperatures as a soft curve, with a label at each end
/// and at the high and low.
private struct TemperatureCurve: View {
    let hours: [WeatherReport.Hour]
    let unit: TemperatureUnit
    let timeZone: TimeZone
    @Environment(\.widgetStyle) private var style

    var body: some View {
        let temperatures = hours.map(\.temperature)
        let low = (temperatures.min() ?? 0) - 1, high = (temperatures.max() ?? 1) + 1
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let points = temperatures.enumerated().map { index, value in
                    CGPoint(x: geometry.size.width * CGFloat(index) / CGFloat(max(temperatures.count - 1, 1)),
                            y: geometry.size.height * (1 - CGFloat((value - low) / (high - low))))
                }
                ZStack(alignment: .topLeading) {
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: CGPoint(x: first.x, y: geometry.size.height))
                        points.forEach { path.addLine(to: $0) }
                        path.addLine(to: CGPoint(x: points.last?.x ?? 0, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [style.accent.opacity(0.28), style.accent.opacity(0)], startPoint: .top, endPoint: .bottom))
                    Path { path in path.addLines(points) }
                        .stroke(style.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                        if index == 0 || index == points.count - 1 || temperatures[index] == temperatures.max() || temperatures[index] == temperatures.min() {
                            Text(Format.temperature(temperatures[index], unit: unit))
                                .font(style.body(10, weight: .semibold))
                                .position(x: min(max(point.x, 14), geometry.size.width - 14), y: max(point.y - 10, 6))
                        }
                    }
                }
            }
            HStack(spacing: 0) {
                ForEach(Array(hours.enumerated()), id: \.element.id) { index, hour in
                    if index % 2 == 0 {
                        VStack(spacing: 2) {
                            WeatherSymbol(code: hour.code, isDay: hour.isDay, size: 12)
                            Text(index == 0 ? "Now" : WidgetDateFormat.string(hour.date, template: "j", timeZone: timeZone))
                                .font(style.label(9)).foregroundStyle(style.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Temperatures for the next \(hours.count) hours, from \(Format.temperature(temperatures.min() ?? 0, unit: unit)) to \(Format.temperature(temperatures.max() ?? 0, unit: unit))")
    }
}

/// A day's low-to-high span on the week's scale, warming in color like the
/// Weather app's.
private struct TemperatureRange: View {
    let low: Double
    let high: Double
    let coldest: Double
    let warmest: Double

    var body: some View {
        GeometryReader { geometry in
            let span = max(warmest - coldest, 1)
            let start = (low - coldest) / span * geometry.size.width
            let end = (high - coldest) / span * geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.15))
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.4, green: 0.8, blue: 1.0), Color(red: 1.0, green: 0.8, blue: 0.3),
                                                  Color(red: 1.0, green: 0.5, blue: 0.25)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(end - start, geometry.size.height))
                    .offset(x: start)
            }
        }
    }
}

/// A sky for the widget's "Color" style, matched to conditions and daylight.
private struct SkyBackground: View {
    let code: Int
    let isDay: Bool

    var body: some View {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .motion(Motion.gentle, value: code)
    }

    private var colors: [Color] {
        func rgb(_ hex: UInt32) -> Color {
            Color(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
        }
        switch (WeatherCondition.sky(code: code), isDay) {
        case (.clear, true): return [rgb(0x2F80ED), rgb(0x56CCF2)]
        case (.clear, false): return [rgb(0x0B1437), rgb(0x2B3A67)]
        case (.cloudy, true): return [rgb(0x5B6F8A), rgb(0x94A6BE)]
        case (.cloudy, false): return [rgb(0x232A36), rgb(0x46505F)]
        case (.wet, true): return [rgb(0x3E5570), rgb(0x6D8299)]
        case (.wet, false): return [rgb(0x151C26), rgb(0x3A4553)]
        case (.storm, _): return [rgb(0x1F2833), rgb(0x45505E)]
        case (.snow, true): return [rgb(0x7F9CC6), rgb(0xB9CDE8)]
        case (.snow, false): return [rgb(0x2E3B57), rgb(0x5A6A8C)]
        }
    }
}

/// A weather symbol in color on dark cards; on light ones Apple's multicolor
/// clouds are white and vanish, so it's drawn in the card's ink instead.
struct WeatherSymbol: View {
    let code: Int
    let isDay: Bool
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetStyle) private var style

    var body: some View {
        let image = Image(systemName: WeatherCondition.symbol(code: code, isDay: isDay))
            .font(.system(size: size))
        Group {
            if colorScheme == .dark {
                image.symbolRenderingMode(.multicolor)
            } else {
                image.symbolRenderingMode(.hierarchical).foregroundStyle(style.ink.opacity(0.8))
            }
        }
        .contentTransition(.symbolEffect(.replace))
        .accessibilityHidden(true)
    }
}
