import Foundation
import Observation
import OSLog

public struct WeatherReport: Codable, Equatable, Sendable {
    public struct Current: Codable, Equatable, Sendable {
        public var temperature: Double
        public var feelsLike: Double
        public var humidity: Int
        /// km/h
        public var windSpeed: Double
        public var code: Int
        public var isDay: Bool
    }

    public struct Hour: Codable, Equatable, Identifiable, Sendable {
        public var date: Date
        public var temperature: Double
        public var code: Int
        public var isDay: Bool
        /// Chance of rain or snow, 0...100.
        public var precipitation: Int?
        public var id: Date { date }
    }

    public struct Day: Codable, Equatable, Identifiable, Sendable {
        public var date: Date
        public var code: Int
        public var high: Double
        public var low: Double
        public var sunrise: Date?
        public var sunset: Date?
        public var uvIndex: Double?
        public var precipitation: Int?
        public var id: Date { date }
    }

    public var current: Current
    /// From the current hour onward.
    public var hours: [Hour]
    /// From today onward.
    public var days: [Day]
    /// The location's time zone, for labelling hours and days.
    public var timeZone: TimeZone
    public var fetchedAt: Date
}

/// Air quality from Open-Meteo, on the US AQI scale.
public struct AirQualityReport: Codable, Equatable, Sendable {
    public var usAQI: Int
    /// Micrograms per cubic meter.
    public var pm25: Double?
    public var pm10: Double?
    public var ozone: Double?
    public var nitrogenDioxide: Double?
    /// The rest of today, hour by hour.
    public var hourly: [Int]
    public var fetchedAt: Date

    /// The EPA's bands.
    public enum Level: Int, Sendable {
        case good, moderate, sensitive, unhealthy, veryUnhealthy, hazardous

        public init(aqi: Int) {
            self = switch aqi {
            case ..<51: .good
            case ..<101: .moderate
            case ..<151: .sensitive
            case ..<201: .unhealthy
            case ..<301: .veryUnhealthy
            default: .hazardous
            }
        }

        public var title: String {
            switch self {
            case .good: "Good"
            case .moderate: "Moderate"
            case .sensitive: "Unhealthy for Sensitive Groups"
            case .unhealthy: "Unhealthy"
            case .veryUnhealthy: "Very Unhealthy"
            case .hazardous: "Hazardous"
            }
        }

        public var shortTitle: String { self == .sensitive ? "Sensitive" : title }

        public var advice: String {
            switch self {
            case .good: "A great day to be outside."
            case .moderate: "Fine for most people."
            case .sensitive: "Take it easy if you're sensitive to air."
            case .unhealthy: "Limit long time outdoors."
            case .veryUnhealthy: "Stay in if you can."
            case .hazardous: "Stay indoors."
            }
        }

        /// The official color, as hex.
        public var color: Int {
            switch self {
            case .good: 0x34C759
            case .moderate: 0xFFCC00
            case .sensitive: 0xFF9500
            case .unhealthy: 0xFF3B30
            case .veryUnhealthy: 0xAF52DE
            case .hazardous: 0x8E2A3A
            }
        }
    }

    public var level: Level { Level(aqi: usAQI) }
}

/// WMO weather interpretation codes, as Open-Meteo reports them.
public enum WeatherCondition {
    public static func symbol(code: Int, isDay: Bool) -> String {
        switch code {
        case 0: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1: isDay ? "sun.max.fill" : "moon.fill"
        case 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51, 53, 55: "cloud.drizzle.fill"
        case 56, 57, 66, 67: "cloud.sleet.fill"
        case 61, 63: "cloud.rain.fill"
        case 65: "cloud.heavyrain.fill"
        case 71, 73, 75, 85, 86: "cloud.snow.fill"
        case 77: "snowflake"
        case 80, 81: isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case 82: "cloud.heavyrain.fill"
        case 95: "cloud.bolt.rain.fill"
        case 96, 99: "cloud.hail.fill"
        default: "cloud.fill"
        }
    }

    public static func description(code: Int) -> String {
        switch code {
        case 0: "Clear"
        case 1: "Mostly Clear"
        case 2: "Partly Cloudy"
        case 3: "Cloudy"
        case 45, 48: "Fog"
        case 51, 53, 55: "Drizzle"
        case 56, 57: "Freezing Drizzle"
        case 61: "Light Rain"
        case 63: "Rain"
        case 65: "Heavy Rain"
        case 66, 67: "Freezing Rain"
        case 71, 73, 75: "Snow"
        case 77: "Snow Grains"
        case 80, 81, 82: "Showers"
        case 85, 86: "Snow Showers"
        case 95: "Thunderstorms"
        case 96, 99: "Hailstorms"
        default: "Unknown"
        }
    }

    /// Broad sky for picking a background.
    public enum Sky: Sendable {
        case clear
        case cloudy
        case wet
        case storm
        case snow
    }

    public static func sky(code: Int) -> Sky {
        switch code {
        case 0, 1, 2: .clear
        case 3, 45, 48: .cloudy
        case 71, 73, 75, 77, 85, 86: .snow
        case 95, 96, 99: .storm
        default: .wet
        }
    }
}

/// Client for Open-Meteo (open-meteo.com): free, no API key, CC BY 4.0 data.
public struct WeatherClient: Sendable {
    public init() {}

    public func searchLocations(_ query: String) async throws -> [WeatherLocation] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: "en"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try Self.decodeLocations(data)
    }

    public func forecast(for location: WeatherLocation, now: Date = .now) async throws -> WeatherReport {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,is_day,weather_code,wind_speed_10m"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,is_day,precipitation_probability"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: "6"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try Self.decodeForecast(data, now: now)
    }

    public func airQuality(for location: WeatherLocation, now: Date = .now) async throws -> AirQualityReport {
        var components = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "us_aqi,pm2_5,pm10,ozone,nitrogen_dioxide"),
            URLQueryItem(name: "hourly", value: "us_aqi"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try Self.decodeAirQuality(data, now: now)
    }

    static func decodeAirQuality(_ data: Data, now: Date) throws -> AirQualityReport {
        struct Response: Decodable {
            struct Current: Decodable {
                var us_aqi: Double?
                var pm2_5: Double?
                var pm10: Double?
                var ozone: Double?
                var nitrogen_dioxide: Double?
            }
            struct Hourly: Decodable {
                var time: [Double]
                var us_aqi: [Double?]
            }
            var current: Current
            var hourly: Hourly?
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        let hourly = response.hourly.map { hourly in
            hourly.time.indices.compactMap { index -> Int? in
                guard Date(timeIntervalSince1970: hourly.time[index]) > now.addingTimeInterval(-3600),
                      let value = hourly.us_aqi[safe: index] ?? nil else { return nil }
                return Int(value.rounded())
            }
        } ?? []
        return AirQualityReport(usAQI: Int((response.current.us_aqi ?? 0).rounded()), pm25: response.current.pm2_5,
                                pm10: response.current.pm10, ozone: response.current.ozone,
                                nitrogenDioxide: response.current.nitrogen_dioxide, hourly: hourly, fetchedAt: now)
    }

    // MARK: Decoding

    private struct LocationResults: Decodable {
        struct Result: Decodable {
            var name: String
            var latitude: Double
            var longitude: Double
            var admin1: String?
            var country: String?
        }
        var results: [Result]?
    }

    // Explicit keys: `.convertFromSnakeCase` turns "temperature_2m" into
    // "temperature2M", which is easy to get wrong.
    private struct Forecast: Decodable {
        struct Current: Decodable {
            var temperature: Double
            var apparentTemperature: Double
            var relativeHumidity: Double
            var isDay: Int
            var weatherCode: Int
            var windSpeed: Double

            enum CodingKeys: String, CodingKey {
                case temperature = "temperature_2m"
                case apparentTemperature = "apparent_temperature"
                case relativeHumidity = "relative_humidity_2m"
                case isDay = "is_day"
                case weatherCode = "weather_code"
                case windSpeed = "wind_speed_10m"
            }
        }
        struct Hourly: Decodable {
            var time: [Double]
            var temperature: [Double?]
            var weatherCode: [Int?]
            var isDay: [Int?]
            var precipitation: [Int?]?

            enum CodingKeys: String, CodingKey {
                case time
                case temperature = "temperature_2m"
                case weatherCode = "weather_code"
                case isDay = "is_day"
                case precipitation = "precipitation_probability"
            }
        }
        struct Daily: Decodable {
            var time: [Double]
            var weatherCode: [Int?]
            var high: [Double?]
            var low: [Double?]
            var sunrise: [Double?]?
            var sunset: [Double?]?
            var uvIndex: [Double?]?
            var precipitation: [Int?]?

            enum CodingKeys: String, CodingKey {
                case time
                case weatherCode = "weather_code"
                case high = "temperature_2m_max"
                case low = "temperature_2m_min"
                case sunrise, sunset
                case uvIndex = "uv_index_max"
                case precipitation = "precipitation_probability_max"
            }
        }
        var utcOffsetSeconds: Int
        var timezone: String
        var current: Current
        var hourly: Hourly
        var daily: Daily

        enum CodingKeys: String, CodingKey {
            case utcOffsetSeconds = "utc_offset_seconds"
            case timezone, current, hourly, daily
        }
    }

    static func decodeLocations(_ data: Data) throws -> [WeatherLocation] {
        try JSONDecoder().decode(LocationResults.self, from: data).results?.map {
            WeatherLocation(name: $0.name, region: $0.admin1, country: $0.country,
                            latitude: $0.latitude, longitude: $0.longitude)
        } ?? []
    }

    static func decodeForecast(_ data: Data, now: Date) throws -> WeatherReport {
        let forecast = try JSONDecoder().decode(Forecast.self, from: data)

        let hours = forecast.hourly.time.indices.compactMap { index -> WeatherReport.Hour? in
            let date = Date(timeIntervalSince1970: forecast.hourly.time[index])
            guard date > now.addingTimeInterval(-3600),
                  let temperature = forecast.hourly.temperature[safe: index] ?? nil,
                  let code = forecast.hourly.weatherCode[safe: index] ?? nil else { return nil }
            return WeatherReport.Hour(date: date, temperature: temperature, code: code,
                                      isDay: (forecast.hourly.isDay[safe: index] ?? nil) != 0,
                                      precipitation: forecast.hourly.precipitation?[safe: index] ?? nil)
        }
        let days = forecast.daily.time.indices.compactMap { index -> WeatherReport.Day? in
            guard let code = forecast.daily.weatherCode[safe: index] ?? nil,
                  let high = forecast.daily.high[safe: index] ?? nil,
                  let low = forecast.daily.low[safe: index] ?? nil else { return nil }
            let daily = forecast.daily
            return WeatherReport.Day(date: Date(timeIntervalSince1970: daily.time[index]),
                                     code: code, high: high, low: low,
                                     sunrise: (daily.sunrise?[safe: index] ?? nil).map(Date.init(timeIntervalSince1970:)),
                                     sunset: (daily.sunset?[safe: index] ?? nil).map(Date.init(timeIntervalSince1970:)),
                                     uvIndex: daily.uvIndex?[safe: index] ?? nil,
                                     precipitation: daily.precipitation?[safe: index] ?? nil)
        }
        let current = forecast.current
        return WeatherReport(
            current: .init(temperature: current.temperature, feelsLike: current.apparentTemperature,
                           humidity: Int(current.relativeHumidity.rounded()), windSpeed: current.windSpeed,
                           code: current.weatherCode, isDay: current.isDay != 0),
            hours: Array(hours.prefix(12)),
            days: days,
            timeZone: TimeZone(identifier: forecast.timezone) ?? TimeZone(secondsFromGMT: forecast.utcOffsetSeconds) ?? .current,
            fetchedAt: now
        )
    }
}

/// Keeps a report per location fresh. Widgets ask for refreshes while
/// visible; the service decides whether anything is due. Reports are kept on
/// disk, so widgets show the last forecast at once after a relaunch, and
/// offline.
@Observable @MainActor
public final class WeatherService {
    public private(set) var reports: [WeatherLocation: WeatherReport] = [:]
    public private(set) var airQuality: [WeatherLocation: AirQualityReport] = [:]
    /// Why the last forecast or air-quality fetch failed, kept apart so one
    /// doesn't hide or fake the other. Cleared by that fetch succeeding.
    public private(set) var forecastFailures: [WeatherLocation: String] = [:]
    public private(set) var airQualityFailures: [WeatherLocation: String] = [:]

    public typealias Fetch<Report> = @Sendable (WeatherLocation) async throws -> Report

    @ObservationIgnored private let requests = SharedRequests()
    @ObservationIgnored private var backoff = RetryBackoff()
    @ObservationIgnored private let fetchForecast: Fetch<WeatherReport>
    @ObservationIgnored private let fetchAirQuality: Fetch<AirQualityReport>
    @ObservationIgnored private let cacheURL: URL?
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "weather")

    public static let refreshInterval: TimeInterval = 30 * 60

    private struct Cache: Codable {
        var reports: [Stored<WeatherReport>]
        var airQuality: [Stored<AirQualityReport>]
    }

    private struct Stored<Value: Codable>: Codable {
        var location: WeatherLocation
        var value: Value
    }

    /// `cacheURL` nil keeps nothing on disk (for tests).
    public init(cacheURL: URL? = WeatherService.defaultCacheURL,
                forecast: @escaping Fetch<WeatherReport> = { try await WeatherClient().forecast(for: $0) },
                airQuality: @escaping Fetch<AirQualityReport> = { try await WeatherClient().airQuality(for: $0) }) {
        self.cacheURL = cacheURL
        fetchForecast = forecast
        fetchAirQuality = airQuality
        if let cacheURL, let data = try? Data(contentsOf: cacheURL),
           let cache = try? JSONDecoder().decode(Cache.self, from: data) {
            // Anything older than a day is too stale to show.
            let recent = Date.now.addingTimeInterval(-86_400)
            reports = Dictionary(cache.reports.filter { $0.value.fetchedAt > recent }.map { ($0.location, $0.value) },
                                 uniquingKeysWith: { first, _ in first })
            self.airQuality = Dictionary(cache.airQuality.filter { $0.value.fetchedAt > recent }.map { ($0.location, $0.value) },
                                         uniquingKeysWith: { first, _ in first })
        }
    }

    public nonisolated static var defaultCacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AllSet", isDirectory: true).appendingPathComponent("weather.json")
    }

    /// Fetches the forecast if it's older than `maxAge` and a recent failure isn't
    /// still being waited out, and waits for it. Cancelling every caller waiting
    /// on the fetch cancels it.
    public func refresh(_ location: WeatherLocation, maxAge: TimeInterval = WeatherService.refreshInterval) async {
        if let report = reports[location], Date.now.timeIntervalSince(report.fetchedAt) < maxAge { return }
        await fetch("forecast", location, using: fetchForecast, into: \.reports, failures: \.forecastFailures)
    }

    public func refreshAirQuality(_ location: WeatherLocation, maxAge: TimeInterval = WeatherService.refreshInterval) async {
        if let report = airQuality[location], Date.now.timeIntervalSince(report.fetchedAt) < maxAge { return }
        await fetch("air", location, using: fetchAirQuality, into: \.airQuality, failures: \.airQualityFailures)
    }

    /// Asked for by hand: fetches both now, whatever failed before.
    public func refreshNow(_ location: WeatherLocation) async {
        backoff.succeeded(Self.key("forecast", location))
        backoff.succeeded(Self.key("air", location))
        async let forecast: Void = refresh(location, maxAge: 0)
        async let air: Void = refreshAirQuality(location, maxAge: 0)
        _ = await (forecast, air)
    }

    /// For callers with nothing to own the fetch (previews, renders).
    public func refreshIfNeeded(_ location: WeatherLocation, maxAge: TimeInterval = WeatherService.refreshInterval) {
        Task { await refresh(location, maxAge: maxAge) }
    }

    public func refreshAirQualityIfNeeded(_ location: WeatherLocation, maxAge: TimeInterval = WeatherService.refreshInterval) {
        Task { await refreshAirQuality(location, maxAge: maxAge) }
    }

    private static func key(_ kind: String, _ location: WeatherLocation) -> String {
        "\(kind)|\(location.latitude),\(location.longitude)"
    }

    private func fetch<Report: Sendable>(_ kind: String, _ location: WeatherLocation, using fetch: @escaping Fetch<Report>,
                                         into store: ReferenceWritableKeyPath<WeatherService, [WeatherLocation: Report]>,
                                         failures: ReferenceWritableKeyPath<WeatherService, [WeatherLocation: String]>) async {
        let key = Self.key(kind, location)
        guard requests.isRunning(key) || backoff.allows(key) else { return }
        await requests.run(key) { [self] in
            do {
                let report = try await fetch(location)
                self[keyPath: store][location] = report
                self[keyPath: failures][location] = nil
                backoff.succeeded(key)
                save()
            } catch where Self.isCancellation(error) {
                // Every widget asking for it left the screen: not a failure.
            } catch {
                log.error("Weather (\(kind, privacy: .public)) for \(location.name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                self[keyPath: failures][location] = error.localizedDescription
                backoff.failed(key)
            }
        }
    }

    nonisolated static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    private func save() {
        guard let cacheURL else { return }
        let cache = Cache(reports: reports.map { Stored(location: $0.key, value: $0.value) },
                          airQuality: airQuality.map { Stored(location: $0.key, value: $0.value) })
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(cache).write(to: cacheURL, options: .atomic)
    }

    public func searchLocations(_ query: String) async throws -> [WeatherLocation] {
        try await WeatherClient().searchLocations(query)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
