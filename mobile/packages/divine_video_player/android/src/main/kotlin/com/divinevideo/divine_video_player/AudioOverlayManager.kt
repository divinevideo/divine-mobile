package com.divinevideo.divine_video_player

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer

/**
 * Manages audio overlay tracks that play alongside the main video.
 *
 * Each overlay is an independent [ExoPlayer] instance positioned and
 * synced to the main video timeline. Drift correction keeps audio
 * aligned within [DRIFT_THRESHOLD_MS].
 *
 * A track with an [AudioOverlayFade] has its volume stepped every
 * [FADE_TICK_MS] from the overlay's own position while it plays. The 200 ms
 * position sync is far too coarse for a ramp, and ExoPlayer has no volume
 * ramp of its own; at this rate each step is too small to hear as one.
 *
 * Each track plays through its own [TrackEqualizerAudioProcessor], ahead of
 * its volume and fade, as the export applies it.
 */
@UnstableApi
internal class AudioOverlayManager(
    private val context: Context,
    private val handler: Handler = Handler(Looper.getMainLooper()),
) {

    private val overlays = mutableListOf<AudioOverlayEntry>()

    private var fadeTickerScheduled = false

    private val fadeTicker = object : Runnable {
        override fun run() {
            fadeTickerScheduled = false
            var fading = false
            for (entry in overlays) {
                if (!entry.isFading) continue
                applyFadeGain(entry, entry.player.currentPosition)
                fading = true
            }
            if (fading) scheduleFadeTicker()
        }
    }

    /** Replaces all audio overlays with the given track definitions. */
    fun setTracks(
        tracksRaw: List<Map<String, Any?>>,
        currentPlaybackSpeed: Float,
    ) {
        releaseAll()

        for (map in tracksRaw) {
            val uri = map["uri"] as? String ?: continue
            val vol = (map["volume"] as? Number)?.toFloat() ?: 1.0f
            val videoStartMs = (map["videoStartMs"] as? Number)?.toLong() ?: 0L
            val videoEndMs = (map["videoEndMs"] as? Number)?.toLong()
            val trackStartMs = (map["trackStartMs"] as? Number)?.toLong() ?: 0L
            val trackEndMs = (map["trackEndMs"] as? Number)?.toLong()

            val equalizer = TrackEqualizerAudioProcessor().apply {
                this.equalizer = AudioEqualizer.fromMap(map["equalizer"] as? Map<*, *>)
            }
            val overlay = ExoPlayer.Builder(
                context,
                TrackEqualizerRenderersFactory(context, equalizer),
            ).build()
            overlay.setMediaItem(MediaItem.fromUri(uri))
            overlay.prepare()
            overlay.setPlaybackSpeed(currentPlaybackSpeed)

            val entry = AudioOverlayEntry(
                player = overlay,
                videoStartMs = videoStartMs,
                videoEndMs = videoEndMs,
                trackStartMs = trackStartMs,
                trackEndMs = trackEndMs,
                baseVolume = vol,
                fade = AudioOverlayFade.fromMap(map),
                equalizer = equalizer,
            )
            // media3 generates the session off the main thread, so it can
            // arrive after the first volume was applied.
            overlay.addListener(object : Player.Listener {
                override fun onAudioSessionIdChanged(audioSessionId: Int) {
                    entry.boost.attach(audioSessionId)
                }
            })
            applyFadeGain(entry, trackStartMs)
            overlays.add(entry)
        }
    }

    /** Sets volume for the overlay at [index]. */
    fun setTrackVolume(index: Int, volume: Float) {
        if (index in overlays.indices) {
            val entry = overlays[index]
            entry.baseVolume = volume
            applyFadeGain(entry, entry.player.currentPosition)
        }
    }

    /**
     * Sets the equalizer of the overlay at [index]; null plays it unchanged.
     * Heard from the track's next buffer on, without reloading it.
     */
    fun setTrackEqualizer(index: Int, equalizer: AudioEqualizer?) {
        overlays.getOrNull(index)?.equalizer?.equalizer = equalizer
    }

    /** Updates playback speed on all overlay players. */
    fun setPlaybackSpeed(speed: Float) {
        for (entry in overlays) {
            entry.player.setPlaybackSpeed(speed)
        }
    }

    /** Resumes playback of currently active overlays. */
    fun resumeActive() {
        for (entry in overlays) {
            if (entry.isActive) entry.player.play()
        }
        ensureFadeTicker()
    }

    /** Pauses all overlay players without changing active state. */
    fun pauseAll() {
        for (entry in overlays) {
            entry.player.pause()
        }
    }

    /** Pauses all overlay players and marks them inactive. */
    fun pauseAndDeactivateAll() {
        for (entry in overlays) {
            entry.player.pause()
            entry.isActive = false
        }
    }

    /** Stops all overlay players and marks them inactive. */
    fun stopAndDeactivateAll() {
        for (entry in overlays) {
            entry.player.stop()
            entry.isActive = false
        }
    }

    /**
     * Syncs every overlay track to the current global video position.
     *
     * Starts, pauses, or drift-corrects each overlay based on whether
     * the video position falls within that track's active range.
     */
    fun update(globalPositionMs: Long, isPlaying: Boolean) {
        for (entry in overlays) {
            val inRange = globalPositionMs >= entry.videoStartMs &&
                (entry.videoEndMs == null || globalPositionMs < entry.videoEndMs)

            if (inRange && isPlaying) {
                val expectedAudioMs = entry.trackStartMs +
                    (globalPositionMs - entry.videoStartMs)

                // Clamp to trackEnd if set.
                if (entry.trackEndMs != null && expectedAudioMs >= entry.trackEndMs) {
                    if (entry.isActive) {
                        entry.player.pause()
                        entry.isActive = false
                    }
                    continue
                }

                if (!entry.isActive) {
                    // Set the level before the first sample plays, so a
                    // start inside a fade in does not blip at full volume.
                    applyFadeGain(entry, expectedAudioMs)
                    entry.player.seekTo(expectedAudioMs)
                    entry.player.play()
                    entry.isActive = true
                } else {
                    // Correct drift.
                    val actualMs = entry.player.currentPosition
                    val drift = kotlin.math.abs(expectedAudioMs - actualMs)
                    if (drift > DRIFT_THRESHOLD_MS) {
                        applyFadeGain(entry, expectedAudioMs)
                        entry.player.seekTo(expectedAudioMs)
                    }
                }
            } else {
                if (entry.isActive) {
                    entry.player.pause()
                    entry.isActive = false
                }
            }
        }
        ensureFadeTicker()
    }

    /** Releases all overlay players and clears the list. */
    fun releaseAll() {
        handler.removeCallbacks(fadeTicker)
        fadeTickerScheduled = false
        for (entry in overlays) {
            entry.boost.release()
            entry.player.stop()
            entry.player.release()
        }
        overlays.clear()
    }

    /**
     * Sets [entry]'s volume to its base level scaled by its fade at
     * [audioPositionMs], a position in the audio file.
     *
     * The fade steps only the player's own volume, the base level up to
     * 100 %; the part above it is a constant [AudioOverlayEntry.boost], so a
     * boosted fade still ramps linearly.
     */
    private fun applyFadeGain(entry: AudioOverlayEntry, audioPositionMs: Long) {
        val gain = entry.fade.gainAt(
            elapsedMs = audioPositionMs - entry.trackStartMs,
            audibleMs = audibleMs(entry),
        )
        val volume = AudioSessionBoost.attenuationOf(entry.baseVolume) * gain
        if (entry.player.volume != volume) entry.player.volume = volume
        entry.boost.attach(entry.player.audioSessionId)
        entry.boost.setGain(AudioSessionBoost.boostOf(entry.baseVolume))
    }

    /**
     * How long [entry] sounds, which is where its fade out ends: the end of its
     * slot on the video timeline, the end of its trimmed audio, or the end of
     * the file, whichever comes first. Null while none of them is known.
     */
    private fun audibleMs(entry: AudioOverlayEntry): Long? {
        val fileDurationMs = entry.player.duration
        return listOfNotNull(
            entry.videoEndMs?.let { it - entry.videoStartMs },
            entry.trackEndMs?.let { it - entry.trackStartMs },
            fileDurationMs.takeIf { it != C.TIME_UNSET }?.let { it - entry.trackStartMs },
        ).minOrNull()
    }

    private fun ensureFadeTicker() {
        if (overlays.any { it.isFading }) scheduleFadeTicker()
    }

    private fun scheduleFadeTicker() {
        if (fadeTickerScheduled) return
        fadeTickerScheduled = true
        handler.postDelayed(fadeTicker, FADE_TICK_MS)
    }

    companion object {
        private const val DRIFT_THRESHOLD_MS = 250L

        /** How often a fading track's volume is stepped. */
        private const val FADE_TICK_MS = 20L
    }
}

/** Holds one audio overlay player and its scheduling metadata. */
@UnstableApi
internal class AudioOverlayEntry(
    val player: ExoPlayer,
    val videoStartMs: Long,
    val videoEndMs: Long?,
    val trackStartMs: Long,
    val trackEndMs: Long?,
    /** The track's volume before its fade is applied, above 1.0 when boosted. */
    var baseVolume: Float = 1.0f,
    val fade: AudioOverlayFade = AudioOverlayFade(fadeInMs = 0, fadeOutMs = 0),
    var isActive: Boolean = false,
    /** Carries [baseVolume] above 100 %; see [AudioSessionBoost]. */
    val boost: AudioSessionBoost = AudioSessionBoost(),
    /** The track's equalizer, in its player's audio sink. */
    val equalizer: TrackEqualizerAudioProcessor? = null,
) {
    /** Whether this track is sounding with a fade that needs stepping. */
    val isFading: Boolean
        get() = isActive && player.playWhenReady && !fade.isNone
}
