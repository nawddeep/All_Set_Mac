import Foundation
import Testing
@testable import AllSetCore

/// The Data & Privacy page lists every connection from `NetworkUse`; this
/// keeps that list true by checking every address written in the source.
@Suite struct NetworkUseTests {
    @Test func everyAddressInTheSourceIsListed() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let files = FileManager.default.enumerator(at: root.appendingPathComponent("Sources"), includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { ["swift", "m", "c", "h"].contains($0.pathExtension) } ?? []
        #expect(files.count > 100)
        let known = NetworkUse.contactedHosts.union(NetworkUse.linkHosts)
        let pattern = try NSRegularExpression(pattern: #"https?://([A-Za-z0-9.-]+)"#)
        var unlisted: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let range = Range(match.range(at: 1), in: text) else { continue }
                let host = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: "."))
                if !known.contains(host) { unlisted.append("\(file.lastPathComponent): \(host)") }
            }
        }
        let missing = Set(unlisted).sorted()
        #expect(missing.isEmpty, "Not in NetworkUse: \(missing)")
    }

    @Test func everyUseSaysWhenAndWhat() {
        for use in NetworkUse.allCases {
            #expect(!use.title.isEmpty && !use.when.isEmpty && !use.sends.isEmpty, "\(use)")
        }
        #expect(NetworkUse.contactedHosts.isDisjoint(with: NetworkUse.linkHosts))
    }
}
