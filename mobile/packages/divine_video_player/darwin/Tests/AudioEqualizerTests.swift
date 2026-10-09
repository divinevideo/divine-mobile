import Foundation

/// The filters the editor preview equalizes a clip or an overlay track with.
/// They have to match `pro_video_editor`'s, which renders the export: the
/// coefficients are the literals that plugin's tests pin on both platforms.
@main
enum AudioEqualizerTests {
    static func main() {
        lowShelfCoefficientsMatchTheExport()
        highShelfCoefficientsMatchTheExport()
        peakCoefficientsMatchTheExport()
        aBandWithoutGainPassesTheSignalThrough()
        raisingALowShelfLiftsLowTonesOnly()
        aPeakLiftsItsOwnFrequencyOnly()
        bandsAddUpOneAfterTheOther()
        retuningKeepsTheHistory()
        aBandTurnedTo0DbPlaysDryAndComesBackWithoutItsOldHistory()
        parsesEveryBandInOrderAndDropsAFlatEqualizer()
        skipsABandItCannotFilter()
        shapingAppliesEachClipsEqualizerOverItsOwnStretch()
        shapingLimitsABoostAtTheExportCeiling()
        shapingAppliesAVolumeAfterTheEqualizer()
        equalizingInPiecesMatchesEqualizingWhole()
        aCornerNearHalfTheSampleRateIsLowered()
        print("Audio equalizer tests passed")
    }

    static func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-12) -> Bool {
        abs(a - b) <= tolerance
    }

    /// A corner too close to half the sample rate is lowered to 45 % of it,
    /// as the export's is, which keeps the 16 kHz shelf stable at 32 and
    /// 22.05 kHz: both poles inside the unit circle.
    static func aCornerNearHalfTheSampleRateIsLowered() {
        for rate in [32_000.0, 22_050.0] {
            let shelf = Biquad.highShelf(frequencyHz: 16_000, gainDb: 6, sampleRate: rate)
            let lowered = Biquad.highShelf(frequencyHz: rate * 0.45, gainDb: 6, sampleRate: rate)
            precondition(shelf == lowered, "\(rate): \(shelf)")
            precondition(abs(shelf.a2) < 1 && abs(shelf.a1) < 1 + shelf.a2, "\(rate): \(shelf)")
        }
    }

    static func lowShelfCoefficientsMatchTheExport() {
        let biquad = Biquad.lowShelf(frequencyHz: 200, gainDb: 6, sampleRate: 48_000)
        precondition(close(biquad.b0, 1.0064455778511419), "\(biquad)")
        precondition(close(biquad.b1, -1.9686123523200318), "\(biquad)")
        precondition(close(biquad.b2, 0.9631200582728409), "\(biquad)")
        precondition(close(biquad.a1, -1.9688501073857254), "\(biquad)")
        precondition(close(biquad.a2, 0.9693278810582894), "\(biquad)")
    }

    static func highShelfCoefficientsMatchTheExport() {
        let biquad = Biquad.highShelf(frequencyHz: 3000, gainDb: 6, sampleRate: 48_000)
        precondition(close(biquad.b0, 1.815113185412132), "\(biquad)")
        precondition(close(biquad.b1, -2.790024630355969), "\(biquad)")
        precondition(close(biquad.b2, 1.13571665291146), "\(biquad)")
        precondition(close(biquad.a1, -1.358218880923325), "\(biquad)")
        precondition(close(biquad.a2, 0.519024088890948), "\(biquad)")
    }

    static func peakCoefficientsMatchTheExport() {
        let boost = Biquad.peak(frequencyHz: 1000, gainDb: 6, q: 0.7071067811865475, sampleRate: 48_000)
        precondition(close(boost.b0, 1.0610424252634374), "\(boost)")
        precondition(close(boost.b1, -1.8612731439964758), "\(boost)")
        precondition(close(boost.b2, 0.816291571321481), "\(boost)")
        precondition(close(boost.a1, -1.8612731439964758), "\(boost)")
        precondition(close(boost.a2, 0.8773339965849185), "\(boost)")

        let cut = Biquad.peak(frequencyHz: 250, gainDb: -6, q: 0.7071067811865475, sampleRate: 44_100)
        precondition(close(cut.b0, 0.9828670212502347), "\(cut)")
        precondition(close(cut.b1, -1.930079966863433), "\(cut)")
        precondition(close(cut.b2, 0.9484379496535652), "\(cut)")
        precondition(close(cut.a1, -1.930079966863433), "\(cut)")
        precondition(close(cut.a2, 0.9313049709037998), "\(cut)")
    }

    static func aBandWithoutGainPassesTheSignalThrough() {
        precondition(Biquad.lowShelf(frequencyHz: 200, gainDb: 0, sampleRate: 48_000) == .identity)
        precondition(Biquad.peak(frequencyHz: 1000, gainDb: 0, q: 1, sampleRate: 48_000) == .identity)
    }

    static func raisingALowShelfLiftsLowTonesOnly() {
        let equalizer = AudioEqualizer(bands: [.init(type: .lowShelf, frequencyHz: 200, gainDb: 6)])
        precondition(close(gainDb(equalizer, frequency: 40), 6, 0.2), "\(gainDb(equalizer, frequency: 40))")
        precondition(close(gainDb(equalizer, frequency: 5000), 0, 0.2))
    }

    /// A peak lifts its own frequency by its gain and leaves one three octaves
    /// away, either side, about as it was.
    static func aPeakLiftsItsOwnFrequencyOnly() {
        let equalizer = AudioEqualizer(bands: [.init(type: .peak, frequencyHz: 1000, gainDb: 6)])
        precondition(close(gainDb(equalizer, frequency: 1000), 6, 0.2), "\(gainDb(equalizer, frequency: 1000))")
        precondition(close(gainDb(equalizer, frequency: 8000), 0, 0.3), "\(gainDb(equalizer, frequency: 8000))")
        precondition(close(gainDb(equalizer, frequency: 125), 0, 0.3), "\(gainDb(equalizer, frequency: 125))")
    }

    static func bandsAddUpOneAfterTheOther() {
        let equalizer = AudioEqualizer(bands: [
            .init(type: .lowShelf, frequencyHz: 200, gainDb: 6),
            .init(type: .peak, frequencyHz: 1000, gainDb: -6),
            .init(type: .highShelf, frequencyHz: 3000, gainDb: 3),
        ])
        precondition(close(gainDb(equalizer, frequency: 40), 6, 0.3), "\(gainDb(equalizer, frequency: 40))")
        precondition(close(gainDb(equalizer, frequency: 1000), -6, 0.6), "\(gainDb(equalizer, frequency: 1000))")
        precondition(close(gainDb(equalizer, frequency: 15_000), 3, 0.3), "\(gainDb(equalizer, frequency: 15_000))")
    }

    /// A slider moving a band keeps its history: restarted from silence, the
    /// filter would put out the dry 0.2 instead of carrying on near 0.36.
    static func retuningKeepsTheHistory() {
        let filters = BandEqualizer(sampleRate: 48_000, channelCount: 1)
        filters.retune(bassBoost(6))
        let last = (0..<4_800).map { filters.process(peakingTone($0), channel: 0) }.last!
        filters.retune(bassBoost(5))
        let next = filters.process(peakingTone(4_800), channel: 0)
        precondition(abs(next - last) < 0.01, "jumped from \(last) to \(next)")
    }

    /// A band turned to 0 dB plays dry from the next sample, rather than
    /// spiking through what it held, and turned up again starts from silence
    /// rather than from that stale history.
    static func aBandTurnedTo0DbPlaysDryAndComesBackWithoutItsOldHistory() {
        let filters = BandEqualizer(sampleRate: 48_000, channelCount: 1)
        filters.retune(bassBoost(12))
        for index in 0..<4_800 { _ = filters.process(peakingTone(index), channel: 0) }
        filters.retune(bassBoost(0))
        for index in 4_800..<4_900 {
            precondition(filters.process(peakingTone(index), channel: 0) == peakingTone(index))
        }
        filters.retune(bassBoost(1))
        let next = filters.process(peakingTone(4_900), channel: 0)
        precondition(abs(next - peakingTone(4_900)) < 0.01, "\(next)")
    }

    static func parsesEveryBandInOrderAndDropsAFlatEqualizer() {
        let parsed = AudioEqualizer.from([
            "bands": [
                ["type": "highShelf", "frequencyHz": 3000, "gainDb": -2.5, "q": 1],
                ["type": "peak", "frequencyHz": 1000.0, "gainDb": 4],
            ]
        ])
        let expected = AudioEqualizer(bands: [
            .init(type: .highShelf, frequencyHz: 3000, gainDb: -2.5, q: 1),
            .init(type: .peak, frequencyHz: 1000, gainDb: 4),
        ])
        precondition(parsed == expected, "\(String(describing: parsed))")
        precondition(parsed?.bands[1].q == AudioEqualizerBand.defaultQ)
        precondition(
            AudioEqualizer.from(["bands": [["type": "lowShelf", "frequencyHz": 200]]]) == nil)
        precondition(AudioEqualizer.from([String: Any]()) == nil)
        precondition(AudioEqualizer.from(nil) == nil)
    }

    static func skipsABandItCannotFilter() {
        let parsed = AudioEqualizer.from([
            "bands": [
                ["type": "notch", "frequencyHz": 1000, "gainDb": 6],
                ["type": "peak", "frequencyHz": 0, "gainDb": 6],
                ["type": "peak", "gainDb": 6],
                ["type": "peak", "frequencyHz": 1000, "gainDb": Double.nan],
                ["type": "peak", "frequencyHz": Double.infinity, "gainDb": 6],
                ["type": "lowShelf", "frequencyHz": 200, "gainDb": 6],
            ]
        ])
        precondition(
            parsed?.bands == [.init(type: .lowShelf, frequencyHz: 200, gainDb: 6)],
            "\(String(describing: parsed))")
    }

    /// Two 0.5 s clips of a 60 Hz tone, the second with the bass 12 dB up: the
    /// first plays unchanged, the second ~3.92 times as loud once settled.
    static func shapingAppliesEachClipsEqualizerOverItsOwnStretch() {
        var samples = tone(seconds: 1, amplitude: 0.1)
        let shaping = ClipAudioShaping(segments: [
            .init(start: 0, volume: 1, equalizer: nil),
            .init(start: 0.5, volume: 1, equalizer: bassBoost(12)),
        ])
        shaping.apply(to: &samples, channels: 1, sampleRate: 48_000)
        precondition(close(Double(peak(samples, 0.1, 0.49)), 0.1, 0.001))
        precondition(close(Double(peak(samples, 0.65, 0.99)), 0.392, 0.01), "\(peak(samples, 0.65, 0.99))")
    }

    static func shapingLimitsABoostAtTheExportCeiling() {
        var samples = tone(seconds: 0.5, amplitude: 0.8)
        let shaping = ClipAudioShaping(segments: [
            .init(start: 0, volume: 1, equalizer: bassBoost(12))
        ])
        shaping.apply(to: &samples, channels: 1, sampleRate: 48_000)
        precondition(peak(samples, 0, 0.5) <= PeakLimiter.ceiling + 1e-4, "\(peak(samples, 0, 0.5))")
    }

    static func shapingAppliesAVolumeAfterTheEqualizer() {
        var samples = tone(seconds: 0.5, amplitude: 0.4)
        let shaping = ClipAudioShaping(segments: [
            .init(start: 0, volume: 0.5, equalizer: nil)
        ])
        shaping.apply(to: &samples, channels: 1, sampleRate: 48_000)
        precondition(close(Double(peak(samples, 0, 0.5)), 0.2, 0.001))
    }

    /// A song rendered a sample buffer at a time has to sound like one
    /// filtered in one go: the filters and the limiter carry over.
    static func equalizingInPiecesMatchesEqualizingWhole() {
        let equalizer = AudioEqualizer(bands: [
            .init(type: .lowShelf, frequencyHz: 200, gainDb: 12),
            .init(type: .highShelf, frequencyHz: 3000, gainDb: -6),
        ])
        let input = tone(seconds: 0.5, amplitude: 0.8)
        var whole = input
        whole.withUnsafeMutableBufferPointer {
            EqualizerPcm(equalizer: equalizer, sampleRate: 48_000, channelCount: 1)
                .process($0.baseAddress!, frames: $0.count)
        }
        var pieces = input
        let chain = EqualizerPcm(equalizer: equalizer, sampleRate: 48_000, channelCount: 1)
        pieces.withUnsafeMutableBufferPointer { buffer in
            var start = 0
            while start < buffer.count {
                let count = min(1_000, buffer.count - start)
                chain.process(buffer.baseAddress! + start, frames: count)
                start += count
            }
        }
        precondition(whole == pieces)
        precondition(whole != input)
        precondition(peak(whole, 0, 0.5) <= PeakLimiter.ceiling + 1e-4, "\(peak(whole, 0, 0.5))")
    }

    static func bassBoost(_ gainDb: Double) -> AudioEqualizer {
        AudioEqualizer(bands: [.init(type: .lowShelf, frequencyHz: 200, gainDb: gainDb)])
    }

    /// A 100 Hz tone at 0.2, peaking at every multiple of 4 800 samples.
    static func peakingTone(_ index: Int) -> Float {
        Float(0.2 * cos(2 * Double.pi * 100 * Double(index) / 48_000))
    }

    static func tone(seconds: Double, amplitude: Double) -> [Float] {
        (0..<Int(seconds * 48_000)).map {
            Float(amplitude * sin(2 * Double.pi * 60 * Double($0) / 48_000))
        }
    }

    static func peak(_ samples: [Float], _ from: Double, _ to: Double) -> Float {
        samples[Int(from * 48_000)..<min(Int(to * 48_000), samples.count)].map(abs).max() ?? 0
    }

    static func gainDb(_ equalizer: AudioEqualizer, frequency: Double) -> Double {
        let filters = BandEqualizer(sampleRate: 48_000, channelCount: 1)
        filters.retune(equalizer)
        let input = (0..<48_000).map { Float(0.25 * sin(2 * Double.pi * frequency * Double($0) / 48_000)) }
        let output = input.map { filters.process($0, channel: 0) }
        func rms(_ values: [Float]) -> Double {
            let settled = values[24_000...]
            return (settled.reduce(0) { $0 + Double($1) * Double($1) } / Double(settled.count)).squareRoot()
        }
        return 20 * log10(rms(output) / rms(input))
    }
}
