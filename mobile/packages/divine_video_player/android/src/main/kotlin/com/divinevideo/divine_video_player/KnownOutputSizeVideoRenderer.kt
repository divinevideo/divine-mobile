package com.divinevideo.divine_video_player

import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.Renderer
import androidx.media3.exoplayer.video.MediaCodecVideoRenderer

/**
 * A [MediaCodecVideoRenderer] that never hands its effect pipeline an output
 * size it cannot draw at.
 *
 * `ExoPlayer.setVideoSurface` reports a newly attached surface's size as
 * unknown, (-1, -1), and Media3 passes that on to the effect pipeline; only a
 * size of 0 is ignored. The player sends the real size right after each
 * attach, but a frame drawn in between builds a canvas of width -1, and the
 * video graph fails for good. Ignored here, the frames in between are
 * dropped instead, as they are while no surface is attached.
 */
@UnstableApi
internal class KnownOutputSizeVideoRenderer(
    builder: Builder,
) : MediaCodecVideoRenderer(builder) {

    override fun handleMessage(messageType: Int, message: Any?) {
        if (messageType == Renderer.MSG_SET_VIDEO_OUTPUT_RESOLUTION &&
            (message as? Size)?.let { it.width <= 0 || it.height <= 0 } == true
        ) {
            return
        }
        super.handleMessage(messageType, message)
    }
}
