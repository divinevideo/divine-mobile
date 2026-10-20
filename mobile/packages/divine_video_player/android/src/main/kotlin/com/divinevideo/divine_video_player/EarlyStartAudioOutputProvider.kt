package com.divinevideo.divine_video_player

import android.content.Context
import android.media.AudioTrack
import android.os.Build
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.audio.AudioOutput
import androidx.media3.exoplayer.audio.AudioOutputProvider
import androidx.media3.exoplayer.audio.AudioTrackAudioOutput
import androidx.media3.exoplayer.audio.AudioTrackAudioOutputProvider
import androidx.media3.exoplayer.audio.ForwardingAudioOutputProvider

/**
 * Lets every [AudioTrack] the player opens start playing with whatever audio
 * it holds, instead of only once its buffer is full.
 *
 * An `AudioTrack` does not stream after `play()` until the audio written to it
 * reaches its start threshold, and that threshold defaults to the whole
 * buffer — 750 ms on a Bluetooth A2DP route. When less audio than that is left
 * before the next clip, the player deadlocks: the audio renderer has read its
 * clip to the end and gets the next clip's audio only once the video renderer
 * has read to the end too, while video waits for the audio clock, which never
 * moves because the track never starts. ExoPlayer sits in READY with a frozen
 * position until media3's stuck-player check fails playback after 10 s.
 *
 * That is what froze the editor preview right after a transition seam, where
 * the sped-up clip body that follows is only a few hundred milliseconds long,
 * and any start or seek closer than the buffer to a clip boundary. ExoPlayer
 * writes as much as it has before it starts the track, so the threshold only
 * changes anything when the buffer cannot be filled — and there the full one
 * meant never starting at all.
 *
 * The threshold can only be set from API 31; earlier devices keep the
 * full-buffer start.
 */
@UnstableApi
internal class EarlyStartAudioOutputProvider(
    delegate: AudioOutputProvider,
    private val sdkInt: Int = Build.VERSION.SDK_INT,
) : ForwardingAudioOutputProvider(delegate) {

    constructor(context: Context) : this(AudioTrackAudioOutputProvider.Builder(context).build())

    override fun getAudioOutput(config: AudioOutputProvider.OutputConfig): AudioOutput {
        val output = super.getAudioOutput(config)
        if (sdkInt >= Build.VERSION_CODES.S &&
            !config.isOffload &&
            !config.isTunneling &&
            output is AudioTrackAudioOutput
        ) {
            startWithFirstFrame(output.audioTrack)
        }
        return output
    }

    private fun startWithFirstFrame(audioTrack: AudioTrack) {
        // A track the platform refuses to reconfigure keeps the full-buffer
        // start, which is no worse than not asking.
        val failure = try {
            audioTrack.setStartThresholdInFrames(START_THRESHOLD_FRAMES)
            null
        } catch (e: IllegalStateException) {
            e
        } catch (e: IllegalArgumentException) {
            e
        }
        if (failure != null) {
            DivineVideoPlayerLog.warning(
                "Could not lower the audio start threshold: $failure",
                name = "DivineVideoPlayer.Audio",
            )
        }
    }

    internal companion object {
        /** The smallest threshold the platform accepts: start on the first frame. */
        const val START_THRESHOLD_FRAMES = 1
    }
}
