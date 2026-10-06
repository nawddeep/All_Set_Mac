import AllSetCore
import AppKit
import SwiftUI

// MARK: GitHub

/// Contributions, activity, pull requests, issues, a repository or its CI,
/// fetched only while on screen, shared between widgets, cached on disk.
/// Click to open the matching page on GitHub.
struct GitHubWidget: View {
    let instance: WidgetInstance
    let github: GitHubService
    let onConfigure: @MainActor () -> Void
    @Environment(\.widgetRefreshScale) private var refreshScale

    @Environment(\.widgetStyle) private var style

    private var config: GitHubConfig { instance.options.github }
    private var size: WidgetSize { instance.size }

    var body: some View {
        let interval = instance.options.refresh.interval(for: .github).map { $0 * refreshScale }
        Group {
            if !GitHubService.isConfigured(config) {
                WidgetStateView(kind: .empty, symbol: "chevron.left.forwardslash.chevron.right", title: "Connect GitHub",
                                message: config.mode.needsRepository ? "Add a repository, like apple/swift." : "Add your GitHub username.",
                                actionTitle: "Set Up…", action: onConfigure)
            } else if let snapshot = github.snapshot(config) {
                content(snapshot.data)
                    .padding(WidgetMetrics.padding(size))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .overlay(alignment: .bottomTrailing) {
                        WidgetStaleBadge(updated: snapshot.fetched, problem: github.error(config), interval: interval)
                    }
            } else if let error = github.error(config) {
                WidgetStateView(kind: .error, symbol: "exclamationmark.triangle", title: "Couldn't reach GitHub", message: error)
            } else {
                WidgetStateView(kind: .loading, symbol: "", title: "Loading \(config.mode.title.lowercased())…")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openOnGitHub() }
        .contextMenu {
            Button("Refresh Now") { Task { await github.refreshNow(config) } }
            Button("Open on GitHub") { openOnGitHub() }
            Divider()
            WidgetMenuItems()
        }
        .widgetRefresh(every: interval, id: GitHubService.key(config)) {
            await github.refresh(config, maxAge: interval ?? .infinity)
        }
    }

    private func openOnGitHub() {
        let base = "https://github.com/"
        let path: String = switch config.mode {
        case .contributions, .activity: config.user
        case .pullRequests: config.repository.isEmpty ? "pulls" : "\(config.repository)/pulls"
        case .issues: config.repository.isEmpty ? "issues" : "\(config.repository)/issues"
        case .repository: config.repository
        case .actions: "\(config.repository)/actions"
        }
        if let url = URL(string: base + path) { NSWorkspace.shared.open(url) }
    }

    @ViewBuilder
    private func content(_ data: GitHubData) -> some View {
        switch data {
        case .contributions(let contributions): contributionsView(contributions)
        case .events(let events): activity(events)
        case .items(let total, let items): itemsView(total: total, items)
        case .repository(let repository): repositoryView(repository)
        case .runs(let runs): runsView(runs)
        }
    }

    // MARK: Contributions

    private func contributionsView(_ c: GitHubContributions) -> some View {
        let weeks: Int = switch size {
        case .small: 10
        case .medium: 24
        case .large: 22
        case .extraLarge: 53
        }
        return VStack(alignment: .leading, spacing: size == .small ? 8 : 10) {
            WidgetHeader(title: config.user, symbol: "square.grid.3x3.fill", detail: size == .small ? nil : "\(c.streak)-day streak")
            if size == .large || size == .extraLarge {
                HStack(spacing: 22) {
                    WidgetMetric(value: c.total.formatted(), caption: "This year", size: 30)
                    WidgetMetric(value: "\(c.streak)", unit: "days", caption: "Streak", size: 30)
                    WidgetMetric(value: "\(c.days.suffix(7).reduce(0) { $0 + $1.count })", caption: "This week", size: 30)
                    if size == .extraLarge {
                        WidgetMetric(value: "\(c.days.map(\.count).max() ?? 0)", caption: "Best day", size: 30)
                    }
                }
            }
            ContributionGraph(days: c.days, weeks: weeks)
                .accessibilityLabel("\(c.total) contributions in the last year, \(c.streak) day streak")
            if size == .small || size == .medium {
                HStack {
                    Text("\(c.total.formatted()) contributions this year").font(style.body(11)).foregroundStyle(style.secondary)
                    Spacer()
                    if size == .small { Text("\(c.streak)d").font(style.body(11, weight: .semibold)).foregroundStyle(style.accent) }
                }
            }
        }
    }

    // MARK: Activity

    private func activity(_ events: [GitHubEvent]) -> some View {
        let count = size == .small ? 3 : size == .medium ? 3 : 8
        return VStack(alignment: .leading, spacing: size == .small ? 7 : 9) {
            WidgetHeader(title: config.user, symbol: "bolt.horizontal.fill", detail: size == .small ? nil : "Activity")
            if events.isEmpty {
                Text("No public activity lately.").font(style.body(12)).foregroundStyle(style.secondary)
            }
            ForEach(events.prefix(count)) { event in
                HStack(alignment: .top, spacing: 7) {
                    WidgetIcon(symbol: event.symbol, size: 11)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.summary).font(style.body(size == .small ? 11 : 12)).lineLimit(size == .small ? 2 : 1)
                        Text(RelativeTime.short(event.date)).font(style.body(10)).foregroundStyle(style.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Pull requests and issues

    private func itemsView(total: Int, _ items: [GitHubItem]) -> some View {
        let isPR = config.mode == .pullRequests
        let title = isPR ? "Pull Requests" : "Issues"
        let symbol = isPR ? "arrow.triangle.pull" : "smallcircle.filled.circle"
        return VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: title, symbol: symbol, detail: size == .small ? nil : "\(total) open")
            if size == .small {
                Spacer(minLength: 0)
                WidgetMetric(value: "\(total)", unit: "open", size: 40)
                if let first = items.first {
                    Text(first.title).font(style.body(11)).foregroundStyle(style.secondary).lineLimit(2)
                }
            } else if items.isEmpty {
                Spacer(minLength: 0)
                WidgetStateView(kind: .empty, symbol: "checkmark.circle", title: "All clear", message: "Nothing open right now.")
            } else {
                ForEach(items.prefix(size == .medium ? 3 : 7)) { item in
                    Button { if let url = URL(string: item.url) { NSWorkspace.shared.open(url) } } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 5) {
                                if item.isDraft {
                                    WidgetWord("Draft").font(style.label(9)).padding(.horizontal, 4).padding(.vertical, 1)
                                        .background(Capsule().strokeBorder(style.ink.opacity(0.3)))
                                }
                                Text(item.title).font(style.body(12, weight: .semibold)).lineLimit(1)
                            }
                            HStack(spacing: 6) {
                                Text("\(item.repository.split(separator: "/").last.map(String.init) ?? item.repository) #\(item.number)")
                                Text("·")
                                Text(RelativeTime.short(item.updated))
                                if item.comments > 0 {
                                    Label("\(item.comments)", systemImage: "text.bubble").labelStyle(.titleAndIcon)
                                }
                            }
                            .font(style.body(10))
                            .foregroundStyle(style.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Repository

    private func repositoryView(_ r: GitHubRepository) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: r.name.split(separator: "/").last.map(String.init) ?? r.name, symbol: "shippingbox.fill",
                         detail: size == .small ? nil : r.language)
            if size != .small, let summary = r.summary {
                Text(summary).font(style.body(12)).foregroundStyle(style.secondary).lineLimit(size == .large ? 3 : 2)
            }
            Spacer(minLength: 0)
            if size == .small {
                WidgetMetric(value: compact(r.stars), unit: "★", size: 36)
                Text("\(r.openIssues) open · pushed \(RelativeTime.short(r.pushed))").font(style.body(10)).foregroundStyle(style.secondary).lineLimit(2)
            } else {
                HStack(spacing: 18) {
                    WidgetMetric(value: compact(r.stars), caption: "Stars", size: 24)
                    WidgetMetric(value: compact(r.forks), caption: "Forks", size: 24)
                    WidgetMetric(value: compact(r.openIssues), caption: "Open", size: 24)
                    if size == .large { WidgetMetric(value: compact(r.watchers), caption: "Watching", size: 24) }
                }
                WidgetFooter(text: "Last push \(RelativeTime.short(r.pushed)) to \(r.defaultBranch)", symbol: "arrow.up.circle")
            }
        }
    }

    private func compact(_ value: Int) -> String {
        value >= 10_000 ? String(format: "%.0fk", Double(value) / 1000) : value >= 1000 ? String(format: "%.1fk", Double(value) / 1000) : "\(value)"
    }

    // MARK: CI

    private func runsView(_ runs: [GitHubRun]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: config.repository.split(separator: "/").last.map(String.init) ?? "Actions", symbol: "checkmark.circle.badge.xmark",
                         detail: size == .small ? nil : "Actions")
            if let latest = runs.first, size == .small {
                Spacer(minLength: 0)
                RunBadge(run: latest, large: true)
                Text("\(latest.name) · \(latest.branch)").font(style.body(11)).foregroundStyle(style.secondary).lineLimit(2)
                Text(RelativeTime.short(latest.created)).font(style.body(10)).foregroundStyle(style.secondary)
            } else if runs.isEmpty {
                WidgetStateView(kind: .empty, symbol: "gearshape.2", title: "No runs yet")
            } else {
                ForEach(runs.prefix(size == .medium ? 3 : 7)) { run in
                    Button { if let url = URL(string: run.url) { NSWorkspace.shared.open(url) } } label: {
                        HStack(spacing: 8) {
                            RunBadge(run: run, large: false)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(run.name).font(style.body(12, weight: .semibold)).lineLimit(1)
                                Text("#\(run.number) · \(run.branch) · \(RelativeTime.short(run.created))")
                                    .font(style.body(10)).foregroundStyle(style.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// A run's outcome as a symbol and a word, so it never depends on color alone.
private struct RunBadge: View {
    let run: GitHubRun
    let large: Bool
    @Environment(\.widgetStyle) private var style

    var body: some View {
        let (symbol, word, color): (String, String, Color) = switch run.outcome {
        case .passed: ("checkmark.circle.fill", "Passed", .green)
        case .failed: ("xmark.octagon.fill", "Failed", .red)
        case .running: ("arrow.triangle.2.circlepath.circle.fill", "Running", style.accent)
        case .other: ("minus.circle.fill", (run.conclusion ?? "Done").capitalized, .gray)
        }
        if large {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 26)).foregroundStyle(color)
                Text(word).font(style.title(20))
            }
        } else {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(color)
                .accessibilityLabel(word)
                .help(word)
        }
    }
}

/// GitHub's contribution calendar: a column per week, a square per day,
/// shaded by how much happened, in the theme's accent.
struct ContributionGraph: View {
    let days: [GitHubContributions.Day]
    let weeks: Int
    @Environment(\.widgetStyle) private var style

    var body: some View {
        Canvas { context, size in
            let columns = columns()
            guard !columns.isEmpty else { return }
            let gap: CGFloat = 2.5
            let cell = min((size.width - gap * CGFloat(columns.count - 1)) / CGFloat(columns.count), (size.height - gap * 6) / 7)
            let width = cell * CGFloat(columns.count) + gap * CGFloat(columns.count - 1)
            let x0 = (size.width - width) / 2
            for (column, week) in columns.enumerated() {
                for (row, level) in week.enumerated() {
                    guard let level else { continue }
                    let rect = CGRect(x: x0 + CGFloat(column) * (cell + gap), y: CGFloat(row) * (cell + gap), width: cell, height: cell)
                    let color = level == 0 ? style.ink.opacity(0.08) : style.accent.opacity([0, 0.32, 0.55, 0.78, 1][min(level, 4)])
                    context.fill(Path(roundedRect: rect, cornerRadius: cell * 0.22), with: .color(color))
                }
            }
        }
    }

    /// The last `weeks` weeks, Sunday on top, as levels (nil before the first day).
    private func columns() -> [[Int?]] {
        guard let first = days.first, let start = Self.parser.date(from: first.date) else { return [] }
        let offset = Calendar(identifier: .gregorian).component(.weekday, from: start) - 1
        var cells: [Int?] = Array(repeating: nil, count: offset) + days.map { $0.level }
        while cells.count % 7 != 0 { cells.append(nil) }
        let all = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
        return Array(all.suffix(weeks))
    }

    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: Status

/// Sites and APIs: up, slow or down, with how fast they answered lately.
struct StatusWidget: View {
    let instance: WidgetInstance
    let status: StatusService
    @Environment(\.widgetRefreshScale) private var refreshScale

    @Environment(\.widgetStyle) private var style

    var body: some View {
        let endpoints = Array(instance.options.endpoints.prefix(instance.size == .small ? 3 : instance.size == .medium ? 4 : 7))
        let checks = endpoints.map { status.check($0) }
        let down = checks.compactMap { $0 }.filter { $0.health != .up }.count
        let interval = instance.options.refresh.interval(for: .status).map { $0 * refreshScale }
        VStack(alignment: .leading, spacing: instance.size == .small ? 8 : 9) {
            WidgetHeader(title: "Status", symbol: "waveform.path.ecg",
                         detail: checks.contains { $0 == nil } ? "Checking…" : down == 0 ? "All up" : "\(down) need attention")
            if endpoints.isEmpty {
                WidgetStateView(kind: .empty, symbol: "network", title: "Nothing to watch", message: "Add a site or API in the widget's options.")
            }
            ForEach(Array(zip(endpoints, checks)), id: \.0.id) { endpoint, check in
                Button { if let url = URL(string: endpoint.url.contains("://") ? endpoint.url : "https://" + endpoint.url) { NSWorkspace.shared.open(url) } } label: {
                    row(endpoint, check)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(WidgetMetrics.padding(instance.size))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contextMenu {
            Button("Check Now") { for endpoint in instance.options.endpoints { status.checkIfNeeded(endpoint, maxAge: 0) } }
            Divider()
            WidgetMenuItems()
        }
        .widgetRefresh(every: interval, id: instance.options.endpoints.map(\.url)) {
            for endpoint in instance.options.endpoints { status.checkIfNeeded(endpoint, maxAge: interval ?? .infinity) }
        }
    }

    private func row(_ endpoint: StatusEndpoint, _ check: StatusCheck?) -> some View {
        let (symbol, color, word): (String, Color, String) = switch check?.health {
        case .up: ("checkmark.circle.fill", .green, "Up")
        case .degraded: ("exclamationmark.circle.fill", .orange, "Slow")
        case .down: ("xmark.circle.fill", .red, "Down")
        case nil: ("circle.dotted", .gray, "Checking")
        }
        return HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(color).accessibilityLabel(word)
            VStack(alignment: .leading, spacing: 0) {
                Text(endpoint.name).font(style.body(12, weight: .semibold)).lineLimit(1)
                if instance.size != .small {
                    Text(check?.message ?? word).font(style.body(10)).foregroundStyle(style.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if instance.size != .small, let history = check?.history, history.count > 1 {
                WidgetSparkline(values: history.map { $0 ?? 0 }, capacity: 24, color: color.opacity(0.8))
                    .frame(width: instance.size == .medium ? 60 : 90, height: 16)
            }
            Text(check?.latency.map { "\(Int($0)) ms" } ?? "—")
                .font(style.body(11))
                .monospacedDigit()
                .foregroundStyle(style.secondary)
                .frame(width: 52, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
