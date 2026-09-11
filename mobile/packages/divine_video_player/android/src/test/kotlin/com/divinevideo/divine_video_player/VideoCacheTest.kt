package com.divinevideo.divine_video_player

import android.net.Uri
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.HttpDataSource
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the transport contract of [CacheBypassDataSource]: gated
 * (viewer-authenticated) requests attach the auth header AND bypass the disk
 * cache so private bytes are never persisted, while anonymous HTTP(S) requests
 * use the cache and add no headers. This is the per-request half of the
 * gated-HLS fix (#4884 / #4897) — the resolver runs on every `open()`, so HLS
 * media segments authenticate alongside the master manifest.
 *
 * Local sources bypass the cache too (#8029): a `file://` URI or a bare path
 * is already on disk, and routing it through the write-through cache stored a
 * second copy of every feed video played from the Dart-side media cache.
 */
@UnstableApi
class VideoCacheTest {

    private val authHeaders = mapOf("Authorization" to "Nostr token")

    private fun dataSpec(uriScheme: String? = "https"): DataSpec {
        val uri = mockk<Uri>(relaxed = true) {
            every { scheme } returns uriScheme
        }
        return DataSpec.Builder().setUri(uri).build()
    }

    @Test
    fun `open attaches viewer headers and bypasses the cache for gated content`() {
        val cachedDelegate = mockk<DataSource>(relaxed = true)
        val uncachedDelegate = mockk<DataSource>(relaxed = true)
        val cachedFactory = mockk<DataSource.Factory> {
            every { createDataSource() } returns cachedDelegate
        }
        val uncachedFactory = mockk<DataSource.Factory> {
            every { createDataSource() } returns uncachedDelegate
        }
        val openedSpec = slot<DataSpec>()
        every { uncachedDelegate.open(capture(openedSpec)) } returns 0L

        val source = CacheBypassDataSource(
            cachedFactory = cachedFactory,
            uncachedFactory = uncachedFactory,
            httpHeadersForUri = { authHeaders },
        )

        source.open(dataSpec())

        // Gated content must NOT touch the disk cache (no-store private bytes)...
        verify(exactly = 1) { uncachedFactory.createDataSource() }
        verify(exactly = 0) { cachedFactory.createDataSource() }
        // ...and the viewer-auth header must ride on the request.
        assertEquals(
            "Nostr token",
            openedSpec.captured.httpRequestHeaders["Authorization"],
        )
    }

    @Test
    fun `open uses the cache and adds no headers for anonymous content`() {
        val cachedDelegate = mockk<DataSource>(relaxed = true)
        val uncachedDelegate = mockk<DataSource>(relaxed = true)
        val cachedFactory = mockk<DataSource.Factory> {
            every { createDataSource() } returns cachedDelegate
        }
        val uncachedFactory = mockk<DataSource.Factory> {
            every { createDataSource() } returns uncachedDelegate
        }
        val openedSpec = slot<DataSpec>()
        every { cachedDelegate.open(capture(openedSpec)) } returns 0L

        val source = CacheBypassDataSource(
            cachedFactory = cachedFactory,
            uncachedFactory = uncachedFactory,
            httpHeadersForUri = { emptyMap() },
        )

        source.open(dataSpec(uriScheme = "https"))

        verify(exactly = 1) { cachedFactory.createDataSource() }
        verify(exactly = 0) { uncachedFactory.createDataSource() }
        assertTrue(openedSpec.captured.httpRequestHeaders.isEmpty())
    }

    @Test
    fun `open bypasses the cache for a file URI`() {
        val cachedFactory = mockk<DataSource.Factory> {
            every { createDataSource() } returns mockk(relaxed = true)
        }
        val uncachedFactory = mockk<DataSource.Factory> {
            every { createDataSource() } returns mockk(relaxed = true)
        }

        val source = CacheBypassDataSource(
            cachedFactory = cachedFactory,
            uncachedFactory = uncachedFactory,
            httpHeadersForUri = { emptyMap() },
        )

        source.open(dataSpec(uriScheme = "file"))

        // The bytes are already on disk; a cache pass would only copy them.
        verify(exactly = 1) { uncachedFactory.createDataSource() }
        verify(exactly = 0) { cachedFactory.createDataSource() }
    }

    @Test
    fun `open bypasses the cache for a bare path`() {
        val cachedFactory = mockk<DataSource.Factory> {
            every { createDataSource() } returns mockk(relaxed = true)
        }
        val uncachedFactory = mockk<DataSource.Factory> {
            every { createDataSource() } returns mockk(relaxed = true)
        }

        val source = CacheBypassDataSource(
            cachedFactory = cachedFactory,
            uncachedFactory = uncachedFactory,
            httpHeadersForUri = { emptyMap() },
        )

        // `VideoClip.file(path)` reaches the player as a scheme-less path,
        // which Media3 resolves to a local file.
        source.open(dataSpec(uriScheme = null))

        verify(exactly = 1) { uncachedFactory.createDataSource() }
        verify(exactly = 0) { cachedFactory.createDataSource() }
    }

    @Test
    fun `only http and https schemes are cacheable`() {
        assertTrue(isCacheableScheme("http"))
        assertTrue(isCacheableScheme("https"))
        assertTrue(isCacheableScheme("HTTPS"))
        assertFalse(isCacheableScheme("file"))
        assertFalse(isCacheableScheme("content"))
        assertFalse(isCacheableScheme(null))
    }

    @Test
    fun `processing response rejects accepted HTTP 202 and closes delegate`() {
        val delegate = mockk<HttpDataSource>(relaxed = true) {
            every { open(any()) } returns 42L
            every { responseCode } returns 202
            every { responseHeaders } returns mapOf(
                "Retry-After" to listOf("3"),
            )
        }
        val source = ProcessingResponseDataSource(delegate)

        val error = assertThrows(HttpDataSource.InvalidResponseCodeException::class.java) {
            source.open(dataSpec())
        }

        assertEquals(202, error.responseCode)
        verify(exactly = 1) { delegate.close() }
    }
}
