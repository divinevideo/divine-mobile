package com.divinevideo.divine_video_player

/**
 * The fade in and fade out of an overlay audio track.
 *
 * Mirrors the fade `pro_video_editor` bakes into an exported custom audio
 * track: linear ramps from and to silence at the edges of the audible part of
 * the track, the quieter ramp winning where they overlap. The editor preview
 * therefore plays the same envelope the export will contain.
 */
internal data class AudioOverlayFade(
    val fadeInMs: Long,
    val fadeOutMs: Long,
) {
    /** Whether the track plays at a constant level. */
    val isNone: Boolean
        get() = fadeInMs <= 0L && fadeOutMs <= 0L

    /**
     * The gain [elapsedMs] into a track that sounds for [audibleMs].
     *
     * When [audibleMs] is unknown only the fade in applies; a fade out needs
     * an end to count back from.
     */
    fun gainAt(elapsedMs: Long, audibleMs: Long?): Float {
        val inGain = if (fadeInMs > 0L) elapsedMs.toDouble() / fadeInMs else 1.0
        val outGain = if (fadeOutMs > 0L && audibleMs != null) {
            (audibleMs - elapsedMs).toDouble() / fadeOutMs
        } else {
            1.0
        }
        return minOf(inGain, outGain, 1.0).coerceAtLeast(0.0).toFloat()
    }

    companion object {
        /** Reads the fade from a track map sent over the method channel. */
        fun fromMap(map: Map<String, Any?>): AudioOverlayFade = AudioOverlayFade(
            fadeInMs = (map["fadeInMs"] as? Number)?.toLong() ?: 0L,
            fadeOutMs = (map["fadeOutMs"] as? Number)?.toLong() ?: 0L,
        )
    }
}
