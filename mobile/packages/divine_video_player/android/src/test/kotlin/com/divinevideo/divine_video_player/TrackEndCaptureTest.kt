package com.divinevideo.divine_video_player

import android.net.Uri
import androidx.media3.common.C
import androidx.media3.extractor.Extractor
import androidx.media3.extractor.ExtractorInput
import androidx.media3.extractor.ExtractorOutput
import androidx.media3.extractor.ExtractorsFactory
import androidx.media3.extractor.PositionHolder
import androidx.media3.extractor.TrackOutput
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

/**
 * Pins that the track lengths the player's extractor parses reach the clip
 * before the player publishes its timeline — at `endTracks`, which the MP4
 * extractor calls ahead of its seek map — and that the extractor it wraps
 * still sees everything it wrote.
 */
class TrackEndCaptureTest {

    /** Writes what an MP4 `moov` box does, in the order it does it. */
    private class FakeMp4Extractor(
        private val tracks: List<Pair<Int, Long>>,
    ) : Extractor {
        override fun sniff(input: ExtractorInput): Boolean = true

        override fun init(output: ExtractorOutput) {
            tracks.forEachIndexed { id, (type, durationUs) ->
                output.track(id, type).durationUs(durationUs)
            }
            output.endTracks()
        }

        override fun read(input: ExtractorInput, seekPosition: PositionHolder): Int =
            Extractor.RESULT_END_OF_INPUT

        override fun seek(position: Long, timeUs: Long) = Unit

        override fun release() = Unit
    }

    private fun capture(
        extractor: Extractor,
        output: ExtractorOutput = mockk(relaxed = true),
    ): List<Triple<Uri, Long, Long>> {
        val reported = mutableListOf<Triple<Uri, Long, Long>>()
        val factory = TrackEndCapturingExtractorsFactory(ExtractorsFactory { arrayOf(extractor) }) {
                uri, videoEndUs, audioEndUs ->
            reported += Triple(uri, videoEndUs, audioEndUs)
        }
        val uri = mockk<Uri>(relaxed = true)
        factory.createExtractors(uri, emptyMap()).single().init(output)
        return reported
    }

    @Test
    fun `reports the video and audio track ends at the end of the track list`() {
        val reported = capture(
            FakeMp4Extractor(
                listOf(C.TRACK_TYPE_VIDEO to 6_290_000L, C.TRACK_TYPE_AUDIO to 6_336_000L),
            ),
        )

        assertEquals(listOf(6_290_000L to 6_336_000L), reported.map { it.second to it.third })
    }

    @Test
    fun `reports nothing for a container without both track types`() {
        // Nothing to trim: a clip without sound has no sound to run out.
        val reported = capture(FakeMp4Extractor(listOf(C.TRACK_TYPE_VIDEO to 6_290_000L)))

        assertEquals(emptyList<Triple<Uri, Long, Long>>(), reported)
    }

    @Test
    fun `the first track of each type is the one reported`() {
        val reported = capture(
            FakeMp4Extractor(
                listOf(
                    C.TRACK_TYPE_VIDEO to 6_290_000L,
                    C.TRACK_TYPE_AUDIO to 6_336_000L,
                    C.TRACK_TYPE_AUDIO to 9_000_000L,
                ),
            ),
        )

        assertEquals(listOf(6_290_000L to 6_336_000L), reported.map { it.second to it.third })
    }

    @Test
    fun `the player still receives every track, its duration and the end of tracks`() {
        val output = mockk<ExtractorOutput>(relaxed = true)
        val video = mockk<TrackOutput>(relaxed = true)
        val audio = mockk<TrackOutput>(relaxed = true)
        every { output.track(0, C.TRACK_TYPE_VIDEO) } returns video
        every { output.track(1, C.TRACK_TYPE_AUDIO) } returns audio

        capture(
            FakeMp4Extractor(
                listOf(C.TRACK_TYPE_VIDEO to 6_290_000L, C.TRACK_TYPE_AUDIO to 6_336_000L),
            ),
            output,
        )

        verify(exactly = 1) { video.durationUs(6_290_000L) }
        verify(exactly = 1) { audio.durationUs(6_336_000L) }
        verify(exactly = 1) { output.endTracks() }
    }

    @Test
    fun `the wrapped extractor is still visible to the loader`() {
        // The progressive loader asks for the real extractor to decide how
        // to treat MP3 streams; a wrapper that hid it would change that.
        val extractor = FakeMp4Extractor(emptyList())
        val factory = TrackEndCapturingExtractorsFactory(ExtractorsFactory { arrayOf(extractor) }) {
                _, _, _ ->
        }

        val wrapped = factory.createExtractors(mockk(relaxed = true), emptyMap()).single()

        assertSame(extractor, wrapped.underlyingImplementation)
    }
}
