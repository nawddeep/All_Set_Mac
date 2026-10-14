import Testing
@testable import AllSetCore

@Suite struct CostCacheTests {
    @Test func evictsLeastRecentlyUsedByCost() {
        var cache = CostCache<String, Int>(costLimit: 100)
        cache.insert(1, forKey: "a", cost: 40)
        cache.insert(2, forKey: "b", cost: 40)
        _ = cache.value(forKey: "a")            // "a" is now the most recent
        cache.insert(3, forKey: "c", cost: 40)  // over 100: "b" goes
        #expect(cache.peek("a") == 1)
        #expect(cache.peek("b") == nil)
        #expect(cache.peek("c") == 3)
        #expect(cache.totalCost == 80)
    }

    @Test func respectsCountAndSkipsOversizedValues() {
        var cache = CostCache<Int, Int>(costLimit: 1_000, countLimit: 2)
        for key in 0..<5 { cache.insert(key, forKey: key, cost: 1) }
        #expect(cache.count == 2)
        #expect(cache.peek(4) == 4 && cache.peek(3) == 3)
        cache.insert(9, forKey: 9, cost: 5_000)
        #expect(cache.peek(9) == nil)
        #expect(cache.count == 2)
    }

    @Test func replacingAndTrimmingKeepTheTotalRight() {
        var cache = CostCache<String, Int>(costLimit: 100)
        cache.insert(1, forKey: "a", cost: 30)
        cache.insert(2, forKey: "a", cost: 50)
        #expect(cache.totalCost == 50 && cache.count == 1)
        cache.insert(3, forKey: "b", cost: 20)
        cache.trim(toCost: 25)
        #expect(cache.peek("a") == nil && cache.peek("b") == 3)
        cache.removeAll(where: { $0 == "b" })
        #expect(cache.totalCost == 0 && cache.count == 0)
    }
}
