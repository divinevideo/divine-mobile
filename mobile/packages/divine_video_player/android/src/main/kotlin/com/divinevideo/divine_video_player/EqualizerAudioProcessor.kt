package com.divinevideo.divine_video_player

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.BaseAudioProcessor
import androidx.media3.common.util.UnstableApi
import java.nio.ByteBuffer

/**
 * Applies an [AudioEqualizer] to a player's 16-bit PCM in its audio sink, ahead
 * of the player's volume, the place `pro_video_editor` applies it in an
 * export.
 *
 * Which equalizer applies is read for every buffer from [currentEqualizer], so
 * a change made while the audio plays — a slider being dragged — is heard as
 * soon as the sink's next buffer: the filters keep their history and only
 * their coefficients move. A boost is limited at the export's ceiling; see
 * [PeakLimiter].
 *
 * The processor stays active with nothing to equalize and then copies its
 * input through: the sink fixes which processors run when a stream starts,
 * so one that switched itself off could not be switched back on by a slider.
 */
@UnstableApi
internal abstract class EqualizerAudioProcessor : BaseAudioProcessor() {

    private var filters: BandEqualizer? = null
    private var limiter: PeakLimiter? = null

    /** The equalizer [filters] are tuned to, null while they are flat. */
    private var tuned: AudioEqualizer? = null

    /** The samples a buffer is filtered in, kept so a buffer allocates nothing. */
    private var samples = FloatArray(0)

    /** The equalizer for the audio being processed now; null for none. */
    protected abstract fun currentEqualizer(): AudioEqualizer?

    override fun onConfigure(
        inputAudioFormat: AudioProcessor.AudioFormat,
    ): AudioProcessor.AudioFormat {
        // Everything upstream is converted to 16-bit PCM before reaching the
        // user processors; anything else is left alone rather than misread.
        if (inputAudioFormat.encoding != C.ENCODING_PCM_16BIT) {
            return AudioProcessor.AudioFormat.NOT_SET
        }
        return inputAudioFormat
    }

    override fun onFlush(streamMetadata: AudioProcessor.StreamMetadata) {
        val format = inputAudioFormat
        filters = if (format.sampleRate > 0) {
            BandEqualizer(format.sampleRate, format.channelCount)
        } else {
            null
        }
        limiter = if (format.sampleRate > 0) PeakLimiter(format.sampleRate) else null
        tuned = null
    }

    override fun onReset() {
        filters = null
        limiter = null
        tuned = null
        samples = FloatArray(0)
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        val remaining = inputBuffer.remaining()
        if (remaining == 0) return
        val equalizer = currentEqualizer()?.takeUnless { it.isFlat }
        val filters = filters
        if (equalizer != tuned) {
            filters?.retune(equalizer)
            if (equalizer?.boosts != tuned?.boosts) limiter?.reset()
            tuned = equalizer
        }
        val outputBuffer = replaceOutputBuffer(remaining)
        if (equalizer == null || filters == null) {
            outputBuffer.put(inputBuffer)
            outputBuffer.flip()
            return
        }
        val count = remaining / 2
        if (samples.size < count) samples = FloatArray(count)
        val samples = samples
        for (i in 0 until count) samples[i] = EqualizerPcm.toFloat(inputBuffer.short)
        filters.process(samples, count)
        if (equalizer.boosts) limiter?.process(samples, inputAudioFormat.channelCount, count)
        for (i in 0 until count) outputBuffer.putShort(EqualizerPcm.toShort(samples[i]))
        outputBuffer.flip()
    }
}

/** Equalizes an overlay track's player, whose one stream is the track. */
@UnstableApi
internal class TrackEqualizerAudioProcessor : EqualizerAudioProcessor() {
    /** Set from the main thread, read on the playback thread. */
    @Volatile
    var equalizer: AudioEqualizer? = null

    override fun currentEqualizer(): AudioEqualizer? = equalizer
}

/**
 * Equalizes the clip timeline of a player, each clip with its own equalizer.
 *
 * Every clip is a stream of its own, and the sink drains and flushes its
 * processors where one stream ends and the next begins. [ClipEqualizerAudioRenderer]
 * tells this processor which clip the next stream plays, before that flush,
 * and the flush switches to it — at the sample where the clip starts, which a
 * switch from the main thread would miss by the whole output buffer.
 */
@UnstableApi
internal class ClipEqualizerAudioProcessor : EqualizerAudioProcessor() {

    /**
     * The equalizer of every loaded clip, by index; null entries play
     * unchanged. Set from the main thread, read on the playback thread.
     */
    @Volatile
    var equalizers: List<AudioEqualizer?> = emptyList()

    /**
     * The clip the next stream, or the one resumed by a seek, belongs to;
     * -1 while unknown. Written and read on the playback thread.
     */
    var nextClipIndex: Int = -1

    /** The clip whose audio is being processed, -1 while unknown. */
    var clipIndex: Int = -1
        private set

    override fun currentEqualizer(): AudioEqualizer? = equalizers.getOrNull(clipIndex)

    override fun onFlush(streamMetadata: AudioProcessor.StreamMetadata) {
        super.onFlush(streamMetadata)
        clipIndex = nextClipIndex
    }

    override fun onReset() {
        super.onReset()
        clipIndex = -1
        nextClipIndex = -1
    }
}
