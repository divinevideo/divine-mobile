package com.divinevideo.divine_video_player

import android.content.Context
import android.graphics.SurfaceTexture
import android.media.MediaFormat
import android.net.Uri
import android.os.Handler
import android.os.SystemClock
import android.view.Surface
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionParameters
import androidx.media3.common.VideoSize
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.HttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import io.mockk.clearMocks
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkObject
import io.mockk.mockkStatic
import io.mockk.runs
import io.mockk.slot
import io.mockk.unmockkConstructor
import io.mockk.unmockkObject
import io.mockk.unmockkStatic
import io.mockk.verify
import io.mockk.verifyOrder
import java.io.IOException
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * Pins the disposal contract of [DivineVideoPlayerInstance] — call ordering is the
 * load-bearing behavior of the #3416 fix, and this test exists so a future refactor
 * of `dispose()` cannot silently revert any of stop / clearVideoSurface / release.
 *
 * The Instance has tight Android-framework coupling (Handler/Looper, AudioOverlayManager
 * with internal ExoPlayers); rather than mock framework classes, we use the injected
 * factories the production constructor exposes.
 */
class DivineVideoPlayerInstanceTest {

    private lateinit var messenger: BinaryMessenger
    private lateinit var context: Context
    private lateinit var mockPlayer: ExoPlayer
    private lateinit var mockHandler: Handler
    private lateinit var mockAudioManager: AudioOverlayManager
    private lateinit var mockRegistry: TextureRegistry
    private lateinit var mockProducer: TextureRegistry.SurfaceProducer
    private lateinit var mockSurface: Surface
    private lateinit var mockTextureEntry: TextureRegistry.SurfaceTextureEntry
    private lateinit var mockSurfaceTexture: SurfaceTexture
    private lateinit var instance: DivineVideoPlayerInstance

    @Before
    fun setUp() {
        DivineVideoPlayerInstance.clearTrackDurationsCacheForTesting()
        messenger = mockk(relaxed = true)
        context = mockk(relaxed = true)
        mockPlayer = mockk(relaxed = true)
        mockHandler = mockk(relaxed = true)
        mockAudioManager = mockk(relaxed = true)
        mockRegistry = mockk(relaxed = true)
        mockProducer = mockk(relaxed = true)
        mockSurface = mockk(relaxed = true)
        mockTextureEntry = mockk(relaxed = true)
        mockSurfaceTexture = mockk(relaxed = true)

        every { mockRegistry.createSurfaceProducer() } returns mockProducer
        every { mockProducer.id() } returns 42L
        every { mockRegistry.createSurfaceTexture() } returns mockTextureEntry
        every { mockTextureEntry.surfaceTexture() } returns mockSurfaceTexture
        every { mockTextureEntry.id() } returns 99L

        instance = DivineVideoPlayerInstance(
            messenger = messenger,
            context = context,
            playerId = 1,
            playerFactory = { _ -> mockPlayer },
            mainHandler = mockHandler,
            audioOverlayManagerFactory = { _ -> mockAudioManager },
            metadataExecutor = DirectExecutorService(),
        )
    }

    @After
    fun tearDown() {
        DivineVideoPlayerInstance.clearTrackDurationsCacheForTesting()
    }

    /**
     * Forces lazy [ExoPlayer] creation by routing a `play` call through the public
     * MethodChannel handler — the same path production uses.
     */
    private fun materializePlayer() {
        instance.onMethodCall(MethodCall("play", null), mockk(relaxed = true))
    }

    @Test
    fun `blobHashFromUrl extracts the hash from every blob variant URL`() {
        val hash = "a".repeat(64)
        assertEquals(hash, instance.blobHashFromUrl("https://media.divine.video/$hash"))
        assertEquals(
            hash,
            instance.blobHashFromUrl("https://media.divine.video/$hash/720p.mp4"),
        )
        assertEquals(
            hash,
            instance.blobHashFromUrl("https://media.divine.video/$hash/hls/master.m3u8"),
        )
        assertEquals(
            hash,
            instance.blobHashFromUrl("https://media.divine.video/$hash/hls/segment_1.ts"),
        )
        assertEquals(
            hash,
            instance.blobHashFromUrl("https://media.divine.video/$hash.mp4"),
        )
    }

    @Test
    fun `blobHashFromUrl returns null for non-blob URLs`() {
        assertEquals(null, instance.blobHashFromUrl("https://example.com/video.mp4"))
        assertEquals(
            null,
            instance.blobHashFromUrl("https://media.divine.video/notahash/720p.mp4"),
        )
    }

    // -- viewer auth header resolution (gated HLS, #4884 / #4897) --

    @Test
    fun `httpHeadersForRequest returns the viewer header for the exact clip URI`() {
        val url = "https://media.divine.video/${"a".repeat(64)}/720p.mp4"
        instance.onMethodCall(
            setClipsWithHeaders(url, mapOf("Authorization" to "Nostr token")),
            mockk(relaxed = true),
        )

        assertEquals(
            mapOf("Authorization" to "Nostr token"),
            instance.httpHeadersForRequest(url),
        )
    }

    @Test
    fun `httpHeadersForRequest authenticates HLS segments via the hash fallback`() {
        val hash = "a".repeat(64)
        instance.onMethodCall(
            setClipsWithHeaders(
                "https://media.divine.video/$hash/hls/master.m3u8",
                mapOf("Authorization" to "Nostr token"),
            ),
            mockk(relaxed = true),
        )

        // A media segment lives under the same blob hash but at a different URI;
        // it must resolve the same viewer-auth header (the #4884 fix) so gated
        // HLS playback authenticates end-to-end.
        assertEquals(
            mapOf("Authorization" to "Nostr token"),
            instance.httpHeadersForRequest(
                "https://media.divine.video/$hash/hls/segment_1.ts",
            ),
        )
    }

    @Test
    fun `httpHeadersForRequest returns empty for a URL outside the gated blob`() {
        val hash = "a".repeat(64)
        instance.onMethodCall(
            setClipsWithHeaders(
                "https://media.divine.video/$hash/720p.mp4",
                mapOf("Authorization" to "Nostr token"),
            ),
            mockk(relaxed = true),
        )

        assertEquals(
            emptyMap<String, String>(),
            instance.httpHeadersForRequest("https://cdn.example.com/other.ts"),
        )
    }

    @Test
    fun `httpHeadersForRequest returns empty for a different, unregistered blob hash`() {
        instance.onMethodCall(
            setClipsWithHeaders(
                "https://media.divine.video/${"a".repeat(64)}/720p.mp4",
                mapOf("Authorization" to "Nostr token"),
            ),
            mockk(relaxed = true),
        )

        // A valid 64-hex hash that was never registered must NOT inherit another
        // blob's viewer header. Unlike the miss above (the URL parses to no hash),
        // this hits the hash-miss branch: blobHashFromUrl succeeds but the hash is
        // absent from httpHeadersByHash, so it falls through to emptyMap().
        assertEquals(
            emptyMap<String, String>(),
            instance.httpHeadersForRequest(
                "https://media.divine.video/${"b".repeat(64)}/hls/segment_1.ts",
            ),
        )
    }

    private fun setClipsWithHeaders(
        uri: String,
        httpHeaders: Map<String, String>,
    ): MethodCall =
        MethodCall(
            "setClips",
            mapOf(
                "clips" to listOf(
                    mapOf(
                        "uri" to uri,
                        "startMs" to 0,
                        "endMs" to 1000,
                        "httpHeaders" to httpHeaders,
                    ),
                ),
            ),
        )

    @Test
    fun `dispose removes listener, stops decoder, clears surface, then releases (in order)`() {
        materializePlayer()

        instance.dispose()

        verifyOrder {
            mockPlayer.removeListener(any())
            mockPlayer.stop()
            mockPlayer.clearVideoSurface()
            mockPlayer.release()
        }
    }

    @Test
    fun `dispose is a no-op on the player when player was never materialized`() {
        // Do NOT materialize — player is null.
        instance.dispose()

        verify(exactly = 0) { mockPlayer.stop() }
        verify(exactly = 0) { mockPlayer.clearVideoSurface() }
        verify(exactly = 0) { mockPlayer.release() }
    }

    @Test
    fun `stopForActivityDetach stops decoder and clears surface but does not release`() {
        materializePlayer()

        instance.stopForActivityDetach()

        verifyOrder {
            mockPlayer.stop()
            mockPlayer.clearVideoSurface()
        }
        verify(exactly = 0) { mockPlayer.release() }
    }

    @Test
    fun `stopForActivityDetach pauses audio overlays for symmetry with onAppBackgrounded`() {
        materializePlayer()

        instance.stopForActivityDetach()

        verify { mockAudioManager.pauseAll() }
    }

    @Test
    fun `stopForActivityDetach is safe when player was never materialized`() {
        instance.stopForActivityDetach()

        verify(exactly = 0) { mockPlayer.stop() }
        verify(exactly = 0) { mockPlayer.clearVideoSurface() }
        // Audio overlay pause still runs — the method is also responsible for
        // muting any orphaned overlay even when no main player exists.
        verify { mockAudioManager.pauseAll() }
    }

    // -- SurfaceProducer.Callback contract --

    @Test
    fun `onSurfaceAvailable attaches surface to player and clears needsSurface`() {
        // Start with a null surface so enableTextureOutput leaves needsSurface = true.
        every { mockProducer.surface } returns null
        instance.enableTextureOutput(mockRegistry)

        // Surface becomes available; simulate the callback firing with the real surface.
        every { mockProducer.surface } returns mockSurface
        materializePlayer()

        // onSurfaceCleanup + onSurfaceAvailable cycle.
        instance.onSurfaceCleanup()
        instance.onSurfaceAvailable()

        verify { mockPlayer.setVideoSurface(mockSurface) }
        // A second onSurfaceAvailable must be a no-op (needsSurface is now false).
        clearMocks(mockPlayer, answers = false, recordedCalls = true)
        instance.onSurfaceAvailable()
        verify(exactly = 0) { mockPlayer.setVideoSurface(any()) }
    }

    @Test
    fun `onSurfaceAvailable leaves needsSurface true when player has not been created`() {
        // Surface is null at enableTextureOutput time → needsSurface = true.
        every { mockProducer.surface } returns null
        instance.enableTextureOutput(mockRegistry)

        // Surface now available, but player still null.
        every { mockProducer.surface } returns mockSurface
        instance.onSurfaceAvailable()

        // No setVideoSurface call — player doesn't exist yet.
        verify(exactly = 0) { mockPlayer.setVideoSurface(any()) }

        // needsSurface must still be true: ensurePlayer() should attach the surface
        // when the player is eventually created.
        materializePlayer()
        verify { mockPlayer.setVideoSurface(mockSurface) }
    }

    @Test
    fun `onSurfaceCleanup detaches surface from player and raises needsSurface`() {
        every { mockProducer.surface } returns mockSurface
        instance.enableTextureOutput(mockRegistry)
        materializePlayer()

        instance.onSurfaceCleanup()

        verify { mockPlayer.setVideoSurface(null) }
        // needsSurface is now true: onSurfaceAvailable should reattach.
        instance.onSurfaceAvailable()
        verify { mockPlayer.setVideoSurface(mockSurface) }
    }

    @Test
    fun `onSurfaceCleanup raises needsSurface even when player is null`() {
        every { mockProducer.surface } returns null
        instance.enableTextureOutput(mockRegistry)
        // Player never materialised — setVideoSurface(null) is a no-op via ?.

        instance.onSurfaceCleanup()

        // Surface becomes available and then the player is created.
        every { mockProducer.surface } returns mockSurface
        materializePlayer()
        // ensurePlayer() must attach because needsSurface was left true.
        verify { mockPlayer.setVideoSurface(mockSurface) }
    }

    @Test
    fun `enableTextureOutput true uses createSurfaceTexture not createSurfaceProducer`() {
        mockkConstructor(Surface::class)
        try {
            val textureId = instance.enableTextureOutput(
                mockRegistry,
                useLegacySurface = true,
            )

            verify(exactly = 1) { mockRegistry.createSurfaceTexture() }
            verify(exactly = 0) { mockRegistry.createSurfaceProducer() }
            verify(exactly = 1) { mockTextureEntry.surfaceTexture() }
            assertEquals(99L, textureId)
        } finally {
            unmockkConstructor(Surface::class)
        }
    }

    // -- onMediaItemTransition detach/reattach --

    private fun capturePlayerListener(): Player.Listener {
        val slot = slot<Player.Listener>()
        every { mockPlayer.addListener(capture(slot)) } just runs
        materializePlayer()
        return slot.captured
    }

    @Test
    fun `video size emits the pixel ratio and resets it with unknown dimensions`() {
        val listener = capturePlayerListener()
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        val state = slot<Any>()
        every { sink.success(capture(state)) } just runs
        instance.onListen(null, sink)

        listener.onVideoSizeChanged(VideoSize(720, 480, 2f / 3f))

        val sized = state.captured as Map<*, *>
        assertEquals(720, sized["videoWidth"])
        assertEquals(480, sized["videoHeight"])
        assertEquals((2f / 3f).toDouble(), sized["pixelWidthHeightRatio"])

        listener.onVideoSizeChanged(VideoSize.UNKNOWN)

        val reset = state.captured as Map<*, *>
        assertEquals(0, reset["videoWidth"])
        assertEquals(0, reset["videoHeight"])
        assertEquals(1.0, reset["pixelWidthHeightRatio"])
    }

    @Test
    fun `video size uses square pixels when the reported ratio is invalid`() {
        val listener = capturePlayerListener()
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        val state = slot<Any>()
        every { sink.success(capture(state)) } just runs
        instance.onListen(null, sink)

        for (ratio in listOf(0f, -1f, Float.NaN, Float.POSITIVE_INFINITY)) {
            listener.onVideoSizeChanged(VideoSize(720, 480, ratio))

            val sized = state.captured as Map<*, *>
            assertEquals(720, sized["videoWidth"])
            assertEquals(480, sized["videoHeight"])
            assertEquals(1.0, sized["pixelWidthHeightRatio"])
        }
    }

    @Test
    fun `MEDIA_ITEM_TRANSITION_REASON_AUTO forces surface detach then reattach`() {
        every { mockProducer.surface } returns mockSurface
        instance.enableTextureOutput(mockRegistry)
        val listener = capturePlayerListener()

        listener.onMediaItemTransition(null, Player.MEDIA_ITEM_TRANSITION_REASON_AUTO)

        verifyOrder {
            mockPlayer.setVideoSurface(null)
            mockPlayer.setVideoSurface(mockSurface)
        }
    }

    @Test
    fun `MEDIA_ITEM_TRANSITION_REASON_AUTO is skipped when surface is not yet attached`() {
        // Surface null during enableTextureOutput → needsSurface = true.
        every { mockProducer.surface } returns null
        instance.enableTextureOutput(mockRegistry)
        every { mockProducer.surface } returns mockSurface
        val listener = capturePlayerListener()
        // ensurePlayer attached the surface (needsSurface = false). Force the flag
        // back to true by calling onSurfaceCleanup to simulate a surface loss before
        // the auto-transition fires.
        instance.onSurfaceCleanup()
        // Clear calls recorded during setup so the assertion only covers the
        // onMediaItemTransition invocation below.
        clearMocks(mockPlayer, answers = false, recordedCalls = true)

        listener.onMediaItemTransition(null, Player.MEDIA_ITEM_TRANSITION_REASON_PLAYLIST_CHANGED)

        verify(exactly = 0) { mockPlayer.setVideoSurface(any()) }
    }

    // -- setClips async completion contract --

    private fun setClipsCall(uri: String = "file:///tmp/a.mp4"): MethodCall =
        MethodCall(
            "setClips",
            mapOf(
                "clips" to listOf(
                    mapOf("uri" to uri, "startMs" to 0, "endMs" to 1000),
                ),
            ),
        )

    @Test
    fun `setClips holds Dart result until STATE_READY then completes with success`() {
        val listener = capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        instance.onMethodCall(setClipsCall(), result)

        // Result must NOT have completed yet — STATE_READY hasn't fired.
        verify(exactly = 0) { result.success(any()) }
        verify(exactly = 0) { result.error(any(), any(), any()) }

        listener.onPlaybackStateChanged(Player.STATE_READY)

        verify(exactly = 1) { result.success(null) }
    }

    @Test
    fun `setClips timeout completes pending result with NOT_READY error`() {
        capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        val scheduled = slot<Runnable>()
        every {
            mockHandler.postDelayed(capture(scheduled), 10_000L)
        } returns true

        instance.onMethodCall(setClipsCall(), result)

        scheduled.captured.run()

        verify(exactly = 1) {
            result.error(
                "NOT_READY",
                "setClips timed out before player reached STATE_READY",
                null,
            )
        }
        verify(exactly = 0) { result.success(any()) }
    }

    /**
     * Installs a [DivineVideoPlayerLog] sink around [action] and returns the
     * `(level, message)` of the unrequested-stop line it emitted, or null.
     */
    private fun captureUnrequestedStopLog(action: () -> Unit): Pair<String, String>? {
        val entries = mutableListOf<Pair<String, String>>()
        DivineVideoPlayerLog.sink = { level, message, _ -> entries.add(level to message) }
        try {
            action()
        } finally {
            DivineVideoPlayerLog.sink = null
        }
        return entries.lastOrNull {
            it.second.contains("stopped playing while still requested to play")
        }
    }

    @Test
    fun `reportUnrequestedStop stays at debug for a requested stop (STATE_IDLE)`() {
        val listener = capturePlayerListener()
        every { mockPlayer.playWhenReady } returns true
        every { mockPlayer.playbackState } returns Player.STATE_IDLE

        val entry = captureUnrequestedStopLog { listener.onIsPlayingChanged(false) }

        // A requested stop() (Dart, Activity detach, or a fatal error) lands
        // in STATE_IDLE with playWhenReady still set — not the "stopped for no
        // reason we asked for" the info line is reserved for.
        assertEquals("debug", entry?.first)
    }

    @Test
    fun `reportUnrequestedStop reports a genuine mid-play stall at info`() {
        val listener = capturePlayerListener()
        every { mockPlayer.playWhenReady } returns true
        every { mockPlayer.playbackState } returns Player.STATE_BUFFERING

        val entry = captureUnrequestedStopLog { listener.onIsPlayingChanged(false) }

        // Buffering with no seek in flight is the anomaly the info line exists
        // to surface — the STATE_IDLE guard must not silence this.
        assertEquals("info", entry?.first)
    }

    @Test
    fun `onPlayerError completes pending setClips result with error`() {
        val listener = capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall(), result)

        val error = mockk<PlaybackException>(relaxed = true)
        every { error.message } returns "boom"
        listener.onPlayerError(error)

        verify(exactly = 1) {
            result.error("PLAYER_ERROR", "boom", mapOf("errorCode" to "unknown"))
        }
        verify(exactly = 0) { result.success(any()) }
    }

    @Test
    fun `onPlayerError maps pending HTTP 401 setClips failure to auth_required`() {
        val listener = capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall("https://example.com/protected.mp4"), result)

        listener.onPlayerError(httpStatusError(401))

        verify(exactly = 1) {
            result.error(
                "PLAYER_ERROR",
                "HTTP 401",
                mapOf("errorCode" to "auth_required"),
            )
        }
        verify(exactly = 0) { result.success(any()) }
    }

    @Test
    fun `onPlayerError maps pending HTTP 403 setClips failure to forbidden`() {
        val listener = capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall("https://example.com/protected.mp4"), result)

        listener.onPlayerError(httpStatusError(403))

        verify(exactly = 1) {
            result.error(
                "PLAYER_ERROR",
                "HTTP 403",
                mapOf("errorCode" to "forbidden"),
            )
        }
        verify(exactly = 0) { result.success(any()) }
    }

    @Test
    fun `onPlayerError maps pending HTTP 404 setClips failure to not_found`() {
        val listener = capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall("https://example.com/protected.mp4"), result)

        listener.onPlayerError(httpStatusError(404))

        verify(exactly = 1) {
            result.error(
                "PLAYER_ERROR",
                "HTTP 404",
                mapOf("errorCode" to "not_found"),
            )
        }
        verify(exactly = 0) { result.success(any()) }
    }

    @Test
    fun `onPlayerError keeps other 4xx failures on http_client_error`() {
        val listener = capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall("https://example.com/protected.mp4"), result)

        listener.onPlayerError(httpStatusError(410))

        verify(exactly = 1) {
            result.error(
                "PLAYER_ERROR",
                "HTTP 410",
                mapOf("errorCode" to "http_client_error"),
            )
        }
        verify(exactly = 0) { result.success(any()) }
    }

    /**
     * Builds a real [PlaybackException] carrying [ERROR_CODE_DECODER_INIT_FAILED]
     * — the `errorCode` is a public field mockk can't stub, so a genuine
     * instance is needed. Its public constructor reads `Clock.DEFAULT`
     * (→ `android.os.SystemClock`), unmocked on the plain-JVM test runtime, so
     * that static is stubbed only for construction.
     */
    private fun decoderInitError(message: String = "decoder boom"): PlaybackException {
        mockkStatic(SystemClock::class)
        every { SystemClock.elapsedRealtime() } returns 0L
        return PlaybackException(
            message,
            null,
            PlaybackException.ERROR_CODE_DECODER_INIT_FAILED,
        ).also { unmockkStatic(SystemClock::class) }
    }

    private fun playbackError(message: String, errorCode: Int): PlaybackException {
        mockkStatic(SystemClock::class)
        every { SystemClock.elapsedRealtime() } returns 0L
        return PlaybackException(message, null, errorCode)
            .also { unmockkStatic(SystemClock::class) }
    }

    private fun httpStatusError(status: Int): PlaybackException {
        mockkStatic(SystemClock::class)
        mockkStatic(Uri::class)
        every { SystemClock.elapsedRealtime() } returns 0L
        every { Uri.parse("https://example.com/protected.mp4") } returns mockk(relaxed = true)
        try {
            val cause = HttpDataSource.InvalidResponseCodeException(
                status,
                "HTTP $status",
                IOException("HTTP $status"),
                emptyMap(),
                DataSpec(Uri.parse("https://example.com/protected.mp4")),
                ByteArray(0),
            )
            return PlaybackException(
                "HTTP $status",
                cause,
                PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS,
            )
        } finally {
            unmockkStatic(Uri::class)
            unmockkStatic(SystemClock::class)
        }
    }

    @Test
    fun `onPlayerError maps residual IO failures to io_error`() {
        val listener = capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall(), result)

        listener.onPlayerError(playbackError("IO unspecified", 2000))

        verify(exactly = 1) {
            result.error("PLAYER_ERROR", "IO unspecified", mapOf("errorCode" to "io_error"))
        }
        verify(exactly = 0) { result.success(any()) }
    }

    @Test
    fun `onPlayerError maps residual cleartext IO failures to io_error`() {
        val listener = capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall(), result)

        listener.onPlayerError(playbackError("Cleartext not permitted", 2007))

        verify(exactly = 1) {
            result.error(
                "PLAYER_ERROR",
                "Cleartext not permitted",
                mapOf("errorCode" to "io_error"),
            )
        }
        verify(exactly = 0) { result.success(any()) }
    }

    @Test
    fun `onPlayerError maps residual read-position IO failures to io_error`() {
        val listener = capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall(), result)

        listener.onPlayerError(playbackError("Read position out of range", 2008))

        verify(exactly = 1) {
            result.error(
                "PLAYER_ERROR",
                "Read position out of range",
                mapOf("errorCode" to "io_error"),
            )
        }
        verify(exactly = 0) { result.success(any()) }
    }

    @Test
    fun `onPlayerError maps renderer failures to decoder_error`() {
        val listener = capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall(), result)

        listener.onPlayerError(playbackError("Renderer failed", 5000))

        verify(exactly = 1) {
            result.error("PLAYER_ERROR", "Renderer failed", mapOf("errorCode" to "decoder_error"))
        }
        verify(exactly = 0) { result.success(any()) }
    }

    @Test
    fun `onPlayerError re-prepares after a decoder init failure instead of failing the pending result`() {
        val listener = capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall(), result)
        // Drop the prepare() that setClips itself issued.
        clearMocks(mockPlayer, answers = false, recordedCalls = true)

        val scheduled = slot<Runnable>()
        every { mockHandler.postDelayed(capture(scheduled), 350L) } returns true

        listener.onPlayerError(decoderInitError())

        // The pending result stays open for the retry; a delayed re-prepare is queued.
        verify(exactly = 0) { result.error(any(), any(), any()) }
        verify(exactly = 1) { mockHandler.postDelayed(any(), 350L) }

        // Running the queued task re-prepares the same player.
        scheduled.captured.run()
        verify(exactly = 1) { mockPlayer.prepare() }
    }

    @Test
    fun `onPlayerError fails the pending result after exhausting decoder retries`() {
        val listener = capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall(), result)

        // The first two errors each queue a re-prepare (MAX_DECODER_RETRIES = 2).
        listener.onPlayerError(decoderInitError())
        listener.onPlayerError(decoderInitError())
        verify(exactly = 0) { result.error(any(), any(), any()) }
        verify(exactly = 2) { mockHandler.postDelayed(any(), 350L) }

        // The third gives up and surfaces the error to Dart.
        listener.onPlayerError(decoderInitError("final boom"))
        verify(exactly = 1) {
            result.error("PLAYER_ERROR", "final boom", mapOf("errorCode" to "decoder_error"))
        }
    }

    @Test
    fun `setClips restores the decoder retry budget after exhaustion`() {
        val listener = capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall(), result)

        // Exhaust the budget without ever rendering a frame.
        listener.onPlayerError(decoderInitError())
        listener.onPlayerError(decoderInitError())
        listener.onPlayerError(decoderInitError("gave up"))
        verify(exactly = 1) {
            result.error("PLAYER_ERROR", "gave up", mapOf("errorCode" to "decoder_error"))
        }

        // A new clip load gets the full budget: the next decoder error is
        // retried instead of immediately failing the new pending result.
        val nextResult = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall(), nextResult)
        listener.onPlayerError(decoderInitError())

        verify(exactly = 0) { nextResult.error(any(), any(), any()) }
        verify(exactly = 3) { mockHandler.postDelayed(any(), 350L) }
    }

    @Test
    fun `superseding setClips cancels a pending decoder retry`() {
        val listener = capturePlayerListener()
        instance.onMethodCall(
            setClipsCall("file:///tmp/a.mp4"),
            mockk(relaxed = true),
        )
        clearMocks(mockHandler, answers = false, recordedCalls = true)

        val scheduled = slot<Runnable>()
        every { mockHandler.postDelayed(capture(scheduled), 350L) } returns true
        listener.onPlayerError(decoderInitError())

        instance.onMethodCall(
            setClipsCall("file:///tmp/b.mp4"),
            mockk(relaxed = true),
        )

        verify { mockHandler.removeCallbacks(scheduled.captured) }
    }

    @Test
    fun `stopForActivityDetach cancels a pending decoder retry before clearing the surface`() {
        val listener = capturePlayerListener()
        instance.onMethodCall(
            setClipsCall("file:///tmp/a.mp4"),
            mockk(relaxed = true),
        )
        clearMocks(mockHandler, mockPlayer, answers = false, recordedCalls = true)

        val scheduled = slot<Runnable>()
        every { mockHandler.postDelayed(capture(scheduled), 350L) } returns true
        listener.onPlayerError(decoderInitError())

        instance.stopForActivityDetach()

        verifyOrder {
            mockHandler.removeCallbacks(scheduled.captured)
            mockPlayer.stop()
            mockPlayer.clearVideoSurface()
        }
    }

    @Test
    fun `superseding setClips completes the previous result with CANCELLED`() {
        capturePlayerListener()
        val first = mockk<MethodChannel.Result>(relaxed = true)
        val second = mockk<MethodChannel.Result>(relaxed = true)

        instance.onMethodCall(setClipsCall("file:///tmp/a.mp4"), first)
        instance.onMethodCall(setClipsCall("file:///tmp/b.mp4"), second)

        verify(exactly = 1) {
            first.error("CANCELLED", "Superseded by newer setClips call", null)
        }
        verify(exactly = 0) { first.success(any()) }
        verify(exactly = 0) { second.success(any()) }
    }

    @Test
    fun `dispose completes pending setClips result so Dart is not left hanging`() {
        capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall(), result)

        instance.dispose()

        verify(exactly = 1) { result.success(null) }
    }

    // -- seekTo per-clip speed --

    /**
     * Regression test for the seek-backward speed bug:
     * Clip 0 at 3× (source 3 s → 1 s on the timeline),
     * clip 1 at 0.25× (source 4 s → 16 s on the timeline).
     *
     * After setClips the player is at clip 0.  When the user seeks to a
     * position inside clip 0 the player must apply clip 0's speed (3×),
     * NOT whatever speed was last active before the seek.
     */
    @Test
    fun `seekTo applies the target clip speed so seeking backward from slow clip restores fast clip speed`() {
        capturePlayerListener()

        // Clip 0: 3 s source at 3× → 1 000 ms of playback timeline (offset 0..1000).
        // Clip 1: 4 s source at 0.25× → 16 000 ms of playback timeline (offset 1000..17000).
        instance.onMethodCall(
            MethodCall(
                "setClips",
                mapOf(
                    "clips" to listOf(
                        mapOf(
                            "uri" to "file:///a.mp4",
                            "startMs" to 0,
                            "endMs" to 3000,
                            "playbackSpeed" to 3.0,
                        ),
                        mapOf(
                            "uri" to "file:///b.mp4",
                            "startMs" to 0,
                            "endMs" to 4000,
                            "playbackSpeed" to 0.25,
                        ),
                    ),
                ),
            ),
            mockk(relaxed = true),
        )

        // Discard calls made by setClips so only the seekTo invocation is verified.
        clearMocks(mockPlayer, answers = false, recordedCalls = true)

        // Seek to global 500 ms → resolves to clip 0 (offset range 0–1000 ms).
        instance.onMethodCall(
            MethodCall("seekTo", mapOf("positionMs" to 500)),
            mockk(relaxed = true),
        )

        // Clip 0's speed (3×) must be applied.
        verify { mockPlayer.setPlaybackParameters(PlaybackParameters(3.0f)) }
        // Clip 1's speed must NOT be applied.
        verify(exactly = 0) { mockPlayer.setPlaybackParameters(PlaybackParameters(0.25f)) }
    }

    // -- common-track-end clamp resolution --

    private fun loopingCall(looping: Boolean): MethodCall =
        MethodCall("setLooping", mapOf("looping" to looping))

    private fun twoClipSetClipsCall(): MethodCall =
        MethodCall(
            "setClips",
            mapOf(
                "clips" to listOf(
                    mapOf("uri" to "file:///tmp/a.mp4", "startMs" to 0, "endMs" to 1000),
                    mapOf("uri" to "file:///tmp/b.mp4", "startMs" to 0, "endMs" to 1000),
                ),
            ),
        )

    @Test
    fun `a clip list that grows leaves single-clip repeat behind`() {
        instance.onMethodCall(setClipsCall(), mockk(relaxed = true))
        instance.onMethodCall(loopingCall(looping = true), mockk(relaxed = true))

        verify { mockPlayer.repeatMode = Player.REPEAT_MODE_ONE }

        // The editor swaps its clip list without calling setLooping again — a
        // split turns one clip into two. A repeat mode left on the single-clip
        // setting would repeat the first clip forever instead of walking the
        // timeline.
        instance.onMethodCall(twoClipSetClipsCall(), mockk(relaxed = true))

        verify { mockPlayer.repeatMode = Player.REPEAT_MODE_ALL }
    }

    /**
     * Records the audio-renderer selections the instance makes, newest last.
     *
     * `true` means the player's own audio was switched off in favour of the
     * private loop track.
     */
    private fun captureAudioTrackDisables(): List<Boolean> {
        val params = mockk<TrackSelectionParameters>(relaxed = true)
        val builder = mockk<TrackSelectionParameters.Builder>(relaxed = true)
        val disabled = mutableListOf<Boolean>()
        every { mockPlayer.trackSelectionParameters } returns params
        every { params.buildUpon() } returns builder
        every { builder.build() } returns params
        every {
            builder.setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, capture(disabled))
        } returns builder
        return disabled
    }

    @Test
    fun `a clip whose audio will not decode gets the player's audio back`() {
        mockkObject(ClipAudioLoopTrack.Companion)
        try {
            every { ClipAudioLoopTrack.create(any(), any(), any()) } returns null
            every { mockPlayer.duration } returns 3_000L
            val disabled = captureAudioTrackDisables()

            instance.onMethodCall(setClipsCall(), mockk(relaxed = true))
            instance.onMethodCall(loopingCall(looping = true), mockk(relaxed = true))
            capturePostedRunnables().forEach { it.run() }

            // The renderer is switched off before the decode is attempted, so a
            // decode that yields nothing has to switch it back on. Leaving it
            // off plays the video silent for the rest of its life.
            assertEquals(true, disabled.contains(true))
            assertEquals(false, disabled.last())
        } finally {
            unmockkObject(ClipAudioLoopTrack.Companion)
        }
    }

    @Test
    fun `a fresh clip list waits for its own timeline before cutting the audio`() {
        mockkObject(ClipAudioLoopTrack.Companion)
        try {
            every { ClipAudioLoopTrack.create(any(), any(), any()) } returns null
            // A reused player still holds the outgoing item while the new clips
            // are applied, so its duration describes that one.
            every { mockPlayer.duration } returns 3_000L
            captureAudioTrackDisables()
            val listener = capturePlayerListener()

            instance.onMethodCall(loopingCall(looping = true), mockk(relaxed = true))
            instance.onMethodCall(setClipsCall(), mockk(relaxed = true))

            // Cutting to that duration here would loop the incoming video's
            // sound at the previous video's length, drifting a little further
            // from the picture every lap.
            verify(exactly = 0) { ClipAudioLoopTrack.create(any(), any(), any()) }

            listener.onPlaybackStateChanged(Player.STATE_READY)

            verify(exactly = 1) { ClipAudioLoopTrack.create(any(), any(), any()) }
        } finally {
            unmockkObject(ClipAudioLoopTrack.Companion)
        }
    }

    @Test
    fun `an off-speed player keeps its own audio`() {
        mockkObject(ClipAudioLoopTrack.Companion)
        try {
            every { ClipAudioLoopTrack.create(any(), any(), any()) } returns null
            every { mockPlayer.duration } returns 3_000L
            val disabled = captureAudioTrackDisables()

            instance.onMethodCall(
                MethodCall("setPlaybackSpeed", mapOf("speed" to 2.0)),
                mockk(relaxed = true),
            )
            instance.onMethodCall(setClipsCall(), mockk(relaxed = true))
            instance.onMethodCall(loopingCall(looping = true), mockk(relaxed = true))

            // A static track plays the recording at its own rate, so it would
            // drift away from a picture running at twice the speed.
            verify(exactly = 0) { ClipAudioLoopTrack.create(any(), any(), any()) }
            assertEquals(false, disabled.contains(true))
        } finally {
            unmockkObject(ClipAudioLoopTrack.Companion)
        }
    }

    /**
     * Brings a looping single clip up with [loop] installed as its private
     * audio path, and hands back the player listener the instance registered.
     */
    private fun installLoopTrack(loop: ClipAudioLoopTrack): Player.Listener {
        every { ClipAudioLoopTrack.create(any(), any(), any()) } returns loop
        every { mockPlayer.duration } returns 3_000L
        captureAudioTrackDisables()
        val listener = capturePlayerListener()

        instance.onMethodCall(setClipsCall(), mockk(relaxed = true))
        instance.onMethodCall(loopingCall(looping = true), mockk(relaxed = true))
        capturePostedRunnables().forEach { it.run() }
        return listener
    }

    @Test
    fun `a pause the player makes by itself pauses the loop track too`() {
        mockkObject(ClipAudioLoopTrack.Companion)
        try {
            val loop = mockk<ClipAudioLoopTrack>(relaxed = true)
            val listener = installLoopTrack(loop)
            every { mockPlayer.currentPosition } returns 1_250L
            every { mockPlayer.volume } returns 0.5f

            // Backgrounding, a buffering stall and an Activity detach all stop
            // the player without a `pause` from Dart. The track has to follow,
            // or it keeps sounding over a still picture.
            listener.onIsPlayingChanged(false)

            verify(exactly = 1) { loop.pause() }

            // And it picks up from where the picture now is, at the player's
            // own volume, when playback resumes.
            listener.onIsPlayingChanged(true)

            verify(exactly = 1) { loop.play(1_250L, 0.5f) }
        } finally {
            unmockkObject(ClipAudioLoopTrack.Companion)
        }
    }

    @Test
    fun `stopForActivityDetach releases the loop track`() {
        mockkObject(ClipAudioLoopTrack.Companion)
        try {
            val loop = mockk<ClipAudioLoopTrack>(relaxed = true)
            installLoopTrack(loop)

            // Nothing resumes after a detach, so the AudioTrack is freed here
            // rather than kept until dispose.
            instance.stopForActivityDetach()

            verify(exactly = 1) { loop.release() }
        } finally {
            unmockkObject(ClipAudioLoopTrack.Companion)
        }
    }

    private fun trimmingSetClipsCall(uri: String): MethodCall =
        MethodCall(
            "setClips",
            mapOf(
                "clips" to listOf(
                    mapOf(
                        "uri" to uri,
                        "startMs" to 0,
                        "trimToCommonTrackEnd" to true,
                    ),
                ),
            ),
        )

    /** The [Runnable]s handed to [mockHandler] via `post`, in order. */
    private fun capturePostedRunnables(): List<Runnable> {
        val posted = mutableListOf<Runnable>()
        verify { mockHandler.post(capture(posted)) }
        return posted
    }

    /**
     * A [BufferProfile.FEED] player over the same mocks as [instance] — the
     * one surface whose remote track lengths warm behind the load instead of
     * in front of it.
     */
    private fun feedInstance(): DivineVideoPlayerInstance =
        DivineVideoPlayerInstance(
            messenger = messenger,
            context = context,
            playerId = 3,
            playerFactory = { _ -> mockPlayer },
            mainHandler = mockHandler,
            audioOverlayManagerFactory = { _ -> mockAudioManager },
            bufferProfile = BufferProfile.FEED,
            metadataExecutor = DirectExecutorService(),
        )

    @Test
    fun `setClips waits for the track lengths before touching the player`() {
        val result = mockk<MethodChannel.Result>(relaxed = true)

        instance.onMethodCall(trimmingSetClipsCall("file:///tmp/a.mp4"), result)

        // The metadata read ran, but applying is posted back to the platform
        // thread — nothing may reach the player until that lands.
        verify(exactly = 0) { mockPlayer.setMediaItems(any(), any(), any()) }

        capturePostedRunnables().forEach { it.run() }

        verify(exactly = 1) { mockPlayer.setMediaItems(any(), any(), any()) }
    }

    @Test
    fun `a resolution that lands after a newer setClips is dropped`() {
        val stale = mockk<MethodChannel.Result>(relaxed = true)
        val fresh = mockk<MethodChannel.Result>(relaxed = true)

        instance.onMethodCall(trimmingSetClipsCall("file:///tmp/stale.mp4"), stale)
        val afterStale = capturePostedRunnables().size

        instance.onMethodCall(trimmingSetClipsCall("file:///tmp/fresh.mp4"), fresh)
        val posted = capturePostedRunnables()

        // Run the newer continuation first, then the superseded one: the
        // stale clips must not be applied over the clips that replaced them.
        posted.drop(afterStale).forEach { it.run() }
        posted.take(afterStale).forEach { it.run() }

        verify(exactly = 1) { mockPlayer.setMediaItems(any(), any(), any()) }
    }

    @Test
    fun `a superseded setClips still answers its caller`() {
        val stale = mockk<MethodChannel.Result>(relaxed = true)
        val fresh = mockk<MethodChannel.Result>(relaxed = true)

        instance.onMethodCall(trimmingSetClipsCall("file:///tmp/one.mp4"), stale)
        instance.onMethodCall(trimmingSetClipsCall("file:///tmp/two.mp4"), fresh)
        capturePostedRunnables().forEach { it.run() }

        // Dropping the superseded result leaves `await setClips()` pending for
        // the life of the app; the feed's failover state stays pinned on that
        // index and never recovers. CANCELLED is the code the Dart controller
        // already swallows.
        verify(exactly = 1) { stale.error("CANCELLED", any(), any()) }
        verify(exactly = 0) { stale.success(any()) }
    }

    @Test
    fun `dispose answers a setClips still waiting on the track lengths`() {
        val result = mockk<MethodChannel.Result>(relaxed = true)

        instance.onMethodCall(trimmingSetClipsCall("file:///tmp/gone.mp4"), result)
        instance.dispose()
        capturePostedRunnables().forEach { it.run() }

        verify(exactly = 1) { result.error("CANCELLED", any(), any()) }
    }

    @Test
    fun `clips are applied unclamped when the track lengths never arrive`() {
        val result = mockk<MethodChannel.Result>(relaxed = true)
        // An executor that accepts work and never runs it: a metadata read that
        // never returns. Nothing below this bounds the wait.
        val stalled = DivineVideoPlayerInstance(
            messenger = messenger,
            context = context,
            playerId = 2,
            playerFactory = { _ -> mockPlayer },
            mainHandler = mockHandler,
            audioOverlayManagerFactory = { _ -> mockAudioManager },
            metadataExecutor = StalledExecutorService(),
        )

        stalled.onMethodCall(trimmingSetClipsCall("file:///tmp/stalled.mp4"), result)
        verify(exactly = 0) { mockPlayer.setMediaItems(any(), any(), any()) }

        val deadline = mutableListOf<Runnable>()
        verify {
            mockHandler.postDelayed(
                capture(deadline),
                DivineVideoPlayerInstance.TRACK_DURATION_RESOLVE_TIMEOUT_MS,
            )
        }
        deadline.forEach { it.run() }

        // A seam is worse than a load that never finishes is worse.
        verify(exactly = 1) { mockPlayer.setMediaItems(any(), any(), any()) }
        verify(exactly = 0) { result.error(any(), any(), any()) }

        stalled.onMethodCall(trimmingSetClipsCall("file:///tmp/next.mp4"), mockk(relaxed = true))
        // Once a read times out, the instance stops queueing metadata work and
        // future loads play immediately instead of paying the same deadline.
        verify(exactly = 2) { mockPlayer.setMediaItems(any(), any(), any()) }
    }

    @Test
    fun `a feed player starts a remote source immediately while track lengths warm in the background`() {
        val result = mockk<MethodChannel.Result>(relaxed = true)

        feedInstance().onMethodCall(trimmingSetClipsCall("https://cdn.example/remote.mp4"), result)

        // Remote MediaExtractor reads add a second connection to the feed's
        // first-frame path, so they must not sit in front of the playlist swap.
        verify(exactly = 1) { mockPlayer.setMediaItems(any(), any(), any()) }
        // The same read still runs and posts a continuation that can tighten
        // the current playlist if the metadata lands before the first loop.
        verify(exactly = 1) { mockHandler.post(any()) }
    }

    @Test
    fun `a full-buffer player reads a remote source's track lengths before the load`() {
        val result = mockk<MethodChannel.Result>(relaxed = true)

        withTrackDurations(videoUs = 6_000_000L, audioUs = 6_040_000L) {
            instance.onMethodCall(trimmingSetClipsCall("https://cdn.example/preview.mp4"), result)

            // A preview plays on tap, so nothing sits paused for a background
            // warm to tighten later: the read has to land before the swap or
            // the play the user just started keeps its seam (#8897).
            verify(exactly = 0) { mockPlayer.setMediaItems(any(), any(), any()) }

            capturePostedRunnables().forEach { it.run() }
        }

        val applied = slot<List<MediaItem>>()
        verify(exactly = 1) { mockPlayer.setMediaItems(capture(applied), any(), any()) }
        assertEquals(6_000L, applied.captured.single().clippingConfiguration.endPositionMs)
        verify(exactly = 0) { mockPlayer.replaceMediaItem(any(), any()) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    /**
     * Runs [block] with `MediaExtractor` reporting one video and one audio
     * track of the given lengths, so a remote probe resolves to a real clamp
     * instead of the stubbed "no tracks" answer the other tests get.
     */
    private fun withTrackDurations(videoUs: Long, audioUs: Long, block: () -> Unit) {
        val video = mockk<MediaFormat>(relaxed = true)
        val audio = mockk<MediaFormat>(relaxed = true)
        every { video.getString(MediaFormat.KEY_MIME) } returns "video/avc"
        every { video.containsKey(MediaFormat.KEY_DURATION) } returns true
        every { video.getLong(MediaFormat.KEY_DURATION) } returns videoUs
        every { audio.getString(MediaFormat.KEY_MIME) } returns "audio/mp4a-latm"
        every { audio.containsKey(MediaFormat.KEY_DURATION) } returns true
        every { audio.getLong(MediaFormat.KEY_DURATION) } returns audioUs

        mockkConstructor(android.media.MediaExtractor::class)
        try {
            every {
                anyConstructed<android.media.MediaExtractor>()
                    .setDataSource(any<String>(), any<Map<String, String>>())
            } just runs
            every { anyConstructed<android.media.MediaExtractor>().trackCount } returns 2
            every { anyConstructed<android.media.MediaExtractor>().getTrackFormat(0) } returns video
            every { anyConstructed<android.media.MediaExtractor>().getTrackFormat(1) } returns audio
            block()
        } finally {
            unmockkConstructor(android.media.MediaExtractor::class)
        }
    }

    @Test
    fun `a resolved clamp tightens a playlist that has not started`() {
        every { mockPlayer.mediaItemCount } returns 1
        every { mockPlayer.getMediaItemAt(0) } returns MediaItem.Builder().build()

        withTrackDurations(videoUs = 6_000_000L, audioUs = 6_040_000L) {
            feedInstance().onMethodCall(
                trimmingSetClipsCall("https://cdn.example/warm.mp4"),
                mockk(relaxed = true),
            )
            capturePostedRunnables().forEach { it.run() }
        }

        // A preloaded tile sits paused at frame zero, so swapping the item for
        // a clamped one costs nothing the viewer can see.
        val replaced = slot<MediaItem>()
        verify { mockPlayer.replaceMediaItem(0, capture(replaced)) }
        assertEquals(6_000L, replaced.captured.clippingConfiguration.endPositionMs)
    }

    /** A [Player.PositionInfo] carrying only the field the listener reads. */
    private fun positionInfo(mediaItemIndex: Int): Player.PositionInfo =
        Player.PositionInfo(
            /* windowUid = */ null,
            /* mediaItemIndex = */ mediaItemIndex,
            /* mediaItem = */ null,
            /* periodUid = */ null,
            /* periodIndex = */ mediaItemIndex,
            /* positionMs = */ 0L,
            /* contentPositionMs = */ 0L,
            /* adGroupIndex = */ C.INDEX_UNSET,
            /* adIndexInAdGroup = */ C.INDEX_UNSET,
        )

    @Test
    fun `a resolved clamp is parked rather than applied mid-watch`() {
        every { mockPlayer.mediaItemCount } returns 1
        every { mockPlayer.getMediaItemAt(0) } returns MediaItem.Builder().build()
        every { mockPlayer.playWhenReady } returns true

        withTrackDurations(videoUs = 6_000_000L, audioUs = 6_040_000L) {
            feedInstance().onMethodCall(
                trimmingSetClipsCall("https://cdn.example/playing.mp4"),
                mockk(relaxed = true),
            )
            capturePostedRunnables().forEach { it.run() }
        }

        // A clipping configuration cannot be updated in place, so applying it
        // here would remove and re-insert the period being played and restart
        // the video from zero mid-watch — worse than the seam it removes.
        verify(exactly = 0) { mockPlayer.replaceMediaItem(any(), any()) }
    }

    @Test
    fun `a parked clamp is applied at the loop restart`() {
        every { mockPlayer.mediaItemCount } returns 1
        every { mockPlayer.getMediaItemAt(0) } returns MediaItem.Builder().build()
        every { mockPlayer.playWhenReady } returns true
        val listenerSlot = slot<Player.Listener>()
        every { mockPlayer.addListener(capture(listenerSlot)) } just runs

        withTrackDurations(videoUs = 6_000_000L, audioUs = 6_040_000L) {
            feedInstance().onMethodCall(
                trimmingSetClipsCall("https://cdn.example/playing.mp4"),
                mockk(relaxed = true),
            )
            capturePostedRunnables().forEach { it.run() }
        }
        verify(exactly = 0) { mockPlayer.replaceMediaItem(any(), any()) }

        // A single repeating clip reports the same media item index on both
        // sides of the restart, which is why the clamp hook sits outside the
        // index guard the speed/volume block uses.
        listenerSlot.captured.onPositionDiscontinuity(
            positionInfo(mediaItemIndex = 0),
            positionInfo(mediaItemIndex = 0),
            Player.DISCONTINUITY_REASON_AUTO_TRANSITION,
        )

        val replaced = slot<MediaItem>()
        verify { mockPlayer.replaceMediaItem(0, capture(replaced)) }
        assertEquals(6_000L, replaced.captured.clippingConfiguration.endPositionMs)
    }

    @Test
    fun `a parked clamp is applied only once`() {
        every { mockPlayer.mediaItemCount } returns 1
        every { mockPlayer.getMediaItemAt(0) } returns MediaItem.Builder().build()
        every { mockPlayer.playWhenReady } returns true
        val listenerSlot = slot<Player.Listener>()
        every { mockPlayer.addListener(capture(listenerSlot)) } just runs

        withTrackDurations(videoUs = 6_000_000L, audioUs = 6_040_000L) {
            feedInstance().onMethodCall(
                trimmingSetClipsCall("https://cdn.example/playing.mp4"),
                mockk(relaxed = true),
            )
            capturePostedRunnables().forEach { it.run() }
        }

        repeat(3) {
            listenerSlot.captured.onPositionDiscontinuity(
                positionInfo(mediaItemIndex = 0),
                positionInfo(mediaItemIndex = 0),
                Player.DISCONTINUITY_REASON_AUTO_TRANSITION,
            )
        }

        // Every later lap must cost nothing: re-installing the same clipping
        // configuration would rebuild the period at each loop, which is the
        // stutter the clamp exists to remove.
        verify(exactly = 1) { mockPlayer.replaceMediaItem(0, any()) }
    }

    @Test
    fun `a parked clamp is not applied on a seek`() {
        every { mockPlayer.mediaItemCount } returns 1
        every { mockPlayer.getMediaItemAt(0) } returns MediaItem.Builder().build()
        every { mockPlayer.playWhenReady } returns true
        val listenerSlot = slot<Player.Listener>()
        every { mockPlayer.addListener(capture(listenerSlot)) } just runs

        withTrackDurations(videoUs = 6_000_000L, audioUs = 6_040_000L) {
            feedInstance().onMethodCall(
                trimmingSetClipsCall("https://cdn.example/playing.mp4"),
                mockk(relaxed = true),
            )
            capturePostedRunnables().forEach { it.run() }
        }

        // A seek lands anywhere, so the remove-and-insert would drop playback
        // back to the default position — the mid-watch restart the parking
        // exists to avoid.
        listenerSlot.captured.onPositionDiscontinuity(
            positionInfo(mediaItemIndex = 0),
            positionInfo(mediaItemIndex = 0),
            Player.DISCONTINUITY_REASON_SEEK,
        )

        verify(exactly = 0) { mockPlayer.replaceMediaItem(any(), any()) }
    }

    @Test
    fun `a source that reads as having no track pair is not probed again`() {
        val uri = "https://cdn.example/no-pair.mp4"

        // MediaExtractor is stubbed to defaults here, so it reports no tracks
        // — the same shape as a genuinely audio-only source. That answer is
        // about the source and does not change, so it is cached.
        instance.onMethodCall(trimmingSetClipsCall(uri), mockk(relaxed = true))
        capturePostedRunnables().forEach { it.run() }
        val afterFirst = capturePostedRunnables().size

        instance.onMethodCall(trimmingSetClipsCall(uri), mockk(relaxed = true))

        // Answered from the cache, so nothing is deferred: the clips reach the
        // player without a second continuation.
        assertEquals(afterFirst, capturePostedRunnables().size)
        verify(exactly = 2) { mockPlayer.setMediaItems(any(), any(), any()) }
    }

    @Test
    fun `a read that threw is probed again rather than cached as unreadable`() {
        val uri = "https://cdn.example/flaky.mp4"
        mockkConstructor(android.media.MediaExtractor::class)
        try {
            every {
                anyConstructed<android.media.MediaExtractor>()
                    .setDataSource(any<String>(), any<Map<String, String>>())
            } throws IOException("connection reset")

            instance.onMethodCall(trimmingSetClipsCall(uri), mockk(relaxed = true))
            capturePostedRunnables().forEach { it.run() }
            val afterFirst = capturePostedRunnables().size

            instance.onMethodCall(trimmingSetClipsCall(uri), mockk(relaxed = true))

            // A socket reset says nothing about the source. Caching it as
            // unreadable would disable the loop-seam clamp for this URL for
            // the rest of the process — the LRU is access-ordered, so the
            // entry is re-promoted on every replay and never even evicts.
            assertEquals(afterFirst + 1, capturePostedRunnables().size)
        } finally {
            unmockkConstructor(android.media.MediaExtractor::class)
        }
    }

    @Test
    fun `an HLS source reaches the player without being probed`() {
        val result = mockk<MethodChannel.Result>(relaxed = true)

        instance.onMethodCall(
            trimmingSetClipsCall("https://cdn.example/abc/hls/master.m3u8?token=t"),
            result,
        )

        // MediaExtractor has no HLS extractor, so probing a playlist can only
        // throw — and a throw is not cached, so deferring for one would pay a
        // doomed fetch on every setClips for that source.
        verify(exactly = 1) { mockPlayer.setMediaItems(any(), any(), any()) }
        verify(exactly = 0) { mockHandler.post(any()) }
    }

    @Test
    fun `a source without both track types is applied unclamped`() {
        val result = mockk<MethodChannel.Result>(relaxed = true)

        // MediaExtractor is stubbed in unit tests, so it reports no tracks —
        // the same shape as an audio-only or unreadable source. That must
        // still reach the player rather than stranding the Dart call.
        instance.onMethodCall(trimmingSetClipsCall("https://cdn.example/b.mp4"), result)
        capturePostedRunnables().forEach { it.run() }

        verify(exactly = 1) { mockPlayer.setMediaItems(any(), any(), any()) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }
}

/** Accepts work and never runs it — a metadata read that never returns. */
private class StalledExecutorService : java.util.concurrent.AbstractExecutorService() {
    private var stopped = false

    override fun execute(command: Runnable) = Unit

    override fun shutdown() {
        stopped = true
    }

    override fun shutdownNow(): MutableList<Runnable> {
        stopped = true
        return mutableListOf()
    }

    override fun isShutdown(): Boolean = stopped

    override fun isTerminated(): Boolean = stopped

    override fun awaitTermination(
        timeout: Long,
        unit: java.util.concurrent.TimeUnit,
    ): Boolean = true
}

/** Runs submitted work on the calling thread so tests stay deterministic. */
private class DirectExecutorService : java.util.concurrent.AbstractExecutorService() {
    private var stopped = false

    override fun execute(command: Runnable) = command.run()

    override fun shutdown() {
        stopped = true
    }

    override fun shutdownNow(): MutableList<Runnable> {
        stopped = true
        return mutableListOf()
    }

    override fun isShutdown(): Boolean = stopped

    override fun isTerminated(): Boolean = stopped

    override fun awaitTermination(
        timeout: Long,
        unit: java.util.concurrent.TimeUnit,
    ): Boolean = true
}
