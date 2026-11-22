package com.divinevideo.divine_video_player

import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.LoadControl

/**
 * Buffering policy applied to a [DivineVideoPlayerInstance]'s ExoPlayer.
 *
 * Mirrors the Dart `VideoBufferProfile` enum sent over the platform channel.
 */
internal enum class BufferProfile {
    /** Short-form feed: bounded buffers to protect memory on low-RAM devices. */
    FEED,

    /** Editing/preview: platform-default (unbounded) buffering. */
    FULL;

    companion object {
        /** Maps the Dart wire value; anything unknown falls back to [FULL]. */
        fun fromWireValue(value: String?): BufferProfile =
            if (value == "feed") FEED else FULL
    }
}

/**
 * Tightly bounded [LoadControl] for the short-form video feed.
 *
 * Divine clips are at most ~6.3 s and the feed keeps up to three players
 * (prev/current/next) live at once. ExoPlayer's default load control buffers
 * up to 50 s ahead with an unbounded byte target, so several concurrent feed
 * players can exhaust a small Java heap and crash with OutOfMemoryError from
 * inside ExoPlayer's loader (issue #3419). These bounds cap each player's
 * read-ahead; a whole clip fits well within [TARGET_BUFFER_BYTES].
 */
@UnstableApi
internal object FeedLoadControl {
    const val MIN_BUFFER_MS = 2_000
    const val MAX_BUFFER_MS = 10_000
    const val BUFFER_FOR_PLAYBACK_MS = 1_000
    const val BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS = 2_000
    const val TARGET_BUFFER_BYTES = 8 * 1024 * 1024

    fun build(): LoadControl =
        DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                MIN_BUFFER_MS,
                MAX_BUFFER_MS,
                BUFFER_FOR_PLAYBACK_MS,
                BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS,
            )
            // Enforce the byte ceiling as a hard memory cap rather than letting
            // the time thresholds buffer past it.
            .setTargetBufferBytes(TARGET_BUFFER_BYTES)
            .setPrioritizeTimeOverSizeThresholds(false)
            .build()
}
