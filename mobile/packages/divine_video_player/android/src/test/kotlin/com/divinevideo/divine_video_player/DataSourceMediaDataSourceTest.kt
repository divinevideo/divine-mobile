package com.divinevideo.divine_video_player

import android.net.Uri
import androidx.media3.common.C
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSourceException
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.TransferListener
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.IOException

/**
 * Pins how [DataSourceMediaDataSource] drives a [DataSource] on behalf of a
 * `MediaExtractor`, whose reads are short, out of order, and treated as I/O
 * errors when they come back short.
 */
class DataSourceMediaDataSourceTest {

    /**
     * Hands out in-memory [DataSource]s over [bytes], each with its own
     * read position, that give at most [chunk] bytes per read; records every
     * open and close across all of them.
     */
    private class FakeSource(
        private val bytes: ByteArray,
        private val chunk: Int = Int.MAX_VALUE,
        private val knowsLength: Boolean = true,
        private val failReadAt: Long = -1L,
    ) {
        val opens = mutableListOf<Long>()
        var closes = 0
        private var failed = false

        fun create(): DataSource = object : DataSource {
            private var position = 0

            override fun addTransferListener(transferListener: TransferListener) = Unit

            override fun open(dataSpec: DataSpec): Long {
                if (dataSpec.position > bytes.size) {
                    throw DataSourceException(DataSourceException.POSITION_OUT_OF_RANGE)
                }
                opens += dataSpec.position
                position = dataSpec.position.toInt()
                val remaining = (bytes.size - position).toLong()
                return if (knowsLength) remaining else C.LENGTH_UNSET.toLong()
            }

            override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
                if (!failed && failReadAt >= 0 && position >= failReadAt) {
                    failed = true
                    throw IOException("connection reset")
                }
                if (position >= bytes.size) return C.RESULT_END_OF_INPUT
                val count = minOf(length, chunk, bytes.size - position)
                bytes.copyInto(buffer, offset, position, position + count)
                position += count
                return count
            }

            override fun getUri(): Uri? = null

            override fun close() {
                closes++
            }
        }
    }

    private val uri: Uri = mockk(relaxed = true)

    private fun sourceOver(fake: FakeSource): DataSourceMediaDataSource {
        val factory = mockk<DataSource.Factory>()
        every { factory.createDataSource() } answers { fake.create() }
        return DataSourceMediaDataSource(factory, uri)
    }

    private val bytes = ByteArray(100) { it.toByte() }

    @Test
    fun `sequential reads share one open`() {
        val fake = FakeSource(bytes)
        val source = sourceOver(fake)
        val out = ByteArray(10)

        assertEquals(10, source.readAt(0, out, 0, 10))
        assertEquals(10, source.readAt(10, out, 0, 10))
        assertEquals(10, source.readAt(20, out, 0, 10))

        assertEquals(listOf(0L), fake.opens)
        assertArrayEquals(bytes.copyOfRange(20, 30), out)
    }

    @Test
    fun `a short hop forward is read through on the open source`() {
        val fake = FakeSource(bytes)
        val source = sourceOver(fake)
        val out = ByteArray(10)

        source.readAt(0, out, 0, 10)
        // Consecutive audio samples sit a video frame apart: on a source
        // that has to go to the network a reopen here is a fresh range
        // request per sample.
        assertEquals(10, source.readAt(60, out, 0, 10))

        assertEquals(listOf(0L), fake.opens)
        assertEquals(0, fake.closes)
        assertArrayEquals(bytes.copyOfRange(60, 70), out)
    }

    @Test
    fun `regions read side by side each keep their own source`() {
        val big = ByteArray(2 * 1024 * 1024) { it.toByte() }
        val fake = FakeSource(big)
        val source = sourceOver(fake)
        val page = ByteArray(2048)
        val sample = ByteArray(700)

        // The extractor's per-sample pattern: a 2 KB window from each of two
        // sample tables in the moov box, slid 4 bytes on from the last, then
        // the sample itself far behind them, a video frame past the previous.
        val tableA = 7_000L
        val tableB = 6_000L
        val samples = 1_000_000L
        for (n in 0 until 200) {
            source.readAt(tableA + 4 * n, page, 0, page.size)
            source.readAt(tableB + 4 * n, page, 0, page.size)
            source.readAt(samples + 5_000 * n, sample, 0, sample.size)
        }

        // One open per region, none of the three ever reopened, walked from
        // the front of the file, or re-read for the overlap of its windows.
        assertEquals(listOf(tableA, tableB, samples), fake.opens)
        assertEquals(0, fake.closes)
        assertArrayEquals(big.copyOfRange(7_796, 7_796 + 2048), page.also {
            source.readAt(7_796, it, 0, it.size)
        })
        assertArrayEquals(big.copyOfRange(1_995_000, 1_995_700), sample)
    }

    @Test
    fun `a read longer than a cursor holds is still filled`() {
        val big = ByteArray(300 * 1024) { it.toByte() }
        val fake = FakeSource(big, chunk = 1000)
        val source = sourceOver(fake)
        val out = ByteArray(200 * 1024)

        assertEquals(out.size, source.readAt(1_000, out, 0, out.size))

        assertArrayEquals(big.copyOfRange(1_000, 1_000 + out.size), out)
        assertEquals(listOf(1_000L), fake.opens)
    }

    @Test
    fun `a hop beyond the reach of every source opens another`() {
        val far = ByteArray(3 * 1024 * 1024) { it.toByte() }
        val fake = FakeSource(far)
        val source = sourceOver(fake)
        val out = ByteArray(10)

        source.readAt(0, out, 0, 10)
        // A moov box behind the media is megabytes away; reading up to it
        // would download the whole file for a few kilobytes of headers.
        val target = far.size - 100L
        assertEquals(10, source.readAt(target, out, 0, 10))

        assertEquals(listOf(0L, target), fake.opens)
        assertArrayEquals(far.copyOfRange(target.toInt(), target.toInt() + 10), out)
    }

    @Test
    fun `the source used longest ago is the one retired`() {
        val big = ByteArray(2 * 1024 * 1024)
        val fake = FakeSource(big)
        val source = sourceOver(fake)
        val out = ByteArray(4)
        val regions = listOf(0L, 400_000L, 800_000L, 1_200_000L, 1_600_000L)

        regions.forEach { source.readAt(it, out, 0, 4) }
        // Five regions, four sources: the first opened has been idle the
        // longest and is the one given up.
        assertEquals(1, fake.closes)
        // Reading it again costs a reopen, which retires the next-oldest;
        // the ones used since are still in hand.
        source.readAt(4, out, 0, 4)
        source.readAt(800_004, out, 0, 4)
        source.readAt(1_600_004, out, 0, 4)

        assertEquals(regions + 4L, fake.opens)
        assertEquals(2, fake.closes)
    }

    @Test
    fun `a read is filled even when the source hands out less at a time`() {
        val fake = FakeSource(bytes, chunk = 3)
        val source = sourceOver(fake)
        val out = ByteArray(10)

        // The container parsers treat a short read as an error, not as a
        // reason to ask again.
        assertEquals(10, source.readAt(5, out, 0, 10))
        assertArrayEquals(bytes.copyOfRange(5, 15), out)
    }

    @Test
    fun `the size comes from the open`() {
        val fake = FakeSource(bytes)
        val source = sourceOver(fake)

        assertEquals(100L, source.size)
        // A later read at the same offset reuses that open rather than
        // paying for another.
        source.readAt(0, ByteArray(10), 0, 10)
        assertEquals(listOf(0L), fake.opens)
    }

    @Test
    fun `an open elsewhere still reports the whole length`() {
        val fake = FakeSource(bytes)
        val source = sourceOver(fake)

        source.readAt(40, ByteArray(10), 0, 10)

        assertEquals(100L, source.size)
    }

    @Test
    fun `the end of the stream reads as -1`() {
        val fake = FakeSource(bytes)
        val source = sourceOver(fake)
        val out = ByteArray(10)

        assertEquals(5, source.readAt(95, out, 0, 10))
        assertEquals(-1, source.readAt(100, out, 0, 10))
        assertEquals(-1, source.readAt(120, out, 0, 10))
        // Known to be past the end, so nothing was opened for it.
        assertEquals(listOf(95L), fake.opens)
    }

    @Test
    fun `a read past the end of a source of unknown length reads as -1`() {
        val fake = FakeSource(bytes, knowsLength = false)
        val source = sourceOver(fake)

        assertEquals(-1L, source.size)
        assertEquals(-1, source.readAt(120, ByteArray(10), 0, 10))
    }

    @Test
    fun `close closes every source`() {
        val big = ByteArray(2 * 1024 * 1024)
        val fake = FakeSource(big)
        val source = sourceOver(fake)
        source.readAt(0, ByteArray(10), 0, 10)
        source.readAt(1_000_000, ByteArray(10), 0, 10)

        source.close()

        assertEquals(2, fake.closes)
    }

    @Test
    fun `a source that fails part way through a hop is not read from again`() {
        val big = ByteArray(200_000) { it.toByte() }
        val fake = FakeSource(big, chunk = 8 * 1024, failReadAt = 40_000)
        val source = sourceOver(fake)
        val out = ByteArray(10)

        // Fills the first cursor, leaving its source at 8 KB.
        assertEquals(10, source.readAt(0, out, 0, 10))
        // Within reach, so the same source is walked forward through the gap,
        // and the network drops part way along it. The extractor is told.
        assertThrows(IOException::class.java) { source.readAt(70_000, out, 0, 10) }

        // The retry must not be served by a source stranded mid-gap: the
        // extractor has no way to tell those bytes from the ones it asked for.
        assertEquals(10, source.readAt(70_000, out, 0, 10))
        assertArrayEquals(big.copyOfRange(70_000, 70_010), out)
    }
}
