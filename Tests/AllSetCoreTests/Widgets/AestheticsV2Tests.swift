import Foundation
import Testing
@testable import AllSetCore

@Suite struct PhotoSearchQualityTests {
    @Test func dropsStickersClipArtAndSmallImages() {
        #expect(PhotoSearch.isWallpaperWorthy(title: "Lake Mountains", filetype: "jpg", width: 5475, height: 3794))
        #expect(PhotoSearch.isWallpaperWorthy(title: "Iconic bridge at night", filetype: "jpg", width: 3000, height: 2000))
        #expect(!PhotoSearch.isWallpaperWorthy(title: "Png anime girl cat sticker", filetype: "jpg", width: 4000, height: 4000))
        #expect(!PhotoSearch.isWallpaperWorthy(title: "Japanese anime girl clip art", filetype: "jpg", width: 4000, height: 4000))
        #expect(!PhotoSearch.isWallpaperWorthy(title: "Night sky", filetype: "png", width: 4000, height: 3000))
        #expect(!PhotoSearch.isWallpaperWorthy(title: "Tiny", filetype: "jpg", width: 640, height: 480))
    }

    @Test func decodesSourcesAndSkipsDuplicates() throws {
        let json = """
        {"page_count": 3, "results": [
          {"id": "a", "title": "Rain Flower", "creator": "Jo", "license": "cc0", "width": 4000, "height": 3000,
           "url": "https://pd.w.org/2026/03/abc.123-2048x1536.jpg", "thumbnail": "https://api.openverse.org/t/a", "source": "wordpress", "filetype": "jpg"},
          {"id": "b", "title": "Rain Flower", "creator": "Jo", "license": "cc0", "width": 4000, "height": 3000,
           "url": "https://pd.w.org/2026/03/abc.123-2048x1536.jpg", "source": "wordpress", "filetype": "jpg"},
          {"id": "c", "title": "Neon sticker png", "creator": "R", "width": 4000, "height": 4000,
           "url": "https://images.rawpixel.com/editor_1024/xyz.jpg", "source": "rawpixel", "filetype": "jpg"}
        ]}
        """
        let decoded = try PhotoSearch.decode(Data(json.utf8))
        #expect(decoded.photos.map(\.id) == ["a"])
        #expect(decoded.pageCount == 3)
        #expect(decoded.photos.first?.origin == "wordpress")
        #expect(decoded.photos.first?.license == "CC0")
    }

    @Test func picksSmallAndLargeCopiesPerSite() {
        let wordpress = WebPhoto(id: "a", author: "", width: 2048, height: 1152, provider: "openverse",
                                 imageURLString: "https://pd.w.org/2026/03/40469c90f57982494.02714368-2048x1152.jpg",
                                 thumbnailURLString: "https://api.openverse.org/v1/images/a/thumb/", origin: "wordpress")
        #expect(wordpress.thumbnailURL().absoluteString == "https://pd.w.org/2026/03/40469c90f57982494.02714368-768x432.jpg")
        #expect(wordpress.displayURL.absoluteString.hasSuffix("-2048x1152.jpg"))
        #expect(wordpress.fallbackThumbnailURL?.absoluteString == "https://api.openverse.org/v1/images/a/thumb/")

        let rawpixel = WebPhoto(id: "b", author: "", width: 4000, height: 3000, provider: "openverse",
                                imageURLString: "https://images.rawpixel.com/editor_1024/abc.jpg", origin: "rawpixel")
        #expect(rawpixel.thumbnailURL().absoluteString == "https://images.rawpixel.com/image_600/abc.jpg")
        #expect(rawpixel.displayURL.absoluteString == "https://images.rawpixel.com/image_1300/abc.jpg")

        let flickr = WebPhoto(id: "c", author: "", width: 1024, height: 768, provider: "openverse",
                              imageURLString: "https://live.staticflickr.com/65535/1_2_b.jpg", origin: "flickr")
        #expect(flickr.thumbnailURL().absoluteString == "https://live.staticflickr.com/65535/1_2_n.jpg")

        // Picsum and saved photos from before still work.
        let picsum = WebPhoto(id: "10", author: "", width: 2500, height: 1667)
        #expect(picsum.thumbnailURL(side: 240).absoluteString == "https://picsum.photos/id/10/240/240")
        let saved = try? JSONDecoder().decode(WebPhoto.self, from: Data(#"{"id":"1","author":"x","width":10,"height":10}"#.utf8))
        #expect(saved?.origin == nil)
    }

    @Test func curatedBackgroundsAreUniqueAndPlenty() {
        let ids = CuratedBackgrounds.all.map(\.id)
        #expect(ids.count >= 140)
        #expect(Set(ids).count == ids.count)
        #expect(CuratedBackgrounds.photo(id: "65") != nil)
        #expect(CuratedBackgrounds.photo(id: "830") != nil)
    }
}

@Suite struct WidgetMathTests {
    @Test func moonPhasesMatchKnownDates() throws {
        let formatter = ISO8601DateFormatter()
        // Full moon 7 September 2025 18:09 UTC; new moon 21 September 2025 19:54 UTC.
        let full = MoonPhase(date: try #require(formatter.date(from: "2025-09-07T18:09:00Z")))
        #expect(full.name == .full)
        #expect(full.illumination > 0.97)
        let new = MoonPhase(date: try #require(formatter.date(from: "2025-09-21T19:54:00Z")))
        #expect(new.name == .new)
        #expect(new.illumination < 0.03)
        let quarter = MoonPhase(date: try #require(formatter.date(from: "2025-09-29T23:54:00Z")))
        #expect(quarter.name == .firstQuarter)
        #expect(quarter.isWaxing)
        // The next full moon after the new one is about two weeks on.
        let next = MoonPhase.next(0.5, after: try #require(formatter.date(from: "2025-09-21T19:54:00Z")))
        let expected = try #require(formatter.date(from: "2025-10-07T03:47:00Z"))
        #expect(abs(next.timeIntervalSince(expected)) < 86_400)
    }

    @Test func wordClockReadsNaturally() {
        #expect(WordClock.phrase(hour: 10, minute: 30) == "half past ten")
        #expect(WordClock.phrase(hour: 10, minute: 44) == "quarter to eleven")
        #expect(WordClock.phrase(hour: 22, minute: 2) == "ten o'clock")
        #expect(WordClock.phrase(hour: 23, minute: 58) == "midnight")
        #expect(WordClock.phrase(hour: 11, minute: 59) == "noon")
        #expect(WordClock.phrase(hour: 0, minute: 10) == "ten past midnight")
        #expect(WordClock.phrase(hour: 14, minute: 36) == "twenty-five to three")
    }

    @Test func newWidgetOptionsSurviveSaving() throws {
        var instance = WidgetInstance(kind: .lockScreen)
        #expect(instance.material == .photo)
        instance.options.backgroundBlur = 0.4
        instance.options.depthEffect = false
        let decoded = try JSONDecoder().decode(WidgetInstance.self, from: JSONEncoder().encode(instance))
        #expect(decoded.options.background == instance.options.background)
        #expect(decoded.options.backgroundBlur == 0.4)
        #expect(!decoded.options.depthEffect)
        // Layouts saved before these options existed still load.
        let old = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","kind":"clock","size":"small","material":"glass","offset":[0,0],"options":{"use24Hour":true}}"#
        let clock = try JSONDecoder().decode(WidgetInstance.self, from: Data(old.utf8))
        #expect(clock.options.use24Hour && clock.options.background == nil && clock.options.depthEffect)
    }
}

@Suite struct SunTests {
    private let iso = ISO8601DateFormatter()

    private func expect(_ date: Date?, near text: String, minutes: Double = 4, sourceLocation: SourceLocation = #_sourceLocation) {
        guard let date, let expected = iso.date(from: text) else {
            Issue.record("No time to compare with \(text)", sourceLocation: sourceLocation)
            return
        }
        #expect(abs(date.timeIntervalSince(expected)) < minutes * 60, "\(date) vs \(text)", sourceLocation: sourceLocation)
    }

    @Test func riseAndSetMatchPublishedTimes() throws {
        // Pune, midsummer: 06:00 and 19:13 IST.
        let pune = Sun.day(around: try #require(iso.date(from: "2025-06-21T06:30:00Z")), latitude: 18.52, longitude: 73.86)
        expect(pune.sunrise, near: "2025-06-21T00:30:00Z")
        expect(pune.sunset, near: "2025-06-21T13:43:00Z")
        // London, midwinter: 08:04 and 15:54.
        let london = Sun.day(around: try #require(iso.date(from: "2025-12-21T12:00:00Z")), latitude: 51.5074, longitude: -0.1278)
        expect(london.sunrise, near: "2025-12-21T08:04:00Z")
        expect(london.sunset, near: "2025-12-21T15:54:00Z")
        // New York, midsummer: 05:25 and 20:31 EDT; sunset falls on the next UTC day.
        let newYork = Sun.day(around: try #require(iso.date(from: "2025-06-21T16:00:00Z")), latitude: 40.7128, longitude: -74.006)
        expect(newYork.sunrise, near: "2025-06-21T09:25:00Z")
        expect(newYork.sunset, near: "2025-06-22T00:31:00Z")
        #expect(abs((newYork.length ?? 0) / 3600 - 15.1) < 0.1)
    }

    @Test func polarDaysHaveNoSunriseOrSunset() throws {
        let winter = Sun.day(around: try #require(iso.date(from: "2025-12-21T11:00:00Z")), latitude: 69.65, longitude: 18.96)
        #expect(winter.sunrise == nil && winter.alwaysUp == false && winter.length == 0)
        let summer = Sun.day(around: try #require(iso.date(from: "2025-06-21T11:00:00Z")), latitude: 69.65, longitude: 18.96)
        #expect(summer.sunset == nil && summer.alwaysUp == true)
    }

    @Test func elevationFollowsTheDay() throws {
        let noon = Sun.day(around: try #require(iso.date(from: "2025-03-20T12:00:00Z")), latitude: 0, longitude: 0).noon
        #expect(Sun.elevation(at: noon, latitude: 0, longitude: 0) > 88)
        #expect(Sun.elevation(at: noon.addingTimeInterval(12 * 3600), latitude: 0, longitude: 0) < -85)
        let pune = try #require(iso.date(from: "2025-06-21T00:30:00Z"))
        #expect(abs(Sun.elevation(at: pune, latitude: 18.52, longitude: 73.86)) < 1.5)
    }

    @Test func guessesAPlaceFromTheTimeZone() throws {
        let table = "# comment\nIN\t+2232+08822\tAsia/Kolkata\nUS\t+404251-0740023\tAmerica/New_York\tEastern (most areas)\n"
        let kolkata = TimeZonePlace.guess(for: try #require(TimeZone(identifier: "Asia/Kolkata")), table: table)
        #expect(kolkata.name == "Kolkata")
        #expect(abs(kolkata.latitude - 22.533) < 0.01 && abs(kolkata.longitude - 88.367) < 0.01)
        let newYork = TimeZonePlace.guess(for: try #require(TimeZone(identifier: "America/New_York")), table: table)
        #expect(newYork.name == "New York")
        #expect(abs(newYork.latitude - 40.714) < 0.01 && abs(newYork.longitude + 74.006) < 0.01)
        // Unknown zones fall back to their meridian.
        let tokyo = TimeZonePlace.guess(for: try #require(TimeZone(identifier: "Asia/Tokyo")), table: table)
        #expect(tokyo.longitude == 135)
    }
}

@Suite struct ImageSizingTests {
    @Test func sizesShareBuckets() {
        #expect(ImageLibrary.pixelBucket(208) == 256)
        #expect(ImageLibrary.pixelBucket(704) == 768)
        #expect(ImageLibrary.pixelBucket(768) == 768)
        #expect(ImageLibrary.pixelBucket(4000) == 0)
    }
}
