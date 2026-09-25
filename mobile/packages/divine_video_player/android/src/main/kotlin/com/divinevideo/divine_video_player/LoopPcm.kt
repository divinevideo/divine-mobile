package com.divinevideo.divine_video_player

/**
 * Cuts decoded PCM to a loop and closes its seam.
 *
 * Split out of [ClipAudioLoopTrack] because everything here is arithmetic on a
 * sample array, and every one of these rules was got wrong at least once while
 * the seam was being chased: the loop was cut to the caller's requested end
 * instead of the player's duration, the blend ran against material that was not
 * there, and a fallback blend made the seam worse than leaving it alone.
 */
internal object LoopPcm {

    /** Blend length at the seam, when there is material to blend with. */
    const val CROSSFADE_MS = 100L

    /** Fallback when there is not: long enough to kill the click, no more. */
    const val RAMP_MS = 5L

    /** Blend length at a seam carried on from earlier in the lap. */
    const val LAP_CROSSFADE_MS = 50L

    /** How long the lap's last milliseconds take to lead into what carries them on. */
    const val JOIN_MS = 5L

    /**
     * The loop, and how its seam was closed.
     *
     * [samples] holds the loop in its first `loopFrames * channels` entries;
     * anything past that was only needed for the blend. [lapLagFrames] is how
     * far back in the lap the seam was carried on from, or zero; see
     * [prepare].
     */
    data class Prepared(
        val samples: ShortArray,
        val loopFrames: Int,
        val fadeFrames: Int,
        val blendedFromPastTheLoop: Boolean,
        val lapLagFrames: Int = 0,
    ) {
        override fun equals(other: Any?): Boolean =
            this === other ||
                (other is Prepared &&
                    samples.contentEquals(other.samples) &&
                    loopFrames == other.loopFrames &&
                    fadeFrames == other.fadeFrames &&
                    blendedFromPastTheLoop == other.blendedFromPastTheLoop &&
                    lapLagFrames == other.lapLagFrames)

        override fun hashCode(): Int =
            samples.contentHashCode() * 31 + loopFrames
    }

    /**
     * Prepares [samples] as a loop of [loopUs], blending its seam.
     *
     * [loopUs] must be the duration the *player* presents, to the microsecond:
     * the track repeats on its own clock, so a loop even a fraction of a
     * millisecond off the picture's period drifts from it every lap. A track's media
     * duration ignores the edit list, and on a clip whose edit list was
     * corrected the two differ — looping the sound on the media length walks it
     * away from the picture a little every lap.
     *
     * The seam is closed with the material that lies past the loop point, so
     * the loop's last sample and its first become two consecutive samples of
     * the recording. Folding the loop's own tail into its head was tried and
     * is worse — the tail has to fade or it is heard twice, so the seam becomes
     * a dip to near-silence followed by material that jumps back.
     *
     * The decode past the loop point is only used as far as it still carries
     * sound. Often the audio track ends with the picture and what follows is
     * the decoder ringing out: blended with, the seam dipped from full level
     * to −45 dB and back within 15 ms, heard as a "blob" at every restart.
     * With nothing live past the loop point, the lap is carried on instead
     * from the moment earlier in it that best matches its end — measured on a
     * DJ set, exactly one beat back — and that continuation crosses into the
     * head over [LAP_CROSSFADE_MS] at constant power, since the two are
     * different moments of the recording.
     *
     * A loop whose sound opens with digital silence is not carried on that
     * way: the silence is the loop's own breath. A 2013 Vine opens with 45 ms
     * of it, the Vine app looped it like that, and every fill tried on device
     * — the lap's last pitch period repeated across it hummed at ~50 Hz, a
     * stretch from earlier in the lap stuttered — was heard as worse than the
     * silence itself. Trimming it off the front did the same in the loop
     * prototype. Such a lap is ramped into its silence instead, as is one whose
     * decode ends before the loop does — the sound stops before the picture:
     * that removes the click and leaves the silence, which is what the clip
     * sounds like unlooped.
     *
     * A decode that falls short of [loopUs] is padded with silence to reach it,
     * however far short. The picture loops at the presented duration whatever
     * the sound does, and the track repeats in the HAL on its own clock, so a
     * loop cut to the decode has a shorter period than the picture and
     * separates from it by the difference on every lap — a 1.7 s shortfall on a
     * feed clip had the sound restart mid-picture. The presented duration can
     * be trusted for this because the player clips it to the source's own
     * length; it is never a cap past the clip.
     *
     * [startUs] is where the first decoded sample sits on the clip's timeline.
     * The decode is a concatenation of buffers and says nothing about where it
     * begins; the timestamp does. A track whose sound starts later than its
     * picture — an initial empty edit, which ffprobe reports as an audio
     * `start_time` past zero — decodes to a first sample stamped that far in,
     * and ExoPlayer plays it there. Placed at zero instead, the sound would run
     * ahead of the picture by that much on every lap. So the loop opens with
     * that much silence. A negative start is the other edit list, gapless
     * trimming: the extractor stamps the encoder's priming samples before zero
     * and the decoder, with its trimming switched off so it hands back the
     * material past the loop point, emits them anyway. Those frames are dropped,
     * which is the same cut the player makes with the trimming left on.
     *
     * Returns null when there is no loop to build, including when the sound
     * starts only after the loop ends.
     */
    fun prepare(
        samples: ShortArray,
        channels: Int,
        sampleRate: Int,
        loopUs: Long,
        startUs: Long = 0L,
    ): Prepared? {
        if (channels <= 0 || sampleRate <= 0 || loopUs <= 0) return null
        val loopFrames = Math.round(loopUs.toDouble() * sampleRate / 1_000_000.0)
            .coerceAtMost(Int.MAX_VALUE / channels.toLong())
            .toInt()
        if (loopFrames <= 0) return null
        val placed = placeOnTimeline(samples, channels, sampleRate, startUs, loopFrames)
            ?: return null
        val decodedFrames = placed.size / channels
        if (decodedFrames <= 0) return null
        if (decodedFrames < loopFrames) {
            return ramped(placed, channels, sampleRate, loopFrames, decodedFrames)
        }

        val pcm = Pcm(placed, channels, sampleRate)
        val tailRms = pcm.rms(loopFrames - pcm.frames(TAIL_MS), loopFrames)
        val spare = decodedFrames - loopFrames
        val crossfade = pcm.frames(CROSSFADE_MS)
        // A lap that ends in silence has nothing to carry across its seam.
        if (tailRms <= SILENT_RMS) {
            val fade = minOf(crossfade, spare)
            if (fade <= 0) return ramped(placed, channels, sampleRate, loopFrames, decodedFrames)
            return pcm.blendWithPast(loopFrames, fade = fade)
        }

        val live = pcm.liveFramesPast(loopFrames, decodedFrames, tailRms)
        if (live >= pcm.frames(LIVE_WINDOW_MS)) {
            return pcm.blendWithPast(loopFrames, fade = minOf(crossfade, live))
        }
        if (pcm.opensWithSilence()) {
            return ramped(placed, channels, sampleRate, loopFrames, decodedFrames)
        }
        return pcm.carryOnFromLap(loopFrames, pcm.frames(LAP_CROSSFADE_MS))
            ?: ramped(placed, channels, sampleRate, loopFrames, decodedFrames)
    }

    /**
     * Ramps both edges of a loop whose sound does not reach its seam: the
     * decode ends before the loop does, or the lap is too short to carry on.
     *
     * The tail is the last decoded sample, not the last of the loop: past the
     * decode the loop is silence, and a ramp there would fade nothing while
     * the real sound stopped with a click.
     */
    private fun ramped(
        placed: ShortArray,
        channels: Int,
        sampleRate: Int,
        loopFrames: Int,
        decodedFrames: Int,
    ): Prepared {
        // Grows, zero-filled, when the loop was padded out to the picture's
        // period.
        val out = placed.copyOf(maxOf(placed.size, loopFrames * channels))
        val tailEnd = minOf(loopFrames, decodedFrames)
        val rampFrames = minOf((RAMP_MS * sampleRate / 1000L).toInt(), tailEnd / 8)
        for (i in 0 until rampFrames) {
            val gain = i.toFloat() / rampFrames
            for (channel in 0 until channels) {
                val head = i * channels + channel
                val tail = (tailEnd - 1 - i) * channels + channel
                out[head] = (out[head] * gain).toInt().toShort()
                out[tail] = (out[tail] * gain).toInt().toShort()
            }
        }
        return Prepared(out, loopFrames, rampFrames, blendedFromPastTheLoop = false)
    }

    /** Frame arithmetic over one interleaved decode. */
    private class Pcm(val samples: ShortArray, val channels: Int, val sampleRate: Int) {

        fun frames(ms: Long): Int = (ms * sampleRate / 1000L).toInt()

        fun sample(frame: Int, channel: Int): Float = samples[frame * channels + channel].toFloat()

        private fun mono(frame: Int): Double {
            var sum = 0.0
            for (channel in 0 until channels) sum += samples[frame * channels + channel]
            return sum / channels
        }

        fun rms(from: Int, until: Int): Double {
            if (until <= from) return 0.0
            var energy = 0.0
            for (frame in from until until) {
                for (channel in 0 until channels) {
                    val v = samples[frame * channels + channel].toDouble()
                    energy += v * v
                }
            }
            return Math.sqrt(energy / ((until - from) * channels))
        }

        /** Whether the lap opens with digital silence: exact zeros, not a quiet start. */
        fun opensWithSilence(): Boolean {
            for (frame in 0 until frames(HEAD_SILENCE_MS)) {
                for (channel in 0 until channels) {
                    if (samples[frame * channels + channel].toInt() != 0) return false
                }
            }
            return true
        }

        /**
         * How much of the decode past the loop point still carries sound, in
         * whole windows no quieter than [LIVE_LEVEL_RATIO] of the lap's tail.
         */
        fun liveFramesPast(loopFrames: Int, decodedFrames: Int, tailRms: Double): Int {
            val window = frames(LIVE_WINDOW_MS)
            var live = 0
            while (loopFrames + live + window <= decodedFrames &&
                rms(loopFrames + live, loopFrames + live + window) >= tailRms * LIVE_LEVEL_RATIO
            ) {
                live += window
            }
            return live
        }

        /**
         * Carries the lap on with the recording's own continuation past the
         * loop point, crossing into the head over [fade].
         */
        fun blendWithPast(loopFrames: Int, fade: Int): Prepared {
            val out = samples.copyOf()
            for (i in 0 until fade) {
                val a = i.toFloat() / fade
                for (channel in 0 until channels) {
                    val past = sample(loopFrames + i, channel)
                    val head = sample(i, channel)
                    out[i * channels + channel] = toPcm(past * (1f - a) + head * a)
                }
            }
            return Prepared(out, loopFrames, fadeFrames = fade, blendedFromPastTheLoop = true)
        }

        /**
         * Carries the lap on with the stretch that followed the moment in it
         * best matching its end, crossing into the head over [fade]; null
         * when the lap is too short to search.
         *
         * The lap's last [JOIN_MS] lead into that stretch the same way, so
         * the waveform runs on across the wrap without a step.
         */
        fun carryOnFromLap(loopFrames: Int, fade: Int): Prepared? {
            val join = frames(JOIN_MS)
            val window = frames(MATCH_WINDOW_MS)
            val maxLag = minOf(loopFrames / 2, frames(MAX_LAP_LAG_MS), loopFrames - window)
            val lag = bestMatchLag(loopFrames, window, minLag = fade + join, maxLag = maxLag)
                ?: return null
            val out = samples.copyOf()
            for (j in 0 until join) {
                val frame = loopFrames - join + j
                val b = (j + 1).toFloat() / (join + 1)
                for (channel in 0 until channels) {
                    out[frame * channels + channel] =
                        toPcm(sample(frame, channel) * (1f - b) + sample(frame - lag, channel) * b)
                }
            }
            for (i in 0 until fade) {
                val a = i.toDouble() / fade
                val carriedGain = Math.cos(a * Math.PI / 2).toFloat()
                val headGain = Math.sin(a * Math.PI / 2).toFloat()
                for (channel in 0 until channels) {
                    val carried = sample(loopFrames - lag + i, channel)
                    val head = sample(i, channel)
                    out[i * channels + channel] = toPcm(carried * carriedGain + head * headGain)
                }
            }
            return Prepared(
                out,
                loopFrames,
                fadeFrames = fade,
                blendedFromPastTheLoop = false,
                lapLagFrames = lag,
            )
        }

        /**
         * The lag, between [minLag] and [maxLag], at which the [window] frames
         * ending at [endFrame] best match themselves — normalised, so a loud
         * stretch does not win on level alone. Searched coarsely first, then
         * refined around the best coarse lag.
         */
        private fun bestMatchLag(endFrame: Int, window: Int, minLag: Int, maxLag: Int): Int? {
            if (minLag < 1 || minLag > maxLag || endFrame - window - maxLag < 0) return null
            fun score(lag: Int, step: Int): Double {
                var dot = 0.0
                var ownEnergy = 0.0
                var lagEnergy = 0.0
                var frame = endFrame - window
                while (frame < endFrame) {
                    val own = mono(frame)
                    val earlier = mono(frame - lag)
                    dot += own * earlier
                    ownEnergy += own * own
                    lagEnergy += earlier * earlier
                    frame += step
                }
                if (ownEnergy <= 0.0 || lagEnergy <= 0.0) return Double.NEGATIVE_INFINITY
                return dot / Math.sqrt(ownEnergy * lagEnergy)
            }
            var coarse = minLag
            var coarseScore = Double.NEGATIVE_INFINITY
            var lag = minLag
            while (lag <= maxLag) {
                val candidate = score(lag, COARSE_STEP)
                if (candidate > coarseScore) {
                    coarseScore = candidate
                    coarse = lag
                }
                lag += COARSE_STEP
            }
            var best = coarse
            var bestScore = Double.NEGATIVE_INFINITY
            for (candidateLag in maxOf(minLag, coarse - COARSE_STEP)..minOf(maxLag, coarse + COARSE_STEP)) {
                val candidate = score(candidateLag, 1)
                if (candidate > bestScore) {
                    bestScore = candidate
                    best = candidateLag
                }
            }
            return best
        }

        private fun toPcm(value: Float): Short =
            Math.round(value).coerceIn(-32768, 32767).toShort()
    }

    /** The stretch of the lap's end its level is measured over. */
    private const val TAIL_MS = 20L

    /** Below this the lap's end is silence, in sample units. */
    private const val SILENT_RMS = 1.0

    /** How much exact silence at the head makes it the loop's own. */
    private const val HEAD_SILENCE_MS = 3L

    /** Past-the-loop material is judged live window by window, this long. */
    private const val LIVE_WINDOW_MS = 5L

    /** −20 dB under the lap's end is the decoder ringing out, not sound. */
    private const val LIVE_LEVEL_RATIO = 0.1

    /** How much of the lap's end is matched against earlier moments. */
    private const val MATCH_WINDOW_MS = 30L

    /** How far back the lap is searched: a beat or two of any tempo. */
    private const val MAX_LAP_LAG_MS = 1_000L

    private const val COARSE_STEP = 4

    /**
     * Shifts [samples] so that frame zero is the clip's time zero rather than
     * the first decoded sample: leading silence for a start past zero, a cut
     * for one before it.
     *
     * Returns null when nothing of the sound falls inside the loop.
     */
    private fun placeOnTimeline(
        samples: ShortArray,
        channels: Int,
        sampleRate: Int,
        startUs: Long,
        loopFrames: Int,
    ): ShortArray? {
        val startFrames = Math.round(startUs.toDouble() * sampleRate / 1_000_000.0)
        if (startFrames >= loopFrames) return null
        val decodedFrames = samples.size / channels
        return when {
            startFrames > 0 -> {
                val lead = startFrames.toInt() * channels
                ShortArray(lead + samples.size).also { samples.copyInto(it, lead) }
            }
            startFrames < 0 -> {
                val cut = (-startFrames).coerceAtMost(decodedFrames.toLong()).toInt()
                samples.copyOfRange(cut * channels, samples.size)
            }
            else -> samples
        }
    }
}
