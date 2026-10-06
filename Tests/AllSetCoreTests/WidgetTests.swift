import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite @MainActor struct WidgetStoreTests {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AllSetTests-\(UUID().uuidString)")
            .appendingPathComponent("widgets.json")
    }

    @Test func savesAndReloadsTheLayout() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        let store = WidgetStore(fileURL: file)
        #expect(!store.hasSavedLayout)
        let clock = store.add(WidgetInstance(kind: .clock, offset: CGPoint(x: 24, y: 24)))
        let note = store.add(WidgetInstance(kind: .note))
        store.update(clock.id) {
            $0.size = .large
            $0.options.use24Hour = true
        }
        store.update(note.id) { $0.options.noteText = "Buy milk" }
        store.saveNow()

        let reloaded = WidgetStore(fileURL: file)
        #expect(reloaded.hasSavedLayout)
        #expect(reloaded.widgets.count == 2)
        #expect(reloaded.instance(clock.id)?.size == .large)
        #expect(reloaded.instance(clock.id)?.options.use24Hour == true)
        #expect(reloaded.instance(clock.id)?.offset == CGPoint(x: 24, y: 24))
        #expect(reloaded.instance(note.id)?.options.noteText == "Buy milk")

        reloaded.remove(note.id)
        reloaded.saveNow()
        #expect(WidgetStore(fileURL: file).widgets.map(\.id) == [clock.id])
    }

    @Test func skipsWidgetsItDoesNotUnderstand() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let id = UUID()
        // A kind from a newer version, and a widget saved before options existed.
        try Data("""
            [{"id":"\(UUID().uuidString)","kind":"stocks","size":"small"},
             {"id":"\(id.uuidString)","kind":"clock","size":"medium","offset":[40,56]}]
            """.utf8).write(to: file)

        let store = WidgetStore(fileURL: file)
        #expect(store.widgets.count == 1)
        let clock = try #require(store.instance(id))
        #expect(clock.size == .medium)
        #expect(clock.offset == CGPoint(x: 40, y: 56))
        #expect(clock.material == .glass)
        #expect(clock.options == WidgetOptions())
    }
}

@Suite struct WidgetLayoutTests {
    private let screen = CGSize(width: 1470, height: 922)

    @Test func snapsToTheGridAndStaysOnScreen() {
        let size = WidgetSize.small.dimensions
        #expect(WidgetLayout.snap(CGPoint(x: 27, y: 21), size: size, within: screen) == CGPoint(x: 24, y: 24))
        #expect(WidgetLayout.snap(CGPoint(x: -40, y: 5000), size: size, within: screen) == CGPoint(x: 0, y: 922 - 168))
    }

    @Test func findsTheFirstFreeSpotDownTheLeftColumn() {
        let small = WidgetSize.small.dimensions
        let first = CGRect(origin: CGPoint(x: WidgetLayout.margin, y: WidgetLayout.margin), size: small)
        let spot = WidgetLayout.freeOffset(for: small, avoiding: [first], within: screen)
        #expect(spot == CGPoint(x: WidgetLayout.margin, y: WidgetLayout.margin + 168 + 16))
        #expect(WidgetLayout.freeOffset(for: small, avoiding: [], within: screen) == CGPoint(x: WidgetLayout.margin, y: WidgetLayout.margin))
    }

    @Test func starterSetFitsTogetherWithoutOverlapping() {
        let widgets = WidgetLayout.starterSet(screenName: "Built-in")
        #expect(widgets.map(\.kind) == [.clock, .calendar, .system])
        let frames = widgets.map { CGRect(origin: $0.offset, size: $0.size.dimensions) }
        for (index, frame) in frames.enumerated() {
            for other in frames[(index + 1)...] {
                #expect(!frame.intersects(other.insetBy(dx: 1, dy: 1)))
            }
        }
        // The two small widgets line up under the medium clock.
        #expect(frames[2].maxX == frames[0].maxX)
    }
}

@Suite struct WeatherTests {
    @Test func decodesAnOpenMeteoForecast() throws {
        let json = """
            {"latitude":18.52,"longitude":73.87,"utc_offset_seconds":19800,"timezone":"Asia/Kolkata",
             "current":{"time":1790190900,"interval":900,"temperature_2m":23.2,"apparent_temperature":26.6,
                        "relative_humidity_2m":92,"is_day":0,"weather_code":3,"wind_speed_10m":9.4},
             "hourly":{"time":[1790186400,1790190000,1790193600,1790197200],
                       "temperature_2m":[23.5,23.2,null,22.8],"weather_code":[3,3,2,61],"is_day":[0,0,0,1]},
             "daily":{"time":[1790101800,1790188200],"weather_code":[61,3],
                      "temperature_2m_max":[29.1,30.2],"temperature_2m_min":[21.9,22.1]}}
            """
        let report = try WeatherClient.decodeForecast(Data(json.utf8), now: Date(timeIntervalSince1970: 1790190900))
        #expect(report.current.temperature == 23.2)
        #expect(report.current.humidity == 92)
        #expect(report.current.code == 3)
        #expect(!report.current.isDay)
        #expect(report.timeZone.identifier == "Asia/Kolkata")
        // Drops hours more than an hour old and hours with missing values.
        #expect(report.hours.map(\.date.timeIntervalSince1970) == [1790190000, 1790197200])
        #expect(report.hours.last?.isDay == true)
        #expect(report.days.count == 2)
        #expect(report.days.first?.high == 29.1)
    }

    @Test func decodesPlaceSearchResults() throws {
        let json = """
            {"results":[{"id":1,"name":"Pune","latitude":18.51957,"longitude":73.85535,
                         "admin1":"Maharashtra","country":"India"}]}
            """
        let places = try WeatherClient.decodeLocations(Data(json.utf8))
        #expect(places.first?.fullName == "Pune, Maharashtra, India")
        #expect(try WeatherClient.decodeLocations(Data("{}".utf8)).isEmpty)
    }

    @Test func mapsConditionCodesToSymbols() {
        #expect(WeatherCondition.symbol(code: 0, isDay: true) == "sun.max.fill")
        #expect(WeatherCondition.symbol(code: 0, isDay: false) == "moon.stars.fill")
        #expect(WeatherCondition.symbol(code: 63, isDay: true) == "cloud.rain.fill")
        #expect(WeatherCondition.symbol(code: 95, isDay: true) == "cloud.bolt.rain.fill")
        #expect(WeatherCondition.description(code: 2) == "Partly Cloudy")
        #expect(WeatherCondition.sky(code: 75) == .snow)
    }
}

@Suite struct CalendarLayoutTests {
    private func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }

    @Test func laysOutAMonthInWeeks() {
        // 1 September 2026 is a Tuesday.
        let sundayFirst = MonthLayout.days(for: date("2026-09-15T12:00:00Z"), calendar: calendar(firstWeekday: 1))
        #expect(sundayFirst.count == 35)
        #expect(sundayFirst[0] == nil && sundayFirst[1] == nil)
        #expect(sundayFirst[2] == 1)
        #expect(sundayFirst[31] == 30)
        #expect(sundayFirst[32...].allSatisfy { $0 == nil })

        let mondayFirst = MonthLayout.days(for: date("2026-09-15T12:00:00Z"), calendar: calendar(firstWeekday: 2))
        #expect(mondayFirst[1] == 1)
        #expect(MonthLayout.weekdaySymbols(calendar(firstWeekday: 2)) == ["M", "T", "W", "T", "F", "S", "S"])
    }

    @Test func describesWhenEventsHappen() {
        let calendar = calendar(firstWeekday: 1)
        let locale = Locale(identifier: "en_US_POSIX")
        let now = date("2026-09-24T10:00:00Z")
        func label(_ start: String, _ end: String, allDay: Bool = false) -> String {
            // Formatters put a narrow no-break space before AM/PM.
            EventTiming.label(start: date(start), end: date(end), isAllDay: allDay, now: now, calendar: calendar, locale: locale)
                .replacingOccurrences(of: "\u{202F}", with: " ")
        }
        #expect(label("2026-09-24T10:30:00Z", "2026-09-24T11:00:00Z") == "10:30 AM – 11:00 AM")
        #expect(label("2026-09-24T09:30:00Z", "2026-09-24T10:30:00Z") == "Now · until 10:30 AM")
        #expect(label("2026-09-25T09:00:00Z", "2026-09-25T09:30:00Z") == "Tomorrow 9:00 AM")
        #expect(label("2026-09-26T14:00:00Z", "2026-09-26T15:00:00Z") == "Sat 2:00 PM")
        #expect(label("2026-09-24T00:00:00Z", "2026-09-25T00:00:00Z", allDay: true) == "All day")
        #expect(label("2026-09-25T00:00:00Z", "2026-09-26T00:00:00Z", allDay: true) == "Tomorrow · All day")
    }
}

@Suite struct AestheticsTests {
    @Test func artLibraryCoversEveryStyleAndPalette() {
        #expect(ArtPiece.all.count == ArtStyle.allCases.count * ArtPalette.allCases.count)
        #expect(Set(ArtPiece.all.map(\.id)).count == ArtPiece.all.count)
        #expect(ArtPalette.allCases.allSatisfy { $0.colors.count == 5 })
        #expect(ArtPalette.pastel.isLight)
        #expect(!ArtPalette.midnight.isLight)
    }

    @Test func everyKindBelongsToAGalleryCategory() {
        let listed = WidgetCategory.allCases.flatMap(\.kinds)
        #expect(Set(listed) == Set(WidgetKind.allCases))
        #expect(listed.count == WidgetKind.allCases.count)
    }

    @Test func imageSourcesSurviveARoundTrip() throws {
        var options = WidgetOptions()
        options.images = [
            .art(ArtPiece(style: .synthwave, palette: .neon)),
            .web(WebPhoto(id: "1015", author: "Alexey Topolyanskiy", width: 6000, height: 4000)),
            .file("ABC.jpg"),
        ]
        options.slideshowInterval = 600
        options.photoFilter = .vintage
        options.countdownDate = Date(timeIntervalSince1970: 1_800_000_000)
        let decoded = try JSONDecoder().decode(WidgetOptions.self, from: JSONEncoder().encode(options))
        #expect(decoded == options)
    }

    @Test func olderLayoutsGainTheNewDefaults() throws {
        let decoded = try JSONDecoder().decode(WidgetOptions.self, from: Data(#"{"noteText":"hi"}"#.utf8))
        #expect(decoded.noteText == "hi")
        #expect(decoded.images.isEmpty)
        #expect(decoded.photoFrame == .fullBleed)
        #expect(decoded.art == ArtPiece(style: .blobs, palette: .sunset))
    }

    @Test func newKindsStartWithSensibleLooks() {
        #expect(WidgetInstance(kind: .ambient).material == .art)
        #expect(WidgetInstance(kind: .quote).material == .art)
        #expect(WidgetInstance(kind: .countdown).options.countdownDate != nil)
        #expect(WidgetInstance(kind: .photo).options.images.count == 1)
    }

    @Test func decodesThePhotoList() throws {
        let json = #"[{"id":"10","author":"Paul Jarvis","width":2500,"height":1667,"url":"https://unsplash.com/x","download_url":"https://picsum.photos/id/10/2500/1667"}]"#
        let photos = try ImageLibrary.decodePhotoList(Data(json.utf8))
        #expect(photos == [WebPhoto(id: "10", author: "Paul Jarvis", width: 2500, height: 1667)])
        #expect(photos[0].displayURL.absoluteString == "https://picsum.photos/id/10/2400/1600")
    }

    @Test func quotesRotateHourly() {
        let hour = Date(timeIntervalSince1970: 3600 * 1000)
        #expect(Affirmations.line(at: hour) == Affirmations.line(at: hour.addingTimeInterval(1800)))
        #expect(Affirmations.line(at: hour) != Affirmations.line(at: hour.addingTimeInterval(3600)))
    }
}

@Suite struct SearchAndWallpaperTests {
    @Test func decodesOpenverseResults() throws {
        let json = """
            {"result_count":240,"page_count":12,"page":1,"results":[
              {"id":"abc","title":"Rocky sunset","creator":"slack12","license":"by-sa","license_version":"2.0",
               "provider":"flickr","width":1024,"height":576,"url":"https://live.staticflickr.com/x_b.jpg",
               "thumbnail":"https://api.openverse.org/v1/images/abc/thumb/"},
              {"id":"pd","creator":null,"license":"cc0","width":null,"height":null,"url":"https://example.com/p.jpg","thumbnail":null},
              {"id":"broken","url":null}
            ]}
            """
        let decoded = try PhotoSearch.decode(Data(json.utf8))
        #expect(decoded.pageCount == 12)
        #expect(decoded.photos.map(\.id) == ["abc", "pd"])
        let first = decoded.photos[0]
        #expect(first.provider == "openverse")
        #expect(first.license == "CC BY-SA 2.0")
        #expect(first.credit == "slack12 · CC BY-SA 2.0")
        #expect(first.displayURL.absoluteString == "https://live.staticflickr.com/x_b.jpg")
        #expect(first.thumbnailURL().absoluteString == "https://api.openverse.org/v1/images/abc/thumb/")
        #expect(decoded.photos[1].license == "CC0")
        #expect(decoded.photos[1].author == "Unknown")
    }

    @Test func photosSavedBeforeSearchStillLoad() throws {
        // A Picsum photo as saved by the previous version: no provider or URLs.
        let old = #"{"web":{"_0":{"id":"1015","author":"Alexey","width":6000,"height":4000}}}"#
        let source = try JSONDecoder().decode(ImageSource.self, from: Data(old.utf8))
        guard case .web(let photo) = source else { Issue.record("expected a web photo"); return }
        #expect(photo.provider == nil)
        #expect(photo.displayURL.absoluteString == "https://picsum.photos/id/1015/2400/1600")
    }

    @Test @MainActor func wallpaperSettingsPersistWithDefaults() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AllSetWallpaper-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }

        let store = WallpaperStore(directory: folder)
        #expect(!store.config.isEnabled)
        store.set(.art(ArtPiece(style: .synthwave, palette: .neon)))
        store.config.dim = 0.3
        store.config.frameRate = 15

        let reloaded = WallpaperStore(directory: folder)
        #expect(reloaded.config.isEnabled)
        #expect(reloaded.config.source == .art(ArtPiece(style: .synthwave, palette: .neon)))
        #expect(reloaded.config.dim == 0.3)
        #expect(reloaded.config.frameRate == 15)

        let partial = try JSONDecoder().decode(WallpaperConfig.self, from: Data(#"{"isEnabled":true}"#.utf8))
        #expect(partial.isEnabled)
        #expect(partial.frameRate == 30)
        #expect(partial.matchSystemWallpaper)
    }

    @Test func recognizesVideoFiles() {
        #expect(WallpaperStore.isVideo(URL(fileURLWithPath: "/tmp/loop.mp4")))
        #expect(WallpaperStore.isVideo(URL(fileURLWithPath: "/tmp/loop.MOV")))
        #expect(!WallpaperStore.isVideo(URL(fileURLWithPath: "/tmp/photo.jpg")))
    }
}
