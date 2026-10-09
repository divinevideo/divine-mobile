package com.divinevideo.divine_video_player

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins which earlier frames a frame effect gets after a seek: the frames the
 * decoder picks for each wanted time, and which of them a later position,
 * while scrubbing, may still use.
 */
class FrameEffectsHistoryTest {

    /** Feeds frames at [framesUs] through a matcher and returns what each served. */
    private fun match(targetsUs: List<Long>, framesUs: List<Long>): Map<Long, List<Long>> {
        val matcher = HistoryTargetMatcher(targetsUs)
        val served = linkedMapOf<Long, List<Long>>()
        for (i in framesUs.indices) {
            if (matcher.isDone) break
            served[framesUs[i]] = matcher.servedBy(framesUs[i], framesUs.getOrNull(i + 1))
        }
        return served.filterValues { it.isNotEmpty() }
    }

    private val thirtyFps = (0 until 60).map { it * 33_333L }

    @Test
    fun `each target gets the last frame shown at or before it`() {
        val served = match(listOf(400_000L, 100_000L, 250_000L), thirtyFps)

        assertEquals(
            mapOf(
                99_999L to listOf(100_000L),
                233_331L to listOf(250_000L),
                399_996L to listOf(400_000L),
            ),
            served,
        )
    }

    @Test
    fun `a frame a millisecond late still counts as on time`() {
        // Container timestamps round to the millisecond.
        val served = match(listOf(100_000L), listOf(0L, 100_900L, 133_333L))

        assertEquals(mapOf(100_900L to listOf(100_000L)), served)
    }

    @Test
    fun `targets closer than a frame share it`() {
        val served = match(listOf(110_000L, 120_000L), thirtyFps)

        assertEquals(mapOf(99_999L to listOf(110_000L, 120_000L)), served)
    }

    @Test
    fun `the end of the stream serves the targets after the last frame`() {
        val matcher = HistoryTargetMatcher(listOf(900_000L, 1_000_000L))

        assertEquals(emptyList<Long>(), matcher.servedBy(500_000L, 800_000L))
        assertEquals(listOf(900_000L, 1_000_000L), matcher.servedBy(800_000L, null))
        assertTrue(matcher.isDone)
    }

    @Test
    fun `a target before the first decoded frame gets none`() {
        val matcher = HistoryTargetMatcher(listOf(10_000L, 200_000L))

        assertEquals(listOf(200_000L), matcher.servedBy(100_000L, 233_333L))
        assertTrue(matcher.isDone)
    }

    @Test
    fun `a position uses the frame decoded for the nearest time`() {
        val frames = listOf(400_000L to 399_996L, 500_000L to 499_995L)

        assertEquals(1, nearestDecodedFrame(frames, 530_000L))
        assertEquals(0, nearestDecodedFrame(frames, 420_000L))
    }

    @Test
    fun `a position too far from every decoded time uses none`() {
        // While scrubbing fast, the frames decoded for where the playhead was
        // would show a trail from the wrong moment.
        val frames = listOf(400_000L to 399_996L)

        assertNull(nearestDecodedFrame(frames, 400_000L + MAX_DECODED_DRIFT_US + 1))
    }

    @Test
    fun `a position never uses a frame shown after it`() {
        // Scrubbing back: the frame decoded for 500 ms lies in the future of
        // a position at 480 ms.
        val frames = listOf(500_000L to 499_995L)

        assertNull(nearestDecodedFrame(frames, 480_000L))
    }
}
