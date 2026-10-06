import Foundation
import IOKit

/// Small helpers over the IOKit registry C API.
enum IORegistry {
    static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    /// Calls `body` for every service matching `className`, releasing each afterwards.
    static func forEachService(matching className: String, _ body: (io_service_t) -> Void) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else {
            return
        }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != 0 {
            body(service)
            IOObjectRelease(service)
        }
    }

    static func int(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    /// IOKit hands some signed values (like battery amperage) back as unsigned
    /// 64-bit numbers; reading the bit pattern as Int64 restores the sign.
    static func signedInt(_ value: Any?) -> Int? {
        (value as? NSNumber).map { Int($0.int64Value) }
    }
}
