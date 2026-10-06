import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite struct WallpaperQueryTests {
    @Test func nicknamesAreSpelledOut() {
        #expect(WallpaperQuery.understand("jjk").positive == "jujutsu kaisen")
        #expect(WallpaperQuery.understand("Lambo 4K wallpaper").positive == "lamborghini")
        #expect(WallpaperQuery.understand("ironman").positive == "iron man")
        #expect(WallpaperQuery.understand("GTA 5").positive == "grand theft auto v")
        #expect(WallpaperQuery.understand("red gtr night").positive == "red nissan gt-r night")
        #expect(WallpaperQuery.understand("jjk").note?.contains("jujutsu kaisen") == true)
        #expect(WallpaperQuery.understand("mountains").note == nil)
        // Ambiguous short words only count as the whole search.
        #expect(WallpaperQuery.understand("lol").positive == "league of legends")
        #expect(WallpaperQuery.understand("lol cat").positive == "lol cat")
    }

    @Test func exclusionsAndFiller() {
        let query = WallpaperQuery.understand("batman -lego wallpaper")
        #expect(query.text == "batman -lego")
        #expect(query.positive == "batman")
        #expect(query.excluded == ["lego"])
        #expect(WallpaperQuery.understand("iron man").quotedText == "\"iron man\"")
        #expect(WallpaperQuery.understand("dbz").quotedText == "\"dragon ball z\"")
        #expect(WallpaperQuery.understand("batman rain").quotedText == "batman rain")
        // All filler still searches something.
        #expect(!WallpaperQuery.understand("4k wallpaper").text.isEmpty)
    }

    @Test func popCultureIsRecognized() {
        for text in ["Marvel", "spider-man", "naruto", "red ferrari", "batman rain", "anime", "gta 6", "supercars"] {
            #expect(WallpaperQuery.understand(text).isPopCulture, "\(text)")
        }
        for text in ["mountains", "coquette", "rain window", "sunset beach"] {
            #expect(!WallpaperQuery.understand(text).isPopCulture, "\(text)")
        }
        #expect(WallpaperQuery.understand("anime").categories == "010")
        // Aesthetics: Wallhaven by its own tag, or not at all.
        #expect(!WallpaperQuery.understand("coquette wallpaper").searchesWallhaven)
        #expect(WallpaperQuery.understand("lo fi").text == "lofi")
        #expect(WallpaperQuery.understand("villain era").text == "villain")
        #expect(WallpaperQuery.understand("villain era").meaning == "villain era")
        #expect(WallpaperQuery.understand("anime").searchesWallhaven)
        #expect(WallpaperQuery.understand("naruto").categories == "111")
    }

    @Test func typosInNamesAreFixed() {
        #expect(WallpaperQuery.correctedSpelling(of: "lamborgni") == "lamborghini")
        #expect(WallpaperQuery.correctedSpelling(of: "naurto") == "naruto")
        #expect(WallpaperQuery.correctedSpelling(of: "batman") == nil)
    }
}

@Suite struct WallhavenTests {
    @Test func decodesAndRanksResults() throws {
        let json = """
            {"data":[
              {"id":"a1","purity":"sfw","category":"general","dimension_x":1920,"dimension_y":1080,"favorites":0,
               "path":"https://w.wallhaven.cc/full/a1/wallhaven-a1.jpg","thumbs":{"large":"https://th.wallhaven.cc/lg/a1/a1.jpg"}},
              {"id":"b2","purity":"sfw","category":"anime","dimension_x":3840,"dimension_y":2160,"favorites":900,
               "path":"https://w.wallhaven.cc/full/b2/wallhaven-b2.png","thumbs":{"large":"https://th.wallhaven.cc/lg/b2/b2.jpg"}},
              {"id":"c3","purity":"sketchy","dimension_x":1920,"dimension_y":1080,"path":"https://w.wallhaven.cc/full/c3/x.jpg"},
              {"id":"d4","purity":"sfw","path":null}
            ],"meta":{"current_page":1,"last_page":7}}
            """
        let decoded = try Wallhaven.decode(Data(json.utf8), sort: .relevance)
        #expect(decoded.pageCount == 7)
        // Unsafe and broken results are dropped; the much-loved one moves up.
        #expect(decoded.photos.map(\.id) == ["b2", "a1"])
        let photo = decoded.photos[0]
        #expect(photo.provider == "wallhaven")
        #expect(photo.credit == "3840 × 2160 · Wallhaven")
        #expect(photo.displayURL.absoluteString == "https://w.wallhaven.cc/full/b2/wallhaven-b2.png")
        #expect(photo.thumbnailURL().absoluteString == "https://th.wallhaven.cc/lg/b2/b2.jpg")
        #expect(photo.pageURL?.absoluteString == "https://wallhaven.cc/w/b2")
        // Other orders are kept as the site gives them.
        #expect(try Wallhaven.decode(Data(json.utf8), sort: .newest).photos.map(\.id) == ["a1", "b2"])
    }

    @Test func requestsAreAlwaysSafeForWork() throws {
        var filters = Wallhaven.Filters()
        filters.sort = .top
        filters.minimumPixels = CGSize(width: 2940, height: 1912)
        filters.orientation = .portrait
        filters.color = "cc0000"
        let url = Wallhaven.url(for: WallpaperQuery.understand("batman -lego"), page: 3, filters: filters)
        let items = Dictionary(uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value ?? "") })
        #expect(items["purity"] == "100")
        #expect(items["q"] == "batman -lego")
        #expect(items["sorting"] == "toplist")
        #expect(items["topRange"] == "1y")
        #expect(items["atleast"] == "2940x1912")
        #expect(items["ratios"] == "portrait")
        #expect(items["colors"] == "cc0000")
        #expect(items["page"] == "3")
        // "anime" alone browses the anime category.
        let anime = Wallhaven.url(for: WallpaperQuery.understand("anime"), page: 1, filters: .init())
        let animeItems = URLComponents(url: anime, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(animeItems.first { $0.name == "categories" }?.value == "010")
        #expect(animeItems.first { $0.name == "q" }?.value == "")
    }

    @Test func sourcesTakeTurns() {
        func photos(_ ids: [String]) -> [WebPhoto] { ids.map { WebPhoto(id: $0, author: "", width: 0, height: 0) } }
        #expect(PhotoSearch.interleave(photos(["a", "b", "c"]), photos(["1"])).map(\.id) == ["a", "1", "b", "c"])
        #expect(PhotoSearch.interleave([], photos(["1", "2"])).map(\.id) == ["1", "2"])
    }

    @MainActor @Test func recentSearchesPersist() {
        let suite = "recent-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let search = PhotoSearch(cacheDirectory: FileManager.default.temporaryDirectory, defaults: defaults)
        search.remember("iron man")
        search.remember("Naruto")
        search.remember("IRON MAN")
        search.remember("Marvel")  // a topic chip, already one click away
        #expect(search.recent == ["IRON MAN", "Naruto"])
        #expect(PhotoSearch(cacheDirectory: FileManager.default.temporaryDirectory, defaults: defaults).recent == ["IRON MAN", "Naruto"])
    }
}
