import AVFoundation
import Foundation

/// The copy of an overlay track's sound the preview plays when the track has
/// an equalizer: the source through the export's chain, sample for sample in
/// place, so a time in the copy is the same time in the source.
@main
enum EqualizedAudioFileTests {
    static func main() async {
        await aLowShelfLiftsALowToneAndKeepsItsLength()
        await aBoostIsLimitedAtTheExportCeiling()
        await anUnreadableSourceRendersNothing()
        print("Equalized audio file tests passed")
    }

    /// A 60 Hz tone under a low shelf 12 dB up plays ~3.92 times as loud once
    /// the filter has settled, from a copy exactly as long as its source.
    static func aLowShelfLiftsALowToneAndKeepsItsLength() async {
        let source = writeTone(amplitude: 0.1, channels: 2)
        defer { try? FileManager.default.removeItem(at: source) }
        guard
            let copy = await EqualizedAudioFile.render(
                source: source, equalizer: bassBoost(12))
        else { preconditionFailure("no copy rendered") }
        defer { try? FileManager.default.removeItem(at: copy) }
        precondition(copy.pathExtension == "caf")
        let (samples, channels, frames) = read(copy)
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
                source: source, equalizer: bassBoost(12))
        else { preconditionFailure("no copy rendered") }
        defer { try? FileManager.default.removeItem(at: copy) }
        let peak = read(copy).samples.map(abs).max() ?? 0
        precondition(peak <= PeakLimiter.ceiling + 1e-4, "\(peak)")
    }

    static func anUnreadableSourceRendersNothing() async {
        let source = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("eq_missing_\(UUID().uuidString).wav")
        let copy = await EqualizedAudioFile.render(
            source: source, equalizer: bassBoost(6))
        precondition(copy == nil)
    }

    static func bassBoost(_ gainDb: Double) -> AudioEqualizer {
        AudioEqualizer(bands: [.init(type: .lowShelf, frequencyHz: 200, gainDb: gainDb)])
    }

    /// One second of a 60 Hz tone at 48 kHz, written as 16-bit WAV.
    static func writeTone(amplitude: Double, channels: AVAudioChannelCount) -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("eq_source_\(UUID().uuidString).wav")
        // AVAudioFile completes the file once released; see EqualizedAudioFile.
        autoreleasepool { writeTone(amplitude: amplitude, channels: channels, to: url) }
        return url
    }

    static func writeTone(amplitude: Double, channels: AVAudioChannelCount, to url: URL) {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: channels)!
        let file = try! AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
            ])
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000)!
        buffer.frameLength = 48_000
        for channel in 0..<Int(channels) {
            for frame in 0..<48_000 {
                buffer.floatChannelData![channel][frame] = Float(
                    amplitude * sin(2 * Double.pi * 60 * Double(frame) / 48_000))
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
