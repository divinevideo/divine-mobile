package com.divinevideo.divine_video_player

import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Where an overlay track's file plays at a moment of the video. A track with
 * its own speed has to land where `pro_video_editor` exports it — its trim in
 * the file, its slot and fades in the video — or the preview plays a
 * different stretch of the song than the posted video.
 */
@UnstableApi
class AudioOverlayEntryTest {

    @Test
    fun `plays the file one to one at normal speed`() {
        val entry = entry(speed = 1.0)

        assertEquals(12_000L, entry.audioPositionAt(7_000L))
        assertEquals(3_000L, entry.videoMsOf(3_000L))
    }

    /** Two seconds into its slot, a track at 2x has played four seconds of the file. */
    @Test
    fun `advances the file faster than the video when sped up`() {
        val entry = entry(speed = 2.0)

        assertEquals(14_000L, entry.audioPositionAt(7_000L))
        assertEquals(3_000L, entry.videoMsOf(6_000L))
    }

    @Test
    fun `advances the file slower than the video when slowed down`() {
        val entry = entry(speed = 0.5)

        assertEquals(11_000L, entry.audioPositionAt(7_000L))
        assertEquals(3_000L, entry.videoMsOf(1_500L))
    }

    /** A track whose slot starts at video 5 s and whose trim starts at file 10 s. */
    private fun entry(speed: Double) = AudioOverlayEntry(
        player = mockk<ExoPlayer>(relaxed = true),
        videoStartMs = 5_000L,
        videoEndMs = 20_000L,
        trackStartMs = 10_000L,
        trackEndMs = null,
        speed = speed,
    )
}
