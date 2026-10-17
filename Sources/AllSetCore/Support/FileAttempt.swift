import Foundation
import OSLog

/// A file operation on the person's own data that mustn't fail silently:
/// the failure is logged (and returned, for callers that show it).
public enum FileAttempt {
    static let log = Logger(subsystem: "com.pratik.allset", category: "files")

    @discardableResult
    public static func run(_ what: String, _ body: () throws -> Void) -> Bool {
        do {
            try body()
            return true
        } catch {
            log.error("Couldn't \(what, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
