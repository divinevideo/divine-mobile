package com.divinevideo.divine_video_player

import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Guards when the upscale stage runs and what size it draws frames at.
 */
@UnstableApi
class VideoUpscaleTest {

    private val source = Size(720, 1280)

    @Test
    fun `wire values match the Dart enum`() {
        assertEquals(VideoUpscale.Mode.LANCZOS, VideoUpscale.Mode.fromWire("lanczos"))
        assertEquals(VideoUpscale.Mode.BILINEAR, VideoUpscale.Mode.fromWire("bilinear"))
        assertEquals(VideoUpscale.Mode.OFF, VideoUpscale.Mode.fromWire("off"))
    }

    @Test
    fun `an unknown or missing wire value means off`() {
        assertEquals(VideoUpscale.Mode.OFF, VideoUpscale.Mode.fromWire("bicubic"))
        assertEquals(VideoUpscale.Mode.OFF, VideoUpscale.Mode.fromWire(null))
    }

    @Test
    fun `the requested mode holds on a device with enough memory`() {
        val mode = VideoUpscale.resolveMode(VideoUpscale.Mode.LANCZOS, null, 8L * GIB)
        assertEquals(VideoUpscale.Mode.LANCZOS, mode)
    }

    @Test
    fun `a device sold with less than 6 GB keeps Flutter's scaling`() {
        // A 4 GB phone reports about 3.6 GiB of total memory.
        val mode = VideoUpscale.resolveMode(VideoUpscale.Mode.LANCZOS, null, 3_700L * MIB)
        assertEquals(VideoUpscale.Mode.OFF, mode)
    }

    @Test
    fun `a device sold with 6 GB upscales`() {
        // A 6 GB phone reports about 5.6 GiB of total memory.
        val mode = VideoUpscale.resolveMode(VideoUpscale.Mode.LANCZOS, null, 5_700L * MIB)
        assertEquals(VideoUpscale.Mode.LANCZOS, mode)
    }

    @Test
    fun `an unknown memory size counts as enough`() {
        val mode = VideoUpscale.resolveMode(VideoUpscale.Mode.LANCZOS, null, null)
        assertEquals(VideoUpscale.Mode.LANCZOS, mode)
    }

    @Test
    fun `the debug override wins over the request and the memory check`() {
        assertEquals(
            VideoUpscale.Mode.BILINEAR,
            VideoUpscale.resolveMode(VideoUpscale.Mode.OFF, VideoUpscale.Mode.BILINEAR, 2L * GIB),
        )
        assertEquals(
            VideoUpscale.Mode.OFF,
            VideoUpscale.resolveMode(VideoUpscale.Mode.LANCZOS, VideoUpscale.Mode.OFF, 8L * GIB),
        )
    }

    @Test
    fun `a larger target becomes the output size`() {
        assertEquals(Size(1316, 2340), VideoUpscale.outputSize(source, Size(1316, 2340)))
    }

    @Test
    fun `without a target the frame keeps its own size`() {
        assertEquals(source, VideoUpscale.outputSize(source, null))
    }

    @Test
    fun `a smaller or equal target keeps the frame at its own size`() {
        assertEquals(source, VideoUpscale.outputSize(source, Size(360, 640)))
        assertEquals(source, VideoUpscale.outputSize(source, Size(720, 1280)))
    }

    @Test
    fun `a target larger in only one direction keeps the frame at its own size`() {
        assertEquals(source, VideoUpscale.outputSize(source, Size(1080, 1280)))
    }

    @Test
    fun `a target beyond the pixel cap keeps the frame at its own size`() {
        assertEquals(source, VideoUpscale.outputSize(source, Size(1600, 3200)))
        assertEquals(Size(1440, 3200), VideoUpscale.outputSize(source, Size(1440, 3200)))
    }

    @Test
    fun `the Lanczos shader resamples along the axis it is built for`() {
        val horizontal = VideoUpscale.lanczosShader("x", "y")
        assertTrue(horizontal.contains("float p = vTexCoord.x * uSrcSize.x - 0.5;"))
        assertTrue(horizontal.contains("uv.y = vTexCoord.y;"))
        // Six taps: -2 through 3 around the source position.
        assertTrue(horizontal.contains("for (int i = -2; i <= 3; i++)"))
        // highp, because a mediump position is off by more than half a texel.
        assertTrue(horizontal.startsWith("precision highp float;"))
    }

    private companion object {
        const val MIB = 1024L * 1024
        const val GIB = 1024 * MIB
    }
}
