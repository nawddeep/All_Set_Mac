import Foundation

/// Splits a byte stream arriving in arbitrary chunks into newline-terminated lines.
/// Safe to feed from a `FileHandle.readabilityHandler` on any thread.
public final class LineReader: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private let onLine: @Sendable (Data) -> Void

    public init(onLine: @escaping @Sendable (Data) -> Void) {
        self.onLine = onLine
    }

    public func append(_ chunk: Data) {
        var lines: [Data] = []
        lock.withLock {
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 0x0A) {
                lines.append(Data(buffer[buffer.startIndex..<newline]))
                buffer.removeSubrange(buffer.startIndex...newline)
            }
        }
        lines.forEach(onLine)
    }
}
