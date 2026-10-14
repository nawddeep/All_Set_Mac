/// The most recent `capacity` samples of a metric, oldest first, for sparklines.
public struct RollingSeries: Equatable, Sendable {
    public let capacity: Int
    public private(set) var values: [Double] = []

    public init(capacity: Int) {
        precondition(capacity > 0, "capacity must be positive")
        self.capacity = capacity
    }

    public mutating func append(_ value: Double) {
        values.append(value)
        if values.count > capacity {
            values.removeFirst(values.count - capacity)
        }
    }

    public var latest: Double? { values.last }
    public var maximum: Double { values.max() ?? 0 }
}
