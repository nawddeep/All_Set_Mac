import Testing
@testable import AllSetCore

@Suite struct SearchMatchTests {
    private let apps = ["Visual Studio Code", "Safari", "Google Chrome", "Microsoft PowerPoint", "Adobe Photoshop 2026",
                        "System Settings", "Calculator", "Calendar", "Chess", "Café Menu"]

    @Test func bestMatchComesFirst() {
        #expect(SearchMatch.rank(apps, by: "cal") { $0 }.prefix(2) == ["Calendar", "Calculator"])
        #expect(SearchMatch.rank(apps, by: "chrome") { $0 }.first == "Google Chrome")
        #expect(SearchMatch.rank(apps, by: "") { $0 } == apps)
    }

    @Test func acceptsInitialsAndLettersInOrder() {
        #expect(SearchMatch.rank(apps, by: "vsc") { $0 }.first == "Visual Studio Code")
        #expect(SearchMatch.rank(apps, by: "pp") { $0 }.first == "Microsoft PowerPoint")
        #expect(SearchMatch.rank(apps, by: "pshop") { $0 }.first == "Adobe Photoshop 2026")
        #expect(SearchMatch.rank(apps, by: "studio vis") { $0 } == ["Visual Studio Code"])
        #expect(SearchMatch.score("xyz", name: "Safari") == nil)
    }

    @Test func ignoresCaseAccentsAndWordOrder() {
        #expect(SearchMatch.rank(apps, by: "cafe") { $0 } == ["Café Menu"])
        #expect(SearchMatch.containsAll("world HELLO", in: "Hello there, world"))
        #expect(!SearchMatch.containsAll("hello moon", in: "Hello there, world"))
        #expect(SearchMatch.containsAll("  ", in: "anything"))
    }

    @Test func clipboardSearchUsesEveryWord() {
        let item = ClipboardItem(kind: .text, text: "Meeting notes for Thursday", sourceBundleID: nil)
        #expect(item.matches("thursday meeting"))
        #expect(!item.matches("friday meeting"))
        let image = ClipboardItem(kind: .image, text: nil, sourceBundleID: nil)
        #expect(image.matches("screenshot"))
    }
}

@Suite struct StableOrderTests {
    private func arrange(_ values: [(String, Double)], previous: [String]) -> [String] {
        StableOrder.arrange(values, previous: previous, id: \.0, value: \.1).map(\.0)
    }

    @Test func smallChangesKeepTheOrder() {
        // B edges past A by 10%: not enough to swap.
        #expect(arrange([("B", 11), ("A", 10), ("C", 5)], previous: ["A", "B", "C"]) == ["A", "B", "C"])
    }

    @Test func clearLeadersClimb() {
        #expect(arrange([("C", 30), ("A", 10), ("B", 9)], previous: ["A", "B", "C"]) == ["C", "A", "B"])
        // Newcomers start at the bottom and climb as far as they deserve.
        #expect(arrange([("N", 12), ("A", 10), ("B", 4)], previous: ["A", "B"]) == ["A", "N", "B"])
        #expect(arrange([("X", 1), ("Y", 2)], previous: []) == ["Y", "X"])
    }
}
