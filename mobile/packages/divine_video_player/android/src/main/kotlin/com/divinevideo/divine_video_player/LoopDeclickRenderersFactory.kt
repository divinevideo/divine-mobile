package com.divinevideo.divine_video_player

import android.content.Context
import android.os.Handler
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.Renderer
import androidx.media3.exoplayer.audio.AudioRendererEventListener
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink
import androidx.media3.exoplayer.audio.MediaCodecAudioRenderer
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector

/**
 * Builds the audio path with the loop declick fade in it (#6468), and the
 * per-clip equalizer when [setClipEqualizer] asked for one.
 *
 * The processors have to be injected at construction because
 * `DefaultAudioSink`'s processor chain is fixed once the sink is built, and
 * the sink is wrapped so the declick processor is told where a loop restarts.
 */
@UnstableApi
internal class LoopDeclickRenderersFactory(
    context: Context,
    private val declickProcessor: LoopDeclickAudioProcessor,
) : DefaultRenderersFactory(context) {

    private var clipEqualizer: ClipEqualizerAudioProcessor? = null

    /**
     * Equalizes each clip with [processor], ahead of the declick fade so a
     * filter's ringing cannot outlast the fade at a loop join.
     */
    fun setClipEqualizer(processor: ClipEqualizerAudioProcessor): LoopDeclickRenderersFactory {
        clipEqualizer = processor
        return this
    }

    override fun buildAudioSink(
        context: Context,
        enableFloatOutput: Boolean,
        enableAudioTrackPlaybackParams: Boolean,
    ): AudioSink {
        // Float output routes around the user processor chain entirely, so the
        // fade would silently do nothing. Divine decodes AAC to 16-bit PCM, and
        // float output is off by default; keep it off explicitly rather than
        // let a future default flip disable the fade without a trace.
        val sink = DefaultAudioSink.Builder(context)
            .setEnableFloatOutput(false)
            .setEnableAudioOutputPlaybackParameters(enableAudioTrackPlaybackParams)
            .setAudioProcessors(listOfNotNull(clipEqualizer, declickProcessor).toTypedArray())
            .build()
        return LoopDeclickAudioSink(sink, declickProcessor)
    }

    override fun buildAudioRenderers(
        context: Context,
        extensionRendererMode: Int,
        mediaCodecSelector: MediaCodecSelector,
        enableDecoderFallback: Boolean,
        audioSink: AudioSink,
        eventHandler: Handler,
        eventListener: AudioRendererEventListener,
        out: ArrayList<Renderer>,
    ) {
        val processor = clipEqualizer
        val start = out.size
        super.buildAudioRenderers(
            context,
            extensionRendererMode,
            mediaCodecSelector,
            enableDecoderFallback,
            audioSink,
            eventHandler,
            eventListener,
            out,
        )
        processor ?: return
        // Only the renderer can name the clip a stream belongs to; see
        // [ClipEqualizerAudioRenderer]. Any extension renderer stays as built.
        val index = (start until out.size).firstOrNull {
            out[it].javaClass == MediaCodecAudioRenderer::class.java
        } ?: return
        out[index] = ClipEqualizerAudioRenderer(
            context,
            codecAdapterFactory,
            mediaCodecSelector,
            enableDecoderFallback,
            eventHandler,
            eventListener,
            audioSink,
            processor,
        )
    }
}
