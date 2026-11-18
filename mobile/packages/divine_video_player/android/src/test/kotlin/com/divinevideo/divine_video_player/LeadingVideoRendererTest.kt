package com.divinevideo.divine_video_player

import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.Renderer
import io.mockk.mockk
import io.mockk.verify
import io.mockk.verifyOrder
import org.junit.Test

/**
 * Guards the editor preview's detached clips against running behind the
 * timeline player: their legacy surface shows each frame later, so their
 * renderer has to release it that much earlier, and only then.
 */
@UnstableApi
class LeadingVideoRendererTest {

    private val inner = mockk<Renderer>(relaxed = true)

    private var leadUs = 40_000L

    private val renderer = LeadingVideoRenderer(inner) { leadUs }

    @Test
    fun `renders as if the clock were the lead ahead`() {
        renderer.render(1_000_000L, 5_000L)

        verify { inner.render(1_040_000L, 5_000L) }
    }

    @Test
    fun `asks when to render next from the same lead position`() {
        renderer.getDurationToProgressUs(1_000_000L, 5_000L)

        verify { inner.getDurationToProgressUs(1_040_000L, 5_000L) }
    }

    @Test
    fun `follows a lead set after the player was built`() {
        leadUs = 0L
        renderer.render(1_000_000L, 5_000L)
        leadUs = 40_000L
        renderer.render(1_000_000L, 5_000L)

        verifyOrder {
            inner.render(1_000_000L, 5_000L)
            inner.render(1_040_000L, 5_000L)
        }
    }

    @Test
    fun `seeks to the position asked for`() {
        renderer.resetPosition(500_000L, true)

        verify { inner.resetPosition(500_000L, true) }
    }
}
