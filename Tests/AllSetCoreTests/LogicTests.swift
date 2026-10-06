import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite struct FormatTests {
    @Test func percentClampsAndRounds() {
        #expect(Format.percent(0.234) == "23%")
        #expect(Format.percent(1.4) == "100%")
        #expect(Format.percent(-0.2) == "0%")
        #expect(Format.percent(.nan) == "–")
    }

    @Test func decimalBytes() {
        #expect(Format.bytes(512) == "512 B")
        #expect(Format.bytes(1_500) == "1.5 KB")
        #expect(Format.bytes(34_000) == "34 KB")
        #expect(Format.bytes(2_345_000) == "2.3 MB")
        // Rounds up across the unit boundary instead of printing "1000 KB".
        #expect(Format.bytes(999_700) == "1.0 MB")
        #expect(Format.rate(1_200_000) == "1.2 MB/s")
    }

    @Test func binaryMemory() {
        #expect(Format.memory(16 * 1024 * 1024 * 1024) == "16 GB")
        #expect(Format.memory(1536 * 1024 * 1024) == "1.5 GB")
    }

    @Test func temperatureUnits() {
        #expect(Format.temperature(38.4, unit: .celsius) == "38°")
        #expect(Format.temperature(100, unit: .fahrenheit) == "212°")
    }

    @Test func perAppPower() {
        #expect(Format.power(0.0454) == "45 mW")
        #expect(Format.power(0.9994) == "999 mW")
        #expect(Format.power(0.9996) == "1.0 W")
        #expect(Format.power(2.34) == "2.3 W")
    }

    @Test func clockAndDuration() {
        #expect(Format.clock(187) == "3:07")
        #expect(Format.clock(3723) == "1:02:03")
        #expect(Format.clock(-5) == "0:00")
        #expect(Format.duration(minutes: 45) == "45m")
        #expect(Format.duration(minutes: 570) == "9h 30m")
    }
}

@Suite struct RollingSeriesTests {
    @Test func keepsNewestValuesUpToCapacity() {
        var series = RollingSeries(capacity: 3)
        for value in [1.0, 2, 3, 4, 5] { series.append(value) }
        #expect(series.values == [3, 4, 5])
        #expect(series.latest == 5)
        #expect(series.maximum == 5)
    }
}

@Suite struct LineReaderTests {
    @Test func reassemblesLinesSplitAcrossChunks() {
        let collected = Collected()
        let reader = LineReader { collected.append(String(decoding: $0, as: UTF8.self)) }
        reader.append(Data("{\"a\":1}\n{\"b\"".utf8))
        reader.append(Data(":2}\n\n{\"c\":3".utf8))
        #expect(collected.values == ["{\"a\":1}", "{\"b\":2}", ""])
        reader.append(Data("}\n".utf8))
        #expect(collected.values.last == "{\"c\":3}")
    }
}

@Suite struct CPUMathTests {
    @Test func computesPerCoreAndTotalUsage() {
        let old = [CPUTicks(user: 100, system: 50, idle: 850, nice: 0),
                   CPUTicks(user: 0, system: 0, idle: 1000, nice: 0)]
        let new = [CPUTicks(user: 160, system: 70, idle: 870, nice: 0),   // 80 busy of 100
                   CPUTicks(user: 10, system: 0, idle: 1090, nice: 0)]    // 10 busy of 100
        let usage = CPUMath.usage(from: old, to: new)
        #expect(usage.perCore == [0.8, 0.1])
        #expect(abs(usage.total - 0.45) < 1e-9)
        #expect(abs(usage.user - 0.35) < 1e-9)
        #expect(abs(usage.system - 0.10) < 1e-9)
    }

    @Test func survivesCounterWraparound() {
        let old = [CPUTicks(user: UInt32.max - 9, system: 0, idle: 0, nice: 0)]
        let new = [CPUTicks(user: 10, system: 0, idle: 20, nice: 0)] // user +20, idle +20
        #expect(CPUMath.usage(from: old, to: new).perCore == [0.5])
    }

    @Test func firstSampleReportsZero() {
        let usage = CPUMath.usage(from: [], to: [CPUTicks(user: 5, system: 5, idle: 5, nice: 0)])
        #expect(usage.perCore == [0])
        #expect(usage.total == 0)
    }
}

@Suite struct MemoryMathTests {
    @Test func matchesActivityMonitorDefinitions() {
        let pages = VMPageCounts(anonymous: 1000, purgeable: 100, external: 300, wired: 200, compressed: 50)
        let usage = MemoryMath.usage(pages: pages, pageSize: 16_384, total: 100_000_000)
        #expect(usage.app == 900 * 16_384)
        #expect(usage.wired == 200 * 16_384)
        #expect(usage.compressed == 50 * 16_384)
        #expect(usage.cached == 400 * 16_384)
        #expect(usage.used == (900 + 200 + 50) * 16_384)
    }
}

@Suite struct BatteryMathTests {
    @Test func healthIsFullChargeOverDesign() {
        // Values read from this project's development MacBook Air.
        let health = BatteryMath.health(fullChargeCapacity: 4469, designCapacity: 4629)
        #expect(health.map { abs($0 - 0.9654) < 0.001 } == true)
        #expect(BatteryMath.health(fullChargeCapacity: 5000, designCapacity: 4629) == 1)
        #expect(BatteryMath.health(fullChargeCapacity: nil, designCapacity: 4629) == nil)
    }

    @Test func wattsFromVoltageAndAmperage() {
        var info = BatteryInfo(percent: 84, isCharging: false, isPluggedIn: false)
        info.voltage = 12.527
        info.amperage = -0.362
        #expect(info.batteryWatts.map { abs($0 + 4.5348) < 0.001 } == true)
    }
}

@Suite struct NotchGeometryTests {
    @Test func findsThePhysicalNotch() {
        // NSScreen values from a 13" M4 MacBook Air at default scaling.
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            safeAreaTop: 32,
            topLeftArea: CGRect(x: 0, y: 924, width: 646, height: 32),
            topRightArea: CGRect(x: 825, y: 924, width: 645, height: 32),
            menuBarHeight: 34
        )
        #expect(geometry.hasPhysicalNotch)
        #expect(geometry.notchRect == CGRect(x: 646, y: 924, width: 179, height: 32))
        #expect(geometry.hangingRect(size: CGSize(width: 300, height: 100))
                == CGRect(x: 585.5, y: 856, width: 300, height: 100))
    }

    @Test func centersAVirtualNotchOnOtherScreens() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 1470, y: 0, width: 2560, height: 1440),
            safeAreaTop: 0, topLeftArea: nil, topRightArea: nil, menuBarHeight: 25
        )
        #expect(!geometry.hasPhysicalNotch)
        #expect(geometry.notchRect.midX == CGFloat(1470 + 1280))
        #expect(geometry.notchRect.maxY == 1440)
        #expect(geometry.notchRect.height == 25)
    }
}

@Suite struct NowPlayingInfoTests {
    private func message(_ json: String) throws -> MediaHelperMessage {
        try JSONDecoder().decode(MediaHelperMessage.self, from: Data(json.utf8))
    }

    @Test func decodesHelperMessage() throws {
        let received = Date(timeIntervalSince1970: 2_000)
        let info = try #require(NowPlayingInfo(message: message("""
            {"type":"nowPlaying","hasInfo":true,"isPlaying":true,"title":"Song","artist":"Band",
             "duration":200,"elapsedTime":50,"timestamp":1000,"playbackRate":1,
             "bundleIdentifier":"com.apple.WebKit.GPU","parentBundleIdentifier":"com.apple.Safari","artworkID":"abc"}
            """), receivedAt: received))
        #expect(info.title == "Song")
        #expect(info.artist == "Band")
        #expect(info.duration == 200)
        #expect(info.timestamp == Date(timeIntervalSince1970: 1000))
        // Web media reports a helper process; the browser is what should show.
        #expect(info.bundleIdentifier == "com.apple.Safari")
        #expect(info.artworkID == "abc")
    }

    @Test func noInfoMeansNothingPlaying() throws {
        #expect(NowPlayingInfo(message: try message(#"{"type":"nowPlaying","hasInfo":false,"isPlaying":false}"#)) == nil)
        #expect(NowPlayingInfo(message: try message(#"{"type":"ready"}"#)) == nil)
    }

    @Test func extrapolatesElapsedTimeWhilePlaying() throws {
        let info = try #require(NowPlayingInfo(message: message("""
            {"type":"nowPlaying","hasInfo":true,"isPlaying":true,"title":"Song",
             "duration":200,"elapsedTime":50,"timestamp":1000,"playbackRate":1}
            """)))
        #expect(info.elapsed(at: Date(timeIntervalSince1970: 1010)) == 60)
        #expect(info.elapsed(at: Date(timeIntervalSince1970: 5000)) == 200) // clamped to duration
        #expect(info.progress(at: Date(timeIntervalSince1970: 1050)) == 0.5)

        var paused = info
        paused.isPlaying = false
        #expect(paused.elapsed(at: Date(timeIntervalSince1970: 1010)) == 50)
    }
}

@Suite struct PowerEventTests {
    @Test func detectsPlugAndUnplug() {
        let battery = PowerState(percent: 50, isPluggedIn: false, isCharging: false)
        let charging = PowerState(percent: 50, isPluggedIn: true, isCharging: true)
        #expect(PowerSourceMonitor.events(from: battery, to: charging) == [.pluggedIn(percent: 50)])
        #expect(PowerSourceMonitor.events(from: charging, to: battery) == [.unplugged(percent: 50)])
    }

    @Test func warnsOnceWhenCrossingALowBatteryThreshold() {
        let at21 = PowerState(percent: 21, isPluggedIn: false, isCharging: false)
        let at20 = PowerState(percent: 20, isPluggedIn: false, isCharging: false)
        let at19 = PowerState(percent: 19, isPluggedIn: false, isCharging: false)
        #expect(PowerSourceMonitor.events(from: at21, to: at20) == [.lowBattery(percent: 20)])
        #expect(PowerSourceMonitor.events(from: at20, to: at19).isEmpty)
        // Not while plugged in.
        let pluggedAt20 = PowerState(percent: 20, isPluggedIn: true, isCharging: true)
        let pluggedAt21 = PowerState(percent: 21, isPluggedIn: true, isCharging: true)
        #expect(PowerSourceMonitor.events(from: pluggedAt21, to: pluggedAt20).isEmpty)
    }
}

@Suite struct ProcessGroupingTests {
    @Test func helpersCountTowardTheirOutermostApp() {
        let renderer = "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/"
            + "Versions/140.0/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)"
        #expect(ProcessGrouping.appBundlePath(forExecutable: renderer) == "/Applications/Google Chrome.app")
        #expect(ProcessGrouping.appBundlePath(forExecutable: "/System/Applications/Mail.app/Contents/MacOS/Mail")
                == "/System/Applications/Mail.app")
    }

    @Test func processesOutsideAppsStandAlone() {
        #expect(ProcessGrouping.appBundlePath(forExecutable: "/usr/libexec/trustd") == nil)
        #expect(ProcessGrouping.displayName(forGroup: "/usr/libexec/trustd") == "trustd")
        #expect(ProcessGrouping.displayName(forGroup: "/Applications/Visual Studio Code.app") == "Visual Studio Code")
    }
}

@Suite struct TemperatureSensorTests {
    @Test func classifiesAppleSiliconSensorNames() {
        #expect(TemperatureSensorKind.classify("PMU tdie3") == .soc)
        #expect(TemperatureSensorKind.classify("PMU2 tdie10") == .soc)
        #expect(TemperatureSensorKind.classify("gas gauge battery") == .battery)
        #expect(TemperatureSensorKind.classify("NAND CH0 temp") == .ssd)
        #expect(TemperatureSensorKind.classify("PMU tdev1") == nil)
        #expect(TemperatureSensorKind.classify("PMU tcal") == nil)
    }
}

@Suite @MainActor struct AppSettingsTests {
    @Test func persistsChangesAndRestoresThem() throws {
        let suite = "AllSetTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        #expect(settings.expandOnHover)
        #expect(settings.notchDisplay == .builtIn)

        settings.expandOnHover = false
        settings.notchDisplay = .primary
        settings.temperatureUnit = .fahrenheit
        settings.hoverDelay = 0.3

        let reloaded = AppSettings(defaults: defaults)
        #expect(!reloaded.expandOnHover)
        #expect(reloaded.notchDisplay == .primary)
        #expect(reloaded.temperatureUnit == .fahrenheit)
        #expect(reloaded.hoverDelay == 0.3)
    }
}

final class Collected: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    func append(_ value: String) { lock.withLock { storage.append(value) } }
    var values: [String] { lock.withLock { storage } }
}
