package com.divinevideo.divine_video_player

import android.media.audiofx.DynamicsProcessing
import androidx.media3.common.C
import kotlin.math.log10

/**
 * Lifts an audio session above 100 %, the most `ExoPlayer.setVolume` and
 * `AudioTrack.setVolume` allow.
 *
 * Callers split a volume with [attenuationOf] and [boostOf]: the part up to 1
 * stays on the player, where fades and crossfades step it, and the part above
 * 1 is a constant gain here.
 *
 * The gain is a session effect, which AudioFlinger applies where it mixes the
 * session — the point a volume change takes effect too. A clip change
 * therefore moves volume and boost together, where a gain in the decode chain
 * would trail it by the whole output buffer.
 *
 * The gain is linear and then limited at [LIMITER_THRESHOLD_DB], the ceiling
 * `pro_video_editor` limits an amplified export at, so the preview plays the
 * level the posted video will have rather than one the file cannot hold. A
 * `LoudnessEnhancer` was measured first and compressed instead: a mastered
 * song at 300 % came out only 5.8 dB louder.
 *
 * No effect exists until a gain above 1 is asked for, so a player that never
 * boosts — every feed player — never carries one. Once it exists it stays on,
 * at 0 dB when nothing is boosted, so moving between a boosted and an
 * unboosted clip never switches the effect's processing in or out mid-play.
 */
internal class AudioSessionBoost(
    private val createEffect: (sessionId: Int) -> GainEffect = ::DynamicsProcessingGain,
) {

    /** The effect behind the boost: a gain on one audio session. */
    internal interface GainEffect {
        fun setGainDb(gainDb: Float)
        fun setEnabled(enabled: Boolean)
        fun release()
    }

    private var sessionId = C.AUDIO_SESSION_ID_UNSET
    private var gain = 1f
    private var effect: GainEffect? = null

    /** Moves the boost onto [sessionId], the session the audio plays in. */
    fun attach(sessionId: Int) {
        if (sessionId == this.sessionId) return
        releaseEffect()
        this.sessionId = sessionId
        apply()
    }

    /** Sets the gain; 1 or less plays the session unchanged. */
    fun setGain(gain: Float) {
        if (gain == this.gain) return
        this.gain = gain
        apply()
    }

    fun release() {
        releaseEffect()
        sessionId = C.AUDIO_SESSION_ID_UNSET
    }

    private fun apply() {
        // Session 0 is the device's output mix: an effect there would lift
        // every app's sound. media3 generates a player's session off the main
        // thread, so a fresh player can still report it.
        if (sessionId == C.AUDIO_SESSION_ID_UNSET) return
        val target = effect ?: if (gain > 1f) createOrNull() else null
        target ?: return
        runCatching {
            target.setGainDb(decibelsOf(boostOf(gain)))
            target.setEnabled(true)
        }.onFailure {
            DivineVideoPlayerLog.warning(
                "Volume boost on session $sessionId failed: $it",
                name = LOG_NAME,
            )
        }
    }

    private fun createOrNull(): GainEffect? =
        runCatching { createEffect(sessionId) }
            .onFailure {
                // An effect the device refuses leaves the audio at 100 %
                // rather than failing playback.
                DivineVideoPlayerLog.warning(
                    "No volume boost for session $sessionId: $it",
                    name = LOG_NAME,
                )
            }
            .getOrNull()
            ?.also { effect = it }

    private fun releaseEffect() {
        effect?.let { runCatching { it.release() } }
        effect = null
    }

    /** A linear input gain into a limiter, every other stage off. */
    private class DynamicsProcessingGain(sessionId: Int) : GainEffect {
        private val processing = DynamicsProcessing(
            0,
            sessionId,
            DynamicsProcessing.Config.Builder(
                DynamicsProcessing.VARIANT_FAVOR_FREQUENCY_RESOLUTION,
                // Adapted to the session's real channel count on creation.
                2,
                false,
                0,
                false,
                0,
                false,
                0,
                true,
            ).build(),
        )

        /**
         * Sets the input gain, with the limiter on only while it amplifies:
         * the export leaves unamplified audio unlimited, so an effect kept on
         * at 0 dB must not limit it either.
         */
        override fun setGainDb(gainDb: Float) {
            processing.setInputGainAllChannelsTo(gainDb)
            processing.setLimiterAllChannelsTo(
                DynamicsProcessing.Limiter(
                    true,
                    gainDb > 0f,
                    // One link group: every channel shares the gain.
                    0,
                    LIMITER_ATTACK_MS,
                    LIMITER_RELEASE_MS,
                    LIMITER_RATIO,
                    LIMITER_THRESHOLD_DB,
                    0f,
                ),
            )
        }

        override fun setEnabled(enabled: Boolean) {
            processing.setEnabled(enabled)
        }

        override fun release() = processing.release()
    }

    companion object {
        private const val LOG_NAME = "DivineVideoPlayer.VolumeBoost"

        /** The export limiter's ceiling, -1 dBFS; see `PeakLimiter` there. */
        private const val LIMITER_THRESHOLD_DB = -1f

        /** The export limiter's release. */
        private const val LIMITER_RELEASE_MS = 50f

        /** As fast as the effect allows: the export limiter has no attack. */
        private const val LIMITER_ATTACK_MS = 1f

        /** Close to a brickwall, like the export limiter. */
        private const val LIMITER_RATIO = 20f

        /** The part of [volume] a player's own volume can carry. */
        fun attenuationOf(volume: Float): Float = volume.coerceIn(0f, 1f)

        /** The part of [volume] above 1, as a gain; 1 when there is none. */
        fun boostOf(volume: Float): Float = volume.coerceAtLeast(1f)

        /** [gain] in decibels. */
        fun decibelsOf(gain: Float): Float = 20 * log10(gain)
    }
}
