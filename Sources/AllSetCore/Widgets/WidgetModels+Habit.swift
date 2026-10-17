import CoreGraphics
import Foundation

/// Something to do every day, with the days it was done.
public struct Habit: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var symbol: String
    /// Days done, as "2026-09-25".
    public var done: [String]

    public init(id: UUID = UUID(), title: String, symbol: String, done: [String] = []) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.done = done
    }

    public func isDone(on date: Date, calendar: Calendar = .current) -> Bool {
        done.contains(Self.key(date, calendar: calendar))
    }

    /// Days in a row up to `date`; today not yet done doesn't break it.
    public func streak(until date: Date, calendar: Calendar = .current) -> Int {
        let days = Set(done)
        var day = days.contains(Self.key(date, calendar: calendar)) ? date : calendar.date(byAdding: .day, value: -1, to: date)!
        var count = 0
        while days.contains(Self.key(day, calendar: calendar)) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    public mutating func toggle(on date: Date, calendar: Calendar = .current) {
        let key = Self.key(date, calendar: calendar)
        if let index = done.firstIndex(of: key) {
            done.remove(at: index)
        } else {
            done.append(key)
            // Only the last year matters for streaks and the grid.
            if done.count > 400 { done.removeFirst(done.count - 400) }
        }
    }

    public static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static let starters: [Habit] = [
        ("Meditate", "leaf.fill"), ("Workout", "figure.run"), ("Journal", "pencil.line"), ("Sleep by 11", "moon.zzz.fill"),
    ].enumerated().map { index, habit in
        Habit(id: UUID(uuidString: String(format: "4AB10000-0000-4000-8000-%012d", index))!, title: habit.0, symbol: habit.1)
    }
}

/// The book being read, and how far.
public struct ReadingBook: Codable, Hashable, Sendable {
    public var title = "The Midnight Library"
    public var author = "Matt Haig"
    public var page = 112
    public var pages = 288
    /// The cover's color.
    public var color = WidgetColor(hex: 0x2F4B7C)

    public init() {}

    public var fraction: Double { pages > 0 ? min(max(Double(page) / Double(pages), 0), 1) : 0 }
}

/// What a GitHub widget shows.
public enum GitHubMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case contributions, activity, pullRequests, issues, repository, actions

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .contributions: "Contributions"
        case .activity: "Activity"
        case .pullRequests: "Pull Requests"
        case .issues: "Issues"
        case .repository: "Repository"
        case .actions: "CI/CD"
        }
    }

    /// Whether it needs a repository ("owner/name") rather than a user.
    public var needsRepository: Bool { self == .repository || self == .actions }
}

public struct GitHubConfig: Codable, Hashable, Sendable {
    public var mode: GitHubMode = .contributions
    /// A GitHub username.
    public var user = ""
    /// "owner/name".
    public var repository = ""

    public init(mode: GitHubMode = .contributions, user: String = "", repository: String = "") {
        self.mode = mode
        self.user = user
        self.repository = repository
    }
}

/// A site or API a Status widget checks.
public struct StatusEndpoint: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var url: String

    public init(id: UUID = UUID(), name: String, url: String) {
        self.id = id
        self.name = name
        self.url = url
    }

    public static let starters: [StatusEndpoint] = [
        ("GitHub", "https://www.githubstatus.com/api/v2/status.json"),
        ("Apple", "https://www.apple.com"),
        ("Open-Meteo", "https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0&current=temperature_2m"),
    ].enumerated().map { index, endpoint in
        StatusEndpoint(id: UUID(uuidString: String(format: "57A70000-0000-4000-8000-%012d", index))!, name: endpoint.0, url: endpoint.1)
    }
}
