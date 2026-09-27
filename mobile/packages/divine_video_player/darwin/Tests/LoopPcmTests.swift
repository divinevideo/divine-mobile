import Foundation

/// The seam rules of [LoopPcm], on synthetic sound whose right answer is
/// known. Each one was got wrong at least once on device and heard there.
@main
enum LoopPcmTests {
    static let rate = 44_100.0
    static let loop = 44_100

    static func main() {
        blendsWithWhatFollowsTheLoopPoint()
        carriesOnFromTheLapWhenNothingLiveFollows()
        keepsAHeadOfDigitalSilence()
        rampsADecodeThatEndsBeforeTheLoop()
        placesTheDecodeByItsFirstTimestamp()
        print("Loop PCM tests passed")
    }

    /// A tone sounding on past the loop point is blended with that
    /// continuation, so the seam steps no further than the tone itself does
    /// from one sample to the next.
    static func blendsWithWhatFollowsTheLoopPoint() {
        let samples = tone(frames: loop + 8_820, channels: 2)
        let prepared = LoopPcm.prepare(
            samples: samples, channels: 2, sampleRate: rate, loopFrames: loop, startFrame: 0
        )!
        precondition(prepared.blendedFromPastTheLoop)
        precondition(prepared.loopFrames == loop)
        precondition(prepared.samples.count == loop * 2)
        for channel in 0..<2 {
            precondition(seamStep(prepared, channel: channel) <= maxToneStep + 1e-4)
        }
    }

    /// A track that stops dead at the loop point — the decoder ringing out
    /// into silence — is not blended with: that dipped the seam to near
    /// silence. The lap is carried on from where it best matches its own
    /// end instead, and the seam stays as smooth as the tone.
    static func carriesOnFromTheLapWhenNothingLiveFollows() {
        let samples = tone(frames: loop, channels: 1) + [Float](repeating: 0, count: 8_820)
        let prepared = LoopPcm.prepare(
            samples: samples, channels: 1, sampleRate: rate, loopFrames: loop, startFrame: 0
        )!
        precondition(!prepared.blendedFromPastTheLoop)
        precondition(prepared.lapLagFrames > 0)
        precondition(seamStep(prepared, channel: 0) <= maxToneStep * 1.2)
        // Carried on, not ramped: the lap ends at full level.
        precondition(rms(prepared.samples[(loop - 220)...]) > 0.3)
    }

    /// A lap that opens with digital silence keeps it — every fill of that
    /// silence was heard as worse on device — and ramps its tail into it.
    static func keepsAHeadOfDigitalSilence() {
        let head = [Float](repeating: 0, count: 441)
        let samples = head + tone(frames: loop - 441, channels: 1)
            + [Float](repeating: 0, count: 8_820)
        let prepared = LoopPcm.prepare(
            samples: samples, channels: 1, sampleRate: rate, loopFrames: loop, startFrame: 0
        )!
        precondition(!prepared.blendedFromPastTheLoop)
        precondition(prepared.lapLagFrames == 0)
        precondition(prepared.fadeFrames > 0)
        precondition(prepared.samples[0..<441].allSatisfy { $0 == 0 })
        precondition(abs(prepared.samples[loop - 1]) < 0.01)
    }

    /// A decode that ends before the loop does is padded with silence, with
    /// both of its edges ramped.
    static func rampsADecodeThatEndsBeforeTheLoop() {
        let samples = tone(frames: loop - 4_410, channels: 1)
        let prepared = LoopPcm.prepare(
            samples: samples, channels: 1, sampleRate: rate, loopFrames: loop, startFrame: 0
        )!
        precondition(prepared.samples.count == loop)
        precondition(prepared.fadeFrames > 0)
        precondition(prepared.samples[(loop - 4_410)...].allSatisfy { $0 == 0 })
        precondition(abs(prepared.samples[loop - 4_411]) < 0.01)
    }

    /// The decode is placed on the clip's timeline by its first timestamp:
    /// one starting late opens the loop with that much silence, one starting
    /// early loses the frames the player never presents.
    static func placesTheDecodeByItsFirstTimestamp() {
        let late = LoopPcm.prepare(
            samples: tone(frames: loop - 1_000, channels: 1),
            channels: 1, sampleRate: rate, loopFrames: loop, startFrame: 1_000
        )!
        precondition(late.samples[0..<1_000].allSatisfy { $0 == 0 })
        precondition(late.samples[1_000..<2_000].contains { $0 != 0 })

        let early = LoopPcm.prepare(
            samples: [Float](repeating: 0.25, count: 150) + tone(frames: loop + 8_820, channels: 1),
            channels: 1, sampleRate: rate, loopFrames: loop, startFrame: -150
        )!
        let expected = tone(frames: 10_001, channels: 1)[10_000]
        precondition(abs(early.samples[10_000] - expected) < 1e-6)
    }

    // MARK: - Helpers

    /// Not a whole number of periods per loop, so a hard cut at the loop
    /// point would jump.
    static let frequency = 437.25
    static let amplitude: Float = 0.5

    /// The largest step a tone of [frequency] takes between two samples.
    static var maxToneStep: Float {
        amplitude * Float(2 * Double.pi * frequency / rate)
    }

    /// A sine of [frequency], the same on every channel, interleaved.
    static func tone(frames: Int, channels: Int) -> [Float] {
        var out = [Float](repeating: 0, count: frames * channels)
        for frame in 0..<frames {
            let value = amplitude * Float(sin(2 * Double.pi * frequency * Double(frame) / rate))
            for channel in 0..<channels { out[frame * channels + channel] = value }
        }
        return out
    }

    static func rms(_ samples: ArraySlice<Float>) -> Float {
        (samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)).squareRoot()
    }

    /// How far the sound jumps where the loop's last frame meets its first.
    static func seamStep(_ prepared: LoopPcm.Prepared, channel: Int) -> Float {
        let channels = prepared.samples.count / prepared.loopFrames
        let last = prepared.samples[(prepared.loopFrames - 1) * channels + channel]
        let first = prepared.samples[channel]
        return abs(first - last)
    }
}
