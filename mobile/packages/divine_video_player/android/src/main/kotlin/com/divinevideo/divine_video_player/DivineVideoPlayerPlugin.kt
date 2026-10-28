package com.divinevideo.divine_video_player

import android.app.Activity
import android.content.Context
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap

/**
 * Entry point for the divine_video_player plugin on Android.
 *
 * Manages the lifecycle of [DivineVideoPlayerInstance] objects and
 * registers the platform view factory for rendering.
 */
class DivineVideoPlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private lateinit var globalChannel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    companion object {
        // Tracks the plugin instance attached to the main FlutterEngine.
        // Flutter creates a NEW DivineVideoPlayerPlugin instance per engine,
        // so instance variables cannot distinguish engines — only a static
        // reference to the known-main instance works.
        //
        // Background engines (Firebase FCM isolate, WorkManager) attach a
        // different instance while mainPluginInstance is non-null. They are
        // skipped entirely so PlayerRegistry.disposeAll() never kills live
        // players owned by the main engine.
        @Volatile
        private var mainPluginInstance: DivineVideoPlayerPlugin? = null
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        // Treat as the main engine when:
        //   • nothing is registered yet (cold start), OR
        //   • this same instance is reattaching (hot restart without a
        //     preceding onDetachedFromEngine call).
        // Any other instance attaching while the main one is registered is
        // a background engine — skip it.
        val isMainEngine = mainPluginInstance == null || mainPluginInstance === this
        if (!isMainEngine) return

        mainPluginInstance = this
        binding = flutterPluginBinding

        // Hot restart re-calls onAttachedToEngine on the same instance without
        // a preceding onDetachedFromEngine. Dispose zombie players left over
        // from the previous Dart VM. main.dart also calls disposeAll() before
        // runApp() as belt-and-suspenders coverage.
        PlayerRegistry.disposeAll()

        globalChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "divine_video_player",
        )
        globalChannel.setMethodCallHandler(this)

        // Forward curated native diagnostics to Dart's UnifiedLogger so video
        // playback problems land in user bug reports. Only the main engine
        // reaches here (background isolates returned early above), so the
        // process-wide sink always points at the UI engine's channel.
        DivineVideoPlayerLog.sink = { level, message, name ->
            mainHandler.post {
                globalChannel.invokeMethod(
                    "onNativeLog",
                    mapOf("level" to level, "message" to message, "name" to name),
                )
            }
        }

        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "divine_video_player_view",
            DivineVideoPlayerViewFactory(flutterPluginBinding),
        )
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        if (mainPluginInstance !== this) {
            // Background engine detaching — do not touch main engine's players.
            return
        }
        mainPluginInstance = null
        globalChannel.setMethodCallHandler(null)
        DivineVideoPlayerLog.sink = null
        PlayerRegistry.disposeAll()
        VideoCache.release()
    }

    // -- ActivityAware: pause/resume players with app lifecycle --

    private val lifecycleObserver = object : DefaultLifecycleObserver {
        override fun onPause(owner: LifecycleOwner) {
            PlayerRegistry.forAll { it.onAppBackgrounded() }
        }

        override fun onResume(owner: LifecycleOwner) {
            PlayerRegistry.forAll { it.onAppForegrounded() }
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        (binding.activity as? LifecycleOwner)?.lifecycle?.addObserver(lifecycleObserver)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // No-op: observer is removed when activity is destroyed.
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        (binding.activity as? LifecycleOwner)?.lifecycle?.addObserver(lifecycleObserver)
    }

    override fun onDetachedFromActivity() {
        // Stop every live player before the Activity unwinds; full release
        // happens later on engine detach. See #3416.
        PlayerRegistry.forAll { it.stopForActivityDetach() }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> {
                val id = call.argument<Int>("id")!!
                // Dispose any existing player with the same ID BEFORE
                // creating the new one. The new instance registers
                // MethodChannel/EventChannel handlers under the same
                // channel name, so the old instance must release them
                // first to avoid nullifying the new handlers.
                PlayerRegistry.remove(id)?.dispose()
                val bufferProfile = BufferProfile.fromWireValue(
                    call.argument<String>("bufferProfile"),
                )
                val debugLabel = call.argument<String>("debugLabel")
                val instance = DivineVideoPlayerInstance(
                    binding.binaryMessenger,
                    binding.applicationContext,
                    id,
                    debugLabel = debugLabel,
                    bufferProfile = bufferProfile,
                )
                PlayerRegistry.put(id, instance)

                val useTexture = call.argument<Boolean>("useTexture") ?: false
                val logTarget =
                    if (debugLabel == null) "Player $id" else "Player $id ($debugLabel)"
                DivineVideoPlayerLog.info(
                    "$logTarget created " +
                        "(useTexture=$useTexture, bufferProfile=$bufferProfile)",
                    name = "DivineVideoPlayer.Lifecycle",
                )
                if (useTexture) {
                    val useLegacySurface =
                        call.argument<Boolean>("useLegacySurface") ?: false
                    val textureId = instance.enableTextureOutput(
                        binding.textureRegistry,
                        useLegacySurface = useLegacySurface,
                        upscale = VideoUpscale.Mode.fromWire(call.argument<String>("upscale")),
                    )
                    result.success(
                        mapOf("textureId" to textureId, "upscales" to instance.upscalesFrames),
                    )
                } else {
                    result.success(null)
                }
            }
            "dispose" -> {
                val id = call.argument<Int>("id")!!
                // Release the native player first, then log — the log then
                // truthfully marks codec-release completion. Emitting it before
                // release makes teardown look finished while the hardware codec
                // is still held, which misreads export encoder-init races on
                // codec-limited devices (the #5522 decoder-release gate).
                PlayerRegistry.remove(id)?.dispose()
                DivineVideoPlayerLog.info(
                    "Player $id disposed",
                    name = "DivineVideoPlayer.Lifecycle",
                )
                result.success(null)
            }
            "preload" -> {
                handlePreload(call, result)
            }
            "configureCache" -> {
                val maxSizeBytes = (call.argument<Number>("maxSizeBytes"))?.toLong()
                    ?: (500L * 1024 * 1024)
                VideoCache.configure(binding.applicationContext, maxSizeBytes)
                result.success(null)
            }
            "disposeAll" -> {
                PlayerRegistry.disposeAll()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Preloads video metadata and initial buffer data by creating a
     * temporary ExoPlayer, preparing the media, and releasing it once
     * ready. The OS-level network/disk cache retains the buffered data
     * so that a real player starts faster.
     */
    private fun handlePreload(call: MethodCall, result: MethodChannel.Result) {
        val clipsRaw = call.argument<List<Map<String, Any?>>>("clips")
        if (clipsRaw.isNullOrEmpty()) {
            result.success(null)
            return
        }

        val context: Context = binding.applicationContext
        val preloadPlayer = ExoPlayer.Builder(context)
            .setMediaSourceFactory(
                DefaultMediaSourceFactory(VideoCache.dataSourceFactory(context)),
            )
            .build()

        val mediaItems = clipsRaw.mapNotNull { map ->
            val uri = map["uri"] as? String ?: return@mapNotNull null
            val startMs = (map["startMs"] as? Number)?.toLong() ?: 0L
            val endMs = (map["endMs"] as? Number)?.toLong()

            MediaItem.Builder().setUri(uri)
                .setClippingConfiguration(
                    MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs(startMs)
                        .apply { if (endMs != null) setEndPositionMs(endMs) }
                        .build(),
                )
                .build()
        }

        if (mediaItems.isEmpty()) {
            preloadPlayer.release()
            result.success(null)
            return
        }

        preloadPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == Player.STATE_READY ||
                    playbackState == Player.STATE_IDLE
                ) {
                    preloadPlayer.release()
                    result.success(null)
                }
            }

            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                preloadPlayer.release()
                result.success(null)
            }
        })

        preloadPlayer.setMediaItems(mediaItems)
        preloadPlayer.prepare()
    }
}

/**
 * Global registry so that [DivineVideoPlayerViewFactory] can find
 * instances created by [DivineVideoPlayerPlugin].
 */
internal object PlayerRegistry {
    private val players = ConcurrentHashMap<Int, DivineVideoPlayerInstance>()

    fun get(id: Int): DivineVideoPlayerInstance? = players[id]
    fun put(id: Int, instance: DivineVideoPlayerInstance) { players[id] = instance }
    fun remove(id: Int): DivineVideoPlayerInstance? = players.remove(id)
    fun forAll(action: (DivineVideoPlayerInstance) -> Unit) {
        players.values.toList().forEach(action)
    }
    val size: Int get() = players.size
    fun disposeAll() {
        players.values.toList().forEach { it.dispose() }
        players.clear()
    }
}
