import Foundation
import Observation
import OSLog

/// Different actions while one app is in front. Empty slots use the usual action.
public struct KnockRule: Codable, Equatable, Identifiable, Sendable {
    public var bundleID: String
    public var appName: String
    public var single: KnockAction?
    public var double: KnockAction?
    public var triple: KnockAction?

    public var id: String { bundleID }

    public init(bundleID: String, appName: String, single: KnockAction? = nil,
                double: KnockAction? = nil, triple: KnockAction? = nil) {
        self.bundleID = bundleID
        self.appName = appName
        self.single = single
        self.double = double
        self.triple = triple
    }

    public subscript(count: KnockCount) -> KnockAction? {
        get {
            switch count {
            case .single: single
            case .double: double
            case .triple: triple
            }
        }
        set {
            switch count {
            case .single: single = newValue
            case .double: double = newValue
            case .triple: triple = newValue
            }
        }
    }

    public var isEmpty: Bool { single == nil && double == nil && triple == nil }

    private enum CodingKeys: String, CodingKey {
        case bundleID, appName, single, double, triple
    }

    // An action a later version dropped just leaves its slot empty.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try container.decode(String.self, forKey: .bundleID)
        appName = (try? container.decode(String.self, forKey: .appName)) ?? bundleID
        single = try? container.decodeIfPresent(KnockAction.self, forKey: .single)
        double = try? container.decodeIfPresent(KnockAction.self, forKey: .double)
        triple = try? container.decodeIfPresent(KnockAction.self, forKey: .triple)
    }
}

public struct KnockSettings: Codable, Equatable, Sendable {
    public var isEnabled = true
    /// Single knocks are the easiest to set off by accident, so they start empty.
    public var single: KnockAction?
    public var double: KnockAction? = .toggleIsland
    public var triple: KnockAction? = .playPause
    public var sensitivity = Sensitivity.normal
    /// `.both` ignores picking the Mac up or tilting the screen.
    public var signal = DetectionSignal.both
    /// Seconds to wait for another knock.
    public var tapWindow = 0.4
    public var ignoreWhileTyping = true
    public var restInLowPowerMode = true
    /// The sensor reports about 800 times a second while listening, so off
    /// the charger it rests unless asked not to.
    public var restOnBattery = true
    public var showInIsland = true
    public var playSound = false
    public var rules: [KnockRule] = []

    public init() {}

    public subscript(count: KnockCount) -> KnockAction? {
        get {
            switch count {
            case .single: single
            case .double: double
            case .triple: triple
            }
        }
        set {
            switch count {
            case .single: single = newValue
            case .double: double = newValue
            case .triple: triple = newValue
            }
        }
    }

    /// What a knock does with `bundleID` in front: its rule, or the usual action.
    public func action(for count: KnockCount, frontmost bundleID: String?) -> KnockAction? {
        if let bundleID, let rule = rules.first(where: { $0.bundleID == bundleID }), let action = rule[count] {
            return action
        }
        return self[count]
    }

    /// Counts with an action anywhere, so the detector knows how long to wait.
    /// Rules count too: a double knock set only for Safari still needs the
    /// detector to wait for a second knock.
    public var assignedCounts: Set<Int> {
        Set(KnockCount.allCases.filter { count in
            self[count] != nil || rules.contains { $0[count] != nil }
        }.map(\.rawValue))
    }

    public var detectorConfiguration: DetectorConfiguration {
        var configuration = DetectorConfiguration(sensitivity: sensitivity, signal: signal)
        configuration.tapWindow = tapWindow
        configuration.assignedCounts = assignedCounts
        configuration.typingSuppression = ignoreWhileTyping ? 0.25 : 0
        return configuration
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, single, double, triple, sensitivity, signal, tapWindow, ignoreWhileTyping,
             restInLowPowerMode, restOnBattery, showInIsland, playSound, rules
    }

    // Written by hand so a missing or unreadable value falls back to its
    // default instead of losing everything, and a cleared slot stays cleared.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = KnockSettings()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        func action(_ key: CodingKeys, _ fallback: KnockAction?) -> KnockAction? {
            container.contains(key) ? (try? container.decode(KnockAction?.self, forKey: key)) ?? nil : fallback
        }
        isEnabled = value(.isEnabled, defaults.isEnabled)
        single = action(.single, defaults.single)
        double = action(.double, defaults.double)
        triple = action(.triple, defaults.triple)
        sensitivity = value(.sensitivity, defaults.sensitivity)
        signal = value(.signal, defaults.signal)
        tapWindow = value(.tapWindow, defaults.tapWindow).clamped(to: DetectorConfiguration.tapWindowRange)
        ignoreWhileTyping = value(.ignoreWhileTyping, defaults.ignoreWhileTyping)
        restInLowPowerMode = value(.restInLowPowerMode, defaults.restInLowPowerMode)
        restOnBattery = value(.restOnBattery, defaults.restOnBattery)
        showInIsland = value(.showInIsland, defaults.showInIsland)
        playSound = value(.playSound, defaults.playSound)
        rules = value(.rules, defaults.rules)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(single, forKey: .single)
        try container.encode(double, forKey: .double)
        try container.encode(triple, forKey: .triple)
        try container.encode(sensitivity, forKey: .sensitivity)
        try container.encode(signal, forKey: .signal)
        try container.encode(tapWindow, forKey: .tapWindow)
        try container.encode(ignoreWhileTyping, forKey: .ignoreWhileTyping)
        try container.encode(restInLowPowerMode, forKey: .restInLowPowerMode)
        try container.encode(restOnBattery, forKey: .restOnBattery)
        try container.encode(showInIsland, forKey: .showInIsland)
        try container.encode(playSound, forKey: .playSound)
        try container.encode(rules, forKey: .rules)
    }
}

/// Knock settings, saved to Application Support as they change.
@Observable @MainActor
public final class KnockStore {
    public var settings: KnockSettings {
        didSet { if settings != oldValue { scheduleSave() } }
    }

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "knock")

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AllSet/knocks.json")
        settings = StoreFile.load(KnockSettings.self, from: self.fileURL)
            ?? KnockSettings()
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    public func save() {
        pendingSave?.cancel()
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(settings).write(to: fileURL, options: .atomic)
        } catch {
            log.error("Couldn't save knock settings: \(error.localizedDescription, privacy: .public)")
        }
    }
}
