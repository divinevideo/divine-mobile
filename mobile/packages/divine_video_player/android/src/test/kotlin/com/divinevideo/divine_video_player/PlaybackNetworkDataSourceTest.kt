package com.divinevideo.divine_video_player

import android.net.Uri
import androidx.media3.common.C
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.*
import org.junit.Test

class PlaybackNetworkDataSourceTest {
    @Test
    fun `only real callbacks produce bytes and completion timing`() {
        var now = 0L
        val samples = mutableListOf<Map<String, Any>>()
        val delegate = mockk<DataSource>(relaxed = true)
        every { delegate.open(any()) } answers { now = 7; 999L }
        every { delegate.read(any(), any(), any()) } returnsMany listOf(3, C.RESULT_END_OF_INPUT)
        val source = PlaybackNetworkDataSource(delegate, samples::add) { now }
        val spec = DataSpec.Builder().setUri(mockk<Uri>(relaxed = true))
            .setHttpRequestHeaders(mapOf("X-Playback-Load-Id" to "11111111-1111-4111-8111-111111111111")).build()
        source.open(spec)
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
        val source = PlaybackNetworkDataSource(delegate, samples::add) { 0L }
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
