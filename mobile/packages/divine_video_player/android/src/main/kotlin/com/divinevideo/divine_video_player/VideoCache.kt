package com.divinevideo.divine_video_player

import android.content.Context
import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.HttpDataSource
import androidx.media3.datasource.TransferListener
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import java.io.File

/**
 * Singleton managing ExoPlayer's disk-backed [SimpleCache].
 *
 * Initialised once via [configure] at app startup. All player instances
 * share the same cache directory and eviction policy.
 *
 * When configured, [dataSourceFactory] returns a factory whose sources read
 * HTTP(S) media from cache first and fill it progressively on cache misses.
 * When **not** configured, it falls back to a plain [DefaultDataSource.Factory].
 *
 * The cache lives at `<cacheDir>/divine_video_cache`. The app's storage
 * screen counts and clears that directory by name, so a rename here must be
 * mirrored in `StorageManagementService`.
 */
@UnstableApi
internal object VideoCache {

    private var cache: SimpleCache? = null
    private var cacheDataSourceFactory: CacheDataSource.Factory? = null

    /** Whether [configure] has been called successfully. */
    val isConfigured: Boolean get() = cache != null

    /**
     * Initialises the shared cache.
     *
     * @param context  Application context (used for the cache dir and
     *                 database provider).
     * @param maxSizeBytes  Maximum size of the LRU disk cache in bytes.
     */
    @Synchronized
    fun configure(context: Context, maxSizeBytes: Long) {
        // Avoid re-creating if already initialised.
        if (cache != null) return

        val cacheDir = File(context.cacheDir, "divine_video_cache")
        val evictor = LeastRecentlyUsedCacheEvictor(maxSizeBytes)
        val databaseProvider = StandaloneDatabaseProvider(context)

        cache = SimpleCache(cacheDir, evictor, databaseProvider)

        cacheDataSourceFactory = CacheDataSource.Factory()
            .setCache(cache!!)
            .setUpstreamDataSourceFactory(upstreamFactory(context))
            // Read from cache first, fill progressively on miss.
            .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)
    }

    /**
     * Returns a [DataSource.Factory] that hits the cache when available,
     * or a plain [DefaultDataSource.Factory] if the cache has not been
     * configured.
     *
     * Only anonymous HTTP(S) requests go through the cache; see
     * [CacheBypassDataSource] for what is routed around it and why.
     */
    fun dataSourceFactory(
        context: Context,
        httpHeadersForUri: (Uri) -> Map<String, String> = { emptyMap() },
    ): DataSource.Factory {
        val cachedFactory = cacheDataSourceFactory ?: upstreamFactory(context)
        val uncachedFactory = upstreamFactory(context)
        return DataSource.Factory {
            CacheBypassDataSource(
                cachedFactory = cachedFactory,
                uncachedFactory = uncachedFactory,
                httpHeadersForUri = httpHeadersForUri,
            )
        }
    }

    private fun upstreamFactory(context: Context): DataSource.Factory {
        val defaultHttpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
        val httpDataSourceFactory = DataSource.Factory {
            ProcessingResponseDataSource(
                defaultHttpDataSourceFactory.createDataSource(),
            )
        }
        return DefaultDataSource.Factory(context, httpDataSourceFactory)
    }

    /** Releases the cache. Called on engine detach. */
    @Synchronized
    fun release() {
        cache?.release()
        cache = null
        cacheDataSourceFactory = null
    }
}

/**
 * Converts an accepted HTTP 202 into a typed HTTP failure before Media3 tries
 * to parse the processing response body as video or a manifest.
 */
internal class ProcessingResponseDataSource(
    private val delegate: HttpDataSource,
) : DataSource {

    override fun addTransferListener(transferListener: TransferListener) {
        delegate.addTransferListener(transferListener)
    }

    override fun open(dataSpec: DataSpec): Long {
        val length = delegate.open(dataSpec)
        if (delegate.responseCode != 202) return length

        val responseHeaders = delegate.responseHeaders
        delegate.close()
        throw HttpDataSource.InvalidResponseCodeException(
            202,
            "Media is still processing",
            null,
            responseHeaders,
            dataSpec,
            ByteArray(0),
        )
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int =
        delegate.read(buffer, offset, length)

    override fun getUri(): Uri? = delegate.uri

    override fun getResponseHeaders(): Map<String, List<String>> =
        delegate.responseHeaders

    override fun close() {
        delegate.close()
    }
}

/**
 * Whether a request for [scheme] can usefully go through [SimpleCache].
 *
 * Only remote HTTP(S) bytes are worth keeping: everything else Media3 can
 * open — `file`, a bare path (no scheme), `content`, `asset`, `data` — is
 * already on the device. Routing those through a write-through cache copies
 * every local read into `divine_video_cache` a second time, which is exactly
 * what happened to each feed video played from the Dart-side media cache
 * (#8029).
 */
internal fun isCacheableScheme(scheme: String?): Boolean =
    scheme.equals("http", ignoreCase = true) ||
        scheme.equals("https", ignoreCase = true)

/**
 * Routes each request either through [cachedFactory] or straight to
 * [uncachedFactory], deciding per `open()` so HLS segments are judged on
 * their own URI rather than the manifest's.
 *
 * Two kinds of request bypass the cache:
 *  - Viewer-authenticated (age-gated) content, which the origin serves
 *    `no-store`; the auth headers are attached and the private bytes are
 *    never persisted.
 *  - Anything that is not an HTTP(S) URL, which is already local and would
 *    only be duplicated on disk (see [isCacheableScheme]).
 */
internal class CacheBypassDataSource(
    private val cachedFactory: DataSource.Factory,
    private val uncachedFactory: DataSource.Factory,
    private val httpHeadersForUri: (Uri) -> Map<String, String>,
) : DataSource {

    private val transferListeners = mutableListOf<TransferListener>()
    private var delegate: DataSource? = null

    override fun addTransferListener(transferListener: TransferListener) {
        transferListeners += transferListener
        delegate?.addTransferListener(transferListener)
    }

    override fun open(dataSpec: DataSpec): Long {
        val httpHeaders = httpHeadersForUri(dataSpec.uri)
        val resolvedDataSpec = if (httpHeaders.isEmpty()) {
            dataSpec
        } else {
            dataSpec.withRequestHeaders(dataSpec.httpRequestHeaders + httpHeaders)
        }
        val useCache = httpHeaders.isEmpty() && isCacheableScheme(dataSpec.uri.scheme)
        val selectedDelegate = if (useCache) {
            cachedFactory.createDataSource()
        } else {
            uncachedFactory.createDataSource()
        }
        transferListeners.forEach(selectedDelegate::addTransferListener)
        delegate = selectedDelegate
        return selectedDelegate.open(resolvedDataSpec)
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        return delegate?.read(buffer, offset, length) ?: C.RESULT_END_OF_INPUT
    }

    override fun getUri(): Uri? = delegate?.uri

    override fun getResponseHeaders(): Map<String, List<String>> {
        return delegate?.responseHeaders ?: emptyMap()
    }

    override fun close() {
        delegate?.close()
        delegate = null
    }
}
