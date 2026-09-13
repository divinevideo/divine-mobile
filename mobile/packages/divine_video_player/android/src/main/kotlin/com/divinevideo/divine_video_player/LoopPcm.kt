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

    /**
     * The loop, and how its seam was closed.
     *
     * [samples] holds the loop in its first `loopFrames * channels` entries;
     * anything past that was only needed for the blend.
     */
    data class Prepared(
        val samples: ShortArray,
        val loopFrames: Int,
        val fadeFrames: Int,
        val blendedFromPastTheLoop: Boolean,
    ) {
        override fun equals(other: Any?): Boolean =
            this === other ||
                (other is Prepared &&
                    samples.contentEquals(other.samples) &&
                    loopFrames == other.loopFrames &&
                    fadeFrames == other.fadeFrames &&
                    blendedFromPastTheLoop == other.blendedFromPastTheLoop)

        override fun hashCode(): Int =
            samples.contentHashCode() * 31 + loopFrames
    }

    /**
     * Prepares [samples] as a loop of [loopMs], blending its seam.
     *
     * [loopMs] must be the duration the *player* presents. A track's media
     * duration ignores the edit list, and on a clip whose edit list was
     * corrected the two differ — looping the sound on the media length walks it
     * away from the picture a little every lap.
     *
     * The seam is closed with the material that lies past the loop point, so
     * the loop's last sample and its first become two consecutive samples of
     * the recording. Where the decode ends at the loop, both ends are ramped
     * instead: that removes the click and leaves the restart audible, which is
     * worse but honest. Folding the loop's own tail into its head was tried and
     * is worse than either — the tail has to fade or it is heard twice, so the
     * seam becomes a dip to near-silence followed by material that jumps back.
     *
     * Returns null when there is no loop to build.
     */
    fun prepare(
        samples: ShortArray,
        channels: Int,
        sampleRate: Int,
        loopMs: Long,
    ): Prepared? {
        if (channels <= 0 || sampleRate <= 0 || loopMs <= 0) return null
        val decodedFrames = samples.size / channels
        val loopFrames = minOf((loopMs * sampleRate / 1000L).toInt(), decodedFrames)
        if (loopFrames <= 0) return null

        val spare = decodedFrames - loopFrames
        val wanted = (CROSSFADE_MS * sampleRate / 1000L).toInt()
        val fadeFrames = minOf(wanted, spare)
        val out = samples.copyOf()

        if (fadeFrames > 0) {
            for (i in 0 until fadeFrames) {
                val a = i.toFloat() / fadeFrames
                for (channel in 0 until channels) {
                    val head = samples[i * channels + channel].toFloat()
                    val past = samples[(loopFrames + i) * channels + channel].toFloat()
                    out[i * channels + channel] =
                        (past * (1f - a) + head * a)
                            .coerceIn(-32768f, 32767f).toInt().toShort()
                }
            }
            return Prepared(out, loopFrames, fadeFrames, blendedFromPastTheLoop = true)
        }

        val rampFrames = minOf((RAMP_MS * sampleRate / 1000L).toInt(), loopFrames / 8)
        for (i in 0 until rampFrames) {
            val gain = i.toFloat() / rampFrames
            for (channel in 0 until channels) {
                val head = i * channels + channel
                val tail = (loopFrames - 1 - i) * channels + channel
                out[head] = (out[head] * gain).toInt().toShort()
                out[tail] = (out[tail] * gain).toInt().toShort()
            }
        }
        return Prepared(out, loopFrames, rampFrames, blendedFromPastTheLoop = false)
    }
}
