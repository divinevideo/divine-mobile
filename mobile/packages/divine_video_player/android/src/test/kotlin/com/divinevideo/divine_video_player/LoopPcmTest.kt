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
            loopMs = 3000,
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
            loopMs = 2020,
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
            loopMs = 7000,
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
            loopMs = 1500,
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
            loopMs = 1000,
        )!!

        assertTrue(prepared.blendedFromPastTheLoop)
        assertEquals((LoopPcm.CROSSFADE_MS * sampleRate / 1000).toInt(), prepared.fadeFrames)
    }

    @Test
    fun `the blend shrinks the step at the wrap`() {
        val loopFrames = sampleRate
        val samples = tone(frames = loopFrames + sampleRate / 4)
        val prepared = LoopPcm.prepare(samples, 1, sampleRate, loopMs = 1000)!!

        val before = abs(samples[loopFrames - 1] - samples[0])
        assertTrue(
            "seam step should fall, was $before now ${seamStep(prepared, 1)}",
            seamStep(prepared, 1) < before,
        )
    }

    @Test
    fun `ramps both ends when nothing lies past the loop point`() {
        // Android's decoder applies the container's gapless trimming and hands
        // back exactly the presented length, which is this case.
        val loopFrames = sampleRate
        val prepared = LoopPcm.prepare(
            samples = tone(frames = loopFrames),
            channels = 1,
            sampleRate = sampleRate,
            loopMs = 1000,
        )!!

        assertEquals(false, prepared.blendedFromPastTheLoop)
        assertEquals((LoopPcm.RAMP_MS * sampleRate / 1000).toInt(), prepared.fadeFrames)
        // Both edges reach zero, so the wrap is silence to silence.
        assertEquals(0, prepared.samples[0].toInt())
        assertEquals(0, prepared.samples[(prepared.loopFrames - 1)].toInt())
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
            loopMs = 1000,
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
            loopMs = 6000,
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
            loopMs = 1000,
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
                loopMs = 1000,
                startUs = 1_000_000L,
            ),
        )
    }

    @Test
    fun `refuses input it cannot make a loop from`() {
        assertNull(LoopPcm.prepare(tone(frames = 100), channels = 1, sampleRate, loopMs = 0))
        assertNull(LoopPcm.prepare(ShortArray(0), channels = 1, sampleRate, loopMs = 1000))
        assertNull(LoopPcm.prepare(tone(frames = 100), channels = 0, sampleRate, loopMs = 1000))
        assertNull(LoopPcm.prepare(tone(frames = 100), channels = 1, 0, loopMs = 1000))
    }

    @Test
    fun `leaves the material outside the blend untouched`() {
        val loopFrames = sampleRate
        val samples = tone(frames = loopFrames + sampleRate / 4)
        val prepared = LoopPcm.prepare(samples, 1, sampleRate, loopMs = 1000)!!

        for (frame in prepared.fadeFrames until loopFrames) {
            assertEquals(
                "frame $frame was altered outside the blend",
                samples[frame],
                prepared.samples[frame],
            )
        }
    }
}
