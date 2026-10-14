/// A least-recently-used cache limited by total cost (bytes, for pictures) as
/// well as count. Counting alone isn't a limit for images: forty decoded
/// photos can be a few megabytes or a gigabyte.
public struct CostCache<Key: Hashable, Value> {
    public let costLimit: Int
    public let countLimit: Int
    public private(set) var totalCost = 0

    private var entries: [Key: (value: Value, cost: Int)] = [:]
    /// Least recently used first.
    private var order: [Key] = []

    public init(costLimit: Int, countLimit: Int = .max) {
        self.costLimit = costLimit
        self.countLimit = countLimit
    }

    public var count: Int { entries.count }
    public var values: [Value] { order.compactMap { entries[$0]?.value } }

    /// The value, marked as just used.
    public mutating func value(forKey key: Key) -> Value? {
        guard let entry = entries[key] else { return nil }
        touch(key)
        return entry.value
    }

    /// The value, without changing which is evicted next (for reads that
    /// mustn't count as use, or can't mutate).
    public func peek(_ key: Key) -> Value? { entries[key]?.value }

    /// Stores a value, evicting the least recently used until both limits
    /// hold. A value costing more than the whole limit isn't kept.
    public mutating func insert(_ value: Value, forKey key: Key, cost: Int) {
        removeValue(forKey: key)
        guard cost <= costLimit else { return }
        entries[key] = (value, cost)
        order.append(key)
        totalCost += cost
        trim(toCost: costLimit, count: countLimit)
    }

    public mutating func removeValue(forKey key: Key) {
        guard let entry = entries.removeValue(forKey: key) else { return }
        totalCost -= entry.cost
        order.removeAll { $0 == key }
    }

    /// Drops the least recently used until at most `cost` and `count` remain.
    public mutating func trim(toCost cost: Int, count: Int = .max) {
        while !order.isEmpty, totalCost > cost || entries.count > count {
            let key = order.removeFirst()
            if let entry = entries.removeValue(forKey: key) { totalCost -= entry.cost }
        }
    }

    public mutating func removeAll() {
        entries.removeAll()
        order.removeAll()
        totalCost = 0
    }

    public mutating func removeAll(where shouldRemove: (Key) -> Bool) {
        for key in order where shouldRemove(key) { removeValue(forKey: key) }
    }

    private mutating func touch(_ key: Key) {
        guard order.last != key, let index = order.firstIndex(of: key) else { return }
        order.remove(at: index)
        order.append(key)
    }
}
