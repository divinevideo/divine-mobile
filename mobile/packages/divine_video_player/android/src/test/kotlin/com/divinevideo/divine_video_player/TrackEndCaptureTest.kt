package com.divinevideo.divine_video_player

import android.net.Uri
import androidx.media3.common.C
import androidx.media3.extractor.Extractor
import androidx.media3.extractor.ExtractorInput
import androidx.media3.extractor.ExtractorOutput
import androidx.media3.extractor.ExtractorsFactory
import androidx.media3.extractor.PositionHolder
import androidx.media3.extractor.SeekMap
import androidx.media3.extractor.SeekPoint
import androidx.media3.extractor.TrackOutput
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

/**
 * Pins that the track bounds the player's extractor parses reach the clip
 * before the player publishes its timeline — with the seek map, which the MP4
 * extractor publishes straight after its track list and the player waits for
 * before it prepares — and that the extractor it wraps still sees everything
 * it wrote.
 */
class TrackEndCaptureTest {

    /**
     * Writes what an MP4 `moov` box does, in the order it does it. The seek
     * map starts from the first video frame, at [firstFrameUs].
     */
    private class FakeMp4Extractor(
        private val tracks: List<Pair<Int, Long>>,
        private val firstFrameUs: Long = 0L,
        private val seekable: Boolean = true,
    ) : Extractor {
        val seekMap = object : SeekMap {
            override fun isSeekable(): Boolean = seekable

            override fun getDurationUs(): Long = tracks.maxOfOrNull { it.second } ?: C.TIME_UNSET

            override fun getSeekPoints(timeUs: Long): SeekMap.SeekPoints =
                SeekMap.SeekPoints(SeekPoint(maxOf(timeUs, firstFrameUs), 0L))
        }

        override fun sniff(input: ExtractorInput): Boolean = true

        override fun init(output: ExtractorOutput) {
            tracks.forEachIndexed { id, (type, durationUs) ->
                output.track(id, type).durationUs(durationUs)
            }
            output.endTracks()
            output.seekMap(seekMap)
        }

        override fun read(input: ExtractorInput, seekPosition: PositionHolder): Int =
            Extractor.RESULT_END_OF_INPUT

        override fun seek(position: Long, timeUs: Long) = Unit

        override fun release() = Unit
    }

    /** What one parse reported: `[videoEndUs, audioEndUs, videoStartUs]`. */
    private fun capture(
        extractor: Extractor,
        output: ExtractorOutput = mockk(relaxed = true),
    ): List<List<Long>> {
        val reported = mutableListOf<List<Long>>()
        val factory = TrackEndCapturingExtractorsFactory(ExtractorsFactory { arrayOf(extractor) }) {
                _, videoEndUs, audioEndUs, videoStartUs ->
            reported += listOf(videoEndUs, audioEndUs, videoStartUs)
        }
        val uri = mockk<Uri>(relaxed = true)
        factory.createExtractors(uri, emptyMap()).single().init(output)
        return reported
    }

    @Test
    fun `reports the video and audio track ends with the seek map`() {
        val reported = capture(
            FakeMp4Extractor(
                listOf(C.TRACK_TYPE_VIDEO to 6_290_000L, C.TRACK_TYPE_AUDIO to 6_336_000L),
            ),
        )

        assertEquals(listOf(listOf(6_290_000L, 6_336_000L, 0L)), reported)
    }

    @Test
    fun `reports where an empty edit makes the first frame appear`() {
        // A CDN derivative: its video edit list is 23 ms of nothing, then the
        // picture, so the seek map starts from a frame shown at 23 ms.
        val reported = capture(
            FakeMp4Extractor(
                listOf(C.TRACK_TYPE_VIDEO to 3_124_000L, C.TRACK_TYPE_AUDIO to 3_135_000L),
                firstFrameUs = 23_000L,
            ),
        )

        assertEquals(listOf(listOf(3_124_000L, 3_135_000L, 23_000L)), reported)
    }

    @Test
    fun `an unseekable container reports its picture from zero`() {
        // Its seek map answers every time with the top of the file, which
        // says nothing about where the first frame is shown.
        val reported = capture(
            FakeMp4Extractor(
                listOf(C.TRACK_TYPE_VIDEO to 3_124_000L, C.TRACK_TYPE_AUDIO to 3_135_000L),
                firstFrameUs = 23_000L,
                seekable = false,
            ),
        )

        assertEquals(listOf(listOf(3_124_000L, 3_135_000L, 0L)), reported)
    }

    @Test
    fun `reports nothing for a container without both track types`() {
        // Nothing to trim: a clip without sound has no sound to run out.
        val reported = capture(FakeMp4Extractor(listOf(C.TRACK_TYPE_VIDEO to 6_290_000L)))

        assertEquals(emptyList<List<Long>>(), reported)
    }

    @Test
    fun `two audio tracks report nothing, rather than guessing which plays`() {
        // Which of two same-type tracks actually plays is decided by track
        // selection, downstream of this extraction-time hook — so an
        // ambiguous type falls back to the same "don't clip" path as a
        // corrupt duration, rather than silently picking the first one.
        val reported = capture(
            FakeMp4Extractor(
                listOf(
                    C.TRACK_TYPE_VIDEO to 6_290_000L,
                    C.TRACK_TYPE_AUDIO to 6_336_000L,
                    C.TRACK_TYPE_AUDIO to 9_000_000L,
                ),
            ),
        )

        assertEquals(emptyList<List<Long>>(), reported)
    }

    @Test
    fun `two video tracks also report nothing`() {
        val reported = capture(
            FakeMp4Extractor(
                listOf(
                    C.TRACK_TYPE_VIDEO to 6_290_000L,
                    C.TRACK_TYPE_VIDEO to 7_000_000L,
                    C.TRACK_TYPE_AUDIO to 6_336_000L,
                ),
            ),
        )

        assertEquals(emptyList<List<Long>>(), reported)
    }

    @Test
    fun `the player still receives every track, its duration, the end of tracks and the seek map`() {
        val output = mockk<ExtractorOutput>(relaxed = true)
        val video = mockk<TrackOutput>(relaxed = true)
        val audio = mockk<TrackOutput>(relaxed = true)
        every { output.track(0, C.TRACK_TYPE_VIDEO) } returns video
        every { output.track(1, C.TRACK_TYPE_AUDIO) } returns audio
        val extractor = FakeMp4Extractor(
            listOf(C.TRACK_TYPE_VIDEO to 6_290_000L, C.TRACK_TYPE_AUDIO to 6_336_000L),
        )

        capture(extractor, output)

        verify(exactly = 1) { video.durationUs(6_290_000L) }
        verify(exactly = 1) { audio.durationUs(6_336_000L) }
        verify(exactly = 1) { output.endTracks() }
        verify(exactly = 1) { output.seekMap(extractor.seekMap) }
    }

    @Test
    fun `the wrapped extractor is still visible to the loader`() {
        // The progressive loader asks for the real extractor to decide how
        // to treat MP3 streams; a wrapper that hid it would change that.
        val extractor = FakeMp4Extractor(emptyList())
        val factory = TrackEndCapturingExtractorsFactory(ExtractorsFactory { arrayOf(extractor) }) {
                _, _, _, _ ->
        }

        val wrapped = factory.createExtractors(mockk(relaxed = true), emptyMap()).single()

        assertSame(extractor, wrapped.underlyingImplementation)
    }
}
