package com.divinevideo.divine_video_player

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.Surface
import java.util.Collections
import kotlin.math.abs
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.ThreadFactory
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.Timeline
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.HttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.SeekParameters
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
    /** Per-clip audio volumes (0.0–1.0). Multiplied by [volume] on each clip transition. */
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

    private var isLooping = false

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
     * Pending result for an async seekTo call.
     * Completed when ExoPlayer transitions to STATE_READY after a seek,
     * so the Dart `await seekTo()` blocks until the frame is decoded.
     */
    private var seekCompletionResult: MethodChannel.Result? = null

    /** Safety timeout so Dart is never left hanging if the callback is lost. */
    private val seekTimeoutRunnable = Runnable {
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
            return entry.id()
        }
        val producer = registry.createSurfaceProducer()
        surfaceProducer = producer
        producer.setCallback(this)
        val surface = producer.surface
        needsSurface = surface == null
        if (surface != null) {
            player?.setVideoSurface(surface)
        }
        return producer.id()
    }

    private fun ensurePlayer(): ExoPlayer {
        return player ?: (playerFactory?.invoke(context) ?: buildDefaultPlayer())
            .also { newPlayer ->
                player = newPlayer
                newPlayer.setSeekParameters(SeekParameters.EXACT)
                newPlayer.addListener(playerListener)
                val surface = activeSurface
                if (surface != null) {
                    newPlayer.setVideoSurface(surface)
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
        // the shorter track ends before its first frame. See
        // [CommonTrackEndMediaSource].
        val extractorsFactory = TrackEndCapturingExtractorsFactory(DefaultExtractorsFactory()) {
                uri, videoEndUs, audioEndUs ->
            recordTrackEnds(uri.toString(), videoEndUs, audioEndUs)
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
                needsSurface = false
                // ExoPlayer does not re-render the current frame after a surface
                // reattach when the player is paused — the surface stays black
                // until the next decoded frame arrives (i.e. not until play()).
                // Seeking to the current position forces the codec to decode and
                // display the frame at the current position without moving it.
                if (!p.isPlaying && p.playbackState == Player.STATE_READY) {
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
            "setPlaybackSpeed" -> handleSetPlaybackSpeed(call, result)
            "setLooping" -> handleSetLooping(call, result)
            "jumpToClip" -> handleJumpToClip(call, result)
            "setAudioTracks" -> handleSetAudioTracks(call, result)
            "removeAllAudioTracks" -> handleRemoveAllAudioTracks(result)
            "setAudioTrackVolume" -> handleSetAudioTrackVolume(call, result)
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
        exoPlayer.volume = clipVolumes.getOrElse(startIndex) { 1.0f } * volume.toFloat()
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
        val containerEndMs = (durations.maxOrNull() ?: return false) / 1000
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
        val path = uri.substringBefore('?').substringBefore('#')
        if (path.endsWith(".m3u8", ignoreCase = true) ||
            path.contains("/hls/", ignoreCase = true)
        ) {
            return false
        }
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
        val loopUs = if (awaitTimeline) C.TIME_UNSET else presentedDurationUs(exoPlayer)
        if (loopUs == C.TIME_UNSET || loopUs <= 0) {
            clipAudioPending = true
            return
        }
        clipAudioPending = false

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
                val loop = ClipAudioLoopTrack.create(uri, headers, loopUs, remoteSourceFactory)
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
     * The single clip's presented length in microseconds, or [C.TIME_UNSET].
     *
     * Read from the timeline rather than [ExoPlayer.getDuration], which rounds
     * down to whole milliseconds. The loop track repeats in the HAL on its own
     * clock, so a loop even a fraction of a millisecond short of the picture's
     * period walks away from it by that much on every lap.
     */
    private fun presentedDurationUs(exoPlayer: ExoPlayer): Long {
        val timeline = exoPlayer.currentTimeline
        if (timeline.isEmpty) return C.TIME_UNSET
        return timeline.getWindow(exoPlayer.currentMediaItemIndex, Timeline.Window()).durationUs
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

    /** The player's volume outside a takeover: the clip's gain times Dart's. */
    private fun nominalPlayerVolume(): Float =
        clipVolumes.getOrElse(player?.currentMediaItemIndex ?: 0) { 1.0f } * volume.toFloat()

    /**
     * Keeps a playing loop on the picture; see [LoopAudioSync].
     *
     * Runs every [CLIP_AUDIO_SYNC_INTERVAL_MS] while the loop plays. A few
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
            mainHandler.postDelayed(this, CLIP_AUDIO_SYNC_INTERVAL_MS)
        }
    }

    private fun scheduleClipAudioSync() {
        mainHandler.removeCallbacks(clipAudioSyncRunnable)
        mainHandler.postDelayed(clipAudioSyncRunnable, CLIP_AUDIO_SYNC_INTERVAL_MS)
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
        exoPlayer.seekTo(targetIndex, resolved.second)
        // The loop track is outside the player and does not hear the seek.
        clipAudioLoop?.seekTo(resolved.second * 1000L)

        // Apply the target clip's per-clip speed and volume immediately.
        // ExoPlayer does not fire onPositionDiscontinuity / onMediaItemTransition
        // with a speed-update path for manual seeks — only AUTO_TRANSITION is
        // covered there. Without this, seeking from clip 2 (e.g. 0.25×) back
        // to clip 1 (e.g. 3×) leaves the player running at 0.25× indefinitely.
        exoPlayer.volume = (clipVolumes.getOrElse(targetIndex) { 1.0f }) * volume.toFloat()
        exoPlayer.setPlaybackParameters(
            PlaybackParameters(clipSpeeds.getOrElse(targetIndex) { 1.0f }),
        )

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
        val currentIndex = player?.currentMediaItemIndex ?: 0
        player?.volume = (clipVolumes.getOrElse(currentIndex) { 1.0f }) * volume.toFloat()
        clipAudioLoop?.setVolume(
            (clipVolumes.getOrElse(currentIndex) { 1.0f }) * volume.toFloat(),
        )
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
            !isLooping -> Player.REPEAT_MODE_OFF
            clipCount == 1 -> Player.REPEAT_MODE_ONE
            else -> Player.REPEAT_MODE_ALL
        }
    }

    private fun handleJumpToClip(call: MethodCall, result: MethodChannel.Result) {
        val index = (call.argument<Number>("index"))?.toInt() ?: 0
        val exoPlayer = ensurePlayer()
        if (index in 0 until clipCount) {
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

    /** Completes the pending seekTo result so Dart's await returns. */
    private fun completeSeekIfPending() {
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
            "videoWidth" to videoWidth,
            "videoHeight" to videoHeight,
            "pixelWidthHeightRatio" to pixelWidthHeightRatio,
            "rotationDegrees" to rotationDegrees,
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
            if (playbackState == Player.STATE_ENDED && isLooping) {
                syncAudioOverlays()
            }
            if (playbackState == Player.STATE_READY) {
                // The video's length is only readable once the timeline is
                // populated, and it bounds how long the fade may be.
                updateDeclickDuration()
                if (clipAudioPending) startClipAudioLoop(lastClipsRaw, lastClipsRaw.size)
                // Seek complete — switch from reporting target to actual position.
                pendingGlobalStartMs = 0L
                completeSeekIfPending()
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
                player?.volume = (clipVolumes.getOrElse(newIndex) { 1.0f }) * volume.toFloat()
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
                    player?.seekTo(newIndex, 0L)
                }
            }
        }

        override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
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
                player?.volume = (clipVolumes.getOrElse(newIndex) { 1.0f }) * volume.toFloat()
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
                p.volume = volume.toFloat()
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
        mainHandler.removeCallbacks(positionUpdater)
        mainHandler.removeCallbacks(seekTimeoutRunnable)
        mainHandler.removeCallbacks(setClipsTimeoutRunnable)
        mainHandler.removeCallbacks(bufferingWatchdogRunnable)
        cancelDecoderRetry()
        releaseClipAudioLoop()
        metadataExecutor.shutdownNow()
        seekCompletionResult?.success(null)
        seekCompletionResult = null
        pendingSetClipsResult?.success(null)
        pendingSetClipsResult = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        // Release the player before the surface producer. Releasing the
        // producer first can cause in-flight decoder frames to land in a
        // detaching surface, triggering native crashes on some OEMs (#3416).
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

        private const val POSITION_UPDATE_INTERVAL_MS = 200L

        /** How often a playing loop track is measured against the picture. */
        private const val CLIP_AUDIO_SYNC_INTERVAL_MS = 250L

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

        /** Records the track ends the player's extractor just parsed. */
        internal fun recordTrackEnds(uri: String, videoEndUs: Long, audioEndUs: Long) {
            trackDurationsCache[uri] = longArrayOf(videoEndUs, audioEndUs)
        }

        /** The `[videoEndUs, audioEndUs]` last recorded for [uri], if any. */
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
