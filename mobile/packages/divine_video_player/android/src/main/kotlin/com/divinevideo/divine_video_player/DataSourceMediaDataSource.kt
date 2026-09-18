package com.divinevideo.divine_video_player

import android.media.MediaDataSource
import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSourceException
import androidx.media3.datasource.DataSpec

/**
 * Lets a [android.media.MediaExtractor] read through a media3 [DataSource].
 *
 * The extractor otherwise opens a remote clip with its own HTTP stack, which
 * knows nothing of ExoPlayer's disk cache: every looping feed clip was
 * downloaded once by the player and once more for its loop audio. Reading
 * through the player's own [DataSource.Factory] serves the bytes the player
 * has already fetched, and fetches only what it has not.
 *
 * The extractor does not read a file front to back. For every sample it
 * reads a 2 KB window from each of the `moov` box's sample tables, slid a
 * few bytes on from the last, and then the sample itself, so its reads walk
 * two or three regions of the file forward at once and overlap themselves
 * heavily. A [DataSource] can only be read forward, so a single one would be
 * reopened at every hop — a fresh range request each on a source that has
 * to go to the network. Instead a few sources stay open, one per region,
 * each keeping the bytes it last read: a read that falls inside what a
 * cursor holds is served from memory, one a short way past it moves that
 * cursor forward, and only a read no cursor can reach opens another, in
 * place of the one used longest ago. Each read is filled completely: the
 * framework's container parsers treat a short read as an I/O error, not as
 * "try again".
 *
 * The framework calls in from its own thread, hence the synchronization.
 */
@UnstableApi
internal class DataSourceMediaDataSource(
    private val factory: DataSource.Factory,
    private val uri: Uri,
) : MediaDataSource() {

    /**
     * An open [source] and the bytes it most recently read.
     *
     * [buffer] holds `[bufferStart, bufferStart + bufferLength)` of the
     * stream, and the next byte [source] returns is the one after it.
     */
    private class Cursor(val source: DataSource, var bufferStart: Long) {
        val buffer = ByteArray(BUFFER_BYTES)
        var bufferLength = 0
        var lastUsed = 0L
        val sourcePosition: Long get() = bufferStart + bufferLength

        /** Whether [position] can be reached without reopening. */
        fun reaches(position: Long): Boolean =
            position >= bufferStart && position <= sourcePosition + MAX_SKIP_BYTES

        /**
         * Makes [buffer] start at [position] and hold up to [wanted] bytes of
         * what follows; fewer only at the end of the stream.
         */
        fun fill(position: Long, wanted: Int) {
            if (position > sourcePosition) {
                // A hop forward: read through the gap and start afresh there.
                var gap = position - sourcePosition
                bufferStart = position
                bufferLength = 0
                while (gap > 0) {
                    val read = source.read(buffer, 0, minOf(gap, buffer.size.toLong()).toInt())
                    if (read == C.RESULT_END_OF_INPUT) return
                    gap -= read
                }
            } else if (position > bufferStart) {
                // Keep what is still wanted and drop what precedes it.
                val drop = (position - bufferStart).toInt()
                buffer.copyInto(buffer, 0, drop, bufferLength)
                bufferStart = position
                bufferLength -= drop
            }
            while (bufferLength < wanted) {
                val read = source.read(buffer, bufferLength, buffer.size - bufferLength)
                if (read == C.RESULT_END_OF_INPUT) return
                bufferLength += read
            }
        }
    }

    private val cursors = ArrayList<Cursor>(MAX_CURSORS)
    private var useCount = 0L

    /** Total length in bytes, or -1 until a source has reported it. */
    private var length = -1L

    @Synchronized
    override fun readAt(position: Long, buffer: ByteArray, offset: Int, size: Int): Int {
        if (size == 0) return 0
        if (length >= 0 && position >= length) return -1
        val cursor = cursors.firstOrNull { it.reaches(position) } ?: try {
            openCursor(position)
        } catch (e: DataSourceException) {
            // A read past the end of a source whose length was not known
            // yet: the end of the stream, not an error.
            if (e.reason == DataSourceException.POSITION_OUT_OF_RANGE) return -1
            throw e
        }
        cursor.lastUsed = ++useCount
        var total = 0
        while (total < size) {
            try {
                cursor.fill(position + total, minOf(size - total, BUFFER_BYTES))
            } catch (e: Throwable) {
                // A failed read leaves the source somewhere the cursor cannot
                // know, and a cursor whose arithmetic no longer matches its
                // source hands out the wrong bytes without anything noticing.
                retire(cursor)
                throw e
            }
            val available = minOf(size - total, cursor.bufferLength)
            if (available == 0) break
            cursor.buffer.copyInto(buffer, offset + total, 0, available)
            total += available
        }
        return if (total == 0) -1 else total
    }

    @Synchronized
    override fun getSize(): Long {
        if (length < 0 && cursors.isEmpty()) openCursor(0)
        return length
    }

    @Synchronized
    override fun close() {
        cursors.forEach { runCatching { it.source.close() } }
        cursors.clear()
    }

    /** Drops [cursor] and closes the source behind it. */
    private fun retire(cursor: Cursor) {
        cursors.remove(cursor)
        runCatching { cursor.source.close() }
    }

    /** Opens a source at [position], retiring the longest-unused cursor. */
    private fun openCursor(position: Long): Cursor {
        if (cursors.size >= MAX_CURSORS) {
            retire(cursors.minByOrNull { it.lastUsed }!!)
        }
        val opened = factory.createDataSource()
        val remaining = try {
            opened.open(DataSpec.Builder().setUri(uri).setPosition(position).build())
        } catch (e: Exception) {
            runCatching { opened.close() }
            throw e
        }
        if (remaining != C.LENGTH_UNSET.toLong()) length = position + remaining
        return Cursor(opened, position).also { cursors += it }
    }

    private companion object {
        /**
         * Regions read side by side: two or three sample tables and the
         * samples themselves, with one to spare.
         */
        const val MAX_CURSORS = 4

        /**
         * What each cursor keeps of its region. Two sample tables of a
         * six-second AAC track fit in it, so after the first fill they are
         * served from memory.
         */
        const val BUFFER_BYTES = 64 * 1024

        /**
         * Longest hop read through rather than reopened. Consecutive audio
         * samples in a feed clip sit a video frame apart — kilobytes; a hop
         * that lands further away is a different region and gets its own
         * cursor.
         */
        const val MAX_SKIP_BYTES = 64L * 1024
    }
}
