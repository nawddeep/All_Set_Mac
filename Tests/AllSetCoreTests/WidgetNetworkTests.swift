import Foundation
import Testing
@testable import AllSetCore

/// Review P5: failures back off, forecast and air errors are kept apart, and a
/// fetch belongs to the widgets waiting on it.
@Suite @MainActor struct WidgetNetworkTests {
    private let pune = WeatherLocation(name: "Pune", latitude: 18.52, longitude: 73.86)

    /// Counts calls; fails, succeeds, or hangs until cancelled.
    private final class Probe: @unchecked Sendable {
        enum Mode { case fail, succeed, hang }
        private let lock = NSLock()
        private var _mode: Mode
        private var _calls = 0
        private var _sawCancel = false
        init(_ mode: Mode) { _mode = mode }
        var mode: Mode { get { lock.withLock { _mode } } set { lock.withLock { _mode = newValue } } }
        var calls: Int { lock.withLock { _calls } }
        var sawCancel: Bool { lock.withLock { _sawCancel } }

        func call<Value>(_ value: Value) async throws -> Value {
            let mode = lock.withLock { _calls += 1; return _mode }
            switch mode {
            case .fail: throw URLError(.notConnectedToInternet)
            case .succeed: return value
            case .hang:
                do { try await Task.sleep(for: .seconds(30)) } catch {
                    lock.withLock { _sawCancel = true }
                    throw error
                }
                return value
            }
        }
    }

    private static let report = WeatherReport(
        current: .init(temperature: 21, feelsLike: 20, humidity: 40, windSpeed: 9, code: 1, isDay: true),
        hours: [], days: [], timeZone: .gmt, fetchedAt: .now)
    /// Never the network.
    private static let noAir: WeatherService.Fetch<AirQualityReport> = { _ in throw URLError(.notConnectedToInternet) }

    @Test func backoffDoublesUpToTheLongestWait() {
        var backoff = RetryBackoff(first: 60, longest: 600)
        let now = Date()
        #expect(backoff.allows("k", at: now))
        backoff.failed("k", at: now)
        #expect(!backoff.allows("k", at: now.addingTimeInterval(59)))
        #expect(backoff.allows("k", at: now.addingTimeInterval(60)))
        backoff.failed("k", at: now)
        #expect(backoff.retryAt("k") == now.addingTimeInterval(120))
        for _ in 0..<10 { backoff.failed("k", at: now) }
        #expect(backoff.retryAt("k") == now.addingTimeInterval(600))
        backoff.failed("k", at: now, atLeast: 3600)
        #expect(backoff.retryAt("k") == now.addingTimeInterval(3600))
        backoff.succeeded("k")
        #expect(backoff.allows("k", at: now))
    }

    @Test func aFailedForecastIsNotRetriedEveryMinute() async {
        let probe = Probe(.fail)
        let weather = WeatherService(cacheURL: nil, forecast: { _ in try await probe.call(Self.report) }, airQuality: Self.noAir)
        await weather.refresh(pune)
        #expect(probe.calls == 1)
        #expect(weather.forecastFailures[pune] != nil)
        // The widget's loop asks again a minute later: still waiting out the failure.
        await weather.refresh(pune)
        await weather.refresh(pune)
        #expect(probe.calls == 1)
        // Refresh Now always asks.
        probe.mode = .succeed
        await weather.refreshNow(pune)
        #expect(probe.calls == 2)
        #expect(weather.reports[pune] != nil && weather.forecastFailures[pune] == nil)
    }

    @Test func forecastAndAirQualityFailuresAreKeptApart() async {
        let air = AirQualityReport(usAQI: 40, pm25: nil, pm10: nil, ozone: nil, nitrogenDioxide: nil, hourly: [], fetchedAt: .now)
        let weather = WeatherService(cacheURL: nil,
                                     forecast: { _ in throw URLError(.timedOut) },
                                     airQuality: { _ in air })
        await weather.refresh(pune)
        await weather.refreshAirQuality(pune)
        #expect(weather.forecastFailures[pune] != nil)
        #expect(weather.airQualityFailures[pune] == nil)
        #expect(weather.airQuality[pune] == air)
    }

    @Test func leavingTheScreenCancelsTheFetchWithoutCallingItAFailure() async throws {
        let probe = Probe(.hang)
        let weather = WeatherService(cacheURL: nil, forecast: { _ in try await probe.call(Self.report) }, airQuality: Self.noAir)
        let widget = Task { await weather.refresh(pune) }
        for _ in 0..<50 where probe.calls == 0 { try await Task.sleep(for: .milliseconds(10)) }
        widget.cancel()
        await widget.value
        for _ in 0..<50 where !probe.sawCancel { try await Task.sleep(for: .milliseconds(10)) }
        #expect(probe.sawCancel)
        #expect(weather.forecastFailures[pune] == nil)
        // Not held against the next widget either.
        probe.mode = .succeed
        await weather.refresh(pune)
        #expect(weather.reports[pune] != nil)
    }

    @Test func aSharedFetchSurvivesWhileAnyWidgetStillWaits() async throws {
        let requests = SharedRequests()
        let started = Probe(.succeed)
        var finished = false
        var cancelled = false
        let work: @MainActor () async -> Void = {
            _ = try? await started.call(())
            do { try await Task.sleep(for: .milliseconds(300)); finished = true } catch { cancelled = true }
        }
        let first = Task { await requests.run("k", work) }
        let second = Task { await requests.run("k", work) }
        for _ in 0..<50 where started.calls == 0 { try await Task.sleep(for: .milliseconds(10)) }
        first.cancel()
        await second.value
        #expect(started.calls == 1)   // one request for both
        #expect(finished && !cancelled)

        finished = false
        let third = Task { await requests.run("k", work) }
        let fourth = Task { await requests.run("k", work) }
        for _ in 0..<50 where started.calls == 1 { try await Task.sleep(for: .milliseconds(10)) }
        third.cancel()
        fourth.cancel()
        await third.value
        await fourth.value
        for _ in 0..<50 where !cancelled { try await Task.sleep(for: .milliseconds(10)) }
        #expect(cancelled && !finished)
        #expect(!requests.isRunning("k"))
    }

    @Test func gitHubFailuresBackOffPerCredential() async {
        let probe = Probe(.fail)
        var scope = "tokenA"
        let config = GitHubConfig(mode: .activity, user: "someone")
        let github = GitHubService(cacheURL: nil, scope: { scope }, fetch: { _ in try await probe.call(GitHubData.events([])) })
        await github.refresh(config, maxAge: 60)
        await github.refresh(config, maxAge: 60)
        #expect(probe.calls == 1)
        #expect(github.error(config) != nil)
        // A different token isn't held to the first one's failures.
        scope = "tokenB"
        await github.refresh(config, maxAge: 60)
        #expect(probe.calls == 2)
    }

    @Test func aRefusedTokenWaitsTheLongestAndSaysWhy() async {
        let probe = Probe(.succeed)
        let config = GitHubConfig(mode: .activity, user: "someone")
        let github = GitHubService(cacheURL: nil, scope: { "tokenA" }, fetch: { _ in
            _ = try await probe.call(())
            throw GitHubClient.Failure.unauthorized
        })
        await github.refresh(config, maxAge: 60)
        #expect(github.error(config)?.contains("token") == true)
        await github.refresh(config, maxAge: 60)
        #expect(probe.calls == 1)
    }
}
