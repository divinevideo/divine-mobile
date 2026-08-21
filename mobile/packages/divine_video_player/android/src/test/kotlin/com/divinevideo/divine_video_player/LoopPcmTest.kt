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
    fun `never cuts past what was decoded`() {
        // The feed asks for its playback cap, far past any clip. Reading that
        // as the loop length would run the track off the end of its own buffer.
        val decoded = sampleRate // one second
        val prepared = LoopPcm.prepare(
            samples = tone(frames = decoded),
            channels = 1,
            sampleRate = sampleRate,
            loopMs = 7000,
        )!!

        assertEquals(decoded, prepared.loopFrames)
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
