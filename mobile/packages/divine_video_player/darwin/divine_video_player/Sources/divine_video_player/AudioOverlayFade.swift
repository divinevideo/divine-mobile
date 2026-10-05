import Foundation

/// The fade in and fade out of an overlay audio track.
///
/// Mirrors the fade `pro_video_editor` bakes into an exported custom audio
/// track: linear ramps from and to silence at the edges of the audible part
/// of the track, the quieter ramp winning where they overlap. The editor
/// preview therefore plays the same envelope the export will contain.
struct AudioOverlayFade: Equatable {
    /// How long the track rises from silence, in seconds.
    let fadeInSec: Double
    /// How long the track falls to silence before it ends, in seconds.
    let fadeOutSec: Double

    /// One linear volume ramp, in seconds from the start of the track.
    struct Ramp: Equatable {
        let startSec: Double
        let endSec: Double
        let fromGain: Double
        let toGain: Double
    }

    /// Reads the fade from a track map sent over the method channel.
    init(map: [String: Any]) {
        self.init(
            fadeInSec: ((map["fadeInMs"] as? NSNumber)?.doubleValue ?? 0) / 1000.0,
            fadeOutSec: ((map["fadeOutMs"] as? NSNumber)?.doubleValue ?? 0) / 1000.0
        )
    }

    init(fadeInSec: Double, fadeOutSec: Double) {
        self.fadeInSec = max(fadeInSec, 0)
        self.fadeOutSec = max(fadeOutSec, 0)
    }

    /// Whether the track plays at a constant level.
    var isNone: Bool { fadeInSec <= 0 && fadeOutSec <= 0 }

    /// The gain `elapsedSec` into a track that sounds for `audibleSec`.
    func gain(atSec elapsedSec: Double, audibleSec: Double) -> Double {
        let inGain = fadeInSec > 0 ? elapsedSec / fadeInSec : 1
        let outGain = fadeOutSec > 0 ? (audibleSec - elapsedSec) / fadeOutSec : 1
        return max(min(inGain, outGain, 1), 0)
    }

    /// The envelope over a track that sounds for `audibleSec`, as the ramps
    /// an `AVAudioMix` plays.
    ///
    /// The gain is linear between its breakpoints — where the fade in ends,
    /// where the fade out starts, and where the two cross when they overlap —
    /// so a ramp between each pair of neighbouring breakpoints reproduces it
    /// exactly. Stretches at full level need no ramp, and ramps never overlap,
    /// which `AVMutableAudioMixInputParameters` requires.
    func ramps(audibleSec: Double) -> [Ramp] {
        guard audibleSec > 0, !isNone else { return [] }
        var breakpoints: Set<Double> = [0, audibleSec]
        if fadeInSec > 0 { breakpoints.insert(min(fadeInSec, audibleSec)) }
        if fadeOutSec > 0 { breakpoints.insert(max(audibleSec - fadeOutSec, 0)) }
        if fadeInSec > 0, fadeOutSec > 0 {
            let crossing = audibleSec * fadeInSec / (fadeInSec + fadeOutSec)
            if crossing > 0, crossing < audibleSec { breakpoints.insert(crossing) }
        }
        let sorted = breakpoints.sorted()
        return zip(sorted, sorted.dropFirst()).compactMap { start, end in
            let from = gain(atSec: start, audibleSec: audibleSec)
            let to = gain(atSec: end, audibleSec: audibleSec)
            if from >= 1, to >= 1 { return nil }
            return Ramp(startSec: start, endSec: end, fromGain: from, toGain: to)
        }
    }

    /// The envelope over a track that sounds for `audibleSec`, played at
    /// `level`: a track boosted above 100 % plays every ramp that much louder.
    func ramps(audibleSec: Double, level: Double) -> [Ramp] {
        ramps(audibleSec: audibleSec).map {
            Ramp(
                startSec: $0.startSec,
                endSec: $0.endSec,
                fromGain: $0.fromGain * level,
                toGain: $0.toGain * level
            )
        }
    }
}
