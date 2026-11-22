package com.divinevideo.divine_video_player

import androidx.media3.common.util.UnstableApi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Guards the bounded feed buffering policy that protects low-RAM Android
 * devices from ExoPlayer OOM during feed playback (#3419).
 */
@UnstableApi
class FeedLoadControlTest {

    @Test
    fun `fromWireValue maps feed to FEED`() {
        assertEquals(BufferProfile.FEED, BufferProfile.fromWireValue("feed"))
    }

    @Test
    fun `fromWireValue maps full to FULL`() {
        assertEquals(BufferProfile.FULL, BufferProfile.fromWireValue("full"))
    }

    @Test
    fun `fromWireValue falls back to FULL for null`() {
        assertEquals(BufferProfile.FULL, BufferProfile.fromWireValue(null))
    }

    @Test
    fun `fromWireValue falls back to FULL for unknown values`() {
        assertEquals(BufferProfile.FULL, BufferProfile.fromWireValue("nonsense"))
    }

    @Test
    fun `build returns a usable LoadControl`() {
        // DefaultLoadControl.Builder.build() asserts the duration ordering
        // contract, so a non-null result also proves the constants are valid.
        assertNotNull(FeedLoadControl.build())
    }

    @Test
    fun `buffer durations satisfy the load-control ordering contract`() {
        assertTrue(FeedLoadControl.MIN_BUFFER_MS <= FeedLoadControl.MAX_BUFFER_MS)
        assertTrue(
            FeedLoadControl.BUFFER_FOR_PLAYBACK_MS <= FeedLoadControl.MIN_BUFFER_MS,
        )
        assertTrue(
            FeedLoadControl.BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS <=
                FeedLoadControl.MIN_BUFFER_MS,
        )
    }

    @Test
    fun `target buffer bytes stay bounded`() {
        assertTrue(FeedLoadControl.TARGET_BUFFER_BYTES > 0)
        // A whole ~6.3s clip fits comfortably; keep the per-player heap cap
        // small enough that several concurrent feed players stay safe.
        assertTrue(FeedLoadControl.TARGET_BUFFER_BYTES <= 16 * 1024 * 1024)
    }
}
