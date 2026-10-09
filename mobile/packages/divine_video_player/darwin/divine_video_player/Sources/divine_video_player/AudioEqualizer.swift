import Foundation

/// The shape of an ``AudioEqualizerBand``'s filter, by its platform-channel
/// name.
enum AudioEqualizerBandType: String, Hashable {
    case lowShelf
    case peak
    case highShelf
}

/// One filter of an ``AudioEqualizer``: a shelf or a peak at [frequencyHz].
struct AudioEqualizerBand: Hashable {
    /// 1/√2. Only a peak reads q; a shelf's slope is 1.
    static let defaultQ = 0.7071067811865476

    var type: AudioEqualizerBandType
    var frequencyHz: Double
    var gainDb: Double = 0
    var q: Double = defaultQ

    /// The section that filters this band at [sampleRate].
    func biquad(sampleRate: Double) -> Biquad {
        switch type {
        case .lowShelf:
            return .lowShelf(frequencyHz: frequencyHz, gainDb: gainDb, sampleRate: sampleRate)
        case .peak:
            return .peak(frequencyHz: frequencyHz, gainDb: gainDb, q: q, sampleRate: sampleRate)
        case .highShelf:
            return .highShelf(frequencyHz: frequencyHz, gainDb: gainDb, sampleRate: sampleRate)
        }
    }

    /// Parses a band from a platform-channel map; nil for one this player
    /// cannot filter, which is skipped rather than failing the equalizer.
    static func from(_ map: Any?) -> AudioEqualizerBand? {
        // A gain that is not a number would turn every sample into one; the
        // export drops such a band too.
        guard let map = map as? [String: Any],
            let type = (map["type"] as? String).flatMap(AudioEqualizerBandType.init(rawValue:)),
            let frequency = (map["frequencyHz"] as? NSNumber)?.doubleValue,
            frequency > 0, frequency.isFinite
        else { return nil }
        let gain = (map["gainDb"] as? NSNumber)?.doubleValue ?? 0
        guard gain.isFinite else { return nil }
        let q = (map["q"] as? NSNumber)?.doubleValue ?? defaultQ
        return AudioEqualizerBand(
            type: type,
            frequencyHz: frequency,
            gainDb: gain,
            q: q > 0 && q.isFinite ? q : defaultQ
        )
    }
}

/// What a clip or an overlay track plays through: [bands], one filter after
/// the other in that order.
///
/// The preview has to sound like the export, which `pro_video_editor` renders
/// with the same filters: [Biquad], [BandEqualizer] and [PeakLimiter] here are
/// twins of that plugin's, down to the coefficients their tests pin.
struct AudioEqualizer: Hashable {
    var bands: [AudioEqualizerBand] = []

    /// Whether the equalizer leaves the audio unchanged.
    var isFlat: Bool { bands.allSatisfy { $0.gainDb == 0 } }

    /// Whether any band raises its frequencies, which can cross full scale.
    var boosts: Bool { bands.contains { $0.gainDb > 0 } }

    /// Parses an equalizer from a platform-channel map; nil when the map is
    /// absent or leaves the audio unchanged, so a flat one costs nothing.
    static func from(_ map: Any?) -> AudioEqualizer? {
        guard let bands = (map as? [String: Any])?["bands"] as? [Any] else { return nil }
        let equalizer = AudioEqualizer(bands: bands.compactMap(AudioEqualizerBand.from))
        return equalizer.isFlat ? nil : equalizer
    }
}

/// One second-order section, normalised so `a0` is 1.
struct Biquad: Equatable {
    let b0: Double
    let b1: Double
    let b2: Double
    let a1: Double
    let a2: Double

    /// A section that passes the signal through unchanged.
    static let identity = Biquad(b0: 1, b1: 0, b2: 0, a1: 0, a2: 0)

    /// The highest frequency a band gets, as a fraction of the sample rate:
    /// close to half of it the bilinear transform squeezes the filter flat.
    static let maxCornerRatio = 0.45

    /// The cookbook's peak at [frequencyHz], [q] wide.
    static func peak(frequencyHz: Double, gainDb: Double, q: Double, sampleRate: Double) -> Biquad {
        guard gainDb != 0 else { return identity }
        let rate = max(sampleRate, 1)
        let a = pow(10, gainDb / 40)
        let w0 = 2 * Double.pi * corner(frequencyHz, rate: rate) / rate
        let cosW0 = cos(w0)
        let alpha = sin(w0) / (2 * q)
        let a0 = 1 + alpha / a
        return Biquad(
            b0: (1 + alpha * a) / a0,
            b1: -2 * cosW0 / a0,
            b2: (1 - alpha * a) / a0,
            a1: -2 * cosW0 / a0,
            a2: (1 - alpha / a) / a0
        )
    }

    /// The cookbook's low shelf at [frequencyHz], slope 1.
    static func lowShelf(frequencyHz: Double, gainDb: Double, sampleRate: Double) -> Biquad {
        shelf(frequencyHz: frequencyHz, gainDb: gainDb, sampleRate: sampleRate, high: false)
    }

    /// The cookbook's high shelf at [frequencyHz], slope 1.
    static func highShelf(frequencyHz: Double, gainDb: Double, sampleRate: Double) -> Biquad {
        shelf(frequencyHz: frequencyHz, gainDb: gainDb, sampleRate: sampleRate, high: true)
    }

    private static func shelf(
        frequencyHz: Double,
        gainDb: Double,
        sampleRate: Double,
        high: Bool
    ) -> Biquad {
        guard gainDb != 0 else { return identity }
        let rate = max(sampleRate, 1)
        let a = pow(10, gainDb / 40)
        let w0 = 2 * Double.pi * corner(frequencyHz, rate: rate) / rate
        let cosW0 = cos(w0)
        // alpha = sin(w0) / 2 * sqrt((A + 1/A) * (1/S - 1) + 2) with S = 1.
        let alpha = sin(w0) / 2 * 2.0.squareRoot()
        let twoSqrtAAlpha = 2 * a.squareRoot() * alpha
        let b0: Double
        let b1: Double
        let b2: Double
        let a0: Double
        let a1: Double
        let a2: Double
        if high {
            b0 = a * ((a + 1) + (a - 1) * cosW0 + twoSqrtAAlpha)
            b1 = -2 * a * ((a - 1) + (a + 1) * cosW0)
            b2 = a * ((a + 1) + (a - 1) * cosW0 - twoSqrtAAlpha)
            a0 = (a + 1) - (a - 1) * cosW0 + twoSqrtAAlpha
            a1 = 2 * ((a - 1) - (a + 1) * cosW0)
            a2 = (a + 1) - (a - 1) * cosW0 - twoSqrtAAlpha
        } else {
            b0 = a * ((a + 1) - (a - 1) * cosW0 + twoSqrtAAlpha)
            b1 = 2 * a * ((a - 1) - (a + 1) * cosW0)
            b2 = a * ((a + 1) - (a - 1) * cosW0 - twoSqrtAAlpha)
            a0 = (a + 1) + (a - 1) * cosW0 + twoSqrtAAlpha
            a1 = -2 * ((a - 1) + (a + 1) * cosW0)
            a2 = (a + 1) + (a - 1) * cosW0 - twoSqrtAAlpha
        }
        return Biquad(b0: b0 / a0, b1: b1 / a0, b2: b2 / a0, a1: a1 / a0, a2: a2 / a0)
    }

    private static func corner(_ frequencyHz: Double, rate: Double) -> Double {
        min(max(frequencyHz, 1), rate * maxCornerRatio)
    }
}

/// Runs float PCM through one [Biquad] per band of an ``AudioEqualizer``, in
/// band order, each channel with its own filter state.
///
/// [retune] moves playing audio to new settings, as a slider is dragged: with
/// as many bands as before, every section keeps the history it holds and only
/// its coefficients move, so the change does not click. A class, because a
/// copy would quietly fork that history.
final class BandEqualizer {
    private let sampleRate: Double
    private let channels: Int
    private var sections: [Biquad] = []
    /// The sections that change the signal; a band at 0 dB costs nothing.
    private var active: [Int] = []
    /// Two delay elements per section per channel, a channel's together.
    private var state: [Double] = []

    init(sampleRate: Double, channelCount: Int) {
        self.sampleRate = sampleRate
        channels = max(channelCount, 1)
    }

    /// Moves the filters to [equalizer], or to none when it is nil.
    func retune(_ equalizer: AudioEqualizer?) {
        let next = (equalizer?.bands ?? []).map { $0.biquad(sampleRate: sampleRate) }
        if next.count != sections.count {
            // Another band count leaves no section whose history still fits.
            state = Array(repeating: 0, count: channels * next.count * 2)
        } else {
            // A band turned to 0 dB drops its history: played out through an
            // identity it would spike, and kept it would come back stale.
            for (index, section) in next.enumerated() where section == .identity {
                for channel in 0..<channels {
                    let offset = (channel * next.count + index) * 2
                    state[offset] = 0
                    state[offset + 1] = 0
                }
            }
        }
        sections = next
        active = next.indices.filter { next[$0] != .identity }
    }

    /// Filters one sample of [channel], transposed direct form II.
    func process(_ sample: Float, channel: Int) -> Float {
        guard channel < channels, !active.isEmpty else { return sample }
        let base = channel * sections.count * 2
        var x = Double(sample)
        for index in active {
            let section = sections[index]
            let offset = base + index * 2
            let y = section.b0 * x + state[offset]
            state[offset] = section.b1 * x - section.a1 * y + state[offset + 1]
            state[offset + 1] = section.b2 * x - section.a2 * y
            x = y
        }
        return Float(x)
    }
}

/// Keeps a boosted signal under full scale by turning it down where it would
/// cross [ceiling], instantly, and letting the gain recover over
/// [releaseSeconds]. All channels of a frame share one gain.
///
/// The twin of `pro_video_editor`'s, which limits a boost in the export at the
/// same ceiling.
struct PeakLimiter {
    /// -1 dBFS, the export's ceiling.
    static let ceiling: Float = 0.891251
    static let releaseSeconds = 0.05

    private let releaseCoefficient: Float
    private(set) var gain: Float = 1

    init(sampleRate: Double) {
        releaseCoefficient = Float(exp(-1.0 / (Self.releaseSeconds * max(sampleRate, 1))))
    }

    /// The gain for a frame whose loudest sample is [peak].
    mutating func gain(forPeak peak: Float) -> Float {
        let target = peak > Self.ceiling ? Self.ceiling / peak : 1
        gain = target < gain ? target : target + (gain - target) * releaseCoefficient
        return gain
    }

    mutating func reset() {
        gain = 1
    }
}

/// Runs interleaved float PCM through an equalizer the way the export does:
/// the bands, then a limiter at the export's ceiling while any boosts.
///
/// The filters keep their history from one call to the next, so audio
/// equalized a piece at a time sounds like audio equalized whole.
final class EqualizerPcm {
    let equalizer: AudioEqualizer
    private let channels: Int
    private let filters: BandEqualizer
    private var limiter: PeakLimiter

    init(equalizer: AudioEqualizer, sampleRate: Double, channelCount: Int) {
        self.equalizer = equalizer
        channels = max(channelCount, 1)
        filters = BandEqualizer(sampleRate: sampleRate, channelCount: channels)
        filters.retune(equalizer)
        limiter = PeakLimiter(sampleRate: sampleRate)
    }

    /// Equalizes [frames] interleaved frames at [samples] in place.
    func process(_ samples: UnsafeMutablePointer<Float>, frames: Int) {
        for frame in 0..<max(frames, 0) {
            let base = frame * channels
            var peak: Float = 0
            for channel in 0..<channels {
                let filtered = filters.process(samples[base + channel], channel: channel)
                samples[base + channel] = filtered
                peak = max(peak, abs(filtered))
            }
            guard equalizer.boosts else { continue }
            let gain = limiter.gain(forPeak: peak)
            guard gain < 1 else { continue }
            for channel in 0..<channels { samples[base + channel] *= gain }
        }
    }
}

/// What a clip timeline's audio plays with, by time on the timeline: each
/// clip's volume and equalizer, applied the way `pro_video_editor` applies
/// them to an export.
struct ClipAudioShaping: Equatable {
    struct Segment: Equatable {
        /// Where the clip starts on the timeline, in seconds.
        let start: Double
        let volume: Float
        let equalizer: AudioEqualizer?
    }

    /// Sorted by start.
    let segments: [Segment]

    /// Whether any clip plays other than as recorded.
    var shapes: Bool {
        segments.contains { $0.volume != 1 || !($0.equalizer?.isFlat ?? true) }
    }

    /// Applies the shaping in place to interleaved [samples] whose first frame
    /// sits at [startSeconds] on the timeline.
    ///
    /// Per clip: the equalizer, limited on its own while it boosts, then the
    /// volume, limited while it amplifies — the export's order. A clip with a
    /// different equalizer than the one before starts its filters from
    /// silence, as each clip's own chain does there.
    func apply(
        to samples: inout [Float],
        channels: Int,
        sampleRate: Double,
        startSeconds: Double = 0
    ) {
        guard shapes, channels > 0, sampleRate > 0, !segments.isEmpty else { return }
        let frames = samples.count / channels
        var volumeLimiter = PeakLimiter(sampleRate: sampleRate)
        var chain: EqualizerPcm?
        var segmentIndex = -1
        var frame = 0
        func seconds(at frame: Int) -> Double { startSeconds + Double(frame) / sampleRate }
        samples.withUnsafeMutableBufferPointer { buffer in
            guard let pointer = buffer.baseAddress else { return }
            while frame < frames {
                var index = max(segmentIndex, 0)
                while index + 1 < segments.count, segments[index + 1].start <= seconds(at: frame) {
                    index += 1
                }
                if index != segmentIndex {
                    segmentIndex = index
                    let equalizer = segments[index].equalizer.flatMap { $0.isFlat ? nil : $0 }
                    if equalizer != chain?.equalizer {
                        chain = equalizer.map {
                            EqualizerPcm(equalizer: $0, sampleRate: sampleRate, channelCount: channels)
                        }
                    }
                    volumeLimiter.reset()
                }
                // The run of frames this clip plays: up to the first frame at
                // or past the next clip's start.
                var runEnd = frames
                if segmentIndex + 1 < segments.count {
                    let nextStart = segments[segmentIndex + 1].start
                    runEnd = min(max(Int(((nextStart - startSeconds) * sampleRate).rounded(.up)), frame + 1), frames)
                    while runEnd > frame + 1, seconds(at: runEnd - 1) >= nextStart { runEnd -= 1 }
                    while runEnd < frames, seconds(at: runEnd) < nextStart { runEnd += 1 }
                }
                let run = pointer + frame * channels
                let runFrames = runEnd - frame
                chain?.process(run, frames: runFrames)
                let volume = segments[segmentIndex].volume
                if volume != 1 {
                    for runFrame in 0..<runFrames {
                        let base = runFrame * channels
                        var peak: Float = 0
                        for channel in 0..<channels { peak = max(peak, abs(run[base + channel] * volume)) }
                        let gain = volume > 1 ? volume * volumeLimiter.gain(forPeak: peak) : volume
                        for channel in 0..<channels { run[base + channel] *= gain }
                    }
                }
                frame = runEnd
            }
        }
    }
}
