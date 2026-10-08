package com.divinevideo.divine_video_player

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.Surface
import java.net.URI
import java.util.Collections
import kotlin.math.abs
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.ThreadFactory
import android.graphics.Bitmap
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import androidx.media3.common.C
import androidx.media3.common.util.Size
import androidx.media3.exoplayer.Renderer
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.Timeline
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.HttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.PlayerMessage
import androidx.media3.exoplayer.SeekParameters
import androidx.media3.exoplayer.video.VideoFrameMetadataListener
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.extractor.DefaultExtractorsFactory
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Wraps a single ExoPlayer instance and bridges it to Dart via
 * per-player [MethodChannel] and [EventChannel].
 *
 * Clips are set as a playlist of [MediaItem]s with clipping
 * configuration. ExoPlayer handles seamless playback between items
 * and native buffering automatically.
 */
@UnstableApi
internal class DivineVideoPlayerInstance(
    messenger: BinaryMessenger,
    private val context: Context,
    private val playerId: Int,
    /** Names the screen that owns this player, as sent by the Dart side. */
    private val debugLabel: String? = null,
    private val playerFactory: ((Context) -> ExoPlayer)? = null,
    private val bufferProfile: BufferProfile = BufferProfile.FULL,
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
    private val audioOverlayManagerFactory: (Context) -> AudioOverlayManager = { ctx ->
        AudioOverlayManager(ctx)
    },
    /**
     * Decodes a looping clip's audio off the platform thread. Single-threaded,
     * so two decodes for the same player cannot interleave.
     */
    private val metadataExecutor: ExecutorService =
        Executors.newSingleThreadExecutor(metadataThreadFactory(playerId)),
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    TextureRegistry.SurfaceProducer.Callback {

    private val methodChannel = MethodChannel(
        messenger,
        "divine_video_player/player_$playerId",
    )
    private val eventChannel = EventChannel(
        messenger,
        "divine_video_player/player_$playerId/events",
    )

    private var player: ExoPlayer? = null
    private var eventSink: EventChannel.EventSink? = null
    private var httpHeadersByUri = emptyMap<String, Map<String, String>>()

    // Viewer auth headers keyed by blob hash. HLS sub-playlist / segment
    // requests use URIs that differ from the clip URI but share the same
    // /<hash>/… prefix; BUD-01 (kind 24242) tokens are hash-bound, so one header
    // set authenticates every variant of a hash. Used when the exact-URI lookup
    // misses (e.g. HLS segments derived from an authenticated manifest).
    private var httpHeadersByHash = emptyMap<String, Map<String, String>>()

    // Texture rendering (non-null when useTexture is enabled).
    //
    // Two backends are supported and selected per player at
    // [enableTextureOutput] time:
    //  * [TextureRegistry.SurfaceProducer] (default): Android 14+ ImageReader
    //    backend. Forwards Surface destroy/recreate events via the
    //    [TextureRegistry.SurfaceProducer.Callback] callback so playback can
    //    survive OEM compositor events (Vivo/Android 16, permission dialogs).
    //    Has a small (3–4) hardcoded buffer pool which can leak a stale
    //    frame across decoder format reprobes — visible as a 1-frame ghost
    //    when many players coexist (the feed). See #3416 / feed flicker.
    //  * [TextureRegistry.SurfaceTextureEntry] (legacy): single-buffer
    //    SurfaceTexture. No surface-recreate callback, but no shared pool
    //    either, so it is immune to the cross-decoder ghost-frame issue.
    //    Used by callers that render many players at once (the feed).
    //
    // Exactly one of these is non-null after [enableTextureOutput].
    private var surfaceProducer: TextureRegistry.SurfaceProducer? = null
    private var legacyEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var legacySurface: Surface? = null

    /**
     * True when ExoPlayer needs a surface re-attached.
     * Set to true on init and after [onSurfaceCleanup]; cleared in [onSurfaceAvailable].
     * Only meaningful for the [surfaceProducer] backend — the legacy
     * SurfaceTexture surface is always available for the lifetime of the
     * player.
     */
    private var needsSurface = true

    /** The currently active output Surface across both backends. */
    private val activeSurface: Surface?
        get() = legacySurface ?: surfaceProducer?.surface

    /**
     * Whether the active backend already applies the GL transform matrix
     * for video rotation (so Dart must NOT also apply RotatedBox).
     * True for legacy SurfaceTexture (transform is encoded in the texture)
     * and for SurfaceProducer when [TextureRegistry.SurfaceProducer.handlesCropAndRotation]
     * reports true.
     */
    private val backendHandlesRotation: Boolean
        get() = legacyEntry != null ||
            (surfaceProducer?.handlesCropAndRotation() == true)

    /**
     * Accumulated per-clip start offsets on the global timeline, expressed
     * in playback (speed-adjusted) time — i.e. the same coordinate space
     * Dart uses for the editor timeline. Source duration is divided by the
     * clip's playback speed (slower → longer on the timeline).
     */
    private var clipOffsets = listOf<Long>()
    /**
     * Per-clip audio volumes, above 1.0 when boosted. Multiplied by [volume]
     * on each clip transition; see [applyClipVolume].
     */
    private var clipVolumes = listOf<Float>()
    /** Per-clip playback speed multipliers (1.0 = normal). Never zero. */
    private var clipSpeeds = listOf<Float>()
    private var clipCount = 0
    /** The clip's audio, played outside ExoPlayer. See [ClipAudioLoopTrack]. */
    private var clipAudioLoop: ClipAudioLoopTrack? = null

    /** Guards a decode that finishes after its clips were replaced. */
    private var clipAudioGeneration = 0

    /** Set when the audio loop is waiting for a readable duration. */
    private var clipAudioPending = false

    /** Set when the audio loop is waiting for the player to finish loading. */
    private var clipAudioAwaitingLoad = false

    /** A loop fading in over ExoPlayer's audio. See [ClipAudioTakeover]. */
    private var clipAudioTakeover: ClipAudioTakeover? = null

    /**
     * The clips last handed over.
     *
     * Dart sends `setLooping` as its own call *after* `setClips`, so whether
     * this player loops is not yet known while the clips are applied.
     */
    private var lastClipsRaw: List<Map<String, Any?>> = emptyList()

    /**
     * The frame effects Dart switched on, shared with the effect stage on the
     * player's GL thread. Null until `setFrameEffects` first asks for one:
     * only then does the player route its frames through that stage, so a
     * player without frame effects plays exactly as before.
     */
    private var frameEffectsState: FrameEffectsState? = null

    /**
     * The display size of the clip playing, which the frame-effect stage
     * needs as its output size. Kept apart from [videoWidth] / [videoHeight],
     * which a stop or seek resets to 0 for a moment.
     */
    private var frameEffectOutputSize: Size? = null

    /** The size reported to Dart while frame effects draw the frames. */
    private val frameEffectReportedSize: Size?
        get() = if (frameEffectsState != null) frameEffectOutputSize else null

    /** The buffer size the output surface was set to for frame effects. */
    private var frameEffectSurfaceSize: Size? = null

    /** Decodes the earlier frames frame effects need after a seek. */
    private val frameEffectsFillExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()

    /**
     * The display size of each clip, read from its file. With the effect
     * stage installed Media3 reports no video size, so the stage's output
     * follows the clip playing from these instead.
     */
    private val frameEffectClipSizes = HashMap<Int, Size?>()

    /** The newest seek, as clip and local source ms, still to be decoded for frame effects. */
    @Volatile
    private var frameEffectsFillRequest: Pair<Int, Long>? = null

    /** The seek being decoded for frame effects now. */
    private var frameEffectsFillRunning: Pair<Int, Long>? = null

    /** The last seek frame effects heard of, which a redraw returns to. */
    private var frameEffectsSeekTarget: Pair<Int, Long>? = null
    private var lastFrameEffectsSeekMs = 0L

    private var isLooping = false

    /** Whether a lap restarted by [loopsBySeeking] is still buffering its start. */
    private var restartingLap = false

    /** The position the loop fade-in is anchored at, for tests. */
    internal val declickStreamStartUsForTesting: Long
        get() = declickProcessor.nextStreamStartUs

    /**
     * Identifies this player in diagnostic logs.
     *
     * Mirrors the Dart side's `_logTarget` so a `Player 665404 (feed[0])`
     * line reads the same whichever half of the channel emitted it.
     */
    private val logTarget: String =
        if (debugLabel == null) "Player $playerId" else "Player $playerId ($debugLabel)"

    private var volume = 1.0
    private var speed = 1.0
    private var firstFrameRendered = false

    /**
     * Consecutive re-prepare attempts made after a transient decoder error,
     * reset once a frame renders or a new clip list is loaded. Bounds
     * [maybeRecoverFromDecoderError] so a genuinely undecodable clip can't
     * spin in a prepare/error loop.
     */
    private var decoderRetryCount = 0
    private var decoderRetryRunnable: Runnable? = null
    private var videoWidth = 0
    private var videoHeight = 0
    private var pixelWidthHeightRatio = 1.0
    private var rotationDegrees = 0

    /**
     * True only during the synchronous stop→clearMediaItems→setMediaItems→prepare
     * sequence inside [handleSetClips]. Suppresses [sendStateUpdate] so the
     * spurious STATE_IDLE / position-0 event from [ExoPlayer.stop] is never
     * forwarded to Dart, preventing the timeline from jumping back to 0.
     */
    private var isResettingPlayer = false

    /**
     * Non-zero while ExoPlayer is buffering toward an initial seek position
     * set via [handleSetClips]. [sendStateUpdate] reports this value instead
     * of the intermediate buffering position so the timeline stays at the
     * target position until STATE_READY confirms the seek is complete.
     * Cleared to 0 on the first STATE_READY after a [handleSetClips] call.
     */
    private var pendingGlobalStartMs: Long = 0L

    private val audioOverlayManager = audioOverlayManagerFactory(context)

    /**
     * Fades the outer edges of a looping video so its loop join is not a click
     * (#6468). Lives for the life of the instance because it is wired into the
     * renderers factory when the player is built.
     */
    private val declickProcessor = LoopDeclickAudioProcessor()

    /**
     * Carries the part of a clip's volume above 100 %, which the player's own
     * volume cannot; see [applyClipVolume].
     */
    private val playerBoost = AudioSessionBoost()

    /**
     * Pending result for an async seekTo call.
     * Completed when ExoPlayer transitions to STATE_READY after a seek,
     * so the Dart `await seekTo()` blocks until the frame is decoded.
     */
    private var seekCompletionResult: MethodChannel.Result? = null

    /**
     * Whether the pending paused seek still waits for its frame. Paused,
     * ExoPlayer reports STATE_READY before a clip's last frames leave the
     * decoder; completing there lets a scrub's next seek flush them unseen.
     *
     * The signal is a frame rendered after the seek has been applied, not
     * [Player.Listener.onRenderedFirstFrame]. That callback fires once per
     * surface, so a later scrub would wait out [seekTimeoutRunnable] while
     * the canvas holds the following seek.
     */
    @Volatile
    private var seekAwaitsFrame = false

    /**
     * The generation a playback-thread message queued after [ExoPlayer.seekTo]
     * armed, or [NO_ARMED_SEEK]. Frame callbacks post this snapshot rather than
     * re-reading [seekFrameGeneration], so a frame already in flight when a
     * newer seek starts carries the older generation and is ignored.
     */
    @Volatile
    private var armedSeekGeneration = NO_ARMED_SEEK

    /**
     * Bumped on each seek and on dispose. A frame callback posted for an
     * older seek must not complete the one that replaced it.
     */
    @Volatile
    private var seekFrameGeneration = 0

    /**
     * Fires on the playback thread for every frame about to be rendered.
     * Returns immediately unless a paused seek is armed, so feed playback
     * does not enqueue a main-thread task per frame.
     */
    private val renderedFrameListener = VideoFrameMetadataListener { _, _, _, _ ->
        val armed = armedSeekGeneration
        if (!seekAwaitsFrame || armed == NO_ARMED_SEEK) return@VideoFrameMetadataListener
        mainHandler.post { onSeekFrameRendered(armed) }
    }

    /** Safety timeout so Dart is never left hanging if the callback is lost. */
    private val seekTimeoutRunnable = Runnable {
        seekAwaitsFrame = false
        seekCompletionResult?.success(null)
        seekCompletionResult = null
    }

    /**
     * Pending result for an async setClips call.
     * Held until ExoPlayer transitions to STATE_READY (or reports an error),
     * so `await setClips()` on the Dart side only resolves once the decoder
     * is truly ready. Required for OEM decoders (e.g. Mediatek) that take
     * variable time to reach STATE_READY after prepare().
     */
    private var pendingSetClipsResult: MethodChannel.Result? = null

    /** Safety timeout so Dart is never left hanging if STATE_READY is lost. */
    private val setClipsTimeoutRunnable = Runnable {
        if (pendingSetClipsResult != null) {
            DivineVideoPlayerLog.warning(
                "$logTarget load froze: never reached ready within " +
                    "${SET_CLIPS_TIMEOUT_MS}ms",
                name = "DivineVideoPlayer.Freeze",
            )
        }
        pendingSetClipsResult?.error(
            "NOT_READY",
            "setClips timed out before player reached STATE_READY",
            null,
        )
        pendingSetClipsResult = null
    }

    /**
     * Fires when the player stays in `STATE_BUFFERING` past
     * [BUFFERING_STALL_MS] — the spinner is stuck and the video appears
     * frozen to the user. Reset whenever the player leaves the buffering
     * state so each stall episode is reported at most once.
     */
    private var bufferingStallReported = false
    private val bufferingWatchdogRunnable = Runnable {
        bufferingStallReported = true
        DivineVideoPlayerLog.warning(
            "$logTarget appears frozen: still buffering after " +
                "${BUFFERING_STALL_MS}ms",
            name = "DivineVideoPlayer.Freeze",
        )
    }

    private val positionUpdater = object : Runnable {
        override fun run() {
            updateFrameEffectWindows()
            syncAudioOverlays()
            sendStateUpdate()
            mainHandler.postDelayed(this, POSITION_UPDATE_INTERVAL_MS)
        }
    }

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    /**
     * Enables texture-based rendering for this player.
     *
     * Must be called before any clips are loaded. Returns the texture
     * ID that Dart should pass to the `Texture` widget.
     *
     * When [useLegacySurface] is `false` (default) this uses
     * [TextureRegistry.SurfaceProducer] so Android can notify us when
     * the underlying surface is destroyed and recreated (permission
     * dialogs, OEM compositor events on Vivo/Android 16).
     *
     * When [useLegacySurface] is `true` this uses the legacy
     * [TextureRegistry.SurfaceTextureEntry], which does not deliver
     * surface-recreate callbacks but is immune to the SurfaceProducer
     * ImageReader-pool ghost-frame issue: a sibling decoder's release
     * can leak a stale frame onto a peer's surface. That ghost last
     * reproduced on the Exynos C2 driver and did not on Flutter 3.47.2,
     * where the feed — its long-time user — moved back to
     * SurfaceProducer. The editor's paired players still opt in for their
     * own cross-player contamination case. Opt a screen in only when the
     * ghost is observed there; under Impeller the legacy surface also
     * costs a per-frame trampoline in the engine.
     */
    fun enableTextureOutput(
        registry: TextureRegistry,
        useLegacySurface: Boolean = false,
    ): Long {
        if (useLegacySurface) {
            val entry = registry.createSurfaceTexture()
            legacyEntry = entry
            val surface = Surface(entry.surfaceTexture())
            legacySurface = surface
            needsSurface = false
            player?.setVideoSurface(surface)
            sendFrameEffectOutputResolution()
            return entry.id()
        }
        val producer = registry.createSurfaceProducer()
        surfaceProducer = producer
        producer.setCallback(this)
        val surface = producer.surface
        needsSurface = surface == null
        if (surface != null) {
            player?.setVideoSurface(surface)
            sendFrameEffectOutputResolution()
        }
        return producer.id()
    }

    private fun ensurePlayer(): ExoPlayer {
        return player ?: (playerFactory?.invoke(context) ?: buildDefaultPlayer())
            .also { newPlayer ->
                player = newPlayer
                frameEffectsState?.let { newPlayer.setVideoEffects(listOf(FrameEffectsGlEffect(it))) }
                newPlayer.setSeekParameters(SeekParameters.EXACT)
                newPlayer.addListener(playerListener)
                newPlayer.setVideoFrameMetadataListener(renderedFrameListener)
                val surface = activeSurface
                if (surface != null) {
                    newPlayer.setVideoSurface(surface)
                    sendFrameEffectOutputResolution()
                    needsSurface = false
                }
            }
    }

    private fun buildDefaultPlayer(): ExoPlayer {
        // Fall back to an alternate (e.g. software) decoder when the preferred
        // hardware decoder fails to initialise. Turns a transient
        // DECODER_INIT_FAILED — common when feed + editor + preview + thumbnail
        // extraction contend for a small hardware decoder pool — into a
        // successful (if slower) decode instead of a dead surface.
        val renderersFactory =
            LoopDeclickRenderersFactory(context, declickProcessor)
                .setEnableDecoderFallback(true)
        // The player's own extractor records each source's track lengths as it
        // parses the container, and a clip tagged for it is clipped to where
        // the shorter track ends, and to where its picture begins, before its
        // first frame. See [CommonTrackEndMediaSource].
        val extractorsFactory = TrackEndCapturingExtractorsFactory(DefaultExtractorsFactory()) {
                uri, videoEndUs, audioEndUs, videoStartUs ->
            recordTrackEnds(uri.toString(), videoEndUs, audioEndUs, videoStartUs)
        }
        val builder = ExoPlayer.Builder(context, renderersFactory)
            .setMediaSourceFactory(
                CommonTrackEndMediaSourceFactory(
                    DefaultMediaSourceFactory(
                        VideoCache.dataSourceFactory(context) { uri: Uri ->
                            httpHeadersForRequest(uri.toString())
                        },
                        extractorsFactory,
                    ),
                ) { uri -> trackEndsFor(uri) },
            )
        // The feed keeps several players live on memory-constrained devices,
        // so cap their read-ahead to avoid ExoPlayer OOM (#3419). Editing
        // surfaces keep the default unbounded buffering.
        if (bufferProfile == BufferProfile.FEED) {
            builder.setLoadControl(FeedLoadControl.build())
        } else {
            // Paused, ExoPlayer otherwise only works once a second. A scrub
            // onto a clip's last frames then waits up to that second: the
            // decoder only releases them once it is fed the end of stream.
            builder.experimentalSetDynamicSchedulingEnabled(true)
        }
        return builder.build()
    }

    private fun isRemoteSource(uri: String): Boolean =
        uri.startsWith("http://") || uri.startsWith("https://")

    /** Whether the player has buffered its clip to the end it presents. */
    private fun ExoPlayer.hasBufferedWholeClip(): Boolean {
        val presentedMs = duration
        return presentedMs != C.TIME_UNSET && bufferedPosition >= presentedMs
    }

    /**
     * What the loop audio decode reads remote clips through: the same factory
     * the player itself uses — its cache for anonymous HTTP(S), straight to
     * the network otherwise — so the extractor reads what the player has
     * fetched. [headers] is the clip's own map rather than a lookup, so the
     * decode carries exactly what the clip was loaded with.
     * Deliberately not the blocking variant of the cache source: the
     * extractor holds several ranges open at once, and one of them blocking
     * on a range another holds locked would wait on itself.
     */
    private fun extractorDataSourceFactory(headers: Map<String, String>): DataSource.Factory =
        VideoCache.dataSourceFactory(context) { _ -> headers }

    internal fun httpHeadersForRequest(url: String): Map<String, String> {
        httpHeadersByUri[url]?.let { return it }
        val hash = blobHashFromUrl(url) ?: return emptyMap()
        return httpHeadersByHash[hash] ?: emptyMap()
    }

    /**
     * Extracts the 64-char hex blob hash from the first path segment of [url],
     * mirroring the origin's hash-from-path rule. Pure string parsing so it
     * needs no `android.net.Uri` and stays unit-testable.
     */
    internal fun blobHashFromUrl(url: String): String? {
        val authorityAndPath = url.substringAfter("://", url)
        val path = authorityAndPath.substringAfter('/', "")
        val firstSegment = path
            .substringBefore('/')
            .substringBefore('?')
            .substringBefore('#')
        val candidate = firstSegment.substringBefore('.')
        val isHex = candidate.length == 64 &&
            candidate.all { it in '0'..'9' || it in 'a'..'f' || it in 'A'..'F' }
        return if (isHex) candidate.lowercase() else null
    }

    // -- SurfaceProducer.Callback --

    override fun onSurfaceAvailable() {
        if (needsSurface) {
            val surface = surfaceProducer?.surface ?: return
            val p = player
            if (p != null) {
                p.setVideoSurface(surface)
                sendFrameEffectOutputResolution()
                needsSurface = false
                // ExoPlayer does not re-render the current frame after a surface
                // reattach when the player is paused — the surface stays black
                // until the next decoded frame arrives (i.e. not until play()).
                // Seeking to the current position forces the codec to decode and
                // display the frame at the current position without moving it.
                if (!p.isPlaying && p.playbackState == Player.STATE_READY) {
                    recordFrameEffectsMove(p.currentMediaItemIndex, p.currentPosition)
                    p.seekTo(p.currentPosition)
                }
            }
            // If player is null, needsSurface stays true so ensurePlayer()
            // attaches the surface when the player is eventually created.
        }
    }

    override fun onSurfaceCleanup() {
        player?.setVideoSurface(null)
        needsSurface = true
    }

    // -- MethodCallHandler --

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setClips" -> handleSetClips(call, result)
            "play" -> handlePlay(result)
            "pause" -> handlePause(result)
            "stop" -> handleStop(result)
            "seekTo" -> handleSeekTo(call, result)
            "setVolume" -> handleSetVolume(call, result)
            "setClipVolumes" -> handleSetClipVolumes(call, result)
            "setPlaybackSpeed" -> handleSetPlaybackSpeed(call, result)
            "setLooping" -> handleSetLooping(call, result)
            "jumpToClip" -> handleJumpToClip(call, result)
            "setAudioTracks" -> handleSetAudioTracks(call, result)
            "removeAllAudioTracks" -> handleRemoveAllAudioTracks(result)
            "setAudioTrackVolume" -> handleSetAudioTrackVolume(call, result)
            "setFrameEffects" -> handleSetFrameEffects(call, result)
            else -> result.notImplemented()
        }
    }

    // -- StreamHandler --

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        mainHandler.post(positionUpdater)
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        mainHandler.removeCallbacks(positionUpdater)
    }

    // -- method handlers --

    @Suppress("UNCHECKED_CAST")
    private fun handleSetClips(call: MethodCall, result: MethodChannel.Result) {
        val clipsRaw = call.argument<List<Map<String, Any?>>>("clips") ?: run {
            result.error("INVALID_ARGS", "clips list required", null)
            return
        }
        // Nothing is read ahead of the load: where each track ends is recorded
        // by the player's own extractor while it prepares the source, and a
        // clip that asked for it is clipped there before its first frame.
        applyClips(call, clipsRaw, result)
    }

    private fun applyClips(
        call: MethodCall,
        clipsRaw: List<Map<String, Any?>>,
        result: MethodChannel.Result,
    ) {
        val exoPlayer = ensurePlayer()
        val mediaItems = mutableListOf<MediaItem>()
        val offsets = mutableListOf<Long>()
        val volumes = mutableListOf<Float>()
        val speeds = mutableListOf<Float>()
        val headersByUri = mutableMapOf<String, Map<String, String>>()
        val headersByHash = mutableMapOf<String, Map<String, String>>()
        var accumulated = 0L

        for (map in clipsRaw) {
            val uri = map["uri"] as? String
            if (uri == null) {
                DivineVideoPlayerLog.warning(
                    "$logTarget skipped a clip: missing uri",
                    name = "DivineVideoPlayer.Load",
                )
                continue
            }
            val startMs = (map["startMs"] as? Number)?.toLong() ?: 0L
            val endMs = (map["endMs"] as? Number)?.toLong()
            val trimToCommonTrackEnd = map["trimToCommonTrackEnd"] as? Boolean ?: false
            // The container duration is the *longest* track, so ending there
            // leaves a stretch where the shorter track has already run out —
            // silence, or a frozen frame. On a looping player that stretch is
            // the seam. Clamping may only ever shorten: an earlier explicit
            // trim still wins.
            val clipsAtTrackEnd = trimToCommonTrackEnd &&
                startMs == 0L &&
                canClipToCommonTrackEnd(uri)
            // A clip clipped at its track end learns that end during prepare;
            // a known one only seeds the offsets until the timeline reports it.
            val commonEndMs = if (trimToCommonTrackEnd) {
                boundedCommonTrackEndMs(uri, startMs, endMs)
            } else {
                null
            }
            val effectiveEndMs = listOfNotNull(endMs, commonEndMs).minOrNull()
            val clipVol = (map["volume"] as? Number)?.toFloat() ?: 1.0f
            val clipSpeed = ((map["playbackSpeed"] as? Number)?.toFloat() ?: 1.0f)
                .coerceAtLeast(MIN_PLAYBACK_SPEED)
            val httpHeaders = httpHeadersOf(map)
            if (httpHeaders.isNotEmpty()) {
                headersByUri[uri] = httpHeaders
                blobHashFromUrl(uri)?.let { headersByHash[it] = httpHeaders }
            }

            mediaItems.add(
                if (clipsAtTrackEnd) {
                    buildCommonTrackEndItem(uri, endMs)
                } else {
                    buildMediaItem(uri, startMs, effectiveEndMs)
                },
            )
            offsets.add(accumulated)
            volumes.add(clipVol)
            speeds.add(clipSpeed)

            // If endMs is unknown, we'll recalculate after prepare.
            // Offsets accumulate in playback time so the global timeline
            // matches what the editor UI shows (slow clips occupy more
            // space, fast clips less).
            if (effectiveEndMs != null) {
                accumulated += sourceToPlaybackMs(effectiveEndMs - startMs, clipSpeed)
            }
        }

        clipOffsets = offsets
        clipVolumes = volumes
        clipSpeeds = speeds
        clipCount = mediaItems.size
        httpHeadersByUri = headersByUri
        httpHeadersByHash = headersByHash
        firstFrameRendered = false
        // New media gets the full retry budget — exhaustion belonged to the
        // previous clip list.
        cancelDecoderRetry()
        decoderRetryCount = 0

        // Resolve the optional global start position to (clipIndex, localMs)
        // so ExoPlayer begins buffering at the right point immediately.
        // [globalStartMs] arrives in playback time; ExoPlayer.seekTo expects
        // source time, so we convert via the resolved clip's speed.
        val globalStartMs = (call.argument<Number>("startPositionMs"))?.toLong() ?: 0L
        var startIndex = 0
        var startLocalMs = globalStartMs
        if (globalStartMs > 0 && offsets.isNotEmpty()) {
            for (i in offsets.indices) {
                val nextOffset = if (i + 1 < offsets.size) offsets[i + 1] else Long.MAX_VALUE
                if (globalStartMs < nextOffset) {
                    startIndex = i
                    startLocalMs = playbackToSourceMs(
                        globalStartMs - offsets[i],
                        speeds[i],
                    )
                    break
                }
            }
        }

        lastClipsRaw = clipsRaw
        frameEffectClipSizes.clear()
        // The repeat mode depends on how many clips are loaded, so a clip list
        // that arrives without a following `setLooping` has to reapply it here.
        applyRepeatMode()
        startClipAudioLoop(clipsRaw, clipCount, awaitTimeline = true)

        // Fade the video's edges only when the whole video is one clip, which
        // is what the feed loops. On a multi-clip timeline a stream is one clip
        // rather than the whole video, so fading every stream would notch the
        // audio at each cut. The length is not known until STATE_READY.
        //
        // Published before the playlist swap below, because that swap disables
        // the audio renderer and flushes the pipeline on the playback thread.
        declickProcessor.enabled = clipCount == 1
        declickProcessor.videoDurationUs = LoopDeclickAudioProcessor.DURATION_UNKNOWN
        declickProcessor.nextStreamStartUs = startLocalMs * 1000L

        // Replace the playlist in-place without calling stop() first.
        // stop() transitions ExoPlayer to STATE_IDLE which on some OEM decoders
        // (e.g. Vivo/Mediatek) triggers a full MediaCodec reset and surface
        // disconnect. setMediaItems() handles playlist replacement internally
        // without that overhead. isResettingPlayer suppresses intermediate
        // state events fired while ExoPlayer processes the new items.
        isResettingPlayer = true
        recordFrameEffectsMove(startIndex, startLocalMs)
        exoPlayer.setMediaItems(mediaItems, startIndex, startLocalMs)
        exoPlayer.prepare()
        isResettingPlayer = false
        DivineVideoPlayerLog.info(
            "$logTarget prepared $clipCount clip(s)",
            name = "DivineVideoPlayer.Load",
        )
        // Apply the starting clip's per-clip volume immediately so the correct
        // level is audible as soon as the decoder is ready. Use startIndex
        // (not 0) so a resume mid-playlist doesn't play clip 0's volume
        // before onMediaItemTransition can correct it.
        applyClipVolume(exoPlayer, startIndex)
        exoPlayer.setPlaybackParameters(PlaybackParameters(clipSpeeds.getOrElse(startIndex) { 1.0f }))
        // While ExoPlayer buffers to the seek position, report the target
        // position so the timeline doesn't show intermediate values.
        pendingGlobalStartMs = globalStartMs

        // Hold the Dart result until STATE_READY so `await setClips()` only
        // resolves once the decoder is truly ready. Cancel any previous
        // in-flight setClips (shouldn't happen, but defensive) — surface as
        // an error so the superseded caller doesn't believe the player is
        // ready for its clips.
        mainHandler.removeCallbacks(setClipsTimeoutRunnable)
        pendingSetClipsResult?.error(
            "CANCELLED",
            "Superseded by newer setClips call",
            null,
        )
        pendingSetClipsResult = result
        // 10 s safety net — if STATE_READY never fires (e.g. corrupt file),
        // Dart is unblocked rather than hanging forever.
        mainHandler.postDelayed(setClipsTimeoutRunnable, SET_CLIPS_TIMEOUT_MS)
    }

    /**
     * Wraps [uri] in a media item, clipping it only when that really cuts
     * something.
     *
     * A clipping configuration is not free: media3 wraps the source in a
     * `ClippingMediaSource`, and a looping player then repeats the wrapper
     * rather than the source. The Apple side had the same shape — every clip
     * was copied into an `AVMutableComposition` even when there was nothing to
     * compose — and there it cost the loop seam; playing the asset itself
     * closed it.
     *
     * Track lengths come from [trackDurationsCache], filled by the player's
     * own extractor whenever it has parsed the source before; when they are
     * unknown the wrapper stays, because guessing wrong here would silently
     * play past a trim.
     */
    private fun buildMediaItem(
        uri: String,
        startMs: Long,
        endMs: Long?,
    ): MediaItem {
        val builder = MediaItem.Builder().setUri(uri)
        if (clipsNothing(uri, startMs, endMs)) return builder.build()
        return builder
            .setClippingConfiguration(
                MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(startMs)
                    .apply {
                        if (endMs != null) setEndPositionMs(endMs)
                    }
                    .build(),
            )
            .build()
    }

    /**
     * Wraps [uri] in a media item that [CommonTrackEndMediaSource] clips to
     * where its shorter track ends, and to [endMs] if that comes first.
     *
     * The end is left to the source rather than written into a clipping
     * configuration because it is not known yet: the player's extractor reads
     * it from the container during prepare, before the first frame.
     */
    private fun buildCommonTrackEndItem(uri: String, endMs: Long?): MediaItem =
        MediaItem.Builder()
            .setUri(uri)
            .setTag(
                CommonTrackEndClip(
                    requestedEndUs = endMs?.let { it * 1000L } ?: C.TIME_END_OF_SOURCE,
                ),
            )
            .build()

    /** Whether clipping [uri] to [startMs]..[endMs] would leave it untouched. */
    private fun clipsNothing(uri: String, startMs: Long, endMs: Long?): Boolean {
        if (startMs != 0L) return false
        if (endMs == null) return true
        val durations = trackDurationsCache[uri] ?: return false
        val containerEndMs = (durations.take(2).maxOrNull() ?: return false) / 1000
        return endMs >= containerEndMs
    }

    /**
     * The point up to which *every* track of [uri] still has content, in
     * milliseconds, or `null` when the source's track lengths are not known.
     *
     * Reads only [trackDurationsCache], which the player's extractor fills
     * each time it parses a source.
     */
    private fun boundedCommonTrackEndMs(
        uri: String,
        startMs: Long,
        requestedEndMs: Long?,
    ): Long? {
        val durations = trackDurationsCache[uri] ?: return null
        if (durations.size < 2) return null
        return commonTrackEndUs(
            requestedEndUs = requestedEndMs?.let { it * 1000L } ?: C.TIME_END_OF_SOURCE,
            videoEndUs = durations[0],
            audioEndUs = durations[1],
            startUs = startMs * 1000L,
        )?.let { it / 1000L }
    }

    /**
     * Whether [uri] can be clipped at its common track end by
     * [CommonTrackEndMediaSource].
     *
     * The track ends come from the progressive extractor, so an HLS playlist
     * never reports them; the feed keeps HLS as a fallback for a progressive
     * source that would not start, and plays it to the playlist's end, as the
     * Apple player does.
     */
    private fun canClipToCommonTrackEnd(uri: String): Boolean {
        if (isHlsSource(uri)) return false
        return uri.startsWith("/") ||
            uri.startsWith("file://") ||
            uri.startsWith("http://") ||
            uri.startsWith("https://")
    }

    /** The per-clip HTTP headers Dart sent, if any. */
    private fun httpHeadersOf(map: Map<String, Any?>): Map<String, String> =
        (map["httpHeaders"] as? Map<*, *>)
            ?.mapNotNull { entry ->
                val key = entry.key as? String
                val value = entry.value as? String
                if (key == null || value == null) null else key to value
            }
            ?.toMap()
            ?: emptyMap()


    /**
     * Hands the declick fade the current video's length, which bounds how long
     * the fade may be on a video too short to carry two of them. Where the
     * fade out sits is not derived from this — the processor holds the last
     * few milliseconds back and releases them at the real end of the stream.
     */
    /**
     * Moves a looping single clip's audio out of ExoPlayer and into its own
     * [ClipAudioLoopTrack].
     *
     * Only for the case that has the seam: one clip, repeating. Multi-clip
     * timelines keep the player's audio — there is no repeat of the same
     * media period there, so nothing to avoid.
     *
     * Decoding blocks, so it runs on [metadataExecutor]. The player keeps its
     * own audio until the loop is ready: a decode reads the source again and
     * lands 0.5–0.7 s after `play` on a video opened straight from a grid,
     * and taking the renderer's audio away before that (#8021) played the
     * picture over silence for exactly that long. A loop that lands before
     * playback starts — every preloaded feed tile — takes over at once; one
     * that lands mid-lap waits for the loop restart, see [adoptClipAudioLoop].
     *
     * [awaitTimeline] is for a caller that still has its playlist swap ahead of
     * it. The player's duration describes whatever is loaded *now*, so on a
     * reused player that is the outgoing video, and cutting the loop to it
     * would play the new video's sound at the previous one's length.
     */
    private fun startClipAudioLoop(
        clipsRaw: List<Map<String, Any?>>,
        clipCount: Int,
        awaitTimeline: Boolean = false,
    ) {
        releaseClipAudioLoop()
        val generation = ++clipAudioGeneration
        if (clipCount != 1 || !isLooping) return
        val map = clipsRaw.firstOrNull() ?: return
        val uri = map["uri"] as? String ?: return
        // The track's extractor cannot read a playlist, and a lap started by
        // a seek has no fixed length for the track to follow.
        if (isHlsSource(uri)) return
        if (((map["startMs"] as? Number)?.toLong() ?: 0L) != 0L) return
        // A static track plays the recording at its own rate and has no
        // stretcher to follow a speed change with, so an off-speed player keeps
        // ExoPlayer's audio rather than drifting away from its own picture.
        if (speed != 1.0) return
        if (((map["playbackSpeed"] as? Number)?.toFloat() ?: 1.0f) != 1.0f) return
        val headers = httpHeadersOf(map)

        // The presented length is only known once the timeline is populated;
        // [onPlaybackStateChanged] calls back in when it is.
        val exoPlayer = ensurePlayer()
        val presented = if (awaitTimeline) null else presentedWindow(exoPlayer)
        val loopUs = presented?.durationUs ?: C.TIME_UNSET
        if (loopUs == C.TIME_UNSET || loopUs <= 0) {
            clipAudioPending = true
            return
        }
        clipAudioPending = false
        // Where the picture's lap begins in the source: past zero when the
        // source clipped an empty edit ahead of the first frame.
        val clipStartUs = presented?.positionInFirstPeriodUs?.coerceAtLeast(0L) ?: 0L

        // A remote anonymous clip is decoded from the player's cache rather
        // than fetched again, so the decode waits until the player has the
        // whole clip buffered — [onIsLoadingChanged] calls back in as the
        // load progresses. Read alongside the download it would find the
        // range the player is writing locked and be sent to the network for
        // it, which is the second download this avoids. Viewer-authenticated
        // clips bypass the cache, so waiting would only delay a second
        // download. On the feed an anonymous clip is buffered within the
        // first lap, and the decode then runs from disk.
        if (isRemoteSource(uri) &&
            headers.isEmpty() &&
            !exoPlayer.hasBufferedWholeClip()
        ) {
            clipAudioAwaitingLoad = true
            return
        }
        clipAudioAwaitingLoad = false
        val remoteSourceFactory = extractorDataSourceFactory(headers)

        if (metadataExecutor.isShutdown) return
        runCatching {
            metadataExecutor.execute {
                val loop = ClipAudioLoopTrack.create(
                    uri,
                    headers,
                    loopUs,
                    clipStartUs,
                    remoteSourceFactory,
                )
                mainHandler.post {
                    if (generation != clipAudioGeneration) {
                        loop?.release()
                        return@post
                    }
                    // Nothing decoded — a clip with no audio, an unreachable
                    // source, a codec that refused. The renderer still has
                    // the audio, so the video keeps its sound.
                    if (loop == null) return@post
                    adoptClipAudioLoop(loop)
                }
            }
        }
    }

    /**
     * The single clip's presented window, or null before there is one: its
     * length in microseconds, and where in the source it begins.
     *
     * Read from the timeline rather than [ExoPlayer.getDuration], which rounds
     * down to whole milliseconds. The loop track repeats in the HAL on its own
     * clock, so a loop even a fraction of a millisecond short of the picture's
     * period walks away from it by that much on every lap.
     */
    private fun presentedWindow(exoPlayer: ExoPlayer): Timeline.Window? {
        val timeline = exoPlayer.currentTimeline
        if (timeline.isEmpty) return null
        return timeline.getWindow(exoPlayer.currentMediaItemIndex, Timeline.Window())
    }

    /**
     * Takes the audio over from ExoPlayer with a freshly decoded [loop].
     *
     * A player that is not playing switches at once: nothing is sounding, and
     * [onIsPlayingChanged] starts the loop against the picture when it does.
     * A playing one hands over mid-lap without a seam of its own: see
     * [ClipAudioTakeover]. Waiting for the next loop restart instead (#9324)
     * left the first restart of every video opened from a grid to ExoPlayer's
     * audio — the very seam the private track exists to avoid.
     */
    private fun adoptClipAudioLoop(loop: ClipAudioLoopTrack) {
        // The loop only runs for a single clip, so its boost is that clip's.
        loop.setBoost(AudioSessionBoost.boostOf(clipVolume(0)))
        val exoPlayer = player
        if (exoPlayer?.isPlaying != true) {
            installClipAudioLoop(loop)
            return
        }
        // Silent until it is in step with the picture, so aligning it cannot
        // be heard; ExoPlayer keeps the sound meanwhile.
        clipAudioLoop = loop
        loop.play(exoPlayer.currentPosition * 1000L, 0f)
        val takeover = ClipAudioTakeover(loop)
        clipAudioTakeover = takeover
        mainHandler.post(takeover)
    }

    /** Switches the sound from the player's renderer to [loop] outright. */
    private fun installClipAudioLoop(loop: ClipAudioLoopTrack) {
        setExoPlayerAudioEnabled(false)
        clipAudioLoop = loop
        player?.takeIf { it.isPlaying }?.let {
            loop.play(it.currentPosition * 1000L, it.volume)
            scheduleClipAudioSync()
        }
    }

    /**
     * Hands the sound from ExoPlayer to [loop] while both are playing.
     *
     * The loop starts muted and is placed again until it measures within
     * [LoopAudioSync.DEADBAND_US] of the picture — inaudible while it is
     * silent — or until [TAKEOVER_ALIGN_TIMEOUT_NS] passes. Then the two
     * cross over in [TAKEOVER_FADE_STEPS] steps: two copies of the same sound
     * a few milliseconds apart, so the crossing is not heard, and neither is a
     * seam, because there is none mid-lap. ExoPlayer's audio renderer is only
     * switched off once it is silent.
     */
    private inner class ClipAudioTakeover(val loop: ClipAudioLoopTrack) : Runnable {
        val startedNanos = System.nanoTime()
        private var fadeStep = -1

        /** Readings since the loop was last placed; judged by their median. */
        private val readings = ArrayList<Long>(TAKEOVER_READINGS)

        override fun run() {
            if (clipAudioTakeover !== this) return
            val exoPlayer = player
            if (exoPlayer == null || !exoPlayer.isPlaying) {
                finishClipAudioTakeover()
                return
            }
            if (fadeStep < 0) {
                val nowNanos = System.nanoTime()
                val positionUs = exoPlayer.currentPosition * 1000L
                val errorUs = loop.sync(positionUs, nowNanos)
                val timedOut = nowNanos - startedNanos >= TAKEOVER_ALIGN_TIMEOUT_NS
                when {
                    // A gap too wide to steer was placed again by [sync]
                    // itself; what was read before it no longer applies.
                    errorUs != null && abs(errorUs) > LoopAudioSync.REANCHOR_THRESHOLD_US ->
                        readings.clear()
                    errorUs != null -> readings.add(errorUs)
                }
                if (readings.size >= TAKEOVER_READINGS || timedOut) {
                    val medianUs = readings.sorted().getOrNull(readings.size / 2)
                    if (timedOut || medianUs == null ||
                        abs(medianUs) <= LoopAudioSync.DEADBAND_US
                    ) {
                        fadeStep = 0
                    } else {
                        // Placed again by exactly what it was off by, which
                        // cannot be heard while muted, rather than steered
                        // over seconds.
                        loop.realign(positionUs, measuredErrorUs = medianUs)
                        readings.clear()
                    }
                }
                if (fadeStep < 0) {
                    mainHandler.postDelayed(this, TAKEOVER_STEP_MS)
                    return
                }
            }
            fadeStep++
            val target = nominalPlayerVolume()
            val progress = fadeStep.toFloat() / TAKEOVER_FADE_STEPS
            loop.setVolume(target * progress)
            exoPlayer.volume = target * (1f - progress)
            if (fadeStep >= TAKEOVER_FADE_STEPS) {
                finishClipAudioTakeover()
            } else {
                mainHandler.postDelayed(this, TAKEOVER_STEP_MS)
            }
        }
    }

    /**
     * Completes a takeover in progress at once: the loop has the sound from
     * here on, at full level, and ExoPlayer's renderer is switched off.
     *
     * Also the way out when playback stops, the volume changes or the loop is
     * released mid-takeover — none of them can leave the two sounding at once.
     */
    private fun finishClipAudioTakeover() {
        val takeover = clipAudioTakeover ?: return
        clipAudioTakeover = null
        DivineVideoPlayerLog.debug(
            "$logTarget loop audio took over after " +
                "${(System.nanoTime() - takeover.startedNanos) / 1_000_000} ms",
            name = "DivineVideoPlayer.AudioLoop",
        )
        mainHandler.removeCallbacks(takeover)
        setExoPlayerAudioEnabled(false)
        val target = nominalPlayerVolume()
        player?.volume = target
        takeover.loop.setVolume(target)
        if (player?.isPlaying == true) scheduleClipAudioSync()
    }

    /**
     * The player's volume outside a takeover: the clip's gain up to 100 %
     * times Dart's. Anything above 100 % is [playerBoost]'s.
     */
    private fun nominalPlayerVolume(): Float =
        AudioSessionBoost.attenuationOf(clipVolume(player?.currentMediaItemIndex ?: 0)) *
            volume.toFloat()

    /** Clip [index]'s volume as Dart set it, which may lie above 1. */
    private fun clipVolume(index: Int): Float = clipVolumes.getOrElse(index) { 1.0f }

    /**
     * Plays clip [index] at its volume: up to 100 % through the player's own
     * volume, scaled by Dart's, and the rest through [playerBoost].
     */
    private fun applyClipVolume(exoPlayer: ExoPlayer, index: Int) {
        val clipVolume = clipVolume(index)
        exoPlayer.volume = AudioSessionBoost.attenuationOf(clipVolume) * volume.toFloat()
        playerBoost.attach(exoPlayer.audioSessionId)
        playerBoost.setGain(AudioSessionBoost.boostOf(clipVolume))
    }

    /**
     * Keeps a playing loop on the picture; see [LoopAudioSync].
     *
     * Runs every [CLIP_AUDIO_SYNC_INTERVAL_MS] while the loop plays, and every
     * [CLIP_AUDIO_SYNC_FIRST_CHECK_MS] after a start until the first
     * measurement: a start that came out wrong — an output waking from
     * standby after a pause — is heard wrong until then, so the sooner it is
     * put right, the closer to the first sound the correction falls. A few
     * milliseconds of measurement noise is ignored; anything wider is steered
     * out through the playback rate.
     */
    private val clipAudioSyncRunnable = object : Runnable {
        private var measurements = 0

        override fun run() {
            val loop = clipAudioLoop ?: return
            val exoPlayer = player ?: return
            if (!exoPlayer.isPlaying || clipAudioTakeover != null) return
            val errorUs = loop.sync(exoPlayer.currentPosition * 1000L, System.nanoTime())
            if (errorUs != null && measurements++ % CLIP_AUDIO_SYNC_LOG_EVERY == 0) {
                DivineVideoPlayerLog.debug(
                    "$logTarget loop audio ${errorUs / 1000.0} ms from the picture",
                    name = "DivineVideoPlayer.AudioLoop",
                )
            }
            mainHandler.postDelayed(
                this,
                if (loop.measuredSinceStart) {
                    CLIP_AUDIO_SYNC_INTERVAL_MS
                } else {
                    CLIP_AUDIO_SYNC_FIRST_CHECK_MS
                },
            )
        }
    }

    private fun scheduleClipAudioSync() {
        mainHandler.removeCallbacks(clipAudioSyncRunnable)
        mainHandler.postDelayed(clipAudioSyncRunnable, CLIP_AUDIO_SYNC_FIRST_CHECK_MS)
    }

    /** Releases the private audio path and lets ExoPlayer see audio again. */
    private fun releaseClipAudioLoop() {
        clipAudioGeneration++
        clipAudioPending = false
        clipAudioAwaitingLoad = false
        clipAudioTakeover?.let { mainHandler.removeCallbacks(it) }
        clipAudioTakeover = null
        mainHandler.removeCallbacks(clipAudioSyncRunnable)
        clipAudioLoop?.release()
        clipAudioLoop = null
        setExoPlayerAudioEnabled(true)
        player?.volume = nominalPlayerVolume()
    }

    /** Selects or deselects the player's own audio renderer. */
    private fun setExoPlayerAudioEnabled(enabled: Boolean) {
        val exoPlayer = player ?: return
        exoPlayer.trackSelectionParameters = exoPlayer.trackSelectionParameters
            .buildUpon()
            .setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, !enabled)
            .build()
    }

    private fun updateDeclickDuration() {
        val durationMs = player?.duration ?: C.TIME_UNSET
        declickProcessor.videoDurationUs = if (durationMs == C.TIME_UNSET) {
            LoopDeclickAudioProcessor.DURATION_UNKNOWN
        } else {
            durationMs * 1000L
        }
    }

    private fun handleSeekTo(call: MethodCall, result: MethodChannel.Result) {
        val globalMs = (call.argument<Number>("positionMs"))?.toLong() ?: 0L
        val exoPlayer = ensurePlayer()

        // Complete any previous pending seek so Dart isn't left hanging.
        mainHandler.removeCallbacks(seekTimeoutRunnable)
        seekCompletionResult?.success(null)
        seekCompletionResult = result
        seekFrameGeneration++
        armedSeekGeneration = NO_ARMED_SEEK
        seekAwaitsFrame = !exoPlayer.playWhenReady && activeSurface != null

        // Ensure clip offsets are up-to-date from ExoPlayer's timeline
        // before resolving the global position. Without this, offsets
        // may all be zero when clips were set without endMs and the
        // lookup would always land on the last clip.
        refreshClipOffsets(exoPlayer)

        // [globalMs] is in playback time; resolveGlobalPosition returns the
        // clip index plus a clip-local position already converted to source
        // time, which is what ExoPlayer.seekTo expects.
        val resolved = resolveGlobalPosition(globalMs)

        val targetIndex = resolved.first
        // The seek flushes the audio pipeline, which re-anchors the fade at
        // whatever the next stream starts with. Tell it that is the seek target
        // and not the start of the video, so the fade out stays on the join.
        declickProcessor.nextStreamStartUs = resolved.second * 1000L
        onFrameEffectsSeek(targetIndex, resolved.second)
        exoPlayer.seekTo(targetIndex, resolved.second)
        if (seekAwaitsFrame) {
            val generation = seekFrameGeneration
            exoPlayer.createMessage { _, _ ->
                if (generation == seekFrameGeneration) armedSeekGeneration = generation
            }.send()
        }
        // Settle any in-flight takeover before repositioning the loop track,
        // the same way pausing and setVolume do — otherwise the crossfade
        // keeps stepping against a track whose position just jumped underneath
        // it, which is audible whenever the loop is already partially audible.
        finishClipAudioTakeover()
        // The loop track is outside the player and does not hear the seek.
        clipAudioLoop?.seekTo(resolved.second * 1000L)

        // Apply the target clip's per-clip speed and volume immediately.
        // ExoPlayer does not fire onPositionDiscontinuity / onMediaItemTransition
        // with a speed-update path for manual seeks — only AUTO_TRANSITION is
        // covered there. Without this, seeking from clip 2 (e.g. 0.25×) back
        // to clip 1 (e.g. 3×) leaves the player running at 0.25× indefinitely.
        applyClipVolume(exoPlayer, targetIndex)
        exoPlayer.setPlaybackParameters(
            PlaybackParameters(clipSpeeds.getOrElse(targetIndex) { 1.0f }),
        )
        updateFrameEffectWindows(globalMs)

        syncAudioOverlays()

        // Safety timeout — complete after 500ms if the callback never fires.
        mainHandler.postDelayed(seekTimeoutRunnable, 500)
    }

    /**
     * Resolves a playback-time global position to a (clipIndex, localMs)
     * pair where [localMs] is in source (clip-local) time, ready for
     * `ExoPlayer.seekTo`.
     *
     * If clip offsets are all zero (durations not yet known because
     * `prepare()` hasn't finished), falls back to seeking within clip 0
     * to avoid accidentally landing on the last clip.
     */
    private fun resolveGlobalPosition(globalMs: Long): Pair<Int, Long> {
        // If offsets haven't been populated yet (all zero with >1 clip)
        // try refreshing once more from the current timeline.
        if (clipCount > 1 && clipOffsets.all { it == 0L }) {
            player?.let { refreshClipOffsets(it) }
        }

        // Still all zero — fall back to clip 0.
        if (clipCount > 1 && clipOffsets.all { it == 0L }) {
            return Pair(0, playbackToSourceMs(globalMs, clipSpeeds.getOrElse(0) { 1.0f }))
        }

        var targetIndex = 0
        var localPlaybackMs = globalMs
        for (i in clipOffsets.indices) {
            val nextOffset = if (i + 1 < clipOffsets.size) clipOffsets[i + 1]
            else Long.MAX_VALUE
            if (globalMs < nextOffset) {
                targetIndex = i
                localPlaybackMs = globalMs - clipOffsets[i]
                break
            }
        }
        val targetSpeed = clipSpeeds.getOrElse(targetIndex) { 1.0f }
        return Pair(targetIndex, playbackToSourceMs(localPlaybackMs, targetSpeed))
    }

    private fun handleSetVolume(call: MethodCall, result: MethodChannel.Result) {
        volume = (call.argument<Number>("volume"))?.toDouble() ?: 1.0
        finishClipAudioTakeover()
        player?.volume = nominalPlayerVolume()
        clipAudioLoop?.setVolume(nominalPlayerVolume())
        result.success(null)
    }

    /**
     * Replaces the loaded clips' volumes without reloading them, so a volume
     * control can be followed while it is dragged. A list that does not match
     * the loaded clips belongs to another composition and is ignored.
     */
    private fun handleSetClipVolumes(call: MethodCall, result: MethodChannel.Result) {
        val volumes = call.argument<List<Number>>("volumes")?.map { it.toFloat() }
        if (volumes == null || volumes.size != clipVolumes.size) {
            result.success(null)
            return
        }
        clipVolumes = volumes
        finishClipAudioTakeover()
        player?.let { applyClipVolume(it, it.currentMediaItemIndex) }
        clipAudioLoop?.let {
            it.setVolume(nominalPlayerVolume())
            it.setBoost(AudioSessionBoost.boostOf(clipVolume(0)))
        }
        result.success(null)
    }

    private fun handleSetPlaybackSpeed(call: MethodCall, result: MethodChannel.Result) {
        val wasNormalSpeed = speed == 1.0
        speed = (call.argument<Number>("speed"))?.toDouble() ?: 1.0
        player?.setPlaybackSpeed(speed.toFloat())
        audioOverlayManager.setPlaybackSpeed(speed.toFloat())
        // The loop track cannot be stretched, so leaving normal speed hands the
        // audio back to the player and returning to it takes the audio again.
        if (wasNormalSpeed != (speed == 1.0)) {
            startClipAudioLoop(lastClipsRaw, clipCount)
        }
        result.success(null)
    }

    private fun handleSetLooping(call: MethodCall, result: MethodChannel.Result) {
        val wasLooping = isLooping
        isLooping = call.argument<Boolean>("looping") ?: false
        if (isLooping != wasLooping && lastClipsRaw.isNotEmpty()) {
            if (isLooping) {
                startClipAudioLoop(lastClipsRaw, lastClipsRaw.size)
            } else {
                releaseClipAudioLoop()
            }
        }
        applyRepeatMode()
        result.success(null)
    }

    /**
     * Puts the player in the repeat mode its current clip list calls for.
     *
     * A single repeating clip is what `REPEAT_MODE_ONE` is for: it repeats the
     * media period in place instead of walking a one-item playlist round. The
     * perfect_loop prototype loops this way and closes the seam; this was the
     * last structural difference left between the two players.
     *
     * Because the mode depends on the clip count, both `setLooping` and
     * `setClips` have to apply it. The editor replaces its clip list without
     * calling `setLooping` again, so a timeline split in two while
     * `REPEAT_MODE_ONE` was set would otherwise repeat its first clip forever.
     */
    private fun applyRepeatMode() {
        player?.repeatMode = when {
            !isLooping || loopsBySeeking -> Player.REPEAT_MODE_OFF
            clipCount == 1 -> Player.REPEAT_MODE_ONE
            else -> Player.REPEAT_MODE_ALL
        }
    }

    /**
     * Whether the loop is closed by seeking back to the start when playback
     * ends, instead of by an ExoPlayer repeat mode.
     *
     * A repeat mode makes ExoPlayer prepare the next lap as soon as the
     * current one is fully buffered, up to 100 laps ahead. Preparing an HLS
     * lap downloads a whole segment unless the playlist declares its codecs,
     * and that download is not counted against [FeedLoadControl]'s budget.
     * When one segment already covers the clip — a 7 s feed cut of a video
     * with 12 s segments — every lap is fully buffered the moment it is
     * prepared, so the player keeps chaining laps until the Java heap runs
     * out. A playlist that does not repeat ends at its last item, and nothing
     * is prepared past it.
     *
     * The seek costs a visible stall at every restart, 300–400 ms on a
     * Galaxy S26, so Divine's own playlists keep the repeat mode: they
     * declare their codecs, and their laps are prepared without a download.
     */
    private val loopsBySeeking: Boolean
        get() = isLooping &&
            lastClipsRaw.any { (it["uri"] as? String)?.let(::isForeignHlsSource) == true }

    // -- frame effects --

    /**
     * Switches the frame effects to the list Dart sent, each with an `id`,
     * `params` and a `startUs` / `endUs` window on the player's timeline.
     *
     * The first non-empty list routes the player's frames through the effect
     * stage. Media3 only builds that pipeline at `prepare()`, so the player
     * is prepared again once, at the same position.
     */
    private fun handleSetFrameEffects(call: MethodCall, result: MethodChannel.Result) {
        val raw = call.argument<List<Map<String, Any?>>>("effects") ?: emptyList()
        val configs = raw.mapNotNull { map ->
            val id = map["id"] as? String ?: return@mapNotNull null
            @Suppress("UNCHECKED_CAST")
            FrameEffectsState.Config(
                id = id,
                params = (map["params"] as? Map<String, Any?>) ?: emptyMap(),
                startUs = (map["startUs"] as? Number)?.toLong(),
                endUs = (map["endUs"] as? Number)?.toLong(),
            )
        }
        val existing = frameEffectsState
        // An unchanged list must not start the history over, or every
        // rebuild on the Dart side would flash the trail away.
        if ((existing == null && configs.isEmpty()) || existing?.configs == configs) {
            result.success(null)
            return
        }
        val state = existing ?: FrameEffectsState().also { created ->
            created.onConfigPublished = {
                mainHandler.post { if (frameEffectsState === created) startFrameEffectsFill() }
            }
        }
        state.setConfigs(configs)
        frameEffectsState = state
        val exoPlayer = player
        if (exoPlayer != null) {
            if (existing == null) installFrameEffects(exoPlayer, state)
            updateFrameEffectWindows()
            val index = exoPlayer.currentMediaItemIndex
            state.speed = clipSpeeds.getOrElse(index) { 1.0f }
            // While playing the history keeps growing on its own. Paused, it
            // has to be decoded, or a newly picked effect shows no trail.
            if (existing == null || !exoPlayer.playWhenReady) {
                val positionMs = exoPlayer.currentPosition
                onFrameEffectsSeek(index, positionMs)
                // Paused, nothing draws a frame that would build the new
                // effects and publish what they need decoded. Installing
                // prepares the player, which draws one anyway.
                if (existing != null) redrawPausedFrame(index, positionMs)
            }
        }
        result.success(null)
    }

    private fun installFrameEffects(exoPlayer: ExoPlayer, state: FrameEffectsState) {
        val index = exoPlayer.currentMediaItemIndex
        if (videoWidth > 0 && videoHeight > 0) {
            frameEffectOutputSize = Size(videoWidth, videoHeight)
        } else if (frameEffectOutputSize == null) {
            // A player that has not shown a frame yet has no size, and the
            // effect pipeline cannot draw its first frame without one.
            frameEffectOutputSize = probeDisplaySize(index)
        }
        val positionMs = exoPlayer.currentPosition
        val playWhenReady = exoPlayer.playWhenReady
        isResettingPlayer = true
        exoPlayer.stop()
        exoPlayer.setVideoEffects(listOf(FrameEffectsGlEffect(state)))
        exoPlayer.prepare()
        recordFrameEffectsMove(index, positionMs)
        exoPlayer.seekTo(index, positionMs)
        exoPlayer.playWhenReady = playWhenReady
        isResettingPlayer = false
        sendFrameEffectOutputResolution()
        DivineVideoPlayerLog.info(
            "$logTarget routes frames through the frame-effect stage",
            name = "DivineVideoPlayer.Effects",
        )
    }

    /**
     * The slow way to [FrameEffectsHistoryDecoder.decode]'s frames: each
     * decoded on its own from its keyframe, for clips that decoder cannot
     * read.
     */
    private fun decodeHistoryFramesOneByOne(
        path: String,
        targetsUs: List<Long>,
        width: Int,
        height: Int,
        isCancelled: () -> Boolean,
    ): List<FrameEffectsState.DecodedFrame> {
        val frames = mutableListOf<FrameEffectsState.DecodedFrame>()
        val longSide = maxOf(width, height)
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            val rotation = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
            for (targetUs in targetsUs) {
                if (isCancelled()) return emptyList()
                val raw = retriever.getScaledFrameAtTime(
                    targetUs, MediaMetadataRetriever.OPTION_CLOSEST, longSide, longSide,
                ) ?: continue
                frames += FrameEffectsState.DecodedFrame(targetUs, targetUs, toHistoryFrame(raw, width, height, rotation))
            }
        } catch (e: Exception) {
            DivineVideoPlayerLog.warning(
                "$logTarget could not decode earlier frames for frame effects: $e",
                name = "DivineVideoPlayer.Effects",
            )
        } finally {
            retriever.release()
        }
        return frames
    }

    /**
     * Turns a frame [MediaMetadataRetriever] decoded into the history's
     * shape: in the display orientation, [width] x [height], and flipped
     * upside down, because a bitmap starts at the top row and a frame
     * texture at the bottom. The retriever may hand the frame over before
     * its [rotation] is applied, which shows as the wrong orientation.
     */
    private fun toHistoryFrame(raw: Bitmap, width: Int, height: Int, rotation: Int): Bitmap {
        val turn = (raw.width > raw.height) != (width > height)
        val turnedWidth = if (turn) raw.height else raw.width
        val turnedHeight = if (turn) raw.width else raw.height
        val matrix = Matrix()
        if (turn) matrix.postRotate((if (rotation % 180 != 0) rotation else 90).toFloat())
        matrix.postScale(width.toFloat() / turnedWidth, -height.toFloat() / turnedHeight)
        return Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, matrix, true)
    }

    /** The display size of clip [index], read from its file's metadata. */
    private fun probeDisplaySize(index: Int): Size? {
        val uri = lastClipsRaw.getOrNull(index)?.get("uri") as? String ?: return null
        val path = when {
            uri.startsWith("/") -> uri
            uri.startsWith("file:") -> Uri.parse(uri).path
            else -> null
        } ?: return null
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                ?.toIntOrNull() ?: return null
            val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                ?.toIntOrNull() ?: return null
            val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
            if (rotation % 180 != 0) Size(height, width) else Size(width, height)
        } catch (e: Exception) {
            null
        } finally {
            retriever.release()
        }
    }

    /**
     * Tells the video renderer the output size, which Media3 needs when its
     * effect pipeline draws into a surface handed over directly.
     */
    private fun sendFrameEffectOutputResolution() {
        if (frameEffectsState == null) return
        val exoPlayer = player ?: return
        val size = frameEffectOutputSize ?: return
        applyFrameEffectSurfaceSize(size)
        for (i in 0 until exoPlayer.rendererCount) {
            if (exoPlayer.getRendererType(i) != C.TRACK_TYPE_VIDEO) continue
            exoPlayer.createMessage(exoPlayer.getRenderer(i))
                .setType(Renderer.MSG_SET_VIDEO_OUTPUT_RESOLUTION)
                .setPayload(size)
                .send()
        }
    }

    /**
     * Draws the paused frame at [positionMs] of clip [index] through the
     * effect stage again by seeking to it, the same way the seek that
     * showed it did. Media3's own redraw needs a frame processor built with
     * a replayable cache, which ExoPlayer's is not, and ExoPlayer skips a
     * seek to where it already is, so this steps a millisecond back and on
     * again, or on and back from the clip's start; stepping on at the end
     * could pass it and end the item. While playing, the next frame does it
     * anyway.
     */
    private fun redrawPausedFrame(index: Int, positionMs: Long) {
        val exoPlayer = player ?: return
        if (exoPlayer.playWhenReady) return
        // A seek of its own: the redrawn frame can come on another timestamp
        // base than the seek that first showed it, and has to be tied anew.
        frameEffectsState?.seekTo(index, frameEffectsSourceUs(index, positionMs))
        val stepMs = if (positionMs > 0) positionMs - 1 else positionMs + 1
        recordFrameEffectsMove(index, stepMs)
        exoPlayer.seekTo(index, stepMs)
        recordFrameEffectsMove(index, positionMs)
        exoPlayer.seekTo(index, positionMs)
    }

    /** Redraws the paused frame at the last seek, so frames decoded after it show. */
    private val frameEffectsRedraw = Runnable {
        val (index, positionMs) = frameEffectsSeekTarget ?: return@Runnable
        redrawPausedFrame(index, positionMs)
    }

    /**
     * Sizes the output surface's buffers to [size]. The effect pipeline
     * draws into them through EGL, which takes their size as the canvas;
     * left to themselves they keep the decoder's coded, unrotated size.
     */
    private fun applyFrameEffectSurfaceSize(size: Size) {
        if (frameEffectSurfaceSize == size) return
        frameEffectSurfaceSize = size
        legacyEntry?.surfaceTexture()?.setDefaultBufferSize(size.width, size.height)
        val producer = surfaceProducer ?: return
        producer.setSize(size.width, size.height)
        val surface = producer.surface ?: return
        // Media3 keeps drawing at the size it measured when the surface was
        // attached; detaching first makes it measure the resized one.
        player?.setVideoSurface(null)
        player?.setVideoSurface(surface)
    }

    /**
     * Tells the frame-effect stage where the playhead is, which effects are
     * in their window there, and the timeline its frames step through. The
     * stage checks each frame's own time against the windows; the playhead's
     * windows, read on the position tick, only stand in for a frame whose
     * place on the timeline it does not know.
     */
    private fun updateFrameEffectWindows(globalMs: Long? = null) {
        val state = frameEffectsState ?: return
        val exoPlayer = player ?: return
        val positionUs = (globalMs ?: currentGlobalPlaybackMs(exoPlayer)) * 1000L
        state.enabled = effectWindowsAt(state.configs, positionUs)
        state.playheadUs = positionUs
        state.timeline = frameEffectsTimeline(exoPlayer)
        state.speed = clipSpeeds.getOrElse(exoPlayer.currentMediaItemIndex) { 1.0f }
    }

    /**
     * The timeline the player's frames step through, or null until every
     * clip's length is known.
     */
    private fun frameEffectsTimeline(exoPlayer: ExoPlayer): FrameEffectsState.Timeline? {
        val timeline = exoPlayer.currentTimeline
        if (timeline.isEmpty || timeline.windowCount != exoPlayer.mediaItemCount) return null
        val window = androidx.media3.common.Timeline.Window()
        val clips = (0 until timeline.windowCount).map { i ->
            val durationUs = timeline.getWindow(i, window).durationUs
            if (durationUs == C.TIME_UNSET || durationUs <= 0) return null
            FrameEffectsState.Timeline.Clip(
                durationUs,
                clipSpeeds.getOrElse(i) { 1.0f }.coerceAtLeast(MIN_PLAYBACK_SPEED),
            )
        }
        return FrameEffectsState.Timeline(clips, isLooping)
    }

    /**
     * Records for the frame-effect stage that the player moves to
     * [localSourceMs] of clip [index]. Call before every seek or prepare.
     */
    private fun recordFrameEffectsMove(index: Int, localSourceMs: Long) {
        val state = frameEffectsState ?: return
        val offsetMs = clipOffsets.getOrNull(index)
        state.repositionTo(
            offsetMs?.let {
                (it + sourceToPlaybackMs(localSourceMs, clipSpeeds.getOrElse(index) { 1.0f })) * 1000L
            },
        )
    }

    /**
     * The display size of clip [index], read from its file the first time it
     * is needed. A clip whose size cannot be read is read again.
     */
    private fun frameEffectClipSize(index: Int): Size? =
        frameEffectClipSizes.getOrPut(index) { probeDisplaySize(index) }

    /**
     * Sizes the effect stage's output to the clip at [index] when its size
     * differs from the last one. A fixed output size would draw a clip of
     * another shape on the previous clip's canvas.
     */
    private fun syncFrameEffectOutputSize(index: Int) {
        if (frameEffectsState == null) return
        val size = frameEffectClipSize(index) ?: return
        if (size == frameEffectOutputSize) return
        frameEffectOutputSize = size
        sendFrameEffectOutputResolution()
        sendStateUpdate()
    }

    /**
     * Tells the frame effects about a seek to [localSourceMs] of clip
     * [index], before the player makes it, and asks for the earlier frames
     * the effects need there to be decoded from the clip's file.
     */
    private fun onFrameEffectsSeek(index: Int, localSourceMs: Long) {
        val state = frameEffectsState ?: return
        recordFrameEffectsMove(index, localSourceMs)
        state.seekTo(index, frameEffectsSourceUs(index, localSourceMs))
        frameEffectsSeekTarget = index to localSourceMs
        lastFrameEffectsSeekMs = android.os.SystemClock.uptimeMillis()
        // This seek draws with whatever was decoded so far; a redraw is only
        // owed once newer frames arrive after it.
        mainHandler.removeCallbacks(frameEffectsRedraw)
        frameEffectsFillRequest = index to localSourceMs
        startFrameEffectsFill()
    }

    /** Where [localSourceMs] of clip [index] lies in its file, in µs. */
    private fun frameEffectsSourceUs(index: Int, localSourceMs: Long): Long {
        val clipStartMs = (lastClipsRaw.getOrNull(index)?.get("startMs") as? Number)?.toLong() ?: 0L
        return (clipStartMs + localSourceMs) * 1000L
    }

    /**
     * Decodes the earlier frames for the newest seek, unless a decode is
     * running. A running decode is not dropped for a seek close to it: while
     * scrubbing slowly every seek would otherwise cancel the one before, and
     * no frames would ever arrive. Its frames serve the positions near it,
     * and the newest seek is decoded right after.
     */
    private fun startFrameEffectsFill() {
        if (frameEffectsFillRunning != null) return
        val request = frameEffectsFillRequest ?: return
        val state = frameEffectsState ?: return
        // The offsets come from the effects the GL thread builds on its next
        // frame; until then they are the previous effects' or none. The
        // request waits, and the GL thread starts it once it published them.
        if (state.publishedConfigVersion != state.configVersion) return
        frameEffectsFillRequest = null
        val offsets = state.historyOffsetsUs
        if (offsets.isEmpty()) return
        val (index, localSourceMs) = request
        val clip = lastClipsRaw.getOrNull(index) ?: return
        val uri = clip["uri"] as? String ?: return
        val path = when {
            uri.startsWith("/") -> uri
            uri.startsWith("file:") -> Uri.parse(uri).path
            else -> null
        } ?: return
        val clipStartUs = ((clip["startMs"] as? Number)?.toLong() ?: 0L) * 1000L
        val speed = clipSpeeds.getOrElse(index) { 1.0f }
        // With frame effects Media3 reports no video size, so [videoWidth]
        // stays 0; the clip's own display size is read from its file.
        val display = frameEffectClipSize(index) ?: frameEffectOutputSize ?: return
        val scale = state.historyScale
        val width = (display.width * scale).toInt().coerceAtLeast(1)
        val height = (display.height * scale).toInt().coerceAtLeast(1)
        val seekUs = frameEffectsSourceUs(index, localSourceMs)
        val targets = offsets.toList()
            .map { offsetUs -> seekUs - (offsetUs * speed).toLong() }
            .filter { it >= clipStartUs }
        if (targets.isEmpty()) return
        if (frameEffectsFillExecutor.isShutdown) return
        frameEffectsFillRunning = request
        frameEffectsFillExecutor.execute {
            val isCancelled = {
                val newer = frameEffectsFillRequest
                frameEffectsState !== state || (newer != null &&
                    (newer.first != index || abs(newer.second - localSourceMs) > FILL_KEEP_DISTANCE_MS))
            }
            val frames = if (isCancelled()) {
                emptyList()
            } else {
                try {
                    FrameEffectsHistoryDecoder(width, height).decode(path, targets, isCancelled)
                } catch (e: Exception) {
                    DivineVideoPlayerLog.warning(
                        "$logTarget falls back to decoding earlier frames one by one: $e",
                        name = "DivineVideoPlayer.Effects",
                    )
                    decodeHistoryFramesOneByOne(path, targets, width, height, isCancelled)
                }
            }
            if (frames.isEmpty() && !isCancelled()) {
                DivineVideoPlayerLog.warning(
                    "$logTarget decoded none of the ${targets.size} earlier frames for clip $index",
                    name = "DivineVideoPlayer.Effects",
                )
            }
            mainHandler.post {
                frameEffectsFillRunning = null
                if (frameEffectsState === state && frames.isNotEmpty()) {
                    state.pendingFill.set(FrameEffectsState.Fill(index, frames))
                    if (player?.playWhenReady == false) {
                        val sinceSeek = android.os.SystemClock.uptimeMillis() - lastFrameEffectsSeekMs
                        mainHandler.removeCallbacks(frameEffectsRedraw)
                        mainHandler.postDelayed(
                            frameEffectsRedraw,
                            (FRAME_EFFECTS_REDRAW_DELAY_MS - sinceSeek).coerceAtLeast(0L),
                        )
                    }
                }
                startFrameEffectsFill()
            }
        }
    }

    private fun handleJumpToClip(call: MethodCall, result: MethodChannel.Result) {
        val index = (call.argument<Number>("index"))?.toInt() ?: 0
        val exoPlayer = ensurePlayer()
        if (index in 0 until clipCount) {
            onFrameEffectsSeek(index, 0L)
            exoPlayer.seekTo(index, 0)
            syncAudioOverlays()
        }
        result.success(null)
    }

    // -- play / pause with audio sync --

    // The private loop track is not started or stopped here: it follows the
    // player's actual playing state in [onIsPlayingChanged], which these
    // calls reach through the player itself.
    private fun handlePlay(result: MethodChannel.Result) {
        ensurePlayer().play()
        audioOverlayManager.resumeActive()
        result.success(null)
    }

    private fun handlePause(result: MethodChannel.Result) {
        ensurePlayer().pause()
        audioOverlayManager.pauseAll()
        result.success(null)
    }

    private fun handleStop(result: MethodChannel.Result) {
        val exoPlayer = player ?: run {
            result.success(null)
            return
        }
        audioOverlayManager.stopAndDeactivateAll()
        // Stop and clear media so the surface goes blank.
        exoPlayer.stop()
        exoPlayer.clearMediaItems()
        // The loop track plays outside the player, so stopping the player does
        // not stop it — the sound would keep looping over a blank surface.
        releaseClipAudioLoop()
        clipOffsets = listOf()
        clipVolumes = listOf()
        clipSpeeds = listOf()
        clipCount = 0
        firstFrameRendered = false
        sendStateUpdate()
        result.success(null)
    }

    // -- audio overlay tracks --

    @Suppress("UNCHECKED_CAST")
    private fun handleSetAudioTracks(call: MethodCall, result: MethodChannel.Result) {
        val tracksRaw = call.argument<List<Map<String, Any?>>>("tracks") ?: run {
            result.error("INVALID_ARGS", "tracks list required", null)
            return
        }
        audioOverlayManager.setTracks(tracksRaw, speed.toFloat())
        DivineVideoPlayerLog.info(
            "$logTarget set ${tracksRaw.size} audio overlay track(s)",
            name = "DivineVideoPlayer.Audio",
        )
        syncAudioOverlays()
        result.success(null)
    }

    private fun handleRemoveAllAudioTracks(result: MethodChannel.Result) {
        audioOverlayManager.releaseAll()
        result.success(null)
    }

    private fun handleSetAudioTrackVolume(call: MethodCall, result: MethodChannel.Result) {
        val index = (call.argument<Number>("index"))?.toInt() ?: -1
        val vol = (call.argument<Number>("volume"))?.toFloat() ?: 1.0f
        audioOverlayManager.setTrackVolume(index, vol)
        result.success(null)
    }

    /** Syncs audio overlays to the current global video position. */
    private fun syncAudioOverlays() {
        val videoPlayer = player ?: return
        val globalPositionMs = currentGlobalPlaybackMs(videoPlayer)
        audioOverlayManager.update(globalPositionMs, videoPlayer.isPlaying)
    }

    /**
     * A frame for [generation] is about to be rendered. Completes a paused
     * seek only when this is still that seek and the player is ready; a
     * frame that arrives first just clears the wait so STATE_READY can.
     */
    private fun onSeekFrameRendered(generation: Int) {
        if (generation != seekFrameGeneration || !seekAwaitsFrame) return
        seekAwaitsFrame = false
        if (player?.playbackState == Player.STATE_READY) completeSeekIfPending()
    }

    /** Completes the pending seekTo result so Dart's await returns. */
    private fun completeSeekIfPending() {
        seekAwaitsFrame = false
        seekCompletionResult?.let {
            mainHandler.removeCallbacks(seekTimeoutRunnable)
            it.success(null)
            seekCompletionResult = null
        }
    }

    // -- state broadcasting --

    private fun sendStateUpdate() {
        if (isResettingPlayer) return
        val exoPlayer = player ?: return
        val sink = eventSink ?: return

        val currentIndex = exoPlayer.currentMediaItemIndex
        val globalPositionMs = when {
            // While buffering toward an initial seek, report the target so the
            // timeline doesn't wander through intermediate positions.
            pendingGlobalStartMs > 0 -> pendingGlobalStartMs
            else -> currentGlobalPlaybackMs(exoPlayer)
        }

        val totalDurationMs = computeTotalDuration(exoPlayer)

        val statusString = when {
            exoPlayer.playerError != null -> "error"
            exoPlayer.playbackState == Player.STATE_BUFFERING -> "buffering"
            exoPlayer.playbackState == Player.STATE_ENDED -> "completed"
            exoPlayer.playbackState == Player.STATE_IDLE -> "idle"
            exoPlayer.isPlaying -> "playing"
            exoPlayer.playbackState == Player.STATE_READY -> if (exoPlayer.playWhenReady) "playing" else "paused"
            else -> "idle"
        }

        val map = mutableMapOf<String, Any>(
            "status" to statusString,
            "positionMs" to globalPositionMs,
            "durationMs" to totalDurationMs,
            "bufferedPositionMs" to computeBufferedPosition(exoPlayer),
            "currentClipIndex" to currentIndex,
            "clipCount" to clipCount,
            "isLooping" to isLooping,
            "volume" to volume,
            "playbackSpeed" to speed,
            "isFirstFrameRendered" to firstFrameRendered,
            // With frame effects, Media3 reports no video size (b/292111083)
            // and its pipeline hands over upright frames: report the display
            // size it draws, unrotated.
            "videoWidth" to (frameEffectReportedSize?.width ?: videoWidth),
            "videoHeight" to (frameEffectReportedSize?.height ?: videoHeight),
            "pixelWidthHeightRatio" to if (frameEffectReportedSize != null) 1.0 else pixelWidthHeightRatio,
            "rotationDegrees" to if (frameEffectReportedSize != null) 0 else rotationDegrees,
        )
        exoPlayer.playerError?.let { error ->
            map["errorMessage"] = error.localizedMessage
                ?: error.cause?.localizedMessage
                ?: error.errorCodeName
            map["errorCode"] = errorCodeFor(error)
        }
        sink.success(map)
    }

    /** Human-readable name for a media3 `PLAY_WHEN_READY_CHANGE_REASON_*`. */
    private fun playWhenReadyReasonName(reason: Int): String =
        when (reason) {
            Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST -> "user_request"
            Player.PLAY_WHEN_READY_CHANGE_REASON_AUDIO_FOCUS_LOSS -> "audio_focus_loss"
            Player.PLAY_WHEN_READY_CHANGE_REASON_AUDIO_BECOMING_NOISY -> "audio_becoming_noisy"
            Player.PLAY_WHEN_READY_CHANGE_REASON_REMOTE -> "remote"
            Player.PLAY_WHEN_READY_CHANGE_REASON_END_OF_MEDIA_ITEM -> "end_of_media_item"
            else -> "unknown($reason)"
        }

    /** Human-readable name for a media3 `Player.STATE_*`. */
    private fun playbackStateName(state: Int?): String =
        when (state) {
            Player.STATE_IDLE -> "idle"
            Player.STATE_BUFFERING -> "buffering"
            Player.STATE_READY -> "ready"
            Player.STATE_ENDED -> "ended"
            else -> "unknown($state)"
        }

    private fun errorCodeFor(error: PlaybackException): String =
        when (error.errorCode) {
            PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS -> {
                val status =
                    (error.cause as? HttpDataSource.InvalidResponseCodeException)
                        ?.responseCode ?: 0
                when {
                    status == 202 -> "media_processing"
                    status == 401 -> "auth_required"
                    status == 403 -> "forbidden"
                    status == 404 -> "not_found"
                    status in 400..499 -> "http_client_error"
                    else -> "http_server_error"
                }
            }
            PlaybackException.ERROR_CODE_IO_FILE_NOT_FOUND,
            PlaybackException.ERROR_CODE_IO_INVALID_HTTP_CONTENT_TYPE,
            PlaybackException.ERROR_CODE_IO_NO_PERMISSION -> "http_client_error"
            PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED -> "network_error"
            PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT -> "timeout"
            in 2000..2999 -> "io_error"
            in 3000..3999 -> "parse_error"
            in 4000..4999 -> "decoder_error"
            in 5000..5999 -> "decoder_error"
            in 6000..6999 -> "decoder_error"
            else -> "unknown"
        }

    private fun computeTotalDuration(exoPlayer: ExoPlayer): Long {
        var total = 0L
        val timeline = exoPlayer.currentTimeline
        for (i in 0 until exoPlayer.mediaItemCount) {
            val windowDuration = if (timeline.isEmpty) {
                0L
            } else {
                val w = androidx.media3.common.Timeline.Window()
                timeline.getWindow(i, w)
                val durationMs = w.durationMs
                // Return 0 for unknown durations to avoid Long overflow when
                // accumulating C.TIME_UNSET across an even number of clips.
                if (durationMs < 0) 0L else durationMs
            }
            // Convert source duration → playback (timeline) duration so the
            // total matches the speed-adjusted timeline Dart renders.
            val clipSpeed = clipSpeeds.getOrElse(i) { 1.0f }
            total += sourceToPlaybackMs(windowDuration, clipSpeed)
        }
        // Update offsets with real durations once media is prepared.
        if (total > 0) refreshClipOffsets(exoPlayer)
        return total
    }

    /**
     * Recalculates [clipOffsets] from ExoPlayer's timeline when real
     * durations are available. Called from [computeTotalDuration] and
     * before seek operations to ensure correct clip-index resolution.
     */
    private fun refreshClipOffsets(exoPlayer: ExoPlayer) {
        val timeline = exoPlayer.currentTimeline
        if (timeline.isEmpty || clipOffsets.size != exoPlayer.mediaItemCount) {
            return
        }
        val newOffsets = mutableListOf<Long>()
        var accum = 0L
        var allResolved = true
        for (i in 0 until exoPlayer.mediaItemCount) {
            newOffsets.add(accum)
            val w = androidx.media3.common.Timeline.Window()
            timeline.getWindow(i, w)
            val durationMs = w.durationMs
            if (durationMs < 0) {
                // Duration not yet resolved for this clip — skip it but
                // continue so that earlier clips still get correct offsets.
                allResolved = false
                continue
            }
            // Offsets accumulate in playback (speed-adjusted) time.
            val clipSpeed = clipSpeeds.getOrElse(i) { 1.0f }
            accum += sourceToPlaybackMs(durationMs, clipSpeed)
        }
        // Only update when ALL durations are known so partial data from clips
        // that haven't buffered yet doesn't corrupt earlier clip offsets.
        if (allResolved && accum > 0) clipOffsets = newOffsets
    }

    /** Returns the global buffered position in ms for the current clip. */
    private fun computeBufferedPosition(exoPlayer: ExoPlayer): Long {
        val currentIndex = exoPlayer.currentMediaItemIndex
        val localBufferedSource = exoPlayer.bufferedPosition
        val clipSpeed = clipSpeeds.getOrElse(currentIndex) { 1.0f }
        val localBufferedPlayback = sourceToPlaybackMs(localBufferedSource, clipSpeed)
        return if (currentIndex < clipOffsets.size) {
            clipOffsets[currentIndex] + localBufferedPlayback
        } else {
            localBufferedPlayback
        }
    }

    /**
     * Returns the current global playback-time position by mapping
     * ExoPlayer's source-time `currentPosition` through the active clip's
     * playback speed.
     */
    private fun currentGlobalPlaybackMs(exoPlayer: ExoPlayer): Long {
        val currentIndex = exoPlayer.currentMediaItemIndex
        val localSourceMs = exoPlayer.currentPosition
        val clipSpeed = clipSpeeds.getOrElse(currentIndex) { 1.0f }
        val localPlaybackMs = sourceToPlaybackMs(localSourceMs, clipSpeed)
        return if (currentIndex < clipOffsets.size) {
            clipOffsets[currentIndex] + localPlaybackMs
        } else {
            localPlaybackMs
        }
    }

    /** Source duration / speed = playback (timeline) duration. */
    private fun sourceToPlaybackMs(sourceMs: Long, speed: Float): Long {
        if (sourceMs <= 0L) return 0L
        val safe = speed.coerceAtLeast(MIN_PLAYBACK_SPEED)
        return (sourceMs.toDouble() / safe.toDouble()).toLong()
    }

    /** Playback (timeline) duration * speed = source duration. */
    private fun playbackToSourceMs(playbackMs: Long, speed: Float): Long {
        if (playbackMs <= 0L) return 0L
        val safe = speed.coerceAtLeast(MIN_PLAYBACK_SPEED)
        return (playbackMs.toDouble() * safe.toDouble()).toLong()
    }

    // -- player listener --

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            if (playbackState == Player.STATE_BUFFERING) {
                // Arm the freeze watchdog once per stall episode.
                if (!bufferingStallReported) {
                    mainHandler.removeCallbacks(bufferingWatchdogRunnable)
                    mainHandler.postDelayed(
                        bufferingWatchdogRunnable,
                        BUFFERING_STALL_MS,
                    )
                }
            } else {
                mainHandler.removeCallbacks(bufferingWatchdogRunnable)
                bufferingStallReported = false
            }
            if (playbackState == Player.STATE_ENDED && loopsBySeeking) {
                // Start the next lap by hand. Dart is not told the clip
                // completed, as it is not under a repeat mode.
                restartingLap = true
                // Anchor the fade in at the lap's start, as handleSeekTo does
                // at its target: a seek is not a stream change, so nothing
                // else retires an offset an earlier seek left behind.
                declickProcessor.nextStreamStartUs = 0L
                recordFrameEffectsMove(0, 0L)
                player?.seekTo(0, 0L)
                syncAudioOverlays()
                return
            }
            if (playbackState == Player.STATE_ENDED && isLooping) {
                syncAudioOverlays()
            }
            if (playbackState == Player.STATE_READY) {
                restartingLap = false
                // The video's length is only readable once the timeline is
                // populated, and it bounds how long the fade may be.
                updateDeclickDuration()
                if (clipAudioPending) startClipAudioLoop(lastClipsRaw, lastClipsRaw.size)
                // Seek complete — switch from reporting target to actual position.
                pendingGlobalStartMs = 0L
                if (!seekAwaitsFrame) completeSeekIfPending()
                // setClips complete — unblock the Dart await.
                mainHandler.removeCallbacks(setClipsTimeoutRunnable)
                pendingSetClipsResult?.success(null)
                pendingSetClipsResult = null
            }
            sendStateUpdate()
        }

        /**
         * The decisive signal when a video stops with no user action: media3
         * names *why* `playWhenReady` flipped, which separates our own
         * `pause()` (`USER_REQUEST`) from the platform taking playback away
         * (`AUDIO_FOCUS_LOSS`, `AUDIO_BECOMING_NOISY`, `REMOTE`).
         */
        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
            val message =
                "$logTarget playWhenReady=$playWhenReady " +
                    "(${playWhenReadyReasonName(reason)})"
            if (playWhenReady) {
                DivineVideoPlayerLog.debug(message, name = "DivineVideoPlayer.Playback")
            } else {
                DivineVideoPlayerLog.info(message, name = "DivineVideoPlayer.Playback")
            }
        }

        /**
         * Reports a stop that nobody asked for.
         *
         * `playWhenReady` still true means this player was not paused — it
         * stopped on its own. The buffering watchdog only fires after 8s, so
         * a shorter stall would otherwise leave no trace at all.
         *
         * Three routine transitions reach the same callback and are not
         * anomalies: a seek drives the player through `STATE_BUFFERING` on
         * its way to the new position, a non-looping clip reaching its end
         * lands in `STATE_ENDED`, and a requested `stop()` lands in
         * `STATE_IDLE`. The last covers Dart's `stop()`, Activity detach, and
         * a fatal error — none of which clear `playWhenReady`, and the error
         * is already reported by [onPlayerError]. All are reported at debug so
         * the info line keeps meaning "stopped for no reason we asked for".
         */
        private fun reportUnrequestedStop() {
            val exoPlayer = player ?: return
            if (!exoPlayer.playWhenReady) return

            val state = exoPlayer.playbackState
            val expected =
                seekCompletionResult != null ||
                    restartingLap ||
                    state == Player.STATE_ENDED ||
                    state == Player.STATE_IDLE
            val message =
                "$logTarget stopped playing while still requested to play " +
                    "(state=${playbackStateName(state)}" +
                    (if (seekCompletionResult != null) ", seeking" else "") +
                    ")"
            if (expected) {
                DivineVideoPlayerLog.debug(message, name = "DivineVideoPlayer.Playback")
            } else {
                DivineVideoPlayerLog.info(message, name = "DivineVideoPlayer.Playback")
            }
        }

        override fun onIsLoadingChanged(isLoading: Boolean) {
            // Fires at every load boundary — the player pauses each megabyte
            // to ask whether to go on — and at the one that completes the
            // clip, which is the only one the waiting decode is after.
            if (clipAudioAwaitingLoad && player?.hasBufferedWholeClip() == true) {
                startClipAudioLoop(lastClipsRaw, lastClipsRaw.size)
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            // The private loop track has no playWhenReady of its own, so it is
            // keyed to the player's *actual* playing state rather than to the
            // play and pause Dart asks for. That covers the pauses the player
            // makes by itself — backgrounding, a buffering stall, an Activity
            // detach — which would otherwise leave the track sounding over a
            // still picture, and restarts it from where the picture now is
            // when play resumes. The player's volume is used because it
            // already folds in the clip's own gain and is deliberately zero
            // during the foreground frame flush.
            if (isPlaying) {
                player?.let { exoPlayer ->
                    clipAudioLoop?.let { loop ->
                        loop.play(exoPlayer.currentPosition * 1000L, exoPlayer.volume)
                        if (clipAudioTakeover == null) scheduleClipAudioSync()
                    }
                }
                syncAudioOverlays()
            } else {
                finishClipAudioTakeover()
                mainHandler.removeCallbacks(clipAudioSyncRunnable)
                clipAudioLoop?.pause()
                audioOverlayManager.pauseAndDeactivateAll()
                reportUnrequestedStop()
            }
            sendStateUpdate()
        }

        override fun onPositionDiscontinuity(
            oldPosition: Player.PositionInfo,
            newPosition: Player.PositionInfo,
            reason: Int,
        ) {
            // Apply per-clip speed/volume as early as possible on auto-transition.
            // [onMediaItemTransition] fires later in the pipeline, after a few
            // frames of the new clip have already rendered with the previous
            // clip's playback parameters — audible/visible as a brief
            // fast-forward (or slow-mo) at the start of the new clip when
            // speeds differ. Position discontinuity fires at the moment the
            // playback position jumps to the new media item, so resetting
            // here closes that window.
            // The mediaItemIndex guard also makes this a no-op for a single
            // repeating clip: both indices are 0, so the block is skipped
            // entirely → seamless loop regardless of speed.
            if (reason == Player.DISCONTINUITY_REASON_AUTO_TRANSITION &&
                newPosition.mediaItemIndex != oldPosition.mediaItemIndex
            ) {
                val newIndex = newPosition.mediaItemIndex
                val oldIndex = oldPosition.mediaItemIndex
                val newSpeed = clipSpeeds.getOrElse(newIndex) { 1.0f }
                val oldSpeed = clipSpeeds.getOrElse(oldIndex) { 1.0f }
                player?.let { applyClipVolume(it, newIndex) }
                player?.setPlaybackParameters(PlaybackParameters(newSpeed))
                // setPlaybackParameters alone does not flush the audio sink
                // (Sonic) buffer that was filled at the previous clip's rate.
                // Audible result: the first ~500 ms of the new clip plays
                // at the previous clip's speed before Sonic catches up. A
                // [seekTo] of the new clip's start forces a renderer flush
                // so subsequent samples are stretched at the new rate from
                // frame zero. Only do this when the speed actually differs,
                // to avoid an unnecessary stutter on equal-speed transitions.
                if (newSpeed != oldSpeed) {
                    recordFrameEffectsMove(newIndex, 0L)
                    player?.seekTo(newIndex, 0L)
                }
            }
        }

        override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
            player?.let { syncFrameEffectOutputSize(it.currentMediaItemIndex) }
            // When ExoPlayer auto-advances to the next playlist item it reuses the
            // decoder without reconfiguring the output surface rotation. Force a
            // detach+reattach so the decoder re-initialises its rotation transform
            // for the new clip. Not needed for PLAYLIST_CHANGED (reason=3) because
            // the surface is freshly attached at that point.
            if (reason == Player.MEDIA_ITEM_TRANSITION_REASON_AUTO) {
                val surface = activeSurface
                if (surface != null && !needsSurface) {
                    player?.setVideoSurface(null)
                    player?.setVideoSurface(surface)
                    sendFrameEffectOutputResolution()
                }
            }
            // Apply per-clip volume and speed for the clip that just started.
            // [onPositionDiscontinuity] already handles the speed/volume switch
            // (including the Sonic-flush seekTo) for every automatic transition
            // between clips. This block is therefore a safety-net only: it
            // covers any edge case where onPositionDiscontinuity did not fire
            // (e.g. a single-item repeat, where mediaItemIndex does not
            // change).
            // The seekTo flush is intentionally NOT repeated here — a second
            // seekTo on the same frame causes a double-stutter at the loop
            // restart point without any audio benefit.
            if (reason == Player.MEDIA_ITEM_TRANSITION_REASON_AUTO ||
                reason == Player.MEDIA_ITEM_TRANSITION_REASON_REPEAT
            ) {
                val newIndex = player?.currentMediaItemIndex ?: 0
                val newSpeed = clipSpeeds.getOrElse(newIndex) { 1.0f }
                player?.let { applyClipVolume(it, newIndex) }
                player?.setPlaybackParameters(PlaybackParameters(newSpeed))
            }
            syncAudioOverlays()
            sendStateUpdate()
        }

        override fun onPlayerError(error: PlaybackException) {
            val currentUri = player?.currentMediaItem?.localConfiguration?.uri
            val nativeErrorCode = errorCodeFor(error)
            val message =
                "$logTarget playback error [${error.errorCodeName}]: " +
                    "source=${currentUri ?: "unknown"} " +
                    (error.message ?: "unknown")
            if (nativeErrorCode == "media_processing") {
                DivineVideoPlayerLog.warning(
                    message,
                    name = "DivineVideoPlayer.Playback",
                )
            } else {
                DivineVideoPlayerLog.error(
                    message,
                    name = "DivineVideoPlayer.Playback",
                )
            }
            // A transient decoder failure may recover on a re-prepare; keep the
            // pending setClips result open so a successful retry still resolves
            // it (or the 10 s watchdog fires if every retry fails).
            if (maybeRecoverFromDecoderError(error)) return
            // Unblock a pending setClips with an error so Dart can react
            // rather than waiting for the 10 s safety timeout.
            mainHandler.removeCallbacks(setClipsTimeoutRunnable)
            pendingSetClipsResult?.error(
                "PLAYER_ERROR",
                error.message ?: "Unknown playback error",
                mapOf("errorCode" to nativeErrorCode),
            )
            pendingSetClipsResult = null
            sendStateUpdate()
        }

        // media3 generates the session off the main thread, so a fresh
        // player may only report it after its first clip's volume was set.
        override fun onAudioSessionIdChanged(audioSessionId: Int) {
            playerBoost.attach(audioSessionId)
        }

        override fun onRenderedFirstFrame() {
            firstFrameRendered = true
            // A frame reached the surface, so whatever contention caused a
            // prior decoder error has cleared — allow the full retry budget
            // again for any future error.
            decoderRetryCount = 0
            sendStateUpdate()
        }

        override fun onVideoSizeChanged(videoSize: androidx.media3.common.VideoSize) {
            // Send 0 when the active backend already applies the GL transform
            // matrix (legacy SurfaceTexture always does; SurfaceProducer does
            // when handlesCropAndRotation() reports true on Android 14+).
            // RotatedBox in Dart would double-rotate in those cases. On the
            // SurfaceProducer fallback path Dart must compensate.
            //
            // Guard: ExoPlayer emits onVideoSizeChanged(0, 0) as an intermediate
            // reset during seeks and transitions; skip to avoid a brief flash
            // of 0° rotation.
            val newRotation = if (backendHandlesRotation) {
                0
            } else {
                player?.videoFormat?.rotationDegrees ?: 0
            }
            if (videoSize.width > 0 && videoSize.height > 0) {
                videoWidth = videoSize.width
                videoHeight = videoSize.height
                pixelWidthHeightRatio = videoSize.pixelWidthHeightRatio
                    .takeIf { it.isFinite() && it > 0f }?.toDouble() ?: 1.0
                rotationDegrees = newRotation
                sendFrameEffectOutputResolution()
            } else {
                // Keep all display-dimension fields coherent during Media3's
                // transient reset between clips and seeks.
                videoWidth = 0
                videoHeight = 0
                pixelWidthHeightRatio = 1.0
            }
            sendStateUpdate()
        }
    }

    /**
     * Re-prepares the player after a transient decoder error, bounded to
     * [MAX_DECODER_RETRIES]. Returns `true` when a retry was scheduled so the
     * caller leaves the pending setClips result open for a successful retry.
     *
     * `DECODER_INIT_FAILED` / `DECODING_FAILED` on an editing/preview surface
     * is usually contention for a scarce hardware decoder (feed + editor +
     * preview + thumbnail extraction competing) rather than a bad file — the
     * same output often decodes on the next attempt once a competing codec
     * releases. Feed players keep ExoPlayer's own recovery, so this is scoped
     * to [BufferProfile.FULL].
     */
    private fun maybeRecoverFromDecoderError(error: PlaybackException): Boolean {
        if (bufferProfile != BufferProfile.FULL) return false
        val isDecoderError =
            error.errorCode == PlaybackException.ERROR_CODE_DECODER_INIT_FAILED ||
                error.errorCode == PlaybackException.ERROR_CODE_DECODING_FAILED
        if (!isDecoderError || decoderRetryCount >= MAX_DECODER_RETRIES) return false

        val recoveringPlayer = player ?: return false
        decoderRetryCount++
        DivineVideoPlayerLog.warning(
            "$logTarget decoder error [${error.errorCodeName}] — " +
                "retry $decoderRetryCount/$MAX_DECODER_RETRIES " +
                "in ${DECODER_RETRY_DELAY_MS}ms",
            name = "DivineVideoPlayer.Playback",
        )
        cancelDecoderRetry()
        val retryRunnable = object : Runnable {
            override fun run() {
                if (decoderRetryRunnable === this) decoderRetryRunnable = null
                // The player may have been released or replaced while waiting;
                // only re-prepare the exact instance that errored.
                if (player === recoveringPlayer) recoveringPlayer.prepare()
            }
        }
        decoderRetryRunnable = retryRunnable
        mainHandler.postDelayed(retryRunnable, DECODER_RETRY_DELAY_MS)
        return true
    }

    private fun cancelDecoderRetry() {
        decoderRetryRunnable?.let { mainHandler.removeCallbacks(it) }
        decoderRetryRunnable = null
    }

    // -- lifecycle --

    /** Whether the player was playing before the app went to background. */
    private var wasPlayingBeforePause = false

    /**
     * Called when the app moves to the background.
     * Pauses playback and remembers the previous state.
     */
    fun onAppBackgrounded() {
        wasPlayingBeforePause = player?.isPlaying ?: false
        if (wasPlayingBeforePause) {
            player?.pause()
            audioOverlayManager.pauseAll()
            sendStateUpdate()
        }
    }

    /**
     * Called when the app returns to the foreground.
     * Resumes playback only if it was playing before. For players that were
     * already paused before backgrounding, seeks to the current position so
     * ExoPlayer decodes and displays the current frame — without this the
     * surface stays black on devices where the Surface is not destroyed and
     * recreated on background (i.e. onSurfaceAvailable is never called).
     */
    fun onAppForegrounded() {
        val p = player
        if (wasPlayingBeforePause) {
            p?.play()
            audioOverlayManager.resumeActive()
            wasPlayingBeforePause = false
            sendStateUpdate()
        } else if (p != null && !p.isPlaying && p.playbackState == Player.STATE_READY) {
            // seekTo() does not reliably flush a frame to the surface on all
            // devices. play() forces the decoder to output a frame; we
            // immediately schedule a pause on the next main-thread loop so the
            // video doesn't actually advance. Mute during this single frame
            // to avoid an audible glitch.
            p.volume = 0f
            p.play()
            mainHandler.post {
                p.pause()
                p.volume = nominalPlayerVolume()
            }
        }
    }

    fun getPlayer(): ExoPlayer? = player

    /**
     * Stops decoding and detaches the video surface without releasing the
     * player. Used during Activity teardown so in-flight decoder frames
     * narrow the window where they can land in a detaching
     * `ImageReaderSurfaceProducer`. The full [dispose] runs later, on
     * engine detach.
     *
     * Cancels any pending decoder-retry re-prepare: the player is not nulled
     * here (only [dispose] does that), so a scheduled retry's
     * `player === recoveringPlayer` guard would still pass and call
     * `prepare()` on the just-cleared surface after detach began.
     *
     * Asymmetric with [onAppBackgrounded] by design: no resume is expected
     * after Activity detach, so [wasPlayingBeforePause] is not set.
     */
    fun stopForActivityDetach() {
        cancelDecoderRetry()
        player?.let {
            it.stop()
            it.clearVideoSurface()
        }
        // Only the SurfaceProducer backend hands the surface back later via
        // onSurfaceAvailable. The legacy SurfaceTexture surface is owned
        // for the player's lifetime and reattaches eagerly, so leave
        // needsSurface untouched in that case.
        if (surfaceProducer != null) {
            needsSurface = true
        }
        audioOverlayManager.pauseAll()
        // The stop above only pauses the loop track through onIsPlayingChanged;
        // nothing resumes after a detach, so free the AudioTrack now rather
        // than holding it until dispose.
        releaseClipAudioLoop()
    }

    fun dispose() {
        seekFrameGeneration++
        armedSeekGeneration = NO_ARMED_SEEK
        seekAwaitsFrame = false
        mainHandler.removeCallbacks(positionUpdater)
        mainHandler.removeCallbacks(seekTimeoutRunnable)
        mainHandler.removeCallbacks(setClipsTimeoutRunnable)
        mainHandler.removeCallbacks(bufferingWatchdogRunnable)
        cancelDecoderRetry()
        releaseClipAudioLoop()
        metadataExecutor.shutdownNow()
        // A decode still running posts its result back; with no state and no
        // request left, that result is dropped and starts nothing new.
        frameEffectsState = null
        frameEffectsFillRequest = null
        mainHandler.removeCallbacks(frameEffectsRedraw)
        frameEffectsFillExecutor.shutdownNow()
        seekCompletionResult?.success(null)
        seekCompletionResult = null
        pendingSetClipsResult?.success(null)
        pendingSetClipsResult = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        // Release the player before the surface producer. Releasing the
        // producer first can cause in-flight decoder frames to land in a
        // detaching surface, triggering native crashes on some OEMs (#3416).
        playerBoost.release()
        player?.let {
            it.removeListener(playerListener)
            it.stop()
            it.clearVideoSurface()
            it.release()
        }
        player = null
        surfaceProducer?.release()
        surfaceProducer = null
        legacySurface?.release()
        legacySurface = null
        legacyEntry?.release()
        legacyEntry = null
        audioOverlayManager.releaseAll()
        eventSink = null
    }

    companion object {

        /** Whether [uri] addresses an HLS playlist rather than a media file. */
        private fun isHlsSource(uri: String): Boolean {
            val path = uri.substringBefore('?').substringBefore('#')
            return path.endsWith(".m3u8", ignoreCase = true) ||
                path.contains("/hls/", ignoreCase = true)
        }

        /** Whether [uri] is an HLS playlist served from outside Divine. */
        private fun isForeignHlsSource(uri: String): Boolean =
            isHlsSource(uri) && !isDivineHosted(uri)

        /** Whether [uri] is served from a `divine.video` host. */
        private fun isDivineHosted(uri: String): Boolean {
            val host = runCatching { URI(uri).host }.getOrNull()?.lowercase()
                ?: return false
            return host == "divine.video" || host.endsWith(".divine.video")
        }

        /** [armedSeekGeneration] while no paused seek is armed. */
        private const val NO_ARMED_SEEK = -1

        private const val POSITION_UPDATE_INTERVAL_MS = 200L

        /**
         * How far a newer seek may lie from a running frame-effect decode
         * before that decode is dropped; closer, its frames still serve.
         */
        private const val FILL_KEEP_DISTANCE_MS = 500L

        /**
         * How long after a seek decoded frames wait before redrawing the
         * paused frame. While scrubbing the next seek draws with them anyway.
         */
        private const val FRAME_EFFECTS_REDRAW_DELAY_MS = 100L

        /** How often a playing loop track is measured against the picture. */
        private const val CLIP_AUDIO_SYNC_INTERVAL_MS = 250L

        /** How often a loop is checked after a start, until it has been measured. */
        private const val CLIP_AUDIO_SYNC_FIRST_CHECK_MS = 20L

        /** Every this many measurements, one goes to the log. */
        private const val CLIP_AUDIO_SYNC_LOG_EVERY = 40

        /** Spacing of a takeover's alignment checks and fade steps. */
        private const val TAKEOVER_STEP_MS = 10L

        /** A takeover lines the loop up on the median of this many readings. */
        private const val TAKEOVER_READINGS = 5

        /** A takeover crosses over in this many steps: 60 ms. */
        private const val TAKEOVER_FADE_STEPS = 6

        /**
         * How long a takeover waits for the loop to measure in step before
         * crossing over regardless. A timestamp usually arrives within
         * 50–100 ms of a start; an output that never reports one still has
         * to hand over.
         */
        private const val TAKEOVER_ALIGN_TIMEOUT_NS = 500_000_000L
        private const val SET_CLIPS_TIMEOUT_MS = 10_000L

        /**
         * Video and audio track lengths in microseconds, keyed by source.
         *
         * Written by the player's extractor on every parse of a container that
         * carries both, so an entry always describes the file last seen at
         * that address. Shared across instances so a second visit, or a clip
         * with an explicit start, can clamp before its own parse. Bounded,
         * because a long feed session visits a lot of sources.
         */
        private val trackDurationsCache: MutableMap<String, LongArray> =
            Collections.synchronizedMap(
                object : LinkedHashMap<String, LongArray>(16, 0.75f, true) {
                    override fun removeEldestEntry(
                        eldest: MutableMap.MutableEntry<String, LongArray>?,
                    ): Boolean = size > TRACK_DURATION_CACHE_ENTRIES
                },
            )

        private const val TRACK_DURATION_CACHE_ENTRIES = 256

        internal fun clearTrackDurationsCacheForTesting() {
            trackDurationsCache.clear()
        }

        /** Records the track bounds the player's extractor just parsed. */
        internal fun recordTrackEnds(
            uri: String,
            videoEndUs: Long,
            audioEndUs: Long,
            videoStartUs: Long = 0L,
        ) {
            trackDurationsCache[uri] = longArrayOf(videoEndUs, audioEndUs, videoStartUs)
        }

        /** The `[videoEndUs, audioEndUs, videoStartUs]` last recorded for [uri], if any. */
        internal fun trackEndsFor(uri: String): LongArray? = trackDurationsCache[uri]

        /**
         * Names the metadata thread and marks it a daemon.
         *
         * `shutdownNow()` cannot interrupt the loop decode's `MediaExtractor`
         * read — it is native I/O — so a stalled host keeps its thread alive
         * past [dispose]. Daemon so it can never hold the process up, named so
         * a thread dump says which player it belongs to instead of showing an
         * anonymous `pool-N-thread-1`.
         */
        private fun metadataThreadFactory(playerId: Int) = ThreadFactory { runnable ->
            Thread(runnable, "divine-video-metadata-$playerId").apply { isDaemon = true }
        }

        /**
         * How long the player may stay in `STATE_BUFFERING` before it is
         * treated as frozen and a diagnostic is emitted. Long enough to not
         * trip on routine rebuffering, short enough that a real freeze is
         * captured while the user is still on the screen.
         */
        private const val BUFFERING_STALL_MS = 8_000L

        /**
         * Floor for clip playback speed. Prevents division by zero when
         * converting between source and playback time, and matches the
         * sensible lower bound the editor UI exposes.
         */
        private const val MIN_PLAYBACK_SPEED = 0.001f


        /**
         * How many times an editing/preview player re-prepares after a
         * transient decoder error before giving up. Small: a couple of
         * attempts covers momentary hardware-decoder contention without
         * masking a genuinely undecodable clip.
         */
        private const val MAX_DECODER_RETRIES = 2

        /**
         * Delay before a decoder-error re-prepare, giving a competing codec
         * time to release its hardware decoder before we ask for one again.
         */
        private const val DECODER_RETRY_DELAY_MS = 350L
    }
}
