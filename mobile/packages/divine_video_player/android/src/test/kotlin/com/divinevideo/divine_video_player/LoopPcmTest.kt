package com.divinevideo.divine_video_player

import kotlin.math.abs
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the arithmetic behind the Android loop's audio.
 *
 * Every rule here was got wrong at least once while the loop seam was being
 * chased, and each time the mistake was audible rather than visible in a log:
 * the loop cut to the wrong length, a blend that ran against material that was
 * not there, and a fallback that made the seam worse than leaving it alone.
 */
class LoopPcmTest {

    private val sampleRate = 44100

    /** A tone with a deliberate step at [loopFrames], so a seam is measurable. */
    private fun tone(frames: Int, channels: Int = 1, offset: Int = 0): ShortArray =
        ShortArray(frames * channels) { index ->
            val frame = index / channels
            val channel = index % channels
            (((frame + offset) % 200 - 100) * 100 + channel * 7).toShort()
        }

    private fun rms(samples: ShortArray, from: Int, until: Int): Double =
        Math.sqrt((from until until).sumOf { samples[it].toDouble() * samples[it] } / (until - from))

    private fun seamStep(prepared: LoopPcm.Prepared, channels: Int): Int {
        val last = (prepared.loopFrames - 1) * channels
        return abs(prepared.samples[last] - prepared.samples[0])
    }

    @Test
    fun `cuts the loop to the duration the player presents`() {
        // 3.1s of audio, but the player presents 3.0s: the loop is the shorter.
        val prepared = LoopPcm.prepare(
            samples = tone(frames = (3.1 * sampleRate).toInt()),
            channels = 1,
            sampleRate = sampleRate,
            loopUs = 3_000_000L,
        )!!

        assertEquals(3000 * sampleRate / 1000, prepared.loopFrames)
    }

    @Test
    fun `pads a short decode with silence instead of shortening the loop`() {
        // The picture loops at the presented duration whatever the sound does,
        // and the track repeats in the HAL on its own clock. A loop cut to the
        // decode would have the shorter period of the two and separate from the
        // picture by that difference on every lap.
        val decoded = sampleRate * 2 // two seconds
        val prepared = LoopPcm.prepare(
            samples = tone(frames = decoded),
            channels = 1,
            sampleRate = sampleRate,
            loopUs = 2_020_000L,
        )!!

        assertEquals(2020 * sampleRate / 1000, prepared.loopFrames)
        assertTrue(prepared.loopFrames > decoded)
        // The pad is silence, which is what the clip sounds like unlooped.
        for (frame in decoded until prepared.loopFrames) {
            assertEquals(0, prepared.samples[frame].toInt())
        }
    }

    @Test
    fun `pads however far the decode falls short`() {
        // A feed clip whose audio track ends 1.7 s before its video track. The
        // presented duration is the player's own, clipped to the source's
        // length, so it is never a cap past the clip and can be padded to
        // outright: the sound stops where the file's sound stops, and restarts
        // with the picture rather than 1.7 s ahead of it.
        val decoded = sampleRate // one second
        val prepared = LoopPcm.prepare(
            samples = tone(frames = decoded),
            channels = 1,
            sampleRate = sampleRate,
            loopUs = 7_000_000L,
        )!!

        assertEquals(7 * sampleRate, prepared.loopFrames)
        assertEquals(0, prepared.samples[decoded + 1].toInt())
        assertEquals(0, prepared.samples[prepared.loopFrames - 1].toInt())
    }

    @Test
    fun `ramps the real tail into the pad rather than the pad itself`() {
        // A ramp over the padded silence would fade nothing while the sound
        // stopped mid-waveform with a click at the decode's end.
        val decoded = sampleRate
        val prepared = LoopPcm.prepare(
            samples = tone(frames = decoded),
            channels = 1,
            sampleRate = sampleRate,
            loopUs = 1_500_000L,
        )!!

        assertTrue(prepared.loopFrames > decoded)
        assertEquals(false, prepared.blendedFromPastTheLoop)
        assertTrue(prepared.fadeFrames > 0)
        assertEquals(0, prepared.samples[decoded - 1].toInt())
        assertEquals(0, prepared.samples[0].toInt())
        // Material ahead of the ramp is left alone.
        val untouched = decoded - prepared.fadeFrames - 1
        assertEquals(tone(frames = decoded)[untouched], prepared.samples[untouched])
    }

    @Test
    fun `blends the seam with the material past the loop point`() {
        val loopFrames = sampleRate
        val prepared = LoopPcm.prepare(
            // A quarter second of material beyond the loop to blend with.
            samples = tone(frames = loopFrames + sampleRate / 4),
            channels = 1,
            sampleRate = sampleRate,
            loopUs = 1_000_000L,
        )!!

        assertTrue(prepared.blendedFromPastTheLoop)
        assertEquals((LoopPcm.CROSSFADE_MS * sampleRate / 1000).toInt(), prepared.fadeFrames)
    }

    @Test
    fun `the blend shrinks the step at the wrap`() {
        val loopFrames = sampleRate
        val samples = tone(frames = loopFrames + sampleRate / 4)
        val prepared = LoopPcm.prepare(samples, 1, sampleRate, loopUs = 1_000_000L)!!

        val before = abs(samples[loopFrames - 1] - samples[0])
        assertTrue(
            "seam step should fall, was $before now ${seamStep(prepared, 1)}",
            seamStep(prepared, 1) < before,
        )
    }

    @Test
    fun `carries a lap with nothing past its loop point on from earlier in it`() {
        // The decode ends exactly at the loop point. Ramping both ends to
        // silence removed the click and left a gap at every restart.
        val loopFrames = sampleRate
        val source = tone(frames = loopFrames)
        val prepared = LoopPcm.prepare(source, 1, sampleRate, loopUs = 1_000_000L)!!

        assertEquals(false, prepared.blendedFromPastTheLoop)
        assertTrue(prepared.lapLagFrames > 0)
        // The tone carries on across the wrap as if it had never stopped.
        assertEquals(tone(frames = loopFrames + 1)[loopFrames], prepared.samples[0])
    }

    @Test
    fun `a seam whose past is only the decoder ringing out carries on from the lap`() {
        // A DJ set cut to the picture: the decode runs 15 ms past the loop
        // point, but at -45 dB and then silence. Blended with, the seam fell
        // from full level to near-silence and back — a "blob" every restart.
        val loopFrames = sampleRate
        val source = tone(frames = loopFrames + 15 * sampleRate / 1000)
        for (frame in loopFrames until source.size) source[frame] = (source[frame] / 200).toShort()
        val prepared = LoopPcm.prepare(source, 1, sampleRate, loopUs = 1_000_000L)!!

        assertEquals(false, prepared.blendedFromPastTheLoop)
        assertTrue(prepared.lapLagFrames > 0)
        val tailRms = rms(prepared.samples, loopFrames - 220, loopFrames)
        val headRms = rms(prepared.samples, 0, 220)
        assertTrue("head fell to $headRms against a tail of $tailRms", headRms > tailRms / 2)
    }

    @Test
    fun `keeps stereo channels in their own lanes`() {
        // A byte offset that misses a frame boundary swaps the channels for the
        // rest of the loop, which is silent in a log and obvious in a room.
        val channels = 2
        val loopFrames = sampleRate
        val prepared = LoopPcm.prepare(
            samples = tone(frames = loopFrames + sampleRate / 4, channels = channels),
            channels = channels,
            sampleRate = sampleRate,
            loopUs = 1_000_000L,
        )!!

        // Channel 1 carries a +7 marker the blend has to preserve.
        for (frame in listOf(0, 1, prepared.fadeFrames + 10, prepared.loopFrames - 1)) {
            val left = prepared.samples[frame * channels]
            val right = prepared.samples[frame * channels + 1]
            assertNotEquals("channels collapsed at frame $frame", left, right)
        }
    }

    @Test
    fun `opens with silence when the sound starts after the picture`() {
        // A clip whose audio track begins 0.978667 s in — an initial empty
        // edit, which ffprobe reports as the audio stream's start_time — while
        // its video starts at zero. ExoPlayer plays the sound there. The
        // decoded buffers only know their first timestamp, so placing them at
        // zero would run the sound that far ahead of the picture, every lap.
        val startUs = 978_667L
        val decoded = (5.021333 * sampleRate).toInt()
        val source = tone(frames = decoded)
        val prepared = LoopPcm.prepare(
            samples = source,
            channels = 1,
            sampleRate = sampleRate,
            loopUs = 6_000_000L,
            startUs = startUs,
        )!!

        val lead = Math.round(startUs * sampleRate / 1_000_000.0).toInt()
        assertEquals(6 * sampleRate, prepared.loopFrames)
        for (frame in 0 until lead) {
            assertEquals("frame $frame should be silence", 0, prepared.samples[frame].toInt())
        }
        // The recording itself sits where its timestamp says, untouched past
        // the head ramp.
        assertEquals(source[1000], prepared.samples[lead + 1000])
        assertNotEquals(0, prepared.samples[lead + 1000].toInt())
    }

    @Test
    fun `drops the priming samples a gapless edit stamps before zero`() {
        // The extractor stamps an AAC track's encoder priming before zero, and
        // with its trimming switched off the decoder emits those frames. The
        // player cuts them; the loop has to as well, or its sound runs late by
        // their length.
        val priming = 2112
        val startUs = -Math.round(priming * 1_000_000.0 / sampleRate)
        val loopFrames = sampleRate
        val source = tone(frames = priming + loopFrames + sampleRate / 4)
        val prepared = LoopPcm.prepare(
            samples = source,
            channels = 1,
            sampleRate = sampleRate,
            loopUs = 1_000_000L,
            startUs = startUs,
        )!!

        assertEquals(loopFrames, prepared.loopFrames)
        // Frame zero of the loop is the sample the edit list points at, read
        // past the head blend where the material is untouched.
        val probe = prepared.fadeFrames + 10
        assertEquals(source[priming + probe], prepared.samples[probe])
        assertTrue(prepared.blendedFromPastTheLoop)
    }

    @Test
    fun `refuses a sound that starts only after the loop ends`() {
        assertNull(
            LoopPcm.prepare(
                samples = tone(frames = sampleRate),
                channels = 1,
                sampleRate = sampleRate,
                loopUs = 1_000_000L,
                startUs = 1_000_000L,
            ),
        )
    }

    @Test
    fun `keeps the picture's period to the sample, not the millisecond`() {
        // The clip end comes from the container in microseconds. Rounded down
        // to 1000 ms, this loop would be 22 frames short of the picture's
        // 1000.5 ms period at 44.1 kHz, and the sound would fall another half
        // a millisecond behind it on every lap.
        val prepared = LoopPcm.prepare(
            samples = tone(frames = sampleRate * 2),
            channels = 1,
            sampleRate = sampleRate,
            loopUs = 1_000_500L,
        )!!

        assertEquals(44_122, prepared.loopFrames)
    }

    @Test
    fun `refuses input it cannot make a loop from`() {
        assertNull(LoopPcm.prepare(tone(frames = 100), channels = 1, sampleRate, loopUs = 0L))
        assertNull(LoopPcm.prepare(ShortArray(0), channels = 1, sampleRate, loopUs = 1_000_000L))
        assertNull(LoopPcm.prepare(tone(frames = 100), channels = 0, sampleRate, loopUs = 1_000_000L))
        assertNull(LoopPcm.prepare(tone(frames = 100), channels = 1, 0, loopUs = 1_000_000L))
    }

    /** [frames] of [tone] whose first [silentMs] are digital silence. */
    private fun toneAfterSilence(frames: Int, silentMs: Int): ShortArray =
        tone(frames).also { it.fill(0, 0, silentMs * sampleRate / 1000) }

    @Test
    fun `keeps the silence a late microphone leaves at the head`() {
        // A 2013 Vine opens with 45 ms of exact zeros and runs 10 ms past its
        // loop point. The silence is the loop's breath: every fill tried on
        // device was heard as worse than leaving it.
        val loopFrames = sampleRate
        val source = toneAfterSilence(frames = loopFrames + sampleRate / 100, silentMs = 45)
        val prepared = LoopPcm.prepare(source, 1, sampleRate, loopUs = 1_000_000L)!!

        // The tail fades out over the 10 ms that follow it, and the rest of
        // the silence stays silent.
        assertTrue(prepared.blendedFromPastTheLoop)
        assertTrue(prepared.fadeFrames in 1..sampleRate / 100)
        for (frame in sampleRate / 100 until 45 * sampleRate / 1000) {
            assertEquals("frame $frame", 0, prepared.samples[frame].toInt())
        }
    }

    @Test
    fun `ramps into a silent head when nothing live follows the loop point`() {
        val loopFrames = sampleRate
        val source = toneAfterSilence(frames = loopFrames + sampleRate / 4, silentMs = 45)
        source.fill(0, loopFrames, source.size)
        val prepared = LoopPcm.prepare(source, 1, sampleRate, loopUs = 1_000_000L)!!

        assertEquals(false, prepared.blendedFromPastTheLoop)
        assertEquals(0, prepared.lapLagFrames)
        assertEquals(0, prepared.samples[loopFrames - 1].toInt())
        for (frame in 0 until 45 * sampleRate / 1000) {
            assertEquals("frame $frame", 0, prepared.samples[frame].toInt())
        }
    }

    @Test
    fun `the lap's end leads into what carries it on without a step`() {
        // No earlier moment in a lap matches its end sample for sample, least
        // of all a transient in its last milliseconds. Cut straight to the
        // carried stretch, this lap stepped by thousands at every restart: a
        // click.
        val loopFrames = sampleRate
        val frames = loopFrames + sampleRate / 4
        val source = ShortArray(frames) { frame ->
            val t = frame.toDouble() / sampleRate
            (6_000 * Math.sin(2 * Math.PI * 97 * t) + 6_000 * Math.sin(2 * Math.PI * 151.3 * t + 1))
                .toInt().toShort()
        }
        val edge = 3 * sampleRate / 1000
        for (k in 0 until edge) {
            val frame = loopFrames - edge + k
            source[frame] = (source[frame] + 8_000 * (k + 1) / edge).toShort()
        }
        // Nothing live past the loop point, so the seam carries on from the lap.
        source.fill(0, loopFrames, frames)
        val prepared = LoopPcm.prepare(source, 1, sampleRate, loopUs = 1_000_000L)!!
        assertTrue(prepared.lapLagFrames > 0)

        val largestStepInTheSound = (loopFrames - 2000 until loopFrames - 200)
            .maxOf { abs(source[it] - source[it - 1]) }
        val played = (loopFrames - 300 until loopFrames).map { prepared.samples[it] } +
            (0 until prepared.fadeFrames).map { prepared.samples[it] }
        val largestStepAcrossTheWrap = played.zipWithNext { a, b -> abs(b - a) }.maxOrNull()!!

        assertTrue(
            "stepped $largestStepAcrossTheWrap, the sound itself at most $largestStepInTheSound",
            largestStepAcrossTheWrap <= largestStepInTheSound * 2,
        )
    }

    @Test
    fun `carries the lap on in each channel's own lane`() {
        val loopFrames = sampleRate
        val source = tone(frames = loopFrames + sampleRate / 4, channels = 2)
        source.fill(0, loopFrames * 2, source.size)
        val prepared = LoopPcm.prepare(source, 2, sampleRate, loopUs = 1_000_000L)!!

        assertTrue(prepared.lapLagFrames > 0)
        val carriedOn = tone(frames = loopFrames + 1, channels = 2)
        for (channel in 0 until 2) {
            assertEquals(carriedOn[loopFrames * 2 + channel], prepared.samples[channel])
        }
    }

    @Test
    fun `leaves the material outside the blend untouched`() {
        val loopFrames = sampleRate
        val samples = tone(frames = loopFrames + sampleRate / 4)
        val prepared = LoopPcm.prepare(samples, 1, sampleRate, loopUs = 1_000_000L)!!

        for (frame in prepared.fadeFrames until loopFrames) {
            assertEquals(
                "frame $frame was altered outside the blend",
                samples[frame],
                prepared.samples[frame],
            )
        }
    }
}
