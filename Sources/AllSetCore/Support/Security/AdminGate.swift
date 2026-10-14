import Foundation
import LocalAuthentication

/// Touch ID, falling back to this Mac's login password — for the one
/// action in the app that reaches past this Mac and permanently deletes
/// something everywhere (the database, the server's file, this Mac's
/// copy). Nothing else in the app is gated by this.
public enum AdminGate {
    /// True only after a real, fresh check this call. Never cached: a
    /// permanent, cross-system delete asks again every time, not once per
    /// launch.
    public static func authorize(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
