package com.divinevideo.divine_video_player

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the fade envelope an overlay track plays in the editor preview.
 *
 * It has to match the one `pro_video_editor` bakes into the export — linear
 * ramps from and to silence, the quieter ramp winning where they overlap — or
 * the creator hears one fade while editing and another in the posted video.
 */
class AudioOverlayFadeTest {

    private val delta = 1e-6f

    @Test
    fun `a fade in rises linearly from silence to full level`() {
        val fade = AudioOverlayFade(fadeInMs = 1000, fadeOutMs = 0)

        assertEquals(0f, fade.gainAt(0, audibleMs = 5000), delta)
        assertEquals(0.25f, fade.gainAt(250, audibleMs = 5000), delta)
        assertEquals(1f, fade.gainAt(1000, audibleMs = 5000), delta)
        assertEquals(1f, fade.gainAt(4999, audibleMs = 5000), delta)
    }

    @Test
    fun `a fade out falls linearly to silence at the end of the audio`() {
        val fade = AudioOverlayFade(fadeInMs = 0, fadeOutMs = 2000)

        assertEquals(1f, fade.gainAt(3000, audibleMs = 5000), delta)
        assertEquals(0.5f, fade.gainAt(4000, audibleMs = 5000), delta)
        assertEquals(0f, fade.gainAt(5000, audibleMs = 5000), delta)
    }

    @Test
    fun `overlapping fades keep the quieter ramp`() {
        val fade = AudioOverlayFade(fadeInMs = 1000, fadeOutMs = 1000)

        // In a one-second track the two ramps cross half-way, at half level.
        assertEquals(0.5f, fade.gainAt(500, audibleMs = 1000), delta)
        assertEquals(0.25f, fade.gainAt(750, audibleMs = 1000), delta)
    }

    @Test
    fun `a position outside the audio is silent rather than negative`() {
        val fade = AudioOverlayFade(fadeInMs = 1000, fadeOutMs = 1000)

        assertEquals(0f, fade.gainAt(-50, audibleMs = 5000), delta)
        assertEquals(0f, fade.gainAt(5200, audibleMs = 5000), delta)
    }

    @Test
    fun `without a known end only the fade in applies`() {
        val fade = AudioOverlayFade(fadeInMs = 1000, fadeOutMs = 1000)

        assertEquals(0.5f, fade.gainAt(500, audibleMs = null), delta)
        assertEquals(1f, fade.gainAt(60_000, audibleMs = null), delta)
    }

    @Test
    fun `reads the fade from the channel map, defaulting to none`() {
        assertEquals(
            AudioOverlayFade(fadeInMs = 250, fadeOutMs = 1500),
            AudioOverlayFade.fromMap(mapOf("fadeInMs" to 250, "fadeOutMs" to 1500L)),
        )
        assertTrue(AudioOverlayFade.fromMap(emptyMap()).isNone)
        assertFalse(AudioOverlayFade(fadeInMs = 0, fadeOutMs = 1).isNone)
    }
}
