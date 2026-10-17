import Foundation

/// Ids renamed on 2026-10-17, when the football and music themes stopped
/// pointing at real players, clubs and artists. Saved desktops, favorites,
/// theme photos and palettes written before then still name the old ids; they
/// are read through this table and saved under the new ones from then on.
///
/// This is the one file allowed to spell the old ids
/// (`RealPeopleDenylistTests.noSourceFileNamesARealPerson` skips it). Nothing
/// here is ever shown or searched.
public enum LegacyIdentifiers {
    static let themes: [String: String] = [
        "seven": "floodlightGold", "redSeven": "rainDerby", "bleuRoyal": "midnightSprint",
        "milanoNights": "emberTerrace", "galactico": "ivoryCrown", "albiceleste": "skyPlaymaker",
        "oRei": "goldenAge", "sambaNeon": "neonFlair", "miamiPink": "palmNightPink",
        "rageMode": "emberCrowd", "sadHours": "rainHours", "slimeGreen": "acidMoss",
        "opiumPunk": "gothicStatic", "blondSummer": "sunflowerDrive",
    ]

    static let palettes: [String: String] = [
        "rossoneri": "emberCharcoal", "blaugrana": "violetGold", "opium": "bloodRed",
    ]

    /// A theme or theme-set id as it is now: `seven` and `setup.seven` become
    /// `floodlightGold` and `setup.floodlightGold`; anything else is unchanged.
    public static func theme(_ id: String) -> String {
        let prefix = "setup."
        if id.hasPrefix(prefix), let renamed = themes[String(id.dropFirst(prefix.count))] { return prefix + renamed }
        return themes[id] ?? id
    }

    public static func palette(_ raw: String) -> String { palettes[raw] ?? raw }

    /// A saved dictionary keyed by theme-set id, with old keys moved to new ones.
    /// A key saved under both keeps the new one's value.
    public static func themeKeys<Value>(_ saved: [String: Value]) -> [String: Value] {
        var result: [String: Value] = [:]
        for (key, value) in saved where theme(key) == key { result[key] = value }
        for (key, value) in saved where theme(key) != key && result[theme(key)] == nil { result[theme(key)] = value }
        return result
    }
}
