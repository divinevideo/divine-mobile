package com.divinevideo.divine_video_player

import android.content.Context
import android.os.Handler
import android.util.Range
import android.view.Surface
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.Renderer
import androidx.media3.exoplayer.video.MediaCodecVideoRenderer
import androidx.media3.exoplayer.video.VideoSink
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.unmockkConstructor
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * Guards the editor preview against the frame-effect pipeline failing for
 * good when the output surface is reattached at a clip end: Media3 reports
 * the reattached surface's size as [Size.UNKNOWN] before the plugin sends the
 * real one, and a frame drawn in between would build a canvas of width -1.
 */
@UnstableApi
class KnownOutputSizeVideoRendererTest {

    private val context = mockk<Context>(relaxed = true) {
        every { applicationContext } returns this
        every { getSystemService(any<String>()) } returns null
    }

    private val sink = mockk<VideoSink>(relaxed = true)

    private val surface = mockk<Surface>()

    private lateinit var renderer: KnownOutputSizeVideoRenderer

    @Before
    fun setUp() {
        // The renderer reads a frame-rate range the JVM's android.jar stub leaves empty.
        mockkConstructor(Range::class)
        every { anyConstructed<Range<Double>>().upper } returns 1.0
        renderer = KnownOutputSizeVideoRenderer(
            MediaCodecVideoRenderer.Builder(context).setVideoSink(sink),
        )
        renderer.handleMessage(Renderer.MSG_SET_VIDEO_OUTPUT, surface)
    }

    @After
    fun tearDown() {
        unmockkConstructor(Range::class)
    }

    @Test
    fun `keeps the unknown size a reattached surface reports from the effect pipeline`() {
        renderer.handleMessage(Renderer.MSG_SET_VIDEO_OUTPUT_RESOLUTION, Size.UNKNOWN)

        verify(exactly = 0) { sink.setOutputSurfaceInfo(any(), any()) }
    }

    @Test
    fun `passes on the real size the player sends after it`() {
        renderer.handleMessage(Renderer.MSG_SET_VIDEO_OUTPUT_RESOLUTION, Size.UNKNOWN)
        renderer.handleMessage(Renderer.MSG_SET_VIDEO_OUTPUT_RESOLUTION, Size(1080, 1920))

        verify(exactly = 1) { sink.setOutputSurfaceInfo(surface, Size(1080, 1920)) }
        verify(exactly = 0) { sink.setOutputSurfaceInfo(any(), Size.UNKNOWN) }
    }

    @Test
    fun `builds the guarded renderer for the player's video`() {
        val renderers = LoopDeclickRenderersFactory(context, LoopDeclickAudioProcessor())
            .createRenderers(
                mockk<Handler>(relaxed = true),
                mockk(relaxed = true),
                mockk(relaxed = true),
                mockk(relaxed = true),
                mockk(relaxed = true),
            )

        val videoRenderers = renderers.filterIsInstance<MediaCodecVideoRenderer>()
        assertEquals(listOf(KnownOutputSizeVideoRenderer::class.java), videoRenderers.map { it.javaClass })
    }
}
