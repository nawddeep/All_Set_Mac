import Foundation
import Testing
@testable import AllSetCore

/// Review R3: the gain is written by the app while the audio thread reads it.
/// Run under ThreadSanitizer (`swift test --sanitize=thread --filter GainBoxTests`)
/// this reported a data race with the plain Float; with atomic load/store it doesn't.
@Suite struct GainBoxTests {
    @Test func theAudioThreadOnlyEverSeesGainsThatWereSet() async {
        let box = GainBox(0)
        let values: [Float] = (0...200).map { Float($0) / 100 }
        let allowed = Set(values.map(\.bitPattern))

        // The app sets volumes rapidly while the "audio thread" reads once per buffer.
        let writer = Task.detached {
            for _ in 0..<50 { for value in values { box.gain = value } }
        }
        let reader = Task.detached { () -> Bool in
            for _ in 0..<10_000 {
                if !allowed.contains(box.loadTarget().bitPattern) { return false }
            }
            return true
        }
        await writer.value
        #expect(await reader.value)
        #expect(box.gain == values.last)
    }

    @Test func aNewGainTakesEffectForTheNextBuffer() {
        let box = GainBox(1)
        box.gain = 0.25
        #expect(box.loadTarget() == 0.25)
        #expect(box.current.pointee == 1)  // the ramp starts where the last buffer ended
    }
}
