package com.divinevideo.divine_video_player

/**
 * The clip of each of the [capacity] streams an audio renderer used last, by
 * the offset it gives the stream's samples.
 *
 * Ordered by use rather than by when an offset was first seen: after a seek
 * outside the loaded queue, media3 hands out the offsets it started with
 * again, so an offset seen long ago can be the output stream once more and
 * has to outlive the streams read ahead of it.
 */
internal class RecentStreamClips(private val capacity: Int) {

    private val clips = object : LinkedHashMap<Long, Int>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<Long, Int>?) =
            size > capacity
    }

    /** Remembers that the stream at [offsetUs] plays the clip at [clipIndex]. */
    operator fun set(offsetUs: Long, clipIndex: Int) {
        clips[offsetUs] = clipIndex
    }

    /** The clip of the stream at [offsetUs], or -1 when it is not remembered. */
    operator fun get(offsetUs: Long): Int = clips[offsetUs] ?: -1
}
