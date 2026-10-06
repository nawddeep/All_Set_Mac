import Foundation

/// The moon's phase on a date, worked out from the average length of a lunar
/// month since a known new moon. Good to within about half a day.
public struct MoonPhase: Equatable, Sendable {
    public static let synodicMonth = 29.530_588_853
    /// A new moon: 6 January 2000, 18:14 UTC.
    static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)

    /// Days since the last new moon.
    public let age: Double

    public init(date: Date) {
        let days = date.timeIntervalSince(Self.referenceNewMoon) / 86_400
        let remainder = days.truncatingRemainder(dividingBy: Self.synodicMonth)
        age = remainder < 0 ? remainder + Self.synodicMonth : remainder
    }

    /// 0 at new moon, 0.5 at full.
    public var fraction: Double { age / Self.synodicMonth }

    /// How much of the face is lit, 0...1.
    public var illumination: Double { (1 - cos(2 * .pi * fraction)) / 2 }

    public var isWaxing: Bool { fraction < 0.5 }

    public enum Name: String, Sendable {
        case new = "New Moon"
        case waxingCrescent = "Waxing Crescent"
        case firstQuarter = "First Quarter"
        case waxingGibbous = "Waxing Gibbous"
        case full = "Full Moon"
        case waningGibbous = "Waning Gibbous"
        case lastQuarter = "Last Quarter"
        case waningCrescent = "Waning Crescent"
    }

    /// The four main phases each get about a day either side.
    public var name: Name {
        let day = age
        let month = Self.synodicMonth
        switch day {
        case ..<1, (month - 1)...: return .new
        case ..<(month / 4 - 1): return .waxingCrescent
        case ..<(month / 4 + 1): return .firstQuarter
        case ..<(month / 2 - 1): return .waxingGibbous
        case ..<(month / 2 + 1): return .full
        case ..<(month * 3 / 4 - 1): return .waningGibbous
        case ..<(month * 3 / 4 + 1): return .lastQuarter
        default: return .waningCrescent
        }
    }

    /// When the moon next reaches `fraction` of its cycle (0 new, 0.5 full...), after `date`.
    public static func next(_ fraction: Double, after date: Date) -> Date {
        let current = MoonPhase(date: date).fraction
        var ahead = fraction - current
        if ahead <= 0.001 { ahead += 1 }
        return date.addingTimeInterval(ahead * synodicMonth * 86_400)
    }
}

/// The time in words, to the nearest five minutes: "quarter to eleven".
public enum WordClock {
    static let hours = ["twelve", "one", "two", "three", "four", "five", "six",
                        "seven", "eight", "nine", "ten", "eleven"]

    public static func phrase(hour: Int, minute: Int) -> String {
        // To the nearest five minutes; 58 past is nearly the next hour.
        let rounded = Int((Double(minute) / 5).rounded()) * 5
        let hourNow = (rounded == 60 ? hour + 1 : hour) % 24
        let minutes = rounded % 60
        let next = (hourNow + 1) % 24
        func name(_ hour: Int) -> String {
            if hour == 0 { return "midnight" }
            if hour == 12 { return "noon" }
            return hours[hour % 12]
        }
        switch minutes {
        case 0: return hourNow == 0 || hourNow == 12 ? name(hourNow) : "\(name(hourNow)) o'clock"
        case 5: return "five past \(name(hourNow))"
        case 10: return "ten past \(name(hourNow))"
        case 15: return "quarter past \(name(hourNow))"
        case 20: return "twenty past \(name(hourNow))"
        case 25: return "twenty-five past \(name(hourNow))"
        case 30: return "half past \(name(hourNow))"
        case 35: return "twenty-five to \(name(next))"
        case 40: return "twenty to \(name(next))"
        case 45: return "quarter to \(name(next))"
        case 50: return "ten to \(name(next))"
        default: return "five to \(name(next))"
        }
    }
}

/// The sun for a place and moment, from NOAA's solar calculator equations:
/// good to about a minute for rise and set times.
public enum Sun {
    /// Degrees above the horizon (negative below), for `date` at a place.
    public static func elevation(at date: Date, latitude: Double, longitude: Double) -> Double {
        let terms = Terms(date)
        let minutes = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400) / 60
        let solarTime = (minutes + terms.equationOfTime + 4 * longitude).truncatingRemainder(dividingBy: 1440)
        let hourAngle = radians(solarTime / 4 - 180)
        let lat = radians(latitude)
        let cosZenith = sin(lat) * sin(terms.declination) + cos(lat) * cos(terms.declination) * cos(hourAngle)
        return 90 - degrees(acos(min(max(cosZenith, -1), 1)))
    }

    /// Sunrise, sunset and noon on the local day around `date`.
    public struct Day: Equatable, Sendable {
        public var sunrise: Date?
        public var sunset: Date?
        public var noon: Date
        /// With no sunrise or sunset: whether the sun stays up all day (true)
        /// or down all day (false).
        public var alwaysUp: Bool?

        public var length: TimeInterval? {
            guard let sunrise, let sunset else { return alwaysUp.map { $0 ? 86_400 : 0 } }
            return sunset.timeIntervalSince(sunrise)
        }
    }

    public static func day(around date: Date, latitude: Double, longitude: Double) -> Day {
        // Local mean midnight, then noon corrected by the equation of time.
        let offset = longitude / 360 * 86_400
        let midnight = ((date.timeIntervalSince1970 + offset) / 86_400).rounded(.down) * 86_400 - offset
        func noon(near time: TimeInterval) -> TimeInterval {
            midnight + 43_200 - Terms(Date(timeIntervalSince1970: time)).equationOfTime * 60
        }
        let solarNoon = noon(near: midnight + 43_200)

        /// Seconds from noon to when the sun is at `elevation`; nil if it never gets there.
        func halfArc(at time: TimeInterval, elevation: Double) -> Double? {
            let terms = Terms(Date(timeIntervalSince1970: time))
            let lat = radians(latitude)
            let cosHourAngle = (cos(radians(90 - elevation)) - sin(lat) * sin(terms.declination))
                / (cos(lat) * cos(terms.declination))
            guard abs(cosHourAngle) <= 1 else { return nil }
            return degrees(acos(cosHourAngle)) * 240
        }
        // The standard -0.833° allows for the sun's size and the air bending its light.
        let horizon = -0.833
        guard let firstGuess = halfArc(at: solarNoon, elevation: horizon) else {
            let up = elevation(at: Date(timeIntervalSince1970: solarNoon), latitude: latitude, longitude: longitude) > 0
            return Day(sunrise: nil, sunset: nil, noon: Date(timeIntervalSince1970: solarNoon), alwaysUp: up)
        }
        // Once more, with the sun's position at each event rather than at noon.
        func refine(_ time: TimeInterval, rising: Bool) -> Date {
            guard let arc = halfArc(at: time, elevation: horizon) else { return Date(timeIntervalSince1970: time) }
            let noonThen = noon(near: time)
            return Date(timeIntervalSince1970: rising ? noonThen - arc : noonThen + arc)
        }
        return Day(sunrise: refine(solarNoon - firstGuess, rising: true),
                   sunset: refine(solarNoon + firstGuess, rising: false),
                   noon: Date(timeIntervalSince1970: solarNoon), alwaysUp: nil)
    }

    /// The sun's declination and the equation of time for a moment.
    private struct Terms {
        var declination: Double
        /// Minutes that sundial time runs ahead of clock time.
        var equationOfTime: Double

        init(_ date: Date) {
            let julianDay = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
            let t = (julianDay - 2_451_545) / 36_525
            let meanLongitude = radians((280.46646 + t * (36000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360))
            let anomaly = radians(357.52911 + t * (35999.05029 - 0.0001537 * t))
            let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
            let center = sin(anomaly) * (1.914602 - t * (0.004817 + 0.000014 * t))
                + sin(2 * anomaly) * (0.019993 - 0.000101 * t) + sin(3 * anomaly) * 0.000289
            let omega = radians(125.04 - 1934.136 * t)
            let apparentLongitude = radians(degrees(meanLongitude) + center - 0.00569 - 0.00478 * sin(omega))
            let meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
            let obliquity = radians(meanObliquity + 0.00256 * cos(omega))
            declination = asin(sin(obliquity) * sin(apparentLongitude))
            let y = pow(tan(obliquity / 2), 2)
            equationOfTime = 4 * degrees(y * sin(2 * meanLongitude) - 2 * eccentricity * sin(anomaly)
                + 4 * eccentricity * y * sin(anomaly) * cos(2 * meanLongitude)
                - 0.5 * y * y * sin(4 * meanLongitude) - 1.25 * eccentricity * eccentricity * sin(2 * anomaly))
        }
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}

/// A rough place for a time zone, for when no city has been chosen: the
/// zone's main city, from the tz database macOS ships with.
public enum TimeZonePlace {
    public static func guess(for zone: TimeZone = .current,
                             table: String? = try? String(contentsOfFile: "/usr/share/zoneinfo/zone.tab", encoding: .utf8)) -> WeatherLocation {
        if let table, let place = lookup(zone.identifier, in: table) { return place }
        // Somewhere along the zone's meridian.
        let longitude = Double(zone.secondsFromGMT()) / 3600 * 15
        return WeatherLocation(name: zone.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? "Here",
                               latitude: 30, longitude: longitude)
    }

    /// Reads "IN	+2232+08822	Asia/Kolkata" style lines.
    static func lookup(_ identifier: String, in table: String) -> WeatherLocation? {
        for line in table.split(separator: "\n") where !line.hasPrefix("#") {
            let fields = line.split(separator: "\t")
            guard fields.count >= 3, fields[2] == identifier, let (latitude, longitude) = coordinates(String(fields[1])) else { continue }
            let city = identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? identifier
            return WeatherLocation(name: city, latitude: latitude, longitude: longitude)
        }
        return nil
    }

    /// ISO 6709: ±DDMM±DDDMM or ±DDMMSS±DDDMMSS.
    static func coordinates(_ text: String) -> (Double, Double)? {
        guard let split = text.dropFirst().firstIndex(where: { $0 == "+" || $0 == "-" }) else { return nil }
        func parse(_ part: Substring, degreeDigits: Int) -> Double? {
            guard let sign = part.first, sign == "+" || sign == "-" else { return nil }
            let digits = part.dropFirst()
            guard digits.allSatisfy(\.isNumber), digits.count == degreeDigits + 2 || digits.count == degreeDigits + 4 else { return nil }
            let values = [digits.prefix(degreeDigits), digits.dropFirst(degreeDigits).prefix(2), digits.dropFirst(degreeDigits + 2)]
                .map { Double($0) ?? 0 }
            let value = values[0] + values[1] / 60 + values[2] / 3600
            return sign == "-" ? -value : value
        }
        guard let latitude = parse(text[..<split], degreeDigits: 2), let longitude = parse(text[split...], degreeDigits: 3) else { return nil }
        return (latitude, longitude)
    }
}
