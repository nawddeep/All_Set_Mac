import Foundation
import Testing
@testable import AllSetCore

@Suite struct BuiltInWallpaperTests {
    @Test func aNewInstallHasPlentyToPick() {
        #expect(BuiltInWallpaper.all.count >= 30)
        #expect(Set(BuiltInWallpaper.all.map(\.id)).count == BuiltInWallpaper.all.count, "two built-ins draw the same art")
        #expect(Set(BuiltInWallpaper.all.map(\.name)).count == BuiltInWallpaper.all.count)
        for category in BuiltInWallpaper.Category.allCases {
            #expect(BuiltInWallpaper.inCategory(category).count >= 5, "\(category) is thin")
        }
    }

    @Test func everyOneIsGeneratedArtNeedingNoFile() {
        for wallpaper in BuiltInWallpaper.all {
            guard case .art(let piece) = wallpaper.source else {
                Issue.record("\(wallpaper.name) isn't generated art")
                continue
            }
            #expect(piece == wallpaper.piece)
        }
    }
}
