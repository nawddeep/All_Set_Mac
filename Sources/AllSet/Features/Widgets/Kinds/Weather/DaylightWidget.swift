import AllSetCore
import SwiftUI

/// The sky as it is right now where you are: pink and gold at dawn, blue by
/// day, orange at sunset, stars and the moon at night, with the sun on its
/// arc between the day's sunrise and sunset.
struct DaylightWidget: View {
    let instance: WidgetInstance
    /// A city another widget (Weather) was given, used until this one has its own.
    let fallbackLocation: WeatherLocation?

    /// Worked out once: reading the time zone table on every redraw would be waste.
    @MainActor private static let guessedPlace = TimeZonePlace.guess()
    @Environment(\.widgetDate) private var fixedDate

    var body: some View {
        let place = instance.options.location ?? fallbackLocation ?? Self.guessedPlace
        WidgetTimeline(.periodic(from: .now, by: 60)) { context in
            DaylightScene(date: fixedDate ?? context.date, place: place, size: instance.size, use24Hour: instance.options.use24Hour)
        }
        .environment(\.colorScheme, .dark)
    }
}

private struct DaylightScene: View {
    let date: Date
    let place: WeatherLocation
    let size: WidgetSize
    let use24Hour: Bool

    var body: some View {
        let elevation = Sun.elevation(at: date, latitude: place.latitude, longitude: place.longitude)
        let day = Sun.day(around: date, latitude: place.latitude, longitude: place.longitude)
        let morning = date < day.noon
        let sky = SkyPalette.sky(elevation: elevation, morning: morning)

        GeometryReader { geometry in
            let bounds = geometry.size
            let horizon = bounds.height * (size == .large ? 0.74 : 0.72)
            let arc = SunArc(day: day, place: place, width: bounds.width, horizon: horizon,
                             height: horizon - (size == .small ? 82 : size == .medium ? 54 : 150))
            ZStack(alignment: .topLeading) {
                LinearGradient(stops: [
                    .init(color: sky.top, location: 0),
                    .init(color: sky.middle, location: horizon / bounds.height * 0.62),
                    .init(color: sky.horizon, location: horizon / bounds.height),
                ], startPoint: .top, endPoint: .bottom)

                Starfield()
                    .opacity(SkyPalette.starOpacity(elevation: elevation))
                    .mask(LinearGradient(colors: [.white, .white.opacity(0.2)], startPoint: .top,
                                         endPoint: UnitPoint(x: 0.5, y: horizon / bounds.height)))

                // Light pooling on the horizon where the sun is, or just was.
                if let glow = arc.glowPoint(at: date, elevation: elevation) {
                    EllipticalGradient(colors: [SkyPalette.sunColor(elevation: max(elevation, 0)).opacity(glow.strength), .clear],
                                       center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
                        .frame(width: bounds.width * 1.3, height: horizon * 0.9)
                        .position(glow.point)
                        .blendMode(.screen)
                }

                arc.path
                    .stroke(.white.opacity(0.32), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1.5, 4.5]))

                if let sun = arc.sunPoint(at: date, elevation: elevation) {
                    SunDisc(elevation: elevation, radius: size == .large ? 11 : 8)
                        .position(sun)
                } else if day.alwaysUp != true {
                    MoonDisc(phase: MoonPhase(date: date))
                        .frame(width: size == .large ? 46 : 30, height: size == .large ? 46 : 30)
                        .position(x: bounds.width * 0.8, y: size == .large ? 64 : bounds.height * 0.28)
                        .opacity(SkyPalette.starOpacity(elevation: elevation) * 0.9 + 0.1)
                }

                Hills(horizon: horizon, sky: sky)

                labels(day: day, elevation: elevation, morning: morning, bounds: bounds, horizon: horizon)
            }
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func labels(day: Sun.Day, elevation: Double, morning: Bool, bounds: CGSize, horizon: CGFloat) -> some View {
        let status = Self.status(at: date, day: day, elevation: elevation, morning: morning,
                                 place: place, clock: clock)
        VStack(alignment: .leading, spacing: 1) {
            Text(clock(date))
                .font(.system(size: size == .small ? 34 : size == .medium ? 38 : 56, weight: .light, design: .rounded))
                .monospacedDigit()
            Text(status)
                .font(.system(size: size == .large ? 13 : 11, weight: .semibold))
                .opacity(0.85)
                .lineLimit(1)
            if size == .large {
                Text(place.name)
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.6)
                    .padding(.top, 2)
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        .padding(.leading, 16)
        .padding(.top, size == .small ? 12 : 14)

        // Sunrise and sunset, standing on the hills.
        if let sunrise = day.sunrise, let sunset = day.sunset {
            HStack(alignment: .lastTextBaseline) {
                event("sunrise.fill", sunrise)
                Spacer(minLength: 4)
                if size != .small, let length = day.length {
                    Text(Self.duration(length) + " of light")
                        .opacity(0.7)
                }
                Spacer(minLength: 4)
                event("sunset.fill", sunset)
            }
            .font(.system(size: size == .large ? 12 : size == .medium ? 10.5 : 10, weight: .semibold).monospacedDigit())
            .symbolRenderingMode(.multicolor)
            .opacity(0.85)
            .padding(.horizontal, 14)
            .padding(.bottom, size == .small ? 10 : 12)
            .frame(width: bounds.width, height: bounds.height, alignment: .bottom)
        }
    }

    private func clock(_ date: Date) -> String {
        (use24Hour ? Self.format24 : Self.format12).string(from: date)
    }

    /// Sunrise and sunset say AM or PM, so 5:25 and 5:31 can't be confused.
    private func event(_ symbol: String, _ date: Date) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
            Text((use24Hour ? Self.format24 : Self.formatEvent).string(from: date))
        }
        .lineLimit(1)
        .fixedSize()
    }

    @MainActor private static let formatEvent: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    @MainActor private static let format12: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter
    }()

    @MainActor private static let format24: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    /// A few words on what the light is doing.
    static func status(at date: Date, day: Sun.Day, elevation: Double, morning: Bool,
                       place: WeatherLocation, clock: (Date) -> String) -> String {
        if let alwaysUp = day.alwaysUp { return alwaysUp ? "Midnight sun" : "Polar night" }
        guard let sunrise = day.sunrise, let sunset = day.sunset else { return "" }
        func until(_ event: Date) -> String { duration(event.timeIntervalSince(date)) }
        if date < sunrise {
            return elevation > -6 ? "Blue hour · sunrise in \(until(sunrise))" : "Sunrise at \(clock(sunrise))"
        }
        if date > sunset {
            if elevation > -6 { return "Blue hour" }
            if elevation > -12 { return "Twilight" }
            let next = Sun.day(around: date.addingTimeInterval(86_400), latitude: place.latitude, longitude: place.longitude)
            return next.sunrise.map { "Sunrise at \(clock($0))" } ?? "Night"
        }
        if elevation < 6 {
            return morning ? "Golden hour" : "Golden hour · sunset in \(until(sunset))"
        }
        if sunset.timeIntervalSince(date) < 90 * 60 { return "Sunset in \(until(sunset))" }
        if morning, date.timeIntervalSince(sunrise) < 60 * 60 { return "Morning light" }
        return "Sunset at \(clock(sunset))"
    }
}

/// The sun's path across the widget: sunrise at the left edge, sunset at the
/// right, as high as the sun really climbs.
private struct SunArc {
    let day: Sun.Day
    let place: WeatherLocation
    let width: CGFloat
    let horizon: CGFloat
    /// Space above the horizon for the highest point.
    let height: CGFloat

    private let inset: CGFloat = 22

    /// The day's highest elevation, for scaling.
    private var peak: Double {
        max(Sun.elevation(at: day.noon, latitude: place.latitude, longitude: place.longitude), 5)
    }

    /// A smooth arch through the day; lower on short winter days, whose sun stays low.
    private func point(at date: Date) -> CGPoint? {
        guard let sunrise = day.sunrise, let sunset = day.sunset else { return nil }
        let fraction = date.timeIntervalSince(sunrise) / sunset.timeIntervalSince(sunrise)
        let x = inset + (width - inset * 2) * fraction
        let y = horizon - height * sin(.pi * min(max(fraction, 0), 1)) * min(0.45 + peak / 120, 1)
        return CGPoint(x: x, y: y)
    }

    var path: Path {
        var path = Path()
        guard let sunrise = day.sunrise, let sunset = day.sunset else { return path }
        let steps = 48
        for step in 0...steps {
            let date = sunrise.addingTimeInterval(sunset.timeIntervalSince(sunrise) * Double(step) / Double(steps))
            guard let point = point(at: date) else { continue }
            step == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }

    /// Where to draw the sun, while it's up.
    func sunPoint(at date: Date, elevation: Double) -> CGPoint? {
        if day.alwaysUp == true {
            return CGPoint(x: width / 2, y: horizon - height * max(elevation, 0) / peak)
        }
        guard let sunrise = day.sunrise, let sunset = day.sunset, date >= sunrise, date <= sunset else { return nil }
        return point(at: date)
    }

    /// Where the horizon glows, and how brightly: around the sun when it's
    /// low, and where it rose or set during twilight.
    func glowPoint(at date: Date, elevation: Double) -> (point: CGPoint, strength: Double)? {
        guard elevation > -12, elevation < 20 else { return nil }
        let strength = elevation >= 0 ? 0.75 * (1 - elevation / 20) : 0.75 * (1 + elevation / 12)
        guard let sunrise = day.sunrise, let sunset = day.sunset else { return nil }
        let x: CGFloat
        if date < sunrise {
            x = inset
        } else if date > sunset {
            x = width - inset
        } else {
            x = point(at: date)?.x ?? width / 2
        }
        return (CGPoint(x: x, y: horizon), strength)
    }
}

/// A soft, glowing sun: orange near the horizon, near white up high.
private struct SunDisc: View {
    let elevation: Double
    let radius: CGFloat

    var body: some View {
        let color = SkyPalette.sunColor(elevation: elevation)
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [color.opacity(0.55), color.opacity(0)], center: .center,
                                     startRadius: radius * 0.8, endRadius: radius * 4))
                .frame(width: radius * 8, height: radius * 8)
            Circle()
                .fill(RadialGradient(colors: [.white, color], center: .center, startRadius: 0, endRadius: radius * 1.1))
                .frame(width: radius * 2, height: radius * 2)
        }
        .blendMode(.screen)
    }
}

/// Two layers of hills along the bottom, fading into the sky's own colors.
private struct Hills: View {
    let horizon: CGFloat
    let sky: SkyPalette.Sky

    var body: some View {
        Canvas { context, size in
            func hill(base: CGFloat, amplitude: CGFloat, waves: [(Double, Double)]) -> Path {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                for step in 0...60 {
                    let x = size.width * CGFloat(step) / 60
                    let t = Double(x / size.width)
                    let rise = waves.reduce(0.0) { $0 + sin(t * $1.0 + $1.1) } / Double(waves.count)
                    path.addLine(to: CGPoint(x: x, y: base - amplitude * CGFloat(rise)))
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
                return path
            }
            context.fill(hill(base: horizon + 2, amplitude: 9, waves: [(7.1, 0.4), (3.3, 2.1), (13, 1)]),
                         with: .color(sky.farHills))
            context.fill(hill(base: horizon + 16, amplitude: 11, waves: [(4.2, 3.3), (9.5, 0.2)]),
                         with: .linearGradient(Gradient(colors: [sky.nearHills, sky.nearHills.opacity(0.92)]),
                                               startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: size.height)))
        }
        .allowsHitTesting(false)
    }
}

/// Sky colors through the day, keyed by how high the sun is. Mornings run a
/// little cooler and pinker than evenings.
enum SkyPalette {
    struct Sky {
        var top: Color
        var middle: Color
        var horizon: Color
        var farHills: Color
        var nearHills: Color
    }

    private typealias RGB = (Double, Double, Double)
    /// (elevation, top, horizon)
    private typealias Stop = (Double, RGB, RGB)

    private static let evening: [Stop] = [
        (-90, (0.01, 0.012, 0.04), (0.035, 0.05, 0.12)),
        (-18, (0.012, 0.02, 0.06), (0.06, 0.08, 0.2)),
        (-12, (0.04, 0.06, 0.17), (0.15, 0.13, 0.32)),
        (-6, (0.1, 0.12, 0.3), (0.45, 0.26, 0.48)),
        (-3, (0.16, 0.22, 0.47), (0.82, 0.4, 0.46)),
        (0, (0.23, 0.35, 0.63), (0.96, 0.54, 0.34)),
        (3, (0.29, 0.47, 0.74), (0.98, 0.7, 0.4)),
        (8, (0.25, 0.53, 0.83), (0.96, 0.83, 0.6)),
        (20, (0.18, 0.5, 0.84), (0.66, 0.84, 0.96)),
        (45, (0.12, 0.44, 0.82), (0.55, 0.78, 0.95)),
        (90, (0.1, 0.4, 0.8), (0.52, 0.76, 0.95)),
    ]

    private static let morning: [Stop] = [
        (-90, (0.01, 0.012, 0.04), (0.035, 0.05, 0.12)),
        (-18, (0.012, 0.02, 0.06), (0.06, 0.08, 0.2)),
        (-12, (0.05, 0.07, 0.19), (0.16, 0.15, 0.36)),
        (-6, (0.12, 0.15, 0.34), (0.4, 0.3, 0.55)),
        (-3, (0.18, 0.26, 0.52), (0.88, 0.52, 0.6)),
        (0, (0.25, 0.39, 0.66), (0.97, 0.63, 0.54)),
        (3, (0.32, 0.52, 0.78), (0.99, 0.79, 0.56)),
        (8, (0.29, 0.56, 0.85), (0.95, 0.89, 0.72)),
        (20, (0.18, 0.5, 0.84), (0.66, 0.84, 0.96)),
        (45, (0.12, 0.44, 0.82), (0.55, 0.78, 0.95)),
        (90, (0.1, 0.4, 0.8), (0.52, 0.76, 0.95)),
    ]

    static func sky(elevation: Double, morning isMorning: Bool) -> Sky {
        let stops = isMorning ? morning : evening
        let upper = stops.firstIndex { $0.0 >= elevation } ?? stops.count - 1
        let lower = max(upper - 1, 0)
        let span = stops[upper].0 - stops[lower].0
        let t = span > 0 ? (elevation - stops[lower].0) / span : 0
        let top = mix(stops[lower].1, stops[upper].1, t)
        let horizon = mix(stops[lower].2, stops[upper].2, t)
        let middle = mix(top, horizon, 0.45)
        // Hills: dark shapes that still pick up the sky's color, farther ones hazier.
        let far = mix(mix(horizon, top, 0.55), (0, 0, 0), 0.5)
        let near = mix(top, (0.01, 0.01, 0.03), 0.8)
        return Sky(top: color(top), middle: color(middle), horizon: color(horizon), farHills: color(far), nearHills: color(near))
    }

    static func sunColor(elevation: Double) -> Color {
        let low: RGB = (1, 0.45, 0.24)
        let mid: RGB = (1, 0.8, 0.5)
        let high: RGB = (1, 0.97, 0.88)
        if elevation < 10 { return color(mix(low, mid, max(elevation, 0) / 10)) }
        return color(mix(mid, high, min((elevation - 10) / 25, 1)))
    }

    /// Stars come out as the sky darkens.
    static func starOpacity(elevation: Double) -> Double {
        min(max((-elevation - 6) / 8, 0), 1)
    }

    private static func mix(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        let t = min(max(t, 0), 1)
        return (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
    }

    private static func color(_ rgb: RGB) -> Color {
        Color(.sRGB, red: rgb.0, green: rgb.1, blue: rgb.2)
    }
}
