import CryptoKit
import Foundation

/// Content hashes of files on disk, read in chunks so a multi-gigabyte video
/// never sits in memory whole.
public enum FileDigest {
    /// Lowercase hex SHA-256 of the file's bytes; nil if it can't be read.
    public static func sha256(of url: URL, chunk: Int = 4 << 20) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        do {
            while let data = try handle.read(upToCount: chunk), !data.isEmpty {
                hasher.update(data: data)
            }
        } catch {
            return nil
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
