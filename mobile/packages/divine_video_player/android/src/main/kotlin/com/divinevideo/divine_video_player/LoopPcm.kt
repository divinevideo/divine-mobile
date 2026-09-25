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
     * the recording. Where the decode ends at the loop, both ends are ramped
     * instead: that removes the click and leaves the restart audible, which is
     * worse but honest. Folding the loop's own tail into its head was tried and
     * is worse than either — the tail has to fade or it is heard twice, so the
     * seam becomes a dip to near-silence followed by material that jumps back.
     *
     * A decode that falls short of [loopUs] is padded with silence to reach it,
     * however far short. The picture loops at the presented duration whatever
     * the sound does, and the track repeats in the HAL on its own clock, so a
     * loop cut to the decode has a shorter period than the picture and
     * separates from it by the difference on every lap — a 1.7 s shortfall on a
     * feed clip had the sound restart mid-picture. Silence is also what the clip
     * sounds like unlooped: its audio track simply ends before its video track
     * does. The presented duration can be trusted for this because the player
     * clips it to the source's own length; it is never a cap past the clip.
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

        val spare = (decodedFrames - loopFrames).coerceAtLeast(0)
        val wanted = (CROSSFADE_MS * sampleRate / 1000L).toInt()
        val fadeFrames = minOf(wanted, spare)
        // Grows, zero-filled, when the loop was padded out to the picture's
        // period; the decode is left whole otherwise, since the blend below
        // reads the material past the loop point out of it.
        val out = placed.copyOf(maxOf(placed.size, loopFrames * channels))

        if (fadeFrames > 0) {
            for (i in 0 until fadeFrames) {
                val a = i.toFloat() / fadeFrames
                for (channel in 0 until channels) {
                    val head = placed[i * channels + channel].toFloat()
                    val past = placed[(loopFrames + i) * channels + channel].toFloat()
                    out[i * channels + channel] =
                        (past * (1f - a) + head * a)
                            .coerceIn(-32768f, 32767f).toInt().toShort()
                }
            }
            return Prepared(out, loopFrames, fadeFrames, blendedFromPastTheLoop = true)
        }

        // The tail is the last decoded sample, not the last of the loop: past
        // the decode the loop is silence, and a ramp there would fade nothing
        // while the real sound stopped with a click.
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
