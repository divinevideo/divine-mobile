package co.openvine.app

import android.view.Display
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class HighRefreshRateTest {
    private fun mode(id: Int, width: Int, height: Int, hz: Float): Display.Mode =
        mockk {
            every { modeId } returns id
            every { physicalWidth } returns width
            every { physicalHeight } returns height
            every { refreshRate } returns hz
        }

    @Test
    fun `picks the fastest mode at the current resolution`() {
        val current = mode(1, 1080, 2340, 60f)
        val modes = arrayOf(
            current,
            mode(2, 1080, 2340, 120f),
            mode(3, 1080, 2340, 90f),
            // A faster mode at another resolution must not win: switching
            // to it would change the window size, not just the cadence.
            mode(4, 720, 1560, 144f),
        )

        assertEquals(2, HighRefreshRate.fastestMode(modes, current)?.modeId)
    }

    @Test
    fun `keeps the current mode when nothing at its resolution is faster`() {
        val current = mode(1, 1080, 2340, 120f)
        val modes = arrayOf(current, mode(2, 1080, 2340, 60f))

        assertEquals(1, HighRefreshRate.fastestMode(modes, current)?.modeId)
    }

    @Test
    fun `returns null when the panel lists no modes`() {
        val current = mode(1, 1080, 2340, 60f)

        assertNull(HighRefreshRate.fastestMode(emptyArray(), current))
    }
}
