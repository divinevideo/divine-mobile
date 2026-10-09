import AVFoundation
import Foundation

/// The copy of an overlay track's sound the preview plays when the track has
/// an equalizer: the stretch of the source it plays through the export's
/// chain, sample for sample in place.
@main
enum EqualizedAudioFileTests {
    static func main() async {
        await aLowShelfLiftsALowToneAndKeepsItsLength()
        await aBoostIsLimitedAtTheExportCeiling()
        await anUnreadableSourceRendersNothing()
        await onlyTheStretchAskedForIsRendered()
        await aStretchPastTheEndStopsWhereTheSourceDoes()
        await aCancelledRenderRendersNothing()
        await aRenderCancelledPartWayStopsReading()
        await aHighRateSourceIsCopiedAt48kHz()
        copiesListsTheCopiesAndNothingElse()
        print("Equalized audio file tests passed")
    }

    /// A 60 Hz tone under a low shelf 12 dB up plays ~3.92 times as loud once
    /// the filter has settled, from a copy exactly as long as its source.
    static func aLowShelfLiftsALowToneAndKeepsItsLength() async {
        let source = writeTone(amplitude: 0.1, channels: 2)
        defer { try? FileManager.default.removeItem(at: source) }
        guard
            let copy = await EqualizedAudioFile.render(
                source: source, equalizer: bassBoost(12), from: 0, to: 1)
        else { preconditionFailure("no copy rendered") }
        defer { try? FileManager.default.removeItem(at: copy.url) }
        precondition(copy.url.pathExtension == "caf")
        precondition(copy.startSec == 0)
        let (samples, channels, frames) = read(copy.url)
        precondition(channels == 2)
        precondition(frames == 48_000, "\(frames)")
        // Each channel through its own filters, both lifted alike.
        for channel in 0..<channels {
            let settled = stride(
                from: 24_000 * channels + channel, to: samples.count, by: channels
            ).map { abs(samples[$0]) }
            let peak = settled.max() ?? 0
            precondition(abs(peak - 0.392) < 0.01, "channel \(channel): \(peak)")
        }
    }

    static func aBoostIsLimitedAtTheExportCeiling() async {
        let source = writeTone(amplitude: 0.8, channels: 1)
        defer { try? FileManager.default.removeItem(at: source) }
        guard
            let copy = await EqualizedAudioFile.render(
                source: source, equalizer: bassBoost(12), from: 0, to: 1)
        else { preconditionFailure("no copy rendered") }
        defer { try? FileManager.default.removeItem(at: copy.url) }
        let peak = read(copy.url).samples.map(abs).max() ?? 0
        precondition(peak <= PeakLimiter.ceiling + 1e-4, "\(peak)")
    }

    static func anUnreadableSourceRendersNothing() async {
        let source = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("eq_missing_\(UUID().uuidString).wav")
        let copy = await EqualizedAudioFile.render(
            source: source, equalizer: bassBoost(6), from: 0, to: 1)
        precondition(copy == nil)
    }

    /// A copy of 0.25–0.75 s holds that half second and no more, starting on
    /// the source's sample at 0.25 s: the 60 Hz tone passes a peak far above
    /// it unchanged, so the copy is the source shifted by 12 000 frames.
    static func onlyTheStretchAskedForIsRendered() async {
        let amplitude = 0.1
        let source = writeTone(amplitude: amplitude, channels: 1)
        defer { try? FileManager.default.removeItem(at: source) }
        let equalizer = AudioEqualizer(bands: [.init(type: .peak, frequencyHz: 8_000, gainDb: 1)])
        guard
            let copy = await EqualizedAudioFile.render(
                source: source, equalizer: equalizer, from: 0.25, to: 0.75)
        else { preconditionFailure("no copy rendered") }
        defer { try? FileManager.default.removeItem(at: copy.url) }
        precondition(copy.startSec == 0.25)
        let (samples, _, frames) = read(copy.url)
        precondition(frames == 24_000, "\(frames)")
        for frame in stride(from: 0, to: frames, by: 997) {
            let expected = amplitude * sin(2 * Double.pi * 60 * Double(12_000 + frame) / 48_000)
            precondition(abs(Double(samples[frame]) - expected) < 1e-3, "\(frame): \(samples[frame])")
        }
    }

    /// Asked for more than the source holds, the copy ends where it does.
    static func aStretchPastTheEndStopsWhereTheSourceDoes() async {
        let source = writeTone(amplitude: 0.1, channels: 1)
        defer { try? FileManager.default.removeItem(at: source) }
        guard
            let copy = await EqualizedAudioFile.render(
                source: source, equalizer: bassBoost(6), from: 0.5, to: 5)
        else { preconditionFailure("no copy rendered") }
        defer { try? FileManager.default.removeItem(at: copy.url) }
        precondition(read(copy.url).frames == 24_000, "\(read(copy.url).frames)")
    }

    /// A render whose task is cancelled, as a superseded one is, gives no copy.
    static func aCancelledRenderRendersNothing() async {
        let source = writeTone(amplitude: 0.1, channels: 2, seconds: 20)
        defer { try? FileManager.default.removeItem(at: source) }
        let render = Task {
            await EqualizedAudioFile.render(source: source, equalizer: bassBoost(6), from: 0, to: 20)
        }
        render.cancel()
        let copy = await render.value
        copy.map { try? FileManager.default.removeItem(at: $0.url) }
        precondition(copy == nil)
    }

    /// A render cancelled part-way, as a superseded one is when the curve
    /// settles again, stops reading there instead of rendering the rest of
    /// its stretch and then dropping it. Timed against an uncancelled render
    /// of the same stretch, so the bound holds on a slower machine.
    static func aRenderCancelledPartWayStopsReading() async {
        let source = writeTone(amplitude: 0.1, channels: 2, seconds: 60)
        defer { try? FileManager.default.removeItem(at: source) }
        let clock = ContinuousClock()
        let full = await clock.measure {
            let copy = await EqualizedAudioFile.render(
                source: source, equalizer: bassBoost(6), from: 0, to: 60)
            precondition(copy != nil, "no copy rendered")
            copy.map { try? FileManager.default.removeItem(at: $0.url) }
        }
        let render = Task {
            await EqualizedAudioFile.render(source: source, equalizer: bassBoost(6), from: 0, to: 60)
        }
        try? await Task.sleep(for: full / 20)
        let cancelled = clock.now
        render.cancel()
        let copy = await render.value
        let afterCancel = clock.now - cancelled
        copy.map { try? FileManager.default.removeItem(at: $0.url) }
        precondition(copy == nil)
        precondition(afterCancel < full / 3, "\(afterCancel) after cancel; full render \(full)")
    }

    /// A source's own sample rate sizes its copy, so one declaring a far
    /// higher rate than it needs, which a published sound can, would multiply
    /// what a stretch costs; above 192 kHz the copy was also labelled
    /// 192 kHz and played slower and lower. A rate above 48 kHz is read at
    /// 48 kHz, so a second of copy is a second of sound at a known size.
    static func aHighRateSourceIsCopiedAt48kHz() async {
        let source = writeTone(amplitude: 0.1, channels: 2, sampleRate: 384_000)
        defer { try? FileManager.default.removeItem(at: source) }
        guard
            let copy = await EqualizedAudioFile.render(
                source: source, equalizer: bassBoost(6), from: 0, to: 1)
        else { preconditionFailure("no copy rendered") }
        defer { try? FileManager.default.removeItem(at: copy.url) }
        let rate = try! AVAudioFile(forReading: copy.url).fileFormat.sampleRate
        precondition(rate == 48_000, "\(rate)")
        // The resampler can end a few frames short of the second.
        let frames = read(copy.url).frames
        precondition(abs(frames - 48_000) <= 16, "\(frames)")
    }

    /// The copies and downloads are listed by their name; other files in the
    /// temporary directory are not.
    static func copiesListsTheCopiesAndNothingElse() {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        let copy = directory.appendingPathComponent("divine_eq_test_\(UUID().uuidString).caf")
        let other = directory.appendingPathComponent("eq_other_\(UUID().uuidString).caf")
        for file in [copy, other] {
            FileManager.default.createFile(atPath: file.path, contents: Data([1]))
        }
        defer { [copy, other].forEach { try? FileManager.default.removeItem(at: $0) } }
        let names = Set(EqualizedAudioFile.copies().map(\.lastPathComponent))
        precondition(names.contains(copy.lastPathComponent))
        precondition(!names.contains(other.lastPathComponent))
    }

    static func bassBoost(_ gainDb: Double) -> AudioEqualizer {
        AudioEqualizer(bands: [.init(type: .lowShelf, frequencyHz: 200, gainDb: gainDb)])
    }

    /// [seconds] of a 60 Hz tone at [sampleRate], written as 16-bit WAV.
    static func writeTone(
        amplitude: Double, channels: AVAudioChannelCount, seconds: Int = 1,
        sampleRate: Int = 48_000
    ) -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("eq_source_\(UUID().uuidString).wav")
        // AVAudioFile completes the file once released; see EqualizedAudioFile.
        autoreleasepool {
            writeTone(
                amplitude: amplitude, channels: channels, seconds: seconds,
                sampleRate: sampleRate, to: url)
        }
        return url
    }

    static func writeTone(
        amplitude: Double, channels: AVAudioChannelCount, seconds: Int,
        sampleRate: Int = 48_000, to url: URL
    ) {
        let format = AVAudioFormat(
            standardFormatWithSampleRate: Double(sampleRate), channels: channels)!
        let file = try! AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
            ])
        let frameCount = sampleRate * seconds
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)
        for channel in 0..<Int(channels) {
            for frame in 0..<frameCount {
                buffer.floatChannelData![channel][frame] = Float(
                    amplitude * sin(2 * Double.pi * 60 * Double(frame) / Double(sampleRate)))
            }
        }
        try! file.write(from: buffer)
    }

    /// The copy's samples, interleaved, with its channel and frame counts.
    static func read(_ url: URL) -> (samples: [Float], channels: Int, frames: Int) {
        let file = try! AVAudioFile(forReading: url)
        let format = file.processingFormat
        let channels = Int(format.channelCount)
        var samples: [Float] = []
        // One read can stop short of the end, so read until there is none.
        while file.framePosition < file.length {
            let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_096)!
            try! file.read(into: chunk)
            guard chunk.frameLength > 0 else { break }
            for frame in 0..<Int(chunk.frameLength) {
                for channel in 0..<channels { samples.append(chunk.floatChannelData![channel][frame]) }
            }
        }
        return (samples, channels, samples.count / max(channels, 1))
    }
}
