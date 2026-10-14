import Foundation

/// When a failed request may be tried again: `first` after the first failure,
/// doubling with each one after, never longer than `longest` (unless a failure
/// asks for more, like a rejected credential). A success forgets the key.
public struct RetryBackoff: Sendable {
    public let first: TimeInterval
    public let longest: TimeInterval
    private var entries: [String: Entry] = [:]

    private struct Entry: Sendable {
        var failures: Int
        var retryAt: Date
    }

    public init(first: TimeInterval = 60, longest: TimeInterval = 30 * 60) {
        self.first = first
        self.longest = longest
    }

    public func allows(_ key: String, at now: Date = .now) -> Bool {
        entries[key].map { now >= $0.retryAt } ?? true
    }

    public func retryAt(_ key: String) -> Date? { entries[key]?.retryAt }

    public mutating func failed(_ key: String, at now: Date = .now, atLeast: TimeInterval = 0) {
        let failures = (entries[key]?.failures ?? 0) + 1
        let wait = max(min(first * pow(2, Double(min(failures - 1, 30))), longest), atLeast)
        entries[key] = Entry(failures: failures, retryAt: now.addingTimeInterval(wait))
    }

    public mutating func succeeded(_ key: String) { entries[key] = nil }

    public mutating func reset() { entries = [:] }
}
