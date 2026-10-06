import Foundation

/// Reads the hardware off the main thread. A detailed sample walks every
/// process and several IOKit services, which would otherwise stall animations.
actor SystemSampler {
    private let cpu = CPUReader()
    private let gpu = GPUReader()
    private let memory = MemoryReader()
    private let network = NetworkReader()
    private let disk = DiskReader()
    private let temperatures = TemperatureReader()
    private let processes = ProcessEnergyReader()

    static let topAppCount = 5

    /// A new snapshot based on `previous`. Quick samples refresh only the cheap
    /// readings and carry the rest over.
    func sample(detailed: Bool, previous: SystemSnapshot) -> SystemSnapshot {
        var next = previous
        next.cpu = cpu.read()
        next.gpu = gpu.read()
        next.memory = memory.read()
        next.network = network.read()
        if detailed {
            next.disk = disk.read()
            next.battery = BatteryReader.read()
            next.temperatures = temperatures.read()
            // Newer macOS leaves the battery's temperature out of the registry; the
            // battery gauge's own sensor reads the same thing.
            if next.battery?.temperatureCelsius == nil { next.battery?.temperatureCelsius = next.temperatures.battery }
            (next.topApps, next.memoryApps) = processes.read(limit: Self.topAppCount)
        }
        next.thermal = ThermalLevel(ProcessInfo.processInfo.thermalState)
        return next
    }
}
