import Foundation
import OSLog

/// Reading the JSON files the stores keep. A missing file is normal (first
/// launch); a file that exists but can't be decoded is not: it's copied aside
/// before the store carries on empty, so its next save can't destroy the only
/// copy of the user's data.
public enum StoreFile {
    private static let log = Logger(subsystem: "com.pratik.allset", category: "storage")

    public static func load<Value: Decodable>(_ type: Value.Type, from url: URL) -> Value? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            let kept = preserve(url)
            log.error("Couldn't read \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public). Kept a copy at \(kept?.lastPathComponent ?? "nowhere", privacy: .public)")
            return nil
        }
    }

    /// Copies `url` next to itself as "name.unreadable-20260925-181500.json".
    @discardableResult
    public static func preserve(_ url: URL, now: Date = .now) -> URL? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let copy = url.deletingPathExtension()
            .appendingPathExtension("unreadable-\(formatter.string(from: now))")
            .appendingPathExtension(url.pathExtension.isEmpty ? "json" : url.pathExtension)
        do {
            try FileManager.default.copyItem(at: url, to: copy)
            return copy
        } catch {
            return nil
        }
    }
}
