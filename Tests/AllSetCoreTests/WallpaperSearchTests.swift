import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite struct WallpaperQueryTests {
    @Test func fillerAndPlacesAreUnderstood() {
        #expect(WallpaperQuery.understand("Mountains 4K wallpaper").positive == "mountains")
        #expect(WallpaperQuery.understand("nyc night").positive == "new york city night")
        #expect(WallpaperQuery.understand("nyc").note?.contains("new york city") == true)
        #expect(WallpaperQuery.understand("mountains").note == nil)
        // All filler still searches something.
        #expect(!WallpaperQuery.understand("4k wallpaper").meaning.isEmpty)
    }

    @Test func exclusionsFilterTitles() {
        let query = WallpaperQuery.understand("rain -car wallpaper")
        #expect(query.positive == "rain")
        #expect(query.excluded == ["car"])
        #expect(query.allows(title: "Rain on the window"))
        #expect(!query.allows(title: "Red car in the rain"))
        #expect(query.allows(title: nil))
        #expect(WallpaperQuery.understand("rain").allows(title: "Red car in the rain"))
    }

    @Test func typosAreFixed() {
        #expect(WallpaperQuery.correctedSpelling(of: "mountians") == "mountains")
        #expect(WallpaperQuery.correctedSpelling(of: "mountains") == nil)
    }
}

@Suite struct OpenverseLicenceTests {
    @Test func onlyLicencesThatAllowAnyUseAreKept() throws {
        let json = """
            {"page_count":1,"results":[
              {"id":"by","creator":"A","license":"by","license_version":"4.0","width":2000,"height":1500,"url":"https://e.com/1.jpg"},
              {"id":"nc","creator":"B","license":"by-nc","license_version":"4.0","width":2000,"height":1500,"url":"https://e.com/2.jpg"},
              {"id":"nd","creator":"C","license":"by-nd","width":2000,"height":1500,"url":"https://e.com/3.jpg"},
              {"id":"pdm","creator":"D","license":"pdm","width":2000,"height":1500,"url":"https://e.com/4.jpg"},
              {"id":"none","creator":"E","width":2000,"height":1500,"url":"https://e.com/5.jpg"}
            ]}
            """
        let decoded = try PhotoSearch.decode(Data(json.utf8))
        #expect(decoded.photos.map(\.id) == ["by", "pdm"])
        #expect(decoded.photos.map(\.credit) == ["A · CC BY 4.0", "D · PDM"])
    }

    @MainActor @Test func requestsAskForThoseLicencesOnly() throws {
        let search = PhotoSearch(cacheDirectory: FileManager.default.temporaryDirectory)
        let url = search.url("rain", page: 2, sources: PhotoSearch.curatedSources)
        let items = Dictionary(uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value ?? "") })
        #expect(url.host == "api.openverse.org")
        #expect(items["license"] == "cc0,pdm,by,by-sa")
        #expect(items["mature"] == "false")
        #expect(items["page"] == "2")
    }

    @Test func picsumPhotosCreditUnsplash() {
        #expect(WebPhoto(id: "1", author: "Ana", width: 10, height: 10).credit == "Ana · Unsplash")
    }

    @MainActor @Test func recentSearchesPersist() {
        let suite = "recent-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let search = PhotoSearch(cacheDirectory: FileManager.default.temporaryDirectory, defaults: defaults)
        search.remember("rain window")
        search.remember("Tokyo")
        search.remember("RAIN WINDOW")
        search.remember("Nature")  // a topic chip, already one click away
        #expect(search.recent == ["RAIN WINDOW", "Tokyo"])
        #expect(PhotoSearch(cacheDirectory: FileManager.default.temporaryDirectory, defaults: defaults).recent == ["RAIN WINDOW", "Tokyo"])
    }
}
