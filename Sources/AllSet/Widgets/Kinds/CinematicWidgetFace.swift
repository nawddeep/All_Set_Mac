import AllSetCore
import AppKit
import SwiftUI

/// The approved wide gallery style is also persisted on widgets added to the desktop.
/// All readings and controls use the existing services; gallery snapshots remain quiet.
struct CinematicWidgetFace: View {
    let instance: WidgetInstance
    let services: AppServices
    @Environment(\.widgetIsPreview) private var isPreview
    @Environment(\.widgetRefreshScale) private var refreshScale
    static func supports(_ kind: WidgetKind) -> Bool { [.weather, .calendar, .system, .focus, .nowPlaying, .clock].contains(kind) }
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            Group {
                switch instance.kind {
                case .weather: weather(size)
                case .calendar:
                    if !isPreview, instance.options.showEvents, services.calendar.access == .granted, !services.calendar.events.isEmpty {
                        CalendarWidget(instance: instance, calendar: services.calendar)
                    } else { calendar(size) }
                case .system:
                    system(size).contentShape(Rectangle())
                        .onTapGesture { if !isPreview { services.openWindow(.monitor) } }
                case .focus: focus(size)
                case .nowPlaying: music(size)
                case .clock: analog(size)
                default: Color.clear
                }
            }
            .frame(width: size.width, height: size.height)
            .foregroundStyle(.white).environment(\.colorScheme, .dark)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: min(28, size.height * 0.13)))
            .overlay(RoundedRectangle(cornerRadius: min(28, size.height * 0.13)).strokeBorder(.white.opacity(0.14)))
        }
    }
    @ViewBuilder private var surface: some View {
        switch instance.material {
        case .photo: CinemaImage(name: focusBackground)
        case .mesh: LinearGradient(colors: [.indigo, .purple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .outline: Color.black.opacity(0.2)
        case .paper: Color(red: 0.19, green: 0.25, blue: 0.38)
        case .tinted: Color(instance.tint)
        default: Color(red: 0.025, green: 0.035, blue: 0.055).opacity(0.92)
        }
    }
    private func weather(_ size: CGSize) -> some View {
        let location = instance.options.location
        let report = location.flatMap { services.weather.reports[$0] }
        let interval = instance.options.refresh.interval(for: .weather).map { $0 * refreshScale }
        return ZStack(alignment: .leading) {
            weatherSurface
            if let report, report.current.isDay, [1, 2].contains(report.current.code), let art = CinemaArtwork.image("cinema-weather-day.png") {
                Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: size.width * 0.61, height: size.height * 0.80).clipped()
                    .frame(width: size.width, height: size.height, alignment: .bottomTrailing)
            } else if let report {
                WeatherSymbol(code: report.current.code, isDay: report.current.isDay, size: size.height * 0.51)
                    .shadow(color: Color.yellow.opacity(report.current.isDay ? 0.5 : 0), radius: 14)
                    .frame(width: size.width * 0.49, height: size.height).frame(maxWidth: .infinity, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: size.height * 0.065) {
                Text(location?.name ?? "Choose a city").font(.system(size: max(11, size.height * 0.067)))
                Text(report.map { temperature($0.current.temperature) } ?? "—°")
                    .font(.system(size: size.height * 0.26, weight: .regular)).monospacedDigit()
                Text(report.map { WeatherCondition.description(code: $0.current.code) } ?? "Loading weather…")
                    .font(.system(size: max(11, size.height * 0.064))).lineLimit(1)
                Spacer(minLength: 0)
                if let day = report?.days.first {
                    Text("H: \(temperature(day.high))  L: \(temperature(day.low))").font(.system(size: max(9, size.height * 0.056))).foregroundStyle(.white.opacity(0.8))
                }
            }.padding(size.height * 0.13).frame(width: size.width * 0.7, height: size.height, alignment: .leading)
        }
        .widgetRefresh(every: interval, id: location) {
            if let location { await services.weather.refresh(location, maxAge: interval ?? WeatherService.refreshInterval) }
        }
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder private var weatherSurface: some View {
        switch instance.material {
        case .tinted, .frosted, .photo:
            LinearGradient(colors: [Color(red: 0.055, green: 0.17, blue: 0.34), Color(red: 0.19, green: 0.36, blue: 0.57)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .mesh: LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .outline: Color.black.opacity(0.1)
        default: Color(red: 0.03, green: 0.05, blue: 0.10)
        }
    }
    private func temperature(_ value: Double) -> String {
        let value = services.settings.temperatureUnit == .fahrenheit ? value * 9 / 5 + 32 : value
        return "\(Int(value.rounded()))°"
    }
    private func calendar(_ size: CGSize) -> some View {
        WidgetTimeline(.everyMinute) { context in
            let calendar = Calendar.current
            let days = MonthLayout.days(for: context.date, calendar: calendar)
            let symbols = MonthLayout.weekdaySymbols(calendar)
            let today = calendar.component(.day, from: context.date)
            VStack(alignment: .leading, spacing: size.height * 0.035) {
                Text(WidgetDateFormat.string(context.date, template: "MMMMy")).font(.system(size: size.height * 0.072, weight: .medium))
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        ForEach(symbols.indices, id: \.self) { index in
                            Text(symbols[index]).font(.system(size: size.height * 0.055)).foregroundStyle(.white.opacity(0.65)).frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(0..<(days.count / 7), id: \.self) { week in
                        GridRow {
                            ForEach(0..<7, id: \.self) { weekday in
                                let day = days[week * 7 + weekday]
                                Text(day.map(String.init) ?? "").font(.system(size: size.height * 0.057))
                                    .frame(width: size.height * 0.115, height: size.height * 0.115)
                                    .background(RoundedRectangle(cornerRadius: 5).fill(day == today ? .blue : .clear))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }.padding(.horizontal, size.width * 0.11).padding(.vertical, size.height * 0.1)
        }.accessibilityLabel("Calendar month")
    }
    private func system(_ size: CGSize) -> some View {
        let readings: any SystemReadings = isPreview ? services.monitor.calm : services.monitor
        return VStack(spacing: size.height * 0.13) {
            history("CPU", fraction: readings.snapshot.cpu.total, values: readings.cpuHistory.values, color: .cyan, height: size.height * 0.17)
            history("RAM", fraction: readings.snapshot.memory.usedFraction, values: readings.memoryHistory.values, color: .purple, height: size.height * 0.17)
        }.padding(.horizontal, size.width * 0.095).padding(.vertical, size.height * 0.12)
    }
    private func history(_ title: String, fraction: Double, values: [Double], color: Color, height: CGFloat) -> some View {
        let samples = Array(values.suffix(24))
        return VStack(spacing: 7) {
            HStack { Text(title); Spacer(); Text(Format.percent(fraction)).monospacedDigit() }.font(.system(size: height * 0.46))
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { index in
                    let value = samples.isEmpty ? fraction : samples[min(index, samples.count - 1)]
                    RoundedRectangle(cornerRadius: 2).fill(color.opacity(index < samples.count || samples.isEmpty ? 0.85 : 0.25))
                        .frame(height: max(4, min(1, max(0, value)) * height))
                }
            }.frame(height: height, alignment: .bottom)
        }.accessibilityElement(children: .ignore).accessibilityLabel("\(title) \(Format.percent(fraction)), recent history")
    }
    private func focus(_ size: CGSize) -> some View {
        let options = instance.options, session = options.focus
        return WidgetTimeline(.periodic(from: .now, by: session.isRunning ? 1 : 3600)) { context in
            let remaining = session.remaining(at: context.date, focusMinutes: options.focusMinutes, breakMinutes: options.breakMinutes)
            let progress = session.progress(at: context.date, focusMinutes: options.focusMinutes, breakMinutes: options.breakMinutes)
            ZStack {
                Circle().stroke(.purple.opacity(0.28), lineWidth: size.height * 0.058)
                Circle().trim(from: 0, to: 1 - progress)
                    .stroke(AngularGradient(colors: [.purple, Color(red: 0.77, green: 0.31, blue: 1), .purple], center: .center), style: StrokeStyle(lineWidth: size.height * 0.058, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 8) {
                    Text(FocusSession.clock(remaining)).font(.system(size: size.height * 0.17)).monospacedDigit()
                    Button { toggleFocus() } label: { Image(systemName: session.isRunning ? "pause.fill" : "play.fill").font(.system(size: size.height * 0.09)) }
                        .buttonStyle(.plain).accessibilityLabel(session.isRunning ? "Pause focus timer" : "Start focus timer")
                }
            }.padding(size.height * 0.10).frame(width: size.width, height: size.height)
                .background {
                    if instance.material != .dark && instance.material != .paper && instance.material != .outline {
                        CinemaImage(name: focusBackground)
                        LinearGradient(colors: [.purple.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                    }
                }
        }
        // Phases finish in AppServices.focusTimers, not in the view.
    }
    private var focusBackground: String {
        if case .bundled(let name) = instance.options.background { return name }
        return StudioScenery.widgets
    }
    private func toggleFocus() {
        services.widgets.update(instance.id) { widget in
            if widget.options.focus.isRunning { widget.options.focus.pause(at: .now) }
            else { widget.options.focus.start(at: .now, focusMinutes: widget.options.focusMinutes, breakMinutes: widget.options.breakMinutes) }
        }
    }
    private func music(_ size: CGSize) -> some View {
        let media = services.media, info = media.info
        return HStack(spacing: size.width * 0.055) {
            Group {
                if let art = media.artwork { Image(nsImage: art).resizable().aspectRatio(contentMode: .fill) }
                else { CinemaImage(name: StudioScenery.orbit) }
            }.frame(width: size.width * 0.36, height: size.height * 0.8).clipped().clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 9) {
                Text(info?.title ?? "Nothing playing").font(.system(size: size.height * 0.084, weight: .medium)).lineLimit(1)
                Text(info?.artist ?? "Play music to begin").font(.system(size: size.height * 0.066)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                Spacer(minLength: 0)
                WidgetTimeline(.periodic(from: .now, by: info?.isPlaying == true ? 1 : 3600)) { context in
                    VStack(spacing: 5) {
                        GeometryReader { g in
                            Capsule().fill(.white.opacity(0.2))
                            Capsule().fill(.white.opacity(0.8)).frame(width: g.size.width * (info?.progress(at: context.date) ?? 0))
                        }.frame(height: 2)
                        HStack { Text(info.map { FocusSession.clock($0.elapsed(at: context.date)) } ?? "—:—"); Spacer(); Text(info?.duration.map(FocusSession.clock) ?? "—:—") }.font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                    }
                }
                HStack(spacing: 5) {
                    musicButton("backward.end.fill", action: media.previousTrack)
                    musicButton(info?.isPlaying == true ? "pause.fill" : "play.fill", action: media.togglePlayPause)
                    musicButton("forward.end.fill", action: media.nextTrack)
                }.disabled(info == nil).opacity(info == nil ? 0.45 : 1)
            }
        }.padding(.horizontal, size.width * 0.07).padding(.vertical, size.height * 0.1)
    }
    private func musicButton(_ symbol: String, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 13)).frame(maxWidth: .infinity, minHeight: 28) }.buttonStyle(.plain)
            .accessibilityLabel(symbol.contains("backward") ? "Previous track" : symbol.contains("forward") ? "Next track" : "Play or pause")
    }
    private func analog(_ size: CGSize) -> some View {
        WidgetTimeline(.periodic(from: .now, by: instance.options.showSeconds ? 1 : 60)) { context in
            ZStack {
                if [.photo, .frosted, .dark, .tinted].contains(instance.material) {
                    CinemaImage(name: StudioScenery.widgets).opacity(instance.material == .photo ? 0.9 : 0.45)
                    Color.black.opacity(instance.material == .photo ? 0.15 : 0.4)
                }
                CinemaDial(date: context.date, zone: instance.options.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current, showSeconds: instance.options.showSeconds).padding(size.height * 0.04)
            }
        }
    }
}
