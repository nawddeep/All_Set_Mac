import Foundation

/// Where the tests are running.
enum TestEnvironment {
    /// A CI virtual machine (GitHub Actions sets `CI`): no temperature
    /// sensors, no motion sensor and no Now Playing, unlike a real Mac.
    static let isCI = ProcessInfo.processInfo.environment["CI"] != nil
}
