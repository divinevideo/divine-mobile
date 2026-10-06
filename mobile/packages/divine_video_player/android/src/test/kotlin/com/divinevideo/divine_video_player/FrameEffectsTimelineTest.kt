package com.divinevideo.divine_video_player

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins how the frame-effect stage places a frame on the player's timeline and
 * which effects it draws there, the way the export does: by the frame's own
 * time, not by the playhead the main thread last read.
 */
class FrameEffectsTimelineTest {

    private val looping = FrameEffectsState.Timeline(lengthUs = 5_324_000L, looping = true)
    private val once = FrameEffectsState.Timeline(lengthUs = 5_324_000L, looping = false)

    private fun config(startUs: Long?, endUs: Long?) =
        FrameEffectsState.Config(id = "effect", params = emptyMap(), startUs = startUs, endUs = endUs)

    @Test
    fun `a frame lies as far past the anchor as its presentation time`() {
        // A seek to 1 s showed the frame at presentation time -951 278 µs.
        val timelineUs = frameTimelineUs(
            presentationTimeUs = -951_278L + 1_100_000L,
            anchorPresentationUs = -951_278L,
            anchorTimelineUs = 1_000_000L,
            timeline = looping,
        )

        assertEquals(2_100_000L, timelineUs)
    }

    @Test
    fun `a looping timeline starts over at its end`() {
        // Measured on a Galaxy S26: each lap adds exactly the timeline's length.
        val timelineUs = frameTimelineUs(
            presentationTimeUs = 7_389_000L,
            anchorPresentationUs = 0L,
            anchorTimelineUs = 0L,
            timeline = looping,
        )

        assertEquals(2_065_000L, timelineUs)
    }

    @Test
    fun `a timeline that plays once does not wrap`() {
        val timelineUs = frameTimelineUs(
            presentationTimeUs = 5_400_000L,
            anchorPresentationUs = 0L,
            anchorTimelineUs = 0L,
            timeline = once,
        )

        assertEquals(5_400_000L, timelineUs)
    }

    @Test
    fun `a window covers the frames from its start up to its end`() {
        // A 72 ms echo: at 30 fps it covers the frames at 2.067, 2.100 and 2.133 s.
        val configs = listOf(config(2_065_000L, 2_137_000L))

        val covered = listOf(2_033_333L, 2_066_667L, 2_100_000L, 2_133_333L, 2_166_667L)
            .map { effectWindowsAt(configs, it)[0] }

        assertEquals(listOf(false, true, true, true, false), covered)
    }

    @Test
    fun `an open end never closes that side of a window`() {
        val configs = listOf(config(null, 500_000L), config(500_000L, null), config(null, null))

        assertArrayEquals(booleanArrayOf(true, false, true), effectWindowsAt(configs, 499_999L))
        assertArrayEquals(booleanArrayOf(false, true, true), effectWindowsAt(configs, 500_000L))
    }

    @Test
    fun `a frame a few frames ahead of the playhead is trusted`() {
        assertTrue(isNearPlayhead(2_200_000L, playheadUs = 2_000_000L, timeline = looping))
    }

    @Test
    fun `a frame far from the playhead is not trusted`() {
        // Anchored to a move it does not belong to, e.g. a flush nothing recorded.
        assertFalse(isNearPlayhead(3_500_000L, playheadUs = 2_000_000L, timeline = looping))
    }

    @Test
    fun `the playhead distance wraps around the end of a looping timeline`() {
        // The pipeline is already on the next lap while the playhead is not.
        assertTrue(isNearPlayhead(50_000L, playheadUs = 5_250_000L, timeline = looping))
        assertFalse(isNearPlayhead(50_000L, playheadUs = 5_250_000L, timeline = once))
    }
}
