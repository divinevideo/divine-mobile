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

/**
 * How an overlay track's volume changes over the video timeline: the volume
 * curve `pro_video_editor` bakes into an exported track, linear between its
 * points, so the preview dips where the export does.
 *
 * @property timesMs When each point sits on the video timeline, sorted.
 * @property volumes The volume of each point, from 0 to 1.
 */
internal class AudioOverlayVolumeCurve(
    private val timesMs: DoubleArray,
    private val volumes: DoubleArray,
) {
    /** The volume at [videoMs] on the video timeline. */
    fun volumeAt(videoMs: Double): Double {
        if (videoMs <= timesMs.first()) return volumes.first()
        if (videoMs >= timesMs.last()) return volumes.last()
        var low = 0
        var high = timesMs.size - 1
        while (high - low > 1) {
            val middle = (low + high) ushr 1
            if (timesMs[middle] <= videoMs) low = middle else high = middle
        }
        val span = timesMs[high] - timesMs[low]
        if (span <= 0.0) return volumes[high]
        return volumes[low] + (volumes[high] - volumes[low]) * (videoMs - timesMs[low]) / span
    }

    companion object {
        /**
         * Reads the curve from a track map: interleaved
         * `[time in ms, volume, …]`, or null when the track has none.
         */
        fun fromMap(map: Map<String, Any?>): AudioOverlayVolumeCurve? {
            val raw = when (val value = map["volumeCurve"]) {
                is DoubleArray -> value
                is List<*> -> DoubleArray(value.size) { (value[it] as? Number)?.toDouble() ?: 0.0 }
                else -> return null
            }
            val count = raw.size / 2
            if (count == 0) return null
            return AudioOverlayVolumeCurve(
                timesMs = DoubleArray(count) { raw[it * 2] },
                volumes = DoubleArray(count) { raw[it * 2 + 1].coerceIn(0.0, 1.0) },
            )
        }
    }
}
