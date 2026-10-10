package com.divinevideo.divine_video_player

import org.junit.Assert.assertEquals
import org.junit.Test

class RecentStreamClipsTest {

    @Test
    fun `forgets the stream used longest ago`() {
        val clips = RecentStreamClips(capacity = 2)
        clips[1_000L] = 0
        clips[2_000L] = 1
        clips[3_000L] = 2

        assertEquals(-1, clips[1_000L])
        assertEquals(1, clips[2_000L])
        assertEquals(2, clips[3_000L])
    }

    @Test
    fun `keeps an offset handed out again after a seek past the streams read ahead`() {
        val clips = RecentStreamClips(capacity = 2)
        clips[1_000L] = 0
        clips[2_000L] = 1
        // A seek outside the loaded queue starts the offsets over: the first
        // one now names the clip sought to, and the next clip is read ahead.
        clips[1_000L] = 4
        clips[2_500L] = 5

        assertEquals(4, clips[1_000L])
        assertEquals(-1, clips[2_000L])
    }

    @Test
    fun `keeps the stream being output while later ones are read`() {
        val clips = RecentStreamClips(capacity = 2)
        clips[1_000L] = 0
        clips[2_000L] = 1
        assertEquals(0, clips[1_000L])
        clips[3_000L] = 2

        assertEquals(0, clips[1_000L])
        assertEquals(-1, clips[2_000L])
    }
}
