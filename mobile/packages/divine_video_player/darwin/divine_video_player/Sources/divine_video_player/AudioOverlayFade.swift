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

    /// The envelope over a track scaled by `curve`, which `pro_video_editor`
    /// bakes into the export as the track's volume curve, played at `level`.
    ///
    /// `audibleSec` is how long the track sounds; nil while that is unknown,
    /// when only the fade in can be placed and the ramps run to the curve's
    /// last point. The curve is read on the video timeline, `videoStartSec`
    /// being where the track starts. The ramps are linear between the fade's
    /// breakpoints and the curve's points; where both change at once, the
    /// stretch is split so the product stays within a step of the export's.
    /// Without a curve this is the fade alone.
    func ramps(
        audibleSec: Double?,
        level: Double,
        curve: AudioOverlayVolumeCurve?,
        videoStartSec: Double
    ) -> [Ramp] {
        let fade = audibleSec == nil ? AudioOverlayFade(fadeInSec: fadeInSec, fadeOutSec: 0) : self
        guard let curve else {
            return fade.ramps(audibleSec: audibleSec ?? fadeInSec, level: level)
        }
        let end = audibleSec ?? max(fadeInSec, (curve.timesSec.last ?? 0) - videoStartSec)
        guard end > 0 else { return [] }
        var breakpoints: Set<Double> = [0, end]
        for ramp in fade.ramps(audibleSec: end) {
            breakpoints.insert(ramp.startSec)
            breakpoints.insert(ramp.endSec)
        }
        for time in curve.timesSec {
            let local = time - videoStartSec
            if local > 0, local < end { breakpoints.insert(local) }
        }
        let sorted = breakpoints.sorted()
        func gain(_ sec: Double) -> Double {
            fade.gain(atSec: sec, audibleSec: end) * curve.volume(atSec: videoStartSec + sec)
        }
        var ramps: [Ramp] = []
        for (start, stop) in zip(sorted, sorted.dropFirst()) {
            let fadeChanges = fade.gain(atSec: start, audibleSec: end) != fade.gain(atSec: stop, audibleSec: end)
            let curveChanges =
                curve.volume(atSec: videoStartSec + start) != curve.volume(atSec: videoStartSec + stop)
            let steps = fadeChanges && curveChanges ? Self.productSteps : 1
            for step in 0..<steps {
                let from = start + (stop - start) * Double(step) / Double(steps)
                let to = start + (stop - start) * Double(step + 1) / Double(steps)
                let fromGain = gain(from)
                let toGain = gain(to)
                if fromGain >= 1, toGain >= 1 { continue }
                ramps.append(
                    Ramp(startSec: from, endSec: to, fromGain: fromGain * level, toGain: toGain * level))
            }
        }
        return ramps
    }

    /// How many ramps a stretch gets where the fade and the curve both change.
    static let productSteps = 8

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

/// How an overlay track's volume changes over the video timeline: the volume
/// curve `pro_video_editor` bakes into an exported track, linear between its
/// points, so the preview dips where the export does.
struct AudioOverlayVolumeCurve: Equatable {
    /// When each point sits on the video timeline, in seconds, sorted.
    let timesSec: [Double]
    /// The volume of each point, from 0 to 1.
    let volumes: [Double]

    /// Reads the curve from a track map: interleaved `[time in ms, volume, …]`,
    /// or nil when the track has none.
    init?(map: [String: Any]) {
        let raw: [Double]
        if let list = map["volumeCurve"] as? [NSNumber] {
            raw = list.map(\.doubleValue)
        } else if let list = map["volumeCurve"] as? [Double] {
            raw = list
        } else {
            return nil
        }
        let count = raw.count / 2
        guard count > 0 else { return nil }
        self.init(
            timesSec: (0..<count).map { raw[$0 * 2] / 1000 },
            volumes: (0..<count).map { min(max(raw[$0 * 2 + 1], 0), 1) }
        )
    }

    init(timesSec: [Double], volumes: [Double]) {
        self.timesSec = timesSec
        self.volumes = volumes
    }

    /// The volume at `videoSec` on the video timeline.
    func volume(atSec videoSec: Double) -> Double {
        guard let first = timesSec.first, let last = timesSec.last else { return 1 }
        if videoSec <= first { return volumes[0] }
        if videoSec >= last { return volumes[volumes.count - 1] }
        var low = 0
        var high = timesSec.count - 1
        while high - low > 1 {
            let middle = (low + high) / 2
            if timesSec[middle] <= videoSec { low = middle } else { high = middle }
        }
        let span = timesSec[high] - timesSec[low]
        if span <= 0 { return volumes[high] }
        return volumes[low] + (volumes[high] - volumes[low]) * (videoSec - timesSec[low]) / span
    }
}
