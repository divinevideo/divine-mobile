// ABOUTME: Main Flutter plugin entry point for Android camera operations
// ABOUTME: Handles method channel communication and delegates to CameraController

package co.openvine.divine_camera

import android.app.Activity
import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry
import java.util.concurrent.atomic.AtomicBoolean

/** DivineCameraPlugin */
class DivineCameraPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var textureRegistry: TextureRegistry
    private var activity: Activity? = null
    private var cameraController: CameraController? = null
    private var volumeKeyHandler: VolumeKeyHandler? = null

    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    // Per-instance forwarder that pushes native diagnostics over THIS engine's
    // channel. `DivineCameraLog.sink` is a process-wide singleton, so a second
    // FlutterEngine (e.g. the FCM background isolate that also runs
    // GeneratedPluginRegistrant) could otherwise overwrite it and route camera
    // logs to the wrong isolate.
    //
    // Ownership is bound to the UI activity lifecycle: we claim the sink in
    // onAttachedToActivity / onReattachedToActivityForConfigChanges and release
    // it (ownership-guarded) in onDetachedFromActivity. A background engine
    // attaches to the engine but never to an Activity, so it can never own the
    // sink — not even in the narrow window before the next UI camera method
    // call, which is the gap a purely native event (e.g. a volume-key callback)
    // could otherwise fall into. onMethodCall re-claims as defense-in-depth,
    // since camera calls only ever reach the UI engine.
    private val logSink: (String, String, String, Double) -> Unit =
        { level, message, name, timestampMs ->
            mainHandler.post {
                channel.invokeMethod(
                    "onNativeLog",
                    mapOf(
                        "level" to level,
                        "message" to message,
                        "name" to name,
                        "timestampMs" to timestampMs
                    )
                )
            }
        }

    // Claim the process-wide diagnostics sink for THIS engine. Only the UI
    // engine reaches these call sites (activity attachment + camera method
    // calls), so a background engine can never become the owner.
    private fun claimLogSink() {
        DivineCameraLog.sink = logSink
    }

    // Relinquish the shared sink only if it still points at this instance, so
    // one engine's teardown can't silence another engine's diagnostics.
    private fun releaseLogSinkIfOwned() {
        if (DivineCameraLog.sink === logSink) {
            DivineCameraLog.sink = null
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "divine_camera")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        textureRegistry = flutterPluginBinding.textureRegistry
        // Intentionally NOT claiming DivineCameraLog.sink here. Engine
        // attachment happens for background engines too; the sink is claimed on
        // activity attachment so only the UI engine can own it.
    }

    // Session-lifecycle operations worth leaving a breadcrumb for. High-
    // frequency calls (zoom / focus / exposure / getCameraState) are excluded
    // on purpose so they don't flood the captured log buffer.
    private val lifecycleMethods = setOf(
        "initializeCamera", "disposeCamera", "switchCamera",
        "startRecording", "stopRecording", "pausePreview", "resumePreview",
        "setFlashMode", "setRemoteRecordControlEnabled",
        "setVideoStabilizationMode"
    )

    private fun logLifecycleCall(call: MethodCall) {
        if (call.method !in lifecycleMethods) return
        val args = call.arguments
        DivineCameraLog.debug(
            "→ ${call.method}${if (args != null) " $args" else ""}",
            name = "DivineCamera.Lifecycle"
        )
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        // Re-claim the shared sink in case another FlutterEngine overwrote it.
        // Camera calls only ever reach the UI engine, so this keeps the sink
        // pointing back here as defense-in-depth alongside activity binding.
        claimLogSink()
        logLifecycleCall(call)
        val oneShotResult = OneShotMethodResult(result)
        when (call.method) {
            "getPlatformVersion" -> {
                oneShotResult.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            "initializeCamera" -> {
                val lens = call.argument<String>("lens") ?: "back"
                val videoQuality = call.argument<String>("videoQuality") ?: "fhd"
                val enableScreenFlash = call.argument<Boolean>("enableScreenFlash") ?: true
                val mirrorFrontCameraOutput = call.argument<Boolean>("mirrorFrontCameraOutput") ?: true
                val enableAutoLensSwitch = call.argument<Boolean>("enableAutoLensSwitch") ?: true
                val preferUnprocessedAudio = call.argument<Boolean>("preferUnprocessedAudio") ?: false
                initializeCamera(lens, videoQuality, enableScreenFlash, mirrorFrontCameraOutput, enableAutoLensSwitch, preferUnprocessedAudio, oneShotResult)
            }

            "disposeCamera" -> {
                disposeCamera(oneShotResult)
            }

            "setFlashMode" -> {
                val mode = call.argument<String>("mode") ?: "off"
                setFlashMode(mode, oneShotResult)
            }

            "setFocusPoint" -> {
                val x = call.argument<Double>("x") ?: 0.5
                val y = call.argument<Double>("y") ?: 0.5
                setFocusPoint(x.toFloat(), y.toFloat(), oneShotResult)
            }

            "setExposurePoint" -> {
                val x = call.argument<Double>("x") ?: 0.5
                val y = call.argument<Double>("y") ?: 0.5
                setExposurePoint(x.toFloat(), y.toFloat(), oneShotResult)
            }

            "cancelFocusAndMetering" -> {
                cancelFocusAndMetering(oneShotResult)
            }

            "setZoomLevel" -> {
                val level = call.argument<Double>("level") ?: 1.0
                setZoomLevel(level.toFloat(), oneShotResult)
            }

            "setVideoStabilizationMode" -> {
                val mode = call.argument<String>("mode") ?: "off"
                setVideoStabilizationMode(mode, oneShotResult)
            }

            "switchCamera" -> {
                val lens = call.argument<String>("lens") ?: "back"
                switchCamera(lens, oneShotResult)
            }

            "startRecording" -> {
                val maxDurationMs = call.argument<Int>("maxDurationMs")
                val useCache = call.argument<Boolean>("useCache") ?: true
                val outputDirectory = call.argument<String>("outputDirectory")
                startRecording(maxDurationMs, useCache, outputDirectory, oneShotResult)
            }

            "stopRecording" -> {
                stopRecording(oneShotResult)
            }

            "capturePhoto" -> {
                val useCache = call.argument<Boolean>("useCache") ?: true
                val outputDirectory = call.argument<String>("outputDirectory")
                capturePhoto(useCache, outputDirectory, oneShotResult)
            }

            "pausePreview" -> {
                pausePreview(oneShotResult)
            }

            "resumePreview" -> {
                resumePreview(oneShotResult)
            }

            // Nothing to suspend: CameraX's Recorder starts its AudioSource
            // when a recording starts and stops it when the recording
            // finalizes, so the mic is already closed between recordings
            // and the countdown beeps never reach an open input path. The
            // iOS controller keeps the mic open for an instant record tap
            // and needs both calls; see CameraController.swift.
            "suspendAudioCapture", "resumeAudioCapture" -> {
                oneShotResult.success(null)
            }

            "getCameraState" -> {
                getCameraState(oneShotResult)
            }

            "setRemoteRecordControlEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setRemoteRecordControlEnabled(enabled, oneShotResult)
            }

            "setVolumeKeysEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                setVolumeKeysEnabled(enabled, oneShotResult)
            }

            "listAudioDevices" -> {
                listAudioDevices(result)
            }

            else -> {
                oneShotResult.notImplemented()
            }
        }
    }

    private fun initializeCamera(lens: String, videoQuality: String, enableScreenFlash: Boolean, mirrorFrontCameraOutput: Boolean, enableAutoLensSwitch: Boolean, preferUnprocessedAudio: Boolean, result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }

        try {
            cameraController?.release()
            cameraController = CameraController(
                context = context,
                activity = currentActivity,
                textureRegistry = textureRegistry
            )

            // Set up auto-stop listener to notify Flutter
            cameraController?.onAutoStopListener = { recordingResult ->
                channel.invokeMethod("onRecordingAutoStopped", recordingResult)
            }

            cameraController?.initialize(lens, videoQuality, enableScreenFlash, mirrorFrontCameraOutput, enableAutoLensSwitch, preferUnprocessedAudio) { state, error ->
                if (error != null) {
                    result.error("INIT_ERROR", error, null)
                } else {
                    val dict = state as? Map<*, *>
                    DivineCameraLog.info(
                        "Camera initialized (lens=${dict?.get("lens")}, " +
                            "aspectRatio=${dict?.get("aspectRatio")}, " +
                            "hasFlash=${dict?.get("hasFlash")}, " +
                            "lenses=${dict?.get("availableLenses")})",
                        name = "DivineCamera.Lifecycle"
                    )
                    result.success(state)
                }
            }
        } catch (e: Exception) {
            result.error("INIT_EXCEPTION", e.message, e.stackTraceToString())
        }
    }

    private fun disposeCamera(result: Result) {
        try {
            volumeKeyHandler?.release()
            volumeKeyHandler = null
            cameraController?.release()
            cameraController = null
            result.success(null)
        } catch (e: Exception) {
            result.error("DISPOSE_ERROR", e.message, null)
        }
    }

    private fun setFlashMode(mode: String, result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            val success = controller.setFlashMode(mode)
            result.success(success)
        } catch (e: Exception) {
            result.error("FLASH_ERROR", e.message, null)
        }
    }

    private fun setFocusPoint(x: Float, y: Float, result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            val success = controller.setFocusPoint(x, y)
            result.success(success)
        } catch (e: Exception) {
            result.error("FOCUS_ERROR", e.message, null)
        }
    }

    private fun setExposurePoint(x: Float, y: Float, result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            val success = controller.setExposurePoint(x, y)
            result.success(success)
        } catch (e: Exception) {
            result.error("EXPOSURE_ERROR", e.message, null)
        }
    }

    private fun cancelFocusAndMetering(result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            val success = controller.cancelFocusAndMetering()
            result.success(success)
        } catch (e: Exception) {
            result.error("FOCUS_ERROR", e.message, null)
        }
    }

    private fun setZoomLevel(level: Float, result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            // Map with the applied zoom + available range, null on failure.
            result.success(controller.setZoomLevel(level))
        } catch (e: Exception) {
            result.error("ZOOM_ERROR", e.message, null)
        }
    }

    private fun setVideoStabilizationMode(mode: String, result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            val success = controller.setVideoStabilizationMode(mode)
            result.success(success)
        } catch (e: Exception) {
            result.error("STABILIZATION_ERROR", e.message, null)
        }
    }

    private fun switchCamera(lens: String, result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            // Suppress volume/Bluetooth triggers during camera switch.
            // Camera reconfiguration can cause connected Bluetooth devices
            // to send spurious play/pause events that would start recording.
            volumeKeyHandler?.suppressTemporarily(3000)

            controller.switchCamera(lens) { state, error ->
                if (error != null) {
                    result.error("SWITCH_ERROR", error, null)
                } else {
                    val dict = state as? Map<*, *>
                    DivineCameraLog.info(
                        "Camera switched (lens=${dict?.get("lens")})",
                        name = "DivineCamera.Lifecycle"
                    )
                    result.success(state)
                }
            }
        } catch (e: Exception) {
            result.error("SWITCH_EXCEPTION", e.message, null)
        }
    }

    private fun startRecording(maxDurationMs: Int?, useCache: Boolean, outputDirectory: String?, result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            controller.startRecording(maxDurationMs, useCache, outputDirectory) { error ->
                if (error != null) {
                    result.error("RECORD_START_ERROR", error, null)
                } else {
                    result.success(null)
                }
            }
        } catch (e: Exception) {
            result.error("RECORD_START_EXCEPTION", e.message, null)
        }
    }

    private fun stopRecording(result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            controller.stopRecording { recordingResult, error ->
                if (error != null) {
                    result.error("RECORD_STOP_ERROR", error, null)
                } else {
                    result.success(recordingResult)
                }
            }
        } catch (e: Exception) {
            result.error("RECORD_STOP_EXCEPTION", e.message, null)
        }
    }

    private fun capturePhoto(useCache: Boolean, outputDirectory: String?, result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            controller.capturePhoto(outputDirectory, useCache) { photoResult, error ->
                if (error != null) {
                    result.error("PHOTO_CAPTURE_ERROR", error, null)
                } else {
                    result.success(photoResult)
                }
            }
        } catch (e: Exception) {
            result.error("PHOTO_CAPTURE_EXCEPTION", e.message, null)
        }
    }

    private fun pausePreview(result: Result) {
        try {
            cameraController?.pausePreview()
            result.success(null)
        } catch (e: Exception) {
            result.error("PAUSE_ERROR", e.message, null)
        }
    }

    private fun resumePreview(result: Result) {
        try {
            cameraController?.resumePreview { state, error ->
                if (error != null) {
                    result.error("RESUME_ERROR", error, null)
                } else {
                    result.success(state)
                }
            }
        } catch (e: Exception) {
            result.error("RESUME_EXCEPTION", e.message, null)
        }
    }

    private fun getCameraState(result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            result.success(controller.getCameraState())
        } catch (e: Exception) {
            result.error("STATE_ERROR", e.message, null)
        }
    }

    private fun setRemoteRecordControlEnabled(enabled: Boolean, result: Result) {
        try {
            if (enabled) {
                if (volumeKeyHandler == null) {
                    volumeKeyHandler = VolumeKeyHandler(context, activity) { triggerType ->
                        // Send trigger event to Flutter on main thread
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            channel.invokeMethod("onRemoteRecordTrigger", triggerType)
                        }
                    }
                }
                val success = volumeKeyHandler?.enable() ?: false
                result.success(success)
            } else {
                volumeKeyHandler?.disable()
                result.success(true)
            }
        } catch (e: Exception) {
            result.error("REMOTE_CONTROL_ERROR", e.message, null)
        }
    }

    private fun setVolumeKeysEnabled(enabled: Boolean, result: Result) {
        try {
            volumeKeyHandler?.setVolumeKeysEnabled(enabled)
            result.success(true)
        } catch (e: Exception) {
            result.error("VOLUME_KEYS_ERROR", e.message, null)
        }
    }

    private fun listAudioDevices(result: Result) {
        val audioManager = context?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        if (audioManager == null) {
            result.success(emptyList<Map<String, String>>())
            return
        }
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
            .filter { it.type != AudioDeviceInfo.TYPE_TELEPHONY }
            .map { device ->
                mapOf(
                    "id" to device.id.toString(),
                    "name" to (device.productName?.toString() ?: "Audio Device ${device.id}")
                )
            }
        result.success(devices)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        releaseLogSinkIfOwned()
        volumeKeyHandler?.release()
        volumeKeyHandler = null
        cameraController?.release()
        cameraController = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        // The UI engine is the one that attaches to an Activity, so this is
        // where diagnostics-sink ownership belongs.
        claimLogSink()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        // Keep the sink: the engine and its method channel survive a config
        // change, and the same UI engine re-attaches via
        // onReattachedToActivityForConfigChanges.
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        claimLogSink()
    }

    override fun onDetachedFromActivity() {
        activity = null
        // Activity is gone (not a config change), so the UI engine no longer
        // owns the diagnostics sink. Ownership-guarded so a background engine's
        // sink — if one had somehow been installed — isn't cleared here.
        releaseLogSinkIfOwned()
    }
}

internal class OneShotMethodResult(
    private val delegate: Result
) : Result {
    private val replied = AtomicBoolean(false)

    override fun success(result: Any?) {
        if (markReplied()) {
            delegate.success(result)
        }
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        if (markReplied()) {
            // Choke point for every error returned to Dart — forward it to the
            // UnifiedLogger so the failure shows up in user bug reports. Fatal
            // native crashes are captured separately by Crashlytics.
            DivineCameraLog.error(
                "$errorCode: ${errorMessage ?: ""}",
                name = "DivineCamera.Plugin"
            )
            delegate.error(errorCode, errorMessage, errorDetails)
        }
    }

    override fun notImplemented() {
        if (markReplied()) {
            delegate.notImplemented()
        }
    }

    private fun markReplied(): Boolean = replied.compareAndSet(false, true)
}
