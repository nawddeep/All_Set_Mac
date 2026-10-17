import Testing

extension Tag {
    /// Reads this Mac's own hardware (sensors, Now Playing through the real
    /// helper): meaningful only on a real, logged-in Mac. CI skips it by tag:
    /// `swift test --skip "LiveSystemTests|MediaHelperTests"` (SwiftPM's CLI has no tag filter yet).
    @Tag static var hardware: Self
}
