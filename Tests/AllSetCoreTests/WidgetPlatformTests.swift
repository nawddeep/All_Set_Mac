import CoreGraphics
import Foundation
import Observation
import Testing
@testable import AllSetCore

@Suite struct DesignThemeTests {
    @Test func themesResolveAppearance() {
        let native = DesignTheme.native
        #expect(native.followsAppearance)
        #expect(native.isDark(.auto, systemIsDark: true))
        #expect(!native.isDark(.auto, systemIsDark: false))
        #expect(native.isDark(.dark, systemIsDark: false))
        #expect(!native.isDark(.light, systemIsDark: true))
        // One-look themes ignore the setting.
        #expect(DesignTheme.amoled.isDark(.light, systemIsDark: false))
        #expect(!DesignTheme.retroMac.isDark(.dark, systemIsDark: true))
        #expect(Set(DesignTheme.all.map(\.id)).count == DesignTheme.all.count)
        #expect(DesignTheme.all.count == 15)
    }

    @Test func palettesHaveReadableInk() {
        for theme in DesignTheme.all {
            for isDark in [false, true] {
                let palette = theme.palette(dark: isDark)
                let contrast = abs(palette.ink.luminance - palette.background.luminance)
                #expect(contrast > 0.5, "\(theme.id) \(isDark ? "dark" : "light") ink doesn't stand out")
            }
        }
    }

    @Test func wallpaperAccentsAreToned() {
        let neon = WidgetColor(red: 1, green: 0, blue: 0.9)
        let onDark = neon.adjusted(forDark: true), onLight = neon.adjusted(forDark: false)
        #expect(onDark.hsv.1 <= 0.721 && onLight.hsv.1 <= 0.721)
        #expect(onDark.luminance > onLight.luminance)
        let back = WidgetColor(hue: 0.5, saturation: 0.5, value: 0.8)
        #expect(abs(back.hsv.0 - 0.5) < 0.01 && abs(back.hsv.2 - 0.8) < 0.01)
    }

    @Test func wallpaperColorFindsTheColorfulPart() {
        let side = 32
        let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.setFillColor(CGColor(red: 0.1, green: 0.4, blue: 0.95, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side / 3, height: side))
        let accent = WallpaperColor.accent(of: context.makeImage()!)
        #expect(accent != nil)
        #expect((accent?.blue ?? 0) > (accent?.red ?? 1))
        let gray = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                             space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        gray.setFillColor(CGColor(gray: 0.4, alpha: 1))
        gray.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        #expect(WallpaperColor.accent(of: gray.makeImage()!) == nil)
    }

    @Test func refreshPoliciesPace() {
        #expect(RefreshPolicy.live.interval(for: .systemStats) == 1)
        #expect(RefreshPolicy.relaxed.interval(for: .weather) == 3600)
        #expect(RefreshPolicy.manual.interval(for: .github) == nil)
        for data in [RefreshData.systemStats, .wifi, .weather, .github, .status] {
            #expect(RefreshPolicy.live.interval(for: data)! < RefreshPolicy.relaxed.interval(for: data)!)
        }
    }
}

@Suite struct CatalogTests {
    @Test func everyEntryIsDistinctAndMakesItsKind() {
        #expect(Set(WidgetCatalog.entries.map(\.id)).count == WidgetCatalog.entries.count)
        for entry in WidgetCatalog.entries {
            #expect(!entry.sizes.isEmpty)
            #expect(entry.sizes.allSatisfy { entry.kind.supportedSizes.contains($0) }, "\(entry.id) offers a size its kind can't draw")
            #expect(entry.sizes.contains(entry.defaultSize))
            let made = entry.make()
            #expect(made.kind == entry.kind && made.size == entry.defaultSize)
        }
        for category in WidgetCategory.allCases {
            #expect(!WidgetCatalog.entries(in: category).isEmpty, "\(category) is empty")
        }
        // Every kind can be found in the gallery.
        #expect(Set(WidgetCatalog.entries.map(\.kind)) == Set(WidgetKind.allCases))
    }

    @Test func presetsConfigureTheirWidgets() {
        #expect(WidgetCatalog.entry("wifi")?.make().options.metric == .wifi)
        #expect(WidgetCatalog.entry("worldClock")?.make().options.clockFace == .world)
        #expect(WidgetCatalog.entry("ciStatus")?.make().options.github.mode == .actions)
        #expect(WidgetCatalog.entry("pomodoro")?.make().options.focusMinutes == 25)
        #expect(WidgetCatalog.entry("focusTimer")?.make().options.focusMinutes == 50)
        // Default options stay equal, so the store's no-change check works.
        #expect(WidgetCatalog.entry("goals")?.make().options.goals == WidgetOptions().goals)
    }
}

@Suite @MainActor struct StoreObservationTests {
    @Test func readingOneWidgetIgnoresChangesToAnother() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("widgets-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let store = WidgetStore(fileURL: file)
        let a = store.add(WidgetInstance(kind: .clock))
        let b = store.add(WidgetInstance(kind: .note))

        final class Flag: @unchecked Sendable { var fired = false }
        let flag = Flag()
        withObservationTracking {
            _ = store.instance(a.id)
        } onChange: {
            flag.fired = true
        }
        store.update(b.id) { $0.options.noteText = "typing…" }
        #expect(!flag.fired, "a change to B redrew A")
        store.update(a.id) { $0.options.use24Hour = true }
        #expect(flag.fired)
        #expect(store.instance(a.id)?.options.use24Hour == true)
        #expect(store.instance(b.id)?.options.noteText == "typing…")

        let removed = Flag()
        withObservationTracking { _ = store.instance(a.id) } onChange: { removed.fired = true }
        store.remove(b.id)
        #expect(removed.fired, "A's reader should hear that the list changed")
        #expect(store.instance(b.id) == nil)
        store.replaceAll(with: [])
        #expect(store.instance(a.id) == nil)
    }
}

@Suite struct DeveloperDataTests {
    /// Review D3: cached GitHub data (possibly private) belongs to the credential
    /// that fetched it; another token, or none, never sees it.
    @Test @MainActor func cachedGitHubDataIsScopedToTheCredential() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetGitHub-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = folder.appendingPathComponent("github.json")
        let config = GitHubConfig(mode: .activity, user: "someone")
        let key = GitHubService.key(config)
        let snapshot = GitHubService.Snapshot(data: .events([]), fetched: .now)
        try JSONEncoder().encode(["tokenA|" + key: snapshot, "tokenB|" + key: snapshot]).write(to: cache)

        let asA = GitHubService(cacheURL: cache, scope: { "tokenA" })
        #expect(asA.snapshot(config) != nil)
        // Loading as A dropped B's entry from disk as well.
        let onDisk = try JSONDecoder().decode([String: GitHubService.Snapshot].self, from: Data(contentsOf: cache))
        #expect(Array(onDisk.keys) == ["tokenA|" + key])

        let asB = GitHubService(cacheURL: cache, scope: { "tokenB" })
        #expect(asB.snapshot(config) == nil)
        let anonymous = GitHubService(cacheURL: cache, scope: { "anonymous" })
        #expect(anonymous.snapshot(config) == nil)

        asA.purgeCache()
        #expect(asA.snapshot(config) == nil)
        #expect(!FileManager.default.fileExists(atPath: cache.path))

        // A fingerprint, never the token itself.
        #expect(GitHubKeychain.fingerprint("ghp_secret") != "ghp_secret")
        #expect(GitHubKeychain.fingerprint("ghp_secret").count == 16)
        #expect(GitHubKeychain.fingerprint(nil) == "anonymous")
    }

    @Test func contributionsParseFromTheProfilePage() {
        let html = """
        <td tabindex="0" data-ix="0" style="width: 10px" data-date="2026-09-20" id="contribution-day-component-0-0" data-level="0" role="gridcell" class="ContributionCalendar-day"></td>
        <td tabindex="0" data-ix="1" style="width: 10px" data-date="2026-09-21" id="contribution-day-component-1-0" data-level="2" role="gridcell" class="ContributionCalendar-day"></td>
        <td tabindex="0" data-ix="2" style="width: 10px" data-date="2026-09-22" id="contribution-day-component-2-0" data-level="4" role="gridcell" class="ContributionCalendar-day"></td>
        <tool-tip id="t1" for="contribution-day-component-0-0" popover="manual">No contributions on September 20th.</tool-tip>
        <tool-tip id="t2" for="contribution-day-component-1-0" popover="manual">5 contributions on September 21st.</tool-tip>
        <tool-tip id="t3" for="contribution-day-component-2-0" popover="manual">1,204 contributions on September 22nd.</tool-tip>
        """
        let parsed = GitHubClient.parseContributions(html)
        #expect(parsed.days.map(\.date) == ["2026-09-20", "2026-09-21", "2026-09-22"])
        #expect(parsed.days.map(\.level) == [0, 2, 4])
        #expect(parsed.total == 1209)
        #expect(parsed.streak == 2)
    }

    @Test func actionsRunsDecode() throws {
        let json = """
        {"workflow_runs":[{"id":1,"name":"CI","status":"completed","conclusion":"failure","head_branch":"main","run_number":42,
          "created_at":"2026-09-25T10:00:00Z","html_url":"https://github.com/o/r/actions/runs/1"},
          {"id":2,"name":"CI","status":"in_progress","conclusion":null,"head_branch":"dev","run_number":43,
          "created_at":"2026-09-25T11:00:00Z","html_url":"https://github.com/o/r/actions/runs/2"}]}
        """
        let runs = try GitHubClient.decodeRuns(Data(json.utf8))
        #expect(runs.map(\.outcome) == [.failed, .running])
        #expect(runs[0].number == 42)
    }

    @Test func configsKnowWhatTheyNeed() {
        #expect(!GitHubService.isConfigured(GitHubConfig(mode: .contributions)))
        #expect(GitHubService.isConfigured(GitHubConfig(mode: .contributions, user: "octocat")))
        #expect(!GitHubService.isConfigured(GitHubConfig(mode: .actions, user: "octocat", repository: "swift")))
        #expect(GitHubService.isConfigured(GitHubConfig(mode: .actions, repository: "apple/swift")))
        #expect(GitHubService.key(GitHubConfig(mode: .activity, user: "OctoCat")) == GitHubService.key(GitHubConfig(mode: .activity, user: "octocat")))
    }

    @Test func statusPagesAreRead() {
        let ok = StatusService.statusPage(Data(#"{"status":{"indicator":"none","description":"All Systems Operational"}}"#.utf8))
        #expect(ok?.health == .up && ok?.message == "All Systems Operational")
        #expect(StatusService.statusPage(Data(#"{"status":{"indicator":"major","description":"Major Outage"}}"#.utf8))?.health == .down)
        #expect(StatusService.statusPage(Data("<html>".utf8)) == nil)
        #expect(StatusService.url("example.com")?.absoluteString == "https://example.com")
        // Review P6: only scheme and host fold case; paths and queries keep theirs.
        #expect(StatusService.key("HTTPS://Example.COM/Health") == StatusService.key("https://example.com/Health"))
        #expect(StatusService.key("example.com") == StatusService.key("https://EXAMPLE.com/"))
        #expect(StatusService.key("https://example.com/Status") != StatusService.key("https://example.com/status"))
        #expect(StatusService.key("https://example.com/s?token=AbC") != StatusService.key("https://example.com/s?token=abc"))
    }
}

@Suite struct LifeDataTests {
    @Test func habitsCountStreaks() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let today = Date(timeIntervalSince1970: 1_790_000_000)
        var habit = Habit(title: "Read", symbol: "book.fill")
        for back in 1...3 { habit.toggle(on: calendar.date(byAdding: .day, value: -back, to: today)!, calendar: calendar) }
        // Not done yet today: the streak still counts.
        #expect(habit.streak(until: today, calendar: calendar) == 3)
        habit.toggle(on: today, calendar: calendar)
        #expect(habit.isDone(on: today, calendar: calendar))
        #expect(habit.streak(until: today, calendar: calendar) == 4)
        habit.toggle(on: calendar.date(byAdding: .day, value: -2, to: today)!, calendar: calendar)
        #expect(habit.streak(until: today, calendar: calendar) == 2)
    }

    @Test func goalsAndBooksReportProgress() {
        var goal = DailyGoal(title: "Water", symbol: "drop.fill", unit: "glasses", target: 8, progress: 6)
        #expect(goal.fraction == 0.75)
        goal.progress = 12
        #expect(goal.fraction == 1)
        var book = ReadingBook()
        book.page = 144
        book.pages = 288
        #expect(book.fraction == 0.5)
    }

    @Test func airQualityDecodesAndBands() throws {
        let json = """
        {"current":{"us_aqi":80,"pm2_5":23.8,"pm10":30.5,"ozone":125.0,"nitrogen_dioxide":6.2},
         "hourly":{"time":[1790000000,1790003600],"us_aqi":[70,null]}}
        """
        let report = try WeatherClient.decodeAirQuality(Data(json.utf8), now: Date(timeIntervalSince1970: 1_790_000_000))
        #expect(report.usAQI == 80 && report.level == .moderate && report.hourly == [70])
        #expect(AirQualityReport.Level(aqi: 20) == .good && AirQualityReport.Level(aqi: 160) == .unhealthy)
    }

    @Test func weatherReportsSurviveTheDiskCache() throws {
        let report = WeatherReport(current: .init(temperature: 21, feelsLike: 20, humidity: 40, windSpeed: 9, code: 1, isDay: true),
                                   hours: [.init(date: Date(timeIntervalSince1970: 0), temperature: 20, code: 2, isDay: true, precipitation: 30)],
                                   days: [.init(date: Date(timeIntervalSince1970: 0), code: 3, high: 24, low: 14, sunrise: Date(timeIntervalSince1970: 100),
                                                sunset: nil, uvIndex: 6.5, precipitation: 10)],
                                   timeZone: TimeZone(identifier: "Asia/Kolkata")!, fetchedAt: Date(timeIntervalSince1970: 5))
        let copy = try JSONDecoder().decode(WeatherReport.self, from: JSONEncoder().encode(report))
        #expect(copy == report)
    }
}

@Suite struct DeepLinkTests {
    @Test func linksRoundTrip() {
        let id = UUID()
        for link in [DeepLink.page("monitor"), .widget(id), .arrange, .fit, .theme("liquidGlass"), .focus(.start)] {
            #expect(DeepLink(link.url) == link)
        }
        #expect(DeepLink(URL(string: "allset://open/Monitor")!) == .page("monitor"))
        #expect(DeepLink(URL(string: "allset://widget/not-a-uuid")!) == nil)
        #expect(DeepLink(URL(string: "https://open/monitor")!) == nil)
        #expect(DeepLink(URL(string: "allset://focus/explode")!) == nil)
    }
}
