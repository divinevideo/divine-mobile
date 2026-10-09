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

    private val oneClip = listOf(FrameEffectsState.Timeline.Clip(mediaUs = 5_324_000L, speed = 1f))
    private val looping = FrameEffectsState.Timeline(oneClip, looping = true)
    private val once = FrameEffectsState.Timeline(oneClip, looping = false)

    /** 2 s at normal speed, then 1 s of media slowed to 2 s, then 3 s of media sped up to 1.5 s. */
    private val mixedSpeeds = FrameEffectsState.Timeline(
        listOf(
            FrameEffectsState.Timeline.Clip(mediaUs = 2_000_000L, speed = 1f),
            FrameEffectsState.Timeline.Clip(mediaUs = 1_000_000L, speed = 0.5f),
            FrameEffectsState.Timeline.Clip(mediaUs = 3_000_000L, speed = 2f),
        ),
        looping = true,
    )

    /** Where frames 30 a second through the media from timeline position 0 lie on [timeline]. */
    private fun framesFromStart(timeline: FrameEffectsState.Timeline, count: Int) =
        (0 until count).map { frame ->
            frameTimelineUs(
                presentationTimeUs = 7_000_000L + frame * 1_000_000L / 30,
                anchorPresentationUs = 7_000_000L,
                anchorTimelineUs = 0L,
                timeline = timeline,
            )
        }

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
    fun `a frame in a clip at a speed of its own lies as far into it as its media time at that speed`() {
        // 0.25 s past the slowed clip's start in media time is 0.5 s on the timeline.
        val timelineUs = frameTimelineUs(
            presentationTimeUs = 2_250_000L,
            anchorPresentationUs = 0L,
            anchorTimelineUs = 0L,
            timeline = mixedSpeeds,
        )

        assertEquals(2_500_000L, timelineUs)
    }

    @Test
    fun `a frame anchored in a sped-up clip lies past the anchor at that clip's speed`() {
        // A seek to 4.2 s lands 0.4 s of media into the sped-up clip.
        val timelineUs = frameTimelineUs(
            presentationTimeUs = 1_300_000L,
            anchorPresentationUs = 1_000_000L,
            anchorTimelineUs = 4_200_000L,
            timeline = mixedSpeeds,
        )

        assertEquals(4_350_000L, timelineUs)
    }

    @Test
    fun `a looping timeline with clips at speeds of their own starts over after one pass of media`() {
        assertEquals(5_500_000L, mixedSpeeds.lengthUs)
        assertEquals(6_000_000L, mixedSpeeds.mediaLengthUs)

        // 8.6 s of media is 2.6 s into the second pass: 0.6 s into the slowed clip.
        val timelineUs = frameTimelineUs(
            presentationTimeUs = 8_600_000L,
            anchorPresentationUs = 0L,
            anchorTimelineUs = 0L,
            timeline = mixedSpeeds,
        )

        assertEquals(3_200_000L, timelineUs)
    }

    @Test
    fun `a short window covers its frames in each clip of a timeline with speeds of their own`() {
        // 100 ms windows in the normal-speed, the slowed and the sped-up clip.
        val configs = listOf(
            config(1_050_000L, 1_150_000L),
            config(2_500_000L, 2_600_000L),
            config(4_300_000L, 4_400_000L),
        )
        val frames = framesFromStart(mixedSpeeds, 150)

        val covered = configs.indices.map { i -> frames.filter { effectWindowsAt(configs, it)[i] } }

        assertEquals(listOf(1_066_666L, 1_100_000L, 1_133_333L), covered[0])
        // The slowed clip shows its 30 frames a second over twice the time.
        assertEquals(listOf(2_533_332L), covered[1])
        // The sped-up clip shows its 30 frames a second in half the time.
        assertEquals(
            listOf(4_300_000L, 4_316_667L, 4_333_333L, 4_350_000L, 4_366_667L, 4_383_333L),
            covered[2],
        )
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
