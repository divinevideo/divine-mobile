package com.divinevideo.divine_video_player

import android.content.Context
import android.os.Handler
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.Timeline
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.audio.AudioRendererEventListener
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.MediaCodecAudioRenderer
import androidx.media3.exoplayer.mediacodec.MediaCodecAdapter
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.source.MediaSource

/**
 * The player's audio renderer, telling [processor] which clip of the timeline
 * each stream it outputs belongs to.
 *
 * Counting streams from a seek would go wrong at the first clip without audio:
 * the renderer is switched off for it, and no stream change is reported. The
 * renderer instead names every stream it reads by its media period, which the
 * playlist timeline maps to the clip's index, and keys it by the stream offset
 * it gives the stream's samples. When output reaches a stream — at a clip
 * change, or after a seek — that offset is handed back, and the processor
 * learns the clip before the sink flushes it for the new stream.
 *
 * Everything here runs on the playback thread.
 */
@UnstableApi
internal class ClipEqualizerAudioRenderer(
    context: Context,
    codecAdapterFactory: MediaCodecAdapter.Factory,
    mediaCodecSelector: MediaCodecSelector,
    enableDecoderFallback: Boolean,
    eventHandler: Handler?,
    eventListener: AudioRendererEventListener?,
    audioSink: AudioSink,
    private val processor: ClipEqualizerAudioProcessor,
) : MediaCodecAudioRenderer(
    context,
    codecAdapterFactory,
    mediaCodecSelector,
    enableDecoderFallback,
    eventHandler,
    eventListener,
    audioSink,
) {
    /** The clip of every recent stream, by the offset of its samples. */
    private val clipsByStreamOffset = RecentStreamClips(MAX_REMEMBERED_STREAMS)

    private val period = Timeline.Period()

    override fun onStreamChanged(
        formats: Array<out Format>,
        startPositionUs: Long,
        offsetUs: Long,
        mediaPeriodId: MediaSource.MediaPeriodId,
    ) {
        clipsByStreamOffset[offsetUs] = clipIndexOf(mediaPeriodId)
        super.onStreamChanged(formats, startPositionUs, offsetUs, mediaPeriodId)
    }

    override fun onOutputStreamOffsetUsChanged(outputStreamOffsetUs: Long) {
        processor.nextClipIndex = clipsByStreamOffset[outputStreamOffsetUs]
        super.onOutputStreamOffsetUsChanged(outputStreamOffsetUs)
    }

    override fun onPositionReset(
        positionUs: Long,
        joining: Boolean,
        sampleStreamIsResetToKeyFrame: Boolean,
    ) {
        super.onPositionReset(positionUs, joining, sampleStreamIsResetToKeyFrame)
        // A seek onto a stream that was already queued makes it the output
        // stream without reporting a new offset. The sink flushes again at
        // the first buffer after the seek, which picks this up.
        processor.nextClipIndex = clipsByStreamOffset[outputStreamOffsetUs]
    }

    /** The clip [mediaPeriodId] plays, or -1 when the timeline cannot tell. */
    private fun clipIndexOf(mediaPeriodId: MediaSource.MediaPeriodId): Int {
        val timeline = timeline
        if (timeline.isEmpty) return -1
        val periodIndex = timeline.getIndexOfPeriod(mediaPeriodId.periodUid)
        if (periodIndex == C.INDEX_UNSET) return -1
        return timeline.getPeriod(periodIndex, period).windowIndex
    }

    private companion object {
        /** More than a looping timeline has streams queued at once. */
        const val MAX_REMEMBERED_STREAMS = 32
    }
}
