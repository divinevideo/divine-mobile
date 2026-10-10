package com.divinevideo.divine_video_player

import android.content.Context
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink

/**
 * Builds an overlay track's audio path with [processor] in it, so the track
 * plays through its equalizer.
 */
@UnstableApi
internal class TrackEqualizerRenderersFactory(
    context: Context,
    private val processor: TrackEqualizerAudioProcessor,
) : DefaultRenderersFactory(context) {

    override fun buildAudioSink(
        context: Context,
        enableFloatOutput: Boolean,
        enableAudioTrackPlaybackParams: Boolean,
    ): AudioSink =
        // Float output routes around the user processor chain entirely.
        DefaultAudioSink.Builder(context)
            .setEnableFloatOutput(false)
            .setEnableAudioOutputPlaybackParameters(enableAudioTrackPlaybackParams)
            .setAudioProcessors(arrayOf(processor))
            .build()
}
