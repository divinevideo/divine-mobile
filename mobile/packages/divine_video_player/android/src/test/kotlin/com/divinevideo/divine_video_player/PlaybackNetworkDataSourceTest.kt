package com.divinevideo.divine_video_player

import android.net.Uri
import androidx.media3.common.C
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import org.junit.Assert.*
import org.junit.Test

class PlaybackNetworkDataSourceTest {
    @Test
    fun `a retained cache spec cannot send revoked correlation on its next upstream open`() {
        val id = "11111111-1111-4111-8111-111111111111"
        var currentId: String? = id
        val samples = mutableListOf<Map<String, Any>>()
        val upstream = mockk<DataSource>(relaxed = true)
        val opened = slot<DataSpec>()
        every { upstream.open(capture(opened)) } returns 7L
        val source = PlaybackNetworkDataSource(
            upstream, samples::add,
            isPlaybackLoadCurrent = { _, candidate -> candidate == currentId },
        ) { 0L }
        val cached = mockk<DataSource>(relaxed = true)
        val retainedSpec = slot<DataSpec>()
        every { cached.open(capture(retainedSpec)) } returns 10L
        val cacheRouter = CacheBypassDataSource(
            cachedFactory = DataSource.Factory { cached },
            uncachedFactory = DataSource.Factory { mockk(relaxed = true) },
            httpHeadersForUri = { if (currentId == null) emptyMap() else mapOf("X-Playback-Load-Id" to id) },
        )
        val uri = mockk<Uri>(relaxed = true) { every { scheme } returns "https" }
        cacheRouter.open(DataSpec.Builder().setUri(uri).build())
        // Media3 holds this request while serving a cached prefix. A later
        // cache hole opens upstream from the retained spec after withdrawal.
        currentId = null
        source.open(retainedSpec.captured.subrange(3).withRequestHeaders(
            retainedSpec.captured.httpRequestHeaders + mapOf("Authorization" to "Nostr token"),
        ))
        source.close()
        assertEquals(mapOf("Authorization" to "Nostr token"), opened.captured.httpRequestHeaders)
        assertEquals(3L, opened.captured.position)
        assertTrue(samples.isEmpty())
    }

    @Test
    fun `finite full reads complete on close without a final EOF read`() {
        for ((openedLength, bytesRead, expected) in listOf(
            Triple(3L, 3, "complete"),
            Triple(3L, 2, "cancelled"),
            Triple(C.LENGTH_UNSET.toLong(), 3, "cancelled"),
        )) {
            val samples = mutableListOf<Map<String, Any>>()
            val delegate = mockk<DataSource>(relaxed = true)
            every { delegate.open(any()) } returns openedLength
            every { delegate.read(any(), any(), any()) } returns bytesRead
            val source = PlaybackNetworkDataSource(delegate, samples::add, isPlaybackLoadCurrent = { _, _ -> true }) { 0L }
            source.open(DataSpec.Builder().setUri(mockk<Uri>(relaxed = true))
                .setHttpRequestHeaders(mapOf("X-Playback-Load-Id" to "11111111-1111-4111-8111-111111111111")).build())
            source.read(ByteArray(3), 0, 3)
            source.close()
            assertEquals(expected, samples.last()["network_outcome"])
            assertEquals(bytesRead.toLong(), samples.last()["network_bytes"])
            assertEquals(0L, samples.last()["network_duration_ms"])
        }
    }

    @Test
    fun `only real callbacks produce bytes and completion timing`() {
        var now = 0L
        val samples = mutableListOf<Map<String, Any>>()
        val delegate = mockk<DataSource>(relaxed = true)
        val opened = slot<DataSpec>()
        every { delegate.open(capture(opened)) } answers { now = 7; 999L }
        every { delegate.read(any(), any(), any()) } returnsMany listOf(3, C.RESULT_END_OF_INPUT)
        val source = PlaybackNetworkDataSource(delegate, samples::add, isPlaybackLoadCurrent = { _, _ -> true }) { now }
        val spec = DataSpec.Builder().setUri(mockk<Uri>(relaxed = true))
            .setHttpRequestHeaders(mapOf("X-Playback-Load-Id" to "11111111-1111-4111-8111-111111111111")).build()
        source.open(spec)
        assertEquals("11111111-1111-4111-8111-111111111111", opened.captured.httpRequestHeaders["X-Playback-Load-Id"])
        assertEquals(7L, samples.single()["network_headers_ms"])
        assertFalse(samples.single().containsKey("network_bytes"))
        now = 12
        source.read(ByteArray(8), 0, 8)
        source.read(ByteArray(8), 0, 8)
        source.close()
        assertEquals(2, samples.size)
        assertEquals(3L, samples.last()["network_bytes"])
        assertEquals(12L, samples.last()["network_duration_ms"])
        assertEquals("complete", samples.last()["network_outcome"])
        assertFalse(samples.last().containsKey("uri"))
    }

    @Test
    fun `no opt in produces no samples and early close is cancellation`() {
        val samples = mutableListOf<Map<String, Any>>()
        val delegate = mockk<DataSource>(relaxed = true)
        every { delegate.open(any()) } returns 5L
        val source = PlaybackNetworkDataSource(delegate, samples::add, isPlaybackLoadCurrent = { _, _ -> true }) { 0L }
        val spec = DataSpec.Builder().setUri(mockk<Uri>(relaxed = true)).build()
        source.open(spec)
        source.close()
        assertTrue(samples.isEmpty())
        source.open(spec.withRequestHeaders(mapOf("X-Playback-Load-Id" to "11111111-1111-4111-8111-111111111111")))
        source.close()
        assertEquals("cancelled", samples.last()["network_outcome"])
        assertEquals(0L, samples.last()["network_bytes"])
    }
}
