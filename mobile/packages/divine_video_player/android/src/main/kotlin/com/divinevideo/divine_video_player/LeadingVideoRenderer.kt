package com.divinevideo.divine_video_player

import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ForwardingRenderer
import androidx.media3.exoplayer.Renderer

/**
 * Wraps a video [Renderer] so it releases its frames [leadUs] ahead of the
 * playback clock.
 *
 * For an output that reaches the screen later than the app's other video:
 * under Impeller the legacy SurfaceTexture shows a frame one or two video
 * frames after a SurfaceProducer does, so a legacy player beside a producer
 * player ran that far behind it. Only the release time moves. A paused or
 * freshly seeked renderer still shows the frame at its position, because the
 * first frame after a reset is released whatever the clock says and the next
 * ones wait for playback to start.
 */
@UnstableApi
internal class LeadingVideoRenderer(
    renderer: Renderer,
    private val leadUs: () -> Long,
) : ForwardingRenderer(renderer) {

    override fun render(positionUs: Long, elapsedRealtimeUs: Long) {
        super.render(positionUs + leadUs(), elapsedRealtimeUs)
    }

    override fun getDurationToProgressUs(positionUs: Long, elapsedRealtimeUs: Long): Long =
        super.getDurationToProgressUs(positionUs + leadUs(), elapsedRealtimeUs)
}
