package com.divinevideo.divine_video_player

import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Guards which devices send their frames through the GL copy that dodges the
 * sheared frames of flutter/flutter#193551, and the size it draws them at.
 */
@UnstableApi
class MaliStrideWorkaroundTest {

    @Test
    fun `MediaTek with a Mali-G610 is affected`() {
        assertTrue(MaliStrideWorkaround.isAffected("Mediatek", "mt6886") { "Mali-G610 MC6" })
    }

    @Test
    fun `MediaTek with an Immortalis GPU is affected`() {
        assertTrue(MaliStrideWorkaround.isAffected("Mediatek", "mt6983") { "Mali-G715-Immortalis MC11" })
    }

    @Test
    fun `MediaTek with a Mali-G57 is not affected`() {
        assertFalse(MaliStrideWorkaround.isAffected("Mediatek", "mt6835") { "Mali-G57 MC2" })
    }

    @Test
    fun `MediaTek with a Mali-G52 is not affected`() {
        assertFalse(MaliStrideWorkaround.isAffected("Mediatek", "mt6769") { "Mali-G52 MC2" })
    }

    @Test
    fun `MediaTek with a PowerVR GPU is not affected`() {
        assertFalse(MaliStrideWorkaround.isAffected("Mediatek", "mt6855") { "PowerVR B-Series BXM-8-256" })
    }

    @Test
    fun `a Mali GPU on another SoC is not affected and is not probed`() {
        var probed = false
        val affected = MaliStrideWorkaround.isAffected("Google", "zuma") {
            probed = true
            "Mali-G715"
        }
        assertFalse(affected)
        assertFalse(probed)
    }

    @Test
    fun `Samsung Xclipse is not affected`() {
        assertFalse(MaliStrideWorkaround.isAffected("Samsung", "s5e9965") { "Samsung Xclipse 960" })
    }

    @Test
    fun `before Android 12 the hardware name identifies MediaTek`() {
        assertTrue(MaliStrideWorkaround.isAffected(null, "mt6893") { "Mali-G610 MC6" })
        assertFalse(MaliStrideWorkaround.isAffected(null, "qcom") { "Mali-G610 MC6" })
    }

    @Test
    fun `an unreadable renderer is not affected`() {
        assertFalse(MaliStrideWorkaround.isAffected("Mediatek", "mt6886") { null })
    }

    @Test
    fun `maliGeneration reads the model number`() {
        assertEquals(610, MaliStrideWorkaround.maliGeneration("Mali-G610 MC6"))
        assertEquals(57, MaliStrideWorkaround.maliGeneration("Mali-G57 MC2"))
        assertEquals(925, MaliStrideWorkaround.maliGeneration("Mali-G925-Immortalis MC12"))
        assertNull(MaliStrideWorkaround.maliGeneration("Adreno (TM) 740"))
        assertNull(MaliStrideWorkaround.maliGeneration(null))
    }

    @Test
    fun `outputSize keeps an upright frame as it is`() {
        assertEquals(Size(720, 1280), MaliStrideWorkaround.outputSize(720, 1280, 0, 1f))
    }

    @Test
    fun `outputSize turns a rotated frame upright`() {
        assertEquals(Size(1080, 1920), MaliStrideWorkaround.outputSize(1920, 1080, 90, 1f))
        assertEquals(Size(1080, 1920), MaliStrideWorkaround.outputSize(1920, 1080, 270, 1f))
        assertEquals(Size(1920, 1080), MaliStrideWorkaround.outputSize(1920, 1080, 180, 1f))
    }

    @Test
    fun `outputSize stretches non-square pixels`() {
        assertEquals(Size(960, 480), MaliStrideWorkaround.outputSize(720, 480, 0, 4f / 3f))
        assertEquals(Size(720, 640), MaliStrideWorkaround.outputSize(720, 480, 0, 0.75f))
    }

    @Test
    fun `outputSize ignores an unusable pixel ratio`() {
        assertEquals(Size(720, 720), MaliStrideWorkaround.outputSize(720, 720, 0, Float.NaN))
    }

    @Test
    fun `outputSize waits for a track with a size`() {
        assertNull(MaliStrideWorkaround.outputSize(0, 0, 0, 1f))
        assertNull(MaliStrideWorkaround.outputSize(-1, 1280, 0, 1f))
    }
}
