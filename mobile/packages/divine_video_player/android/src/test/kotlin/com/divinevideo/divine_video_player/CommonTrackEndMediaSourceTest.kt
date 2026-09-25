package com.divinevideo.divine_video_player

import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Timeline
import androidx.media3.exoplayer.source.ForwardingTimeline
import androidx.media3.exoplayer.source.MediaPeriod
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.SinglePeriodTimeline
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins where a clip tagged for its common track end starts and stops, and
 * that both reach the periods already playing rather than only the ones
 * created later.
 */
class CommonTrackEndMediaSourceTest {

    private fun timeline(durationUs: Long): Timeline =
        SinglePeriodTimeline(
            /* durationUs = */ durationUs,
            /* isSeekable = */ true,
            /* isDynamic = */ false,
            /* useLiveConfiguration = */ false,
            /* manifest = */ null,
            /* mediaItem = */ MediaItem.EMPTY,
        )

    private fun windowDurationUs(timeline: Timeline): Long =
        timeline.getWindow(0, Timeline.Window()).durationUs

    private fun periodDurationUs(timeline: Timeline): Long =
        timeline.getPeriod(0, Timeline.Period()).durationUs

    /** A child period that reports [bufferedUs] as loaded, and seeks where asked. */
    private fun childPeriod(bufferedUs: Long): MediaPeriod =
        mockk<MediaPeriod>(relaxed = true).also {
            every { it.bufferedPositionUs } returns bufferedUs
            every { it.seekToUs(any()) } answers { firstArg() }
        }

    private fun source(
        trackEnds: LongArray?,
        requestedEndUs: Long = C.TIME_END_OF_SOURCE,
        childPeriod: MediaPeriod = childPeriod(bufferedUs = 0L),
    ): CommonTrackEndMediaSource {
        val child = mockk<MediaSource>(relaxed = true)
        every { child.createPeriod(any(), any(), any()) } returns childPeriod
        return CommonTrackEndMediaSource(child, requestedEndUs) { trackEnds }
    }

    private fun createPeriod(source: CommonTrackEndMediaSource): MediaPeriod =
        source.createPeriod(MediaSource.MediaPeriodId(Any()), mockk(relaxed = true), 0L)

    @Test
    fun `an audio track that outlives the picture ends the clip at the last frame`() {
        // Measured on a CDN derivative: the picture ends at 6290 ms and the
        // sound at 6336 ms, so the container holds the last frame for 46 ms
        // at every restart.
        assertEquals(
            6_290_000L,
            commonTrackEndUs(C.TIME_END_OF_SOURCE, videoEndUs = 6_290_000L, audioEndUs = 6_336_000L),
        )
    }

    @Test
    fun `a picture that outlives its sound ends the clip where the sound does`() {
        assertEquals(
            6_295_000L,
            commonTrackEndUs(C.TIME_END_OF_SOURCE, videoEndUs = 6_307_000L, audioEndUs = 6_295_000L),
        )
    }

    @Test
    fun `a long tail is the creator's and is left alone`() {
        // Past half a second it is not muxing granularity.
        assertNull(commonTrackEndUs(C.TIME_END_OF_SOURCE, 4_000_000L, 5_700_000L))
        // Nor past a tenth of a short clip.
        assertNull(commonTrackEndUs(C.TIME_END_OF_SOURCE, 1_000_000L, 1_150_000L))
    }

    @Test
    fun `an earlier requested end wins over the track end`() {
        assertNull(commonTrackEndUs(3_000_000L, videoEndUs = 6_290_000L, audioEndUs = 6_336_000L))
    }

    @Test
    fun `the published timeline ends where the shorter track does`() {
        val source = source(trackEnds = longArrayOf(6_290_000L, 6_336_000L))

        val clipped = source.clip(timeline(durationUs = 6_336_000L))

        assertEquals(6_290_000L, windowDurationUs(clipped))
        assertEquals(6_290_000L, periodDurationUs(clipped))
    }

    @Test
    fun `a period already playing is clipped when the track ends arrive`() {
        // The period exists before the moov box is parsed: it is what parses
        // it. Only an end pushed into it stops the renderers at the last frame
        // on the very first lap.
        val source = source(
            trackEnds = longArrayOf(6_290_000L, 6_336_000L),
            childPeriod = childPeriod(bufferedUs = 6_300_000L),
        )
        val period = createPeriod(source)
        assertEquals(6_300_000L, period.bufferedPositionUs)

        source.clip(timeline(durationUs = 6_336_000L))

        assertEquals(C.TIME_END_OF_SOURCE, period.bufferedPositionUs)
    }

    @Test
    fun `a period created after the track ends arrived is clipped from the start`() {
        // Every repeat of the clip is a new period; each has to carry the end.
        val source = source(
            trackEnds = longArrayOf(6_290_000L, 6_336_000L),
            childPeriod = childPeriod(bufferedUs = 6_300_000L),
        )
        source.clip(timeline(durationUs = 6_336_000L))

        val period = createPeriod(source)

        assertEquals(C.TIME_END_OF_SOURCE, period.bufferedPositionUs)
    }

    @Test
    fun `unknown track ends leave the timeline as the source published it`() {
        val source = source(trackEnds = null)
        val published = timeline(durationUs = 6_336_000L)

        assertSame(published, source.clip(published))
    }

    @Test
    fun `unknown track ends still honour the requested end`() {
        val source = source(trackEnds = null, requestedEndUs = 3_000_000L)

        val clipped = source.clip(timeline(durationUs = 6_336_000L))

        assertEquals(3_000_000L, windowDurationUs(clipped))
    }

    @Test
    fun `a requested end past the clip leaves the clip its own length`() {
        val source = source(trackEnds = null, requestedEndUs = 30_000_000L)

        val clipped = source.clip(timeline(durationUs = 6_336_000L))

        assertEquals(6_336_000L, windowDurationUs(clipped))
    }

    @Test
    fun `the factory wraps only items tagged for the track end`() {
        val delegate = mockk<MediaSource.Factory>(relaxed = true)
        val plain = mockk<MediaSource>(relaxed = true)
        every { delegate.createMediaSource(any()) } returns plain
        val factory = CommonTrackEndMediaSourceFactory(delegate) { null }
        val uri = mockk<Uri>(relaxed = true)
        every { uri.toString() } returns "https://cdn.example/a.mp4"

        val untagged = factory.createMediaSource(MediaItem.Builder().setUri(uri).build())
        val tagged = factory.createMediaSource(
            MediaItem.Builder()
                .setUri(uri)
                .setTag(CommonTrackEndClip(requestedEndUs = C.TIME_END_OF_SOURCE))
                .build(),
        )

        assertSame(plain, untagged)
        assertTrue(tagged is CommonTrackEndMediaSource)
    }

    @Test
    fun `the factory looks the track ends up by the item's own URI`() {
        val delegate = mockk<MediaSource.Factory>(relaxed = true)
        every { delegate.createMediaSource(any()) } returns mockk<MediaSource>(relaxed = true).also {
            every { it.createPeriod(any(), any(), any()) } returns childPeriod(6_300_000L)
        }
        val asked = mutableListOf<String>()
        val factory = CommonTrackEndMediaSourceFactory(delegate) { uri ->
            asked += uri
            longArrayOf(6_290_000L, 6_336_000L)
        }
        val uri = mockk<Uri>(relaxed = true)
        every { uri.toString() } returns "https://cdn.example/a.mp4"

        val source = factory.createMediaSource(
            MediaItem.Builder()
                .setUri(uri)
                .setTag(CommonTrackEndClip(requestedEndUs = C.TIME_END_OF_SOURCE))
                .build(),
        ) as CommonTrackEndMediaSource
        val clipped = source.clip(timeline(durationUs = 6_336_000L))

        assertEquals(listOf("https://cdn.example/a.mp4"), asked)
        assertEquals(6_290_000L, windowDurationUs(clipped))
    }

    @Test
    fun `a first frame a muxer's edit shows late starts the clip`() {
        // The CDN derivative of a 3.1 s Vine: 23 ms of empty edit, then the
        // picture. From zero, each restart held the last frame 23 ms longer.
        assertEquals(23_000L, leadingVideoGapUs(videoStartUs = 23_000L, endUs = 3_124_000L))
    }

    @Test
    fun `a late first frame past the bounds is the creator's and stays`() {
        // Past a tenth of a second it is not a muxer's edit.
        assertEquals(0L, leadingVideoGapUs(videoStartUs = 150_000L, endUs = 6_000_000L))
        // Nor past a tenth of a short clip.
        assertEquals(0L, leadingVideoGapUs(videoStartUs = 60_000L, endUs = 500_000L))
        assertEquals(0L, leadingVideoGapUs(videoStartUs = 0L, endUs = 3_124_000L))
    }

    @Test
    fun `the published timeline runs from the first frame to the shorter track's end`() {
        val source = source(trackEnds = longArrayOf(3_124_000L, 3_135_000L, 23_000L))

        val clipped = source.clip(timeline(durationUs = 3_135_000L))

        val window = clipped.getWindow(0, Timeline.Window())
        val period = clipped.getPeriod(0, Timeline.Period())
        assertEquals(3_101_000L, window.durationUs)
        assertEquals(23_000L, window.positionInFirstPeriodUs)
        assertEquals(-23_000L, period.positionInWindowUs)
        assertEquals(3_124_000L, period.durationUs)
    }

    @Test
    fun `a period already playing starts at the first frame when the bounds arrive`() {
        val source = source(
            trackEnds = longArrayOf(3_124_000L, 3_135_000L, 23_000L),
            childPeriod = childPeriod(bufferedUs = 0L),
        )
        val period = createPeriod(source)
        assertEquals(0L, period.seekToUs(0L))

        source.clip(timeline(durationUs = 3_135_000L))

        assertEquals(23_000L, period.seekToUs(0L))
    }

    @Test
    fun `a period created after the bounds arrived starts at the first frame`() {
        // Every repeat is a new period, and it is where every later lap begins.
        val source = source(
            trackEnds = longArrayOf(3_124_000L, 3_135_000L, 23_000L),
            childPeriod = childPeriod(bufferedUs = 0L),
        )
        source.clip(timeline(durationUs = 3_135_000L))

        val period = createPeriod(source)

        assertEquals(23_000L, period.seekToUs(0L))
    }

    @Test
    fun `releasing an already-released period fails instead of double-forwarding`() {
        // A mismatched create-release pairing must surface here, not as a
        // silent second release into the child source's own period pool.
        val source = source(trackEnds = longArrayOf(6_290_000L, 6_336_000L))
        val period = createPeriod(source)
        source.releasePeriod(period)

        assertThrows(IllegalStateException::class.java) { source.releasePeriod(period) }
    }

    @Test
    fun `a placeholder timeline stays a placeholder once clipped`() {
        // The player moves an unprepared period to the new start only when
        // the timeline it was created against was a placeholder.
        val placeholder = object : ForwardingTimeline(timeline(durationUs = C.TIME_UNSET)) {
            override fun getPeriod(periodIndex: Int, period: Period, setIds: Boolean): Period {
                super.getPeriod(periodIndex, period, setIds)
                period.isPlaceholder = true
                return period
            }
        }
        val source = source(trackEnds = longArrayOf(3_124_000L, 3_135_000L, 23_000L))

        val clipped = source.clip(placeholder)

        assertTrue(clipped.getPeriod(0, Timeline.Period()).isPlaceholder)
    }
}
