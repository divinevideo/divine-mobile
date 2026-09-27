import Foundation

/// Cuts decoded PCM to a loop and closes its seam — the Apple counterpart of
/// the Android plugin's `LoopPcm.kt`, with the same rules.
///
/// Samples are interleaved 32-bit floats. Every rule here was got wrong at
/// least once on Android while its seam was being chased, and each mistake was
/// heard rather than seen in a log, so the two sides are kept rule for rule.
enum LoopPcm {

    /// Blend length at the seam, when there is live material past the loop.
    static let crossfadeMs = 100.0

    /// Blend length at a seam carried on from earlier in the lap.
    static let lapCrossfadeMs = 50.0

    /// Fallback when there is nothing to blend with.
    static let rampMs = 5.0

    /// How long the lap's last milliseconds take to lead into what carries
    /// them on.
    static let joinMs = 5.0

    private static let tailMs = 20.0
    private static let silentLevel: Float = 1.0 / 32768.0

    /// Material past the loop point is judged live millisecond by
    /// millisecond. In 5 ms windows, as on Android, a track that stops 1 ms
    /// after the loop point — Apple's loop ends that much earlier than
    /// Android's on the same file — passed as live on the strength of that
    /// millisecond, and the seam cut to the decoder ringing out.
    private static let liveWindowMs = 1.0

    /// Less live material than this is not worth blending with.
    private static let minLiveMs = 5.0
    private static let liveLevelRatio: Float = 0.1
    private static let headSilenceMs = 3.0
    private static let matchWindowMs = 30.0
    private static let maxLapLagMs = 1000.0
    private static let coarseStep = 4

    /// The loop, and how its seam was closed.
    struct Prepared {
        /// `loopFrames * channels` interleaved samples.
        let samples: [Float]
        let loopFrames: Int
        let fadeFrames: Int
        let blendedFromPastTheLoop: Bool
        /// How far back in the lap the seam was carried on from, or zero.
        let lapLagFrames: Int
    }

    /// Prepares [samples] as a loop of [loopFrames], closing its seam.
    ///
    /// [startFrame] is where the first decoded sample sits on the clip's
    /// timeline: past zero opens the loop with that much silence, before zero
    /// drops the frames the player never presents.
    ///
    /// The seam is blended with the material that lies past the loop point
    /// while it still carries sound — often the audio track ends with the
    /// picture and what follows is the decoder ringing out, which blended with
    /// dipped the seam to near-silence. With nothing live there, the lap is
    /// carried on from the moment in it that best matches its end and crossed
    /// into the head at constant power. A head of digital silence is the
    /// loop's own breath and is kept: every fill of it was heard as worse on
    /// device. A lap that opens that way, or a decode that ends before the
    /// loop does, has both edges ramped instead.
    ///
    /// Returns nil when there is no loop to build.
    static func prepare(
        samples: [Float],
        channels: Int,
        sampleRate: Double,
        loopFrames: Int,
        startFrame: Int
    ) -> Prepared? {
        guard channels > 0, sampleRate > 0, loopFrames > 0 else { return nil }
        guard let placed = placeOnTimeline(
            samples,
            channels: channels,
            startFrame: startFrame,
            loopFrames: loopFrames
        ) else { return nil }
        let decodedFrames = placed.count / channels
        guard decodedFrames > 0 else { return nil }
        let pcm = Pcm(samples: placed, channels: channels, sampleRate: sampleRate)
        if decodedFrames < loopFrames {
            return pcm.ramped(loopFrames: loopFrames, decodedFrames: decodedFrames)
        }

        let tailLevel = pcm.rms(from: loopFrames - pcm.frames(tailMs), until: loopFrames)
        let spare = decodedFrames - loopFrames
        let crossfade = pcm.frames(crossfadeMs)
        if tailLevel <= silentLevel {
            let fade = min(crossfade, spare)
            if fade <= 0 {
                return pcm.ramped(loopFrames: loopFrames, decodedFrames: decodedFrames)
            }
            return pcm.blendWithPast(loopFrames: loopFrames, fade: fade)
        }
        let live = pcm.liveFramesPast(
            loopFrames: loopFrames,
            decodedFrames: decodedFrames,
            tailLevel: tailLevel
        )
        if live >= pcm.frames(minLiveMs) {
            return pcm.blendWithPast(loopFrames: loopFrames, fade: min(crossfade, live))
        }
        if pcm.opensWithSilence() {
            return pcm.ramped(loopFrames: loopFrames, decodedFrames: decodedFrames)
        }
        return pcm.carryOnFromLap(loopFrames: loopFrames, fade: pcm.frames(lapCrossfadeMs))
            ?? pcm.ramped(loopFrames: loopFrames, decodedFrames: decodedFrames)
    }

    /// Shifts [samples] so frame zero is the clip's time zero: leading
    /// silence for a start past zero, a cut for one before it. Nil when
    /// nothing of the sound falls inside the loop.
    private static func placeOnTimeline(
        _ samples: [Float],
        channels: Int,
        startFrame: Int,
        loopFrames: Int
    ) -> [Float]? {
        if startFrame >= loopFrames { return nil }
        if startFrame > 0 {
            return [Float](repeating: 0, count: startFrame * channels) + samples
        }
        if startFrame < 0 {
            let cut = min(-startFrame * channels, samples.count)
            return Array(samples[cut...])
        }
        return samples
    }

    /// Frame arithmetic over one interleaved decode.
    private struct Pcm {
        let samples: [Float]
        let channels: Int
        let sampleRate: Double

        func frames(_ ms: Double) -> Int { Int(ms * sampleRate / 1000.0) }

        func sample(_ frame: Int, _ channel: Int) -> Float {
            samples[frame * channels + channel]
        }

        private func mono(_ frame: Int) -> Double {
            var sum = 0.0
            for channel in 0..<channels { sum += Double(sample(frame, channel)) }
            return sum / Double(channels)
        }

        func rms(from: Int, until: Int) -> Float {
            guard until > from, from >= 0 else { return 0 }
            var energy = 0.0
            for frame in from..<until {
                for channel in 0..<channels {
                    let value = Double(sample(frame, channel))
                    energy += value * value
                }
            }
            return Float((energy / Double((until - from) * channels)).squareRoot())
        }

        func opensWithSilence() -> Bool {
            for frame in 0..<frames(LoopPcm.headSilenceMs) {
                for channel in 0..<channels where sample(frame, channel) != 0 {
                    return false
                }
            }
            return true
        }

        func liveFramesPast(loopFrames: Int, decodedFrames: Int, tailLevel: Float) -> Int {
            let window = frames(LoopPcm.liveWindowMs)
            guard window > 0 else { return 0 }
            var live = 0
            while loopFrames + live + window <= decodedFrames,
                rms(from: loopFrames + live, until: loopFrames + live + window)
                    >= tailLevel * LoopPcm.liveLevelRatio
            {
                live += window
            }
            return live
        }

        func ramped(loopFrames: Int, decodedFrames: Int) -> Prepared {
            var out = [Float](repeating: 0, count: loopFrames * channels)
            let kept = min(loopFrames, decodedFrames) * channels
            out.replaceSubrange(0..<kept, with: samples[0..<kept])
            let tailEnd = min(loopFrames, decodedFrames)
            let rampFrames = min(frames(LoopPcm.rampMs), tailEnd / 8)
            for i in 0..<rampFrames {
                let gain = Float(i) / Float(rampFrames)
                for channel in 0..<channels {
                    out[i * channels + channel] *= gain
                    out[(tailEnd - 1 - i) * channels + channel] *= gain
                }
            }
            return Prepared(
                samples: out,
                loopFrames: loopFrames,
                fadeFrames: rampFrames,
                blendedFromPastTheLoop: false,
                lapLagFrames: 0
            )
        }

        func blendWithPast(loopFrames: Int, fade: Int) -> Prepared {
            var out = Array(samples[0..<(loopFrames * channels)])
            for i in 0..<fade {
                let a = Float(i) / Float(fade)
                for channel in 0..<channels {
                    let past = sample(loopFrames + i, channel)
                    out[i * channels + channel] = past * (1 - a) + sample(i, channel) * a
                }
            }
            return Prepared(
                samples: out,
                loopFrames: loopFrames,
                fadeFrames: fade,
                blendedFromPastTheLoop: true,
                lapLagFrames: 0
            )
        }

        func carryOnFromLap(loopFrames: Int, fade: Int) -> Prepared? {
            let join = frames(LoopPcm.joinMs)
            let window = frames(LoopPcm.matchWindowMs)
            let maxLag = min(loopFrames / 2, frames(LoopPcm.maxLapLagMs), loopFrames - window)
            guard let lag = bestMatchLag(
                endFrame: loopFrames,
                window: window,
                minLag: fade + join,
                maxLag: maxLag
            ) else { return nil }
            var out = Array(samples[0..<(loopFrames * channels)])
            for j in 0..<join {
                let frame = loopFrames - join + j
                let b = Float(j + 1) / Float(join + 1)
                for channel in 0..<channels {
                    out[frame * channels + channel] =
                        sample(frame, channel) * (1 - b) + sample(frame - lag, channel) * b
                }
            }
            for i in 0..<fade {
                let a = Double(i) / Double(fade)
                let carriedGain = Float(cos(a * Double.pi / 2))
                let headGain = Float(sin(a * Double.pi / 2))
                for channel in 0..<channels {
                    out[i * channels + channel] =
                        sample(loopFrames - lag + i, channel) * carriedGain
                        + sample(i, channel) * headGain
                }
            }
            return Prepared(
                samples: out,
                loopFrames: loopFrames,
                fadeFrames: fade,
                blendedFromPastTheLoop: false,
                lapLagFrames: lag
            )
        }

        /// The lag, between [minLag] and [maxLag], at which the [window]
        /// frames ending at [endFrame] best match themselves, normalised so a
        /// loud stretch does not win on level alone.
        private func bestMatchLag(endFrame: Int, window: Int, minLag: Int, maxLag: Int) -> Int? {
            guard minLag >= 1, minLag <= maxLag, endFrame - window - maxLag >= 0 else {
                return nil
            }
            func score(_ lag: Int, step: Int) -> Double {
                var dot = 0.0
                var ownEnergy = 0.0
                var lagEnergy = 0.0
                var frame = endFrame - window
                while frame < endFrame {
                    let own = mono(frame)
                    let earlier = mono(frame - lag)
                    dot += own * earlier
                    ownEnergy += own * own
                    lagEnergy += earlier * earlier
                    frame += step
                }
                guard ownEnergy > 0, lagEnergy > 0 else { return -.infinity }
                return dot / (ownEnergy * lagEnergy).squareRoot()
            }
            var coarse = minLag
            var coarseScore = -Double.infinity
            var lag = minLag
            while lag <= maxLag {
                let candidate = score(lag, step: LoopPcm.coarseStep)
                if candidate > coarseScore {
                    coarseScore = candidate
                    coarse = lag
                }
                lag += LoopPcm.coarseStep
            }
            var best = coarse
            var bestScore = -Double.infinity
            let low = max(minLag, coarse - LoopPcm.coarseStep)
            let high = min(maxLag, coarse + LoopPcm.coarseStep)
            for candidateLag in low...high {
                let candidate = score(candidateLag, step: 1)
                if candidate > bestScore {
                    bestScore = candidate
                    best = candidateLag
                }
            }
            return best
        }
    }
}
