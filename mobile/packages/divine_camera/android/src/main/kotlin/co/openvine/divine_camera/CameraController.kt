// ABOUTME: CameraX-based camera controller for Android
// ABOUTME: Handles camera initialization, preview, recording, and controls

package co.openvine.divine_camera

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.CaptureResult
import android.hardware.camera2.TotalCaptureResult
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Surface
import android.view.WindowManager
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.camera2.interop.Camera2Interop
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.*
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.view.TextureRegistry
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

private const val TAG = "DivineCameraController"
private const val LENS_SWITCH_HYSTERESIS = 0.03f

/** How a preview [Surface] should be supplied to a CameraX surface request. */
internal enum class SurfaceProvision { CREATE, DECLINE }

/**
 * Controller for CameraX-based camera operations.
 * Handles camera initialization, preview, video recording, and camera controls.
 */
class CameraController(
    private val context: Context,
    private val activity: Activity,
    private val textureRegistry: TextureRegistry
) {
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var recording: Recording? = null

    // Still-photo use case for single-frame (stop-motion) capture. Null when the
    // device cannot bind it concurrently with Preview + VideoCapture, in which
    // case photo capture is unavailable but video keeps working.
    private var imageCapture: ImageCapture? = null

    // Flutter's SurfaceProducer (not the deprecated SurfaceTexture API): under
    // Impeller it retains the last rendered frame while CameraX detaches and
    // rebinds during a lens switch, so the preview freezes instead of flashing
    // black — issue #5865.
    private var surfaceProducer: TextureRegistry.SurfaceProducer? = null

    // The outgoing camera's SurfaceProducer during a lens switch. A switch gives
    // the incoming camera a brand-new producer/texture and keeps the old one
    // here so the Dart freeze-gate can keep showing its last (correctly
    // oriented) frame until the new texture is swapped in. Released at the start
    // of the next switch — by then Dart has long swapped off it — and on
    // dispose. This is what fixes the upside-down flash: the outgoing texture
    // never receives the incoming camera's frames, so its rotation can't desync.
    private var retiringSurfaceProducer: TextureRegistry.SurfaceProducer? = null

    private var cameraExecutor: ExecutorService =
        RejectionTolerantExecutorService(Executors.newSingleThreadExecutor())
    private val mainHandler = Handler(Looper.getMainLooper())

    private var currentLens: Int = CameraSelector.LENS_FACING_BACK
    private var currentFlashMode: Int = ImageCapture.FLASH_MODE_OFF
    private var isTorchEnabled: Boolean = false
    private var isRecording: Boolean = false
    private var recordingTrulyStarted: Boolean = false

    // Last observed CameraX audio-source state for the active recording, so we
    // only forward a diagnostic when it transitions (the Status event fires
    // continuously). Reset to the sentinel on each recording Start.
    private var lastAudioState: Int = Int.MIN_VALUE

    // Whether the user asked for capture without the platform's speech-tuned
    // processing (Music mode, #7796). Set per initialize like every other
    // session flag, and read when a Recorder picks its audio source.
    private var prefersUnprocessedAudio: Boolean = false

    // Callback for startRecording - called when recording truly starts or is aborted
    private var startRecordingCallback: ((String?) -> Unit)? = null

    // True while [pausePreview] has unbound the use cases. The camera stays
    // "initialized" (the Flutter texture and use-case objects are kept) so
    // [resumePreview] only has to rebind them.
    private var isPaused: Boolean = false

    // Screen brightness for front camera "torch" mode
    private var isScreenFlashEnabled: Boolean = false
    private var screenFlashFeatureEnabled: Boolean = true

    // Whether to mirror front camera video output
    private var mirrorFrontCameraOutput: Boolean = true

    // Requested video stabilization mode (cross-platform string). Applied to
    // the shared capture session via Camera2 interop, so it affects both the
    // preview and the recorded file. Defaults to "off" to preserve existing
    // behaviour until the user opts in.
    private var requestedStabilizationMode: String = STABILIZATION_OFF

    // Auto flash mode - checks brightness once when recording starts
    private var isAutoFlashMode: Boolean = false
    private var autoFlashTorchEnabled: Boolean = false
    
    // Camera2 Interop for exposure measurement (no ImageAnalysis needed)
    // These values are continuously updated from CaptureResult
    private var currentIso: Int = 100
    private var currentExposureTime: Long = 0L  // nanoseconds
    // Thresholds for "dark" detection:
    // Front camera: Lower thresholds - screen flash helps even in moderate darkness
    // Back camera: Higher thresholds - real flash is more aggressive, only for true darkness
    private val frontCameraIsoThreshold: Int = 650
    private val frontCameraExposureThreshold: Long = 20_000_000L  // 20ms
    private val backCameraIsoThreshold: Int = 800
    private val backCameraExposureThreshold: Long = 40_000_000L  // 40ms
    
    // Camera2 CaptureCallback to monitor exposure values continuously
    private val exposureCaptureCallback = object : CameraCaptureSession.CaptureCallback() {
        override fun onCaptureCompleted(
            session: CameraCaptureSession,
            request: CaptureRequest,
            result: TotalCaptureResult
        ) {
            // Extract exposure values from capture result
            result.get(CaptureResult.SENSOR_SENSITIVITY)?.let { iso ->
                currentIso = iso
            }
            result.get(CaptureResult.SENSOR_EXPOSURE_TIME)?.let { exposureTime ->
                currentExposureTime = exposureTime
            }

            // Frames after a lens switch: let a few settle so the incoming
            // camera's pixels are actually on its fresh texture before resolving
            // the switch — otherwise the UI swaps onto a still-empty (black)
            // texture. Until then the old frozen frame stays on screen.
            onFirstFrameAfterSwitch?.let { completion ->
                if (switchSettleFramesRemaining > 0) {
                    switchSettleFramesRemaining--
                } else {
                    onFirstFrameAfterSwitch = null
                    completion()
                }
            }
        }
    }

    private var minZoom: Float = 1.0f
    private var maxZoom: Float = 1.0f
    private var currentZoom: Float = 1.0f

    // Auto lens switching: unified virtual zoom across back lenses
    private var autoLensSwitchRequested: Boolean = true
    private var autoLensSwitchEnabled: Boolean = false
    private var isAutoSwitching: Boolean = false

    // Focal lengths from Camera2 (mm)
    private var mainCameraFocalLength: Float = 0f
    private var ultraWideCameraFocalLength: Float = 0f
    private var telephotoCameraFocalLength: Float = 0f

    // Zoom ratios relative to main (main = 1.0)
    private var ultraWideZoomRatio: Float = 0.5f
    private var telephotoZoomRatio: Float = 2.0f

    // Virtual zoom (1.0 = main at native 1x)
    private var virtualMinZoom: Float = 1.0f
    private var virtualMaxZoom: Float = 1.0f
    private var virtualCurrentZoom: Float = 1.0f

    // Native max zoom estimates (Camera2 SCALER_AVAILABLE_MAX_DIGITAL_ZOOM)
    private var ultraWideNativeMaxZoom: Float = 8.0f
    private var mainNativeMaxZoom: Float = 10.0f
    private var telephotoNativeMaxZoom: Float = 10.0f

    // Portrait-Modus: 9:16, 1080x1920
    private var aspectRatio: Float = 9f / 16f
    private var videoWidth: Int = 1080
    private var videoHeight: Int = 1920

    private var hasFrontCamera: Boolean = false
    private var hasBackCamera: Boolean = false
    private var hasFlash: Boolean = false
    private var isFocusPointSupported: Boolean = false
    private var isExposurePointSupported: Boolean = false
    
    // Multi-lens support: camera IDs for each lens type
    private var frontCameraId: String? = null
    private var frontUltraWideCameraId: String? = null
    private var backCameraId: String? = null
    private var ultraWideCameraId: String? = null
    private var telephotoCameraId: String? = null
    private var macroCameraId: String? = null
    
    // Track current lens type (more granular than just front/back)
    private var currentLensType: String = "back"

    private var recordingStartTime: Long = 0
    private var currentRecordingFile: File? = null
    private var videoQuality: Quality = Quality.FHD
    private var maxDurationRunnable: Runnable? = null
    private var autoStopCallback: ((Map<String, Any?>?, String?) -> Unit)? = null

    // Fires once the incoming camera has produced enough frames after a lens
    // switch (see [switchSettleFramesRemaining]) to resolve the switch. The
    // incoming camera renders onto a brand-new texture, so completing before it
    // carries real pixels would swap the UI onto an empty (black) texture;
    // waiting also keeps the frozen old frame — with its own correct rotation —
    // on screen until then (#5865). Written on the main thread, read on the
    // Camera2 capture thread, so it must be @Volatile.
    @Volatile
    private var onFirstFrameAfterSwitch: (() -> Unit)? = null

    // Preview frames still to let pass before [onFirstFrameAfterSwitch] resolves
    // the switch — see [SWITCH_SETTLE_FRAMES]. Written on the main thread when a
    // switch starts, decremented on the Camera2 capture thread, so @Volatile.
    @Volatile
    private var switchSettleFramesRemaining: Int = 0

    // Quality fallback: when the hardware encoder rejects the requested quality
    // (e.g. device falsely reports FHD support), retry with lower quality.
    private var encoderRetryCount: Int = 0
    private var pendingRecordingParams: RecordingParams? = null

    private data class RecordingParams(
        val maxDurationMs: Int?,
        val useCache: Boolean,
        val outputDirectory: String?,
        val callback: (String?) -> Unit
    )

    /**
     * Which physical cameras back each lens type, derived once from
     * `CameraCharacteristics`. The set of cameras does not change while the
     * process lives, so a fresh controller (one per initialize) reuses it
     * instead of querying every camera's characteristics again.
     */
    private data class CameraInventory(
        val hasFrontCamera: Boolean,
        val hasBackCamera: Boolean,
        val frontCameraId: String?,
        val frontUltraWideCameraId: String?,
        val backCameraId: String?,
        val ultraWideCameraId: String?,
        val telephotoCameraId: String?,
        val macroCameraId: String?,
        val mainCameraFocalLength: Float,
        val ultraWideCameraFocalLength: Float,
        val telephotoCameraFocalLength: Float,
        val mainNativeMaxZoom: Float,
        val ultraWideNativeMaxZoom: Float,
        val telephotoNativeMaxZoom: Float,
    )

    companion object {
        private const val MAX_ENCODER_RETRIES = 2

        // Process-wide result of the camera scan; see [CameraInventory].
        @Volatile
        private var cachedInventory: CameraInventory? = null

        // Safety net: resolve a lens switch even if the incoming camera never
        // reports a frame (rare device quirk), so `await switchCamera` on the
        // Dart side can't hang forever.
        private const val SWITCH_FIRST_FRAME_TIMEOUT_MS = 1200L

        // Preview frames to let pass after a lens switch before resolving it.
        // The incoming camera renders onto a fresh texture; its capture result
        // completes a frame or two before those pixels reach the surface, so
        // resolving on the very first completion would swap the UI onto a still-
        // empty (black) texture. A few settle frames guarantee real pixels are
        // there before the swap. The extra frozen frames are hidden by the
        // switch blur, so they're imperceptible.
        private const val SWITCH_SETTLE_FRAMES = 3

        // Canonical cross-platform stabilization mode strings, shared with the
        // iOS/macOS implementations so the Dart layer speaks one vocabulary.
        const val STABILIZATION_OFF = "off"
        const val STABILIZATION_STANDARD = "standard"
        const val STABILIZATION_CINEMATIC = "cinematic"
        const val STABILIZATION_CINEMATIC_EXTENDED = "cinematicExtended"
        const val STABILIZATION_PREVIEW_OPTIMIZED = "previewOptimized"
        const val STABILIZATION_LOW_LATENCY = "lowLatency"
        const val STABILIZATION_AUTO = "auto"

        private val CANONICAL_STABILIZATION_MODES = setOf(
            STABILIZATION_OFF,
            STABILIZATION_STANDARD,
            STABILIZATION_CINEMATIC,
            STABILIZATION_CINEMATIC_EXTENDED,
            STABILIZATION_PREVIEW_OPTIMIZED,
            STABILIZATION_LOW_LATENCY,
            STABILIZATION_AUTO,
        )

        /**
         * Decides how a preview surface request should be fulfilled.
         *
         * The Flutter surface producer can be released between registering a
         * surface provider and CameraX actually dispatching the request. When
         * no producer is available the caller must [DECLINE] the request via
         * `willNotProvideSurface()` rather than provide a null surface;
         * otherwise [CREATE] fetches the current surface from the producer.
         *
         * The surface is always re-fetched from the producer rather than
         * cached: a cross-lens resolution change applied via `setSize()` is
         * materialised lazily by `ImageReaderSurfaceProducer` inside
         * `getSurface()`, so reusing a cached surface would strand the preview
         * on the previous lens's reader for the session.
         */
        internal fun decideSurfaceProvision(
            hasTexture: Boolean,
        ): SurfaceProvision =
            if (hasTexture) SurfaceProvision.CREATE else SurfaceProvision.DECLINE

        /** Returns the next lower quality, or null if already at minimum. */
        fun lowerQuality(current: Quality): Quality? = when (current) {
            Quality.UHD -> Quality.FHD
            Quality.FHD -> Quality.HD
            Quality.HIGHEST -> Quality.FHD
            Quality.HD -> Quality.SD
            else -> null
        }

        /** True when [mode] is one of the recognised stabilization strings. */
        fun isCanonicalStabilizationMode(mode: String): Boolean =
            mode in CANONICAL_STABILIZATION_MODES

        /**
         * Builds the supported cross-platform stabilization mode strings from
         * the device's `CONTROL_AVAILABLE_VIDEO_STABILIZATION_MODES`. "off" is
         * always present.
         *
         * Android exposes only two real EIS levels, so the menu surfaces at most
         * two active rungs: "standard" ([onSupported] →
         * `CONTROL_VIDEO_STABILIZATION_MODE_ON`, basic) and "cinematic"
         * ([previewStabilizationSupported] → `PREVIEW_STABILIZATION`, strong,
         * preview AND recording). The finer iOS tiers (`cinematicExtended`,
         * `previewOptimized`, `lowLatency`, `auto`) would map to the identical
         * underlying mode, so they're omitted here to avoid duplicate-looking
         * menu entries.
         */
        fun buildStabilizationModeList(
            onSupported: Boolean,
            previewStabilizationSupported: Boolean,
        ): List<String> {
            val result = mutableListOf(STABILIZATION_OFF)
            if (onSupported) result.add(STABILIZATION_STANDARD)
            if (previewStabilizationSupported) {
                result.add(STABILIZATION_CINEMATIC)
            }
            return result
        }

        /**
         * Derives the supported cross-platform stabilization mode strings from
         * the device's `CONTROL_AVAILABLE_VIDEO_STABILIZATION_MODES`.
         */
        fun availableVideoStabilizationModes(
            availableModes: IntArray?,
        ): List<String> = buildStabilizationModeList(
            onSupported = availableModes?.contains(
                CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_ON
            ) == true,
            previewStabilizationSupported = availableModes?.contains(
                CameraMetadata
                    .CONTROL_VIDEO_STABILIZATION_MODE_PREVIEW_STABILIZATION
            ) == true,
        )
    }

    /** Listener for auto-stop events, set by the plugin. */
    var onAutoStopListener: ((Map<String, Any?>) -> Unit)? = null

    /**
     * Listener called on the main thread whenever the screen flash turns on or
     * off, so Flutter can light the UI around the preview while it is on.
     */
    var onScreenFlashChangedListener: ((Boolean) -> Unit)? = null

    /**
     * Initializes the camera with the specified lens and video quality.
     */
    fun initialize(
        lens: String,
        quality: String,
        enableScreenFlash: Boolean = true,
        mirrorFrontCameraOutput: Boolean = true,
        enableAutoLensSwitch: Boolean = true,
        preferUnprocessedAudio: Boolean = false,
        videoStabilizationMode: String = STABILIZATION_OFF,
        callback: (Map<String, Any?>?, String?) -> Unit
    ) {
        DivineCameraLog.d(TAG, "Initializing camera with lens: $lens, quality: $quality, enableScreenFlash: $enableScreenFlash, mirrorFrontCameraOutput: $mirrorFrontCameraOutput, autoLensSwitch: $enableAutoLensSwitch, unprocessedAudio: $preferUnprocessedAudio, stabilization: $videoStabilizationMode (portrait mode 1080x1920)")

        screenFlashFeatureEnabled = enableScreenFlash
        this.mirrorFrontCameraOutput = mirrorFrontCameraOutput
        this.autoLensSwitchRequested = enableAutoLensSwitch
        this.prefersUnprocessedAudio = preferUnprocessedAudio

        // Map lens string to lens type and facing
        currentLensType = lens
        currentLens = getLensFacingForType(lens)

        videoQuality = when (quality) {
            "sd" -> Quality.SD
            "hd" -> Quality.HD
            "fhd" -> Quality.FHD
            "uhd" -> Quality.UHD
            "highest" -> Quality.HIGHEST
            "lowest" -> Quality.LOWEST
            else -> Quality.FHD
        }

        checkCameraAvailability()

        // Fallback to available camera if requested camera is not available
        val requestedCameraId = getCameraIdForLens(currentLensType)
        if (requestedCameraId == null) {
            // Fallback: try back camera first, then front
            if (hasBackCamera) {
                DivineCameraLog.w(TAG, "Requested lens $lens not available, falling back to back camera")
                currentLensType = "back"
                currentLens = CameraSelector.LENS_FACING_BACK
            } else if (hasFrontCamera) {
                DivineCameraLog.w(TAG, "Requested lens $lens not available, falling back to front camera")
                currentLensType = "front"
                currentLens = CameraSelector.LENS_FACING_FRONT
            }
        }

        // Applied by the first bind below. Setting it after initialize instead
        // would rebind the whole camera a second time just to change it.
        requestedStabilizationMode = initialStabilizationMode(videoStabilizationMode)

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()
                DivineCameraLog.d(TAG, "Camera provider obtained")
                startCamera(callback)
            } catch (e: Exception) {
                DivineCameraLog.e(TAG, "Failed to get camera provider", e)
                mainHandler.post {
                    callback(null, "Failed to get camera provider: ${e.message}")
                }
            }
        }, ContextCompat.getMainExecutor(context))
    }

    /**
     * Checks which cameras are available on the device.
     * Detects front, back, ultra-wide, telephoto, and macro cameras.
     */
    private fun checkCameraAvailability() {
        cachedInventory?.let {
            applyInventory(it)
            return
        }
        try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            
            // Track focal lengths for cameras to determine lens types
            val backCameraFocalLengths = mutableMapOf<String, Float>()
            val frontCameraFocalLengths = mutableMapOf<String, Float>()
            
            for (cameraId in cameraManager.cameraIdList) {
                val characteristics = cameraManager.getCameraCharacteristics(cameraId)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                val focalLengths = characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                val capabilities = characteristics.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
                
                // Check if this is a logical camera (multi-camera on newer devices)
                val isLogicalCamera = capabilities?.contains(
                    CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA
                ) == true
                
                when (facing) {
                    CameraCharacteristics.LENS_FACING_FRONT -> {
                        val primaryFocalLength = focalLengths?.firstOrNull() ?: 0f
                        frontCameraFocalLengths[cameraId] = primaryFocalLength
                        DivineCameraLog.d(TAG, "Front camera $cameraId: focalLength=$primaryFocalLength, logical=$isLogicalCamera")
                    }
                    CameraCharacteristics.LENS_FACING_BACK -> {
                        // Get the primary focal length for this camera
                        val primaryFocalLength = focalLengths?.firstOrNull() ?: 0f
                        backCameraFocalLengths[cameraId] = primaryFocalLength
                        DivineCameraLog.d(TAG, "Back camera $cameraId: focalLength=$primaryFocalLength, logical=$isLogicalCamera")
                    }
                }
            }
            
            // Analyze front cameras by focal length
            if (frontCameraFocalLengths.isNotEmpty()) {
                val sorted = frontCameraFocalLengths.entries.sortedByDescending { it.value }
                
                // The camera with the longer focal length is the "normal" front camera
                // The camera with the shorter focal length is the ultra-wide front camera
                hasFrontCamera = true
                frontCameraId = sorted.first().key
                
                if (sorted.size > 1) {
                    // Second camera (shorter focal length) is front ultra-wide
                    val ultraWideCandidate = sorted.last()
                    if (ultraWideCandidate.value < sorted.first().value - 0.3f) {
                        frontUltraWideCameraId = ultraWideCandidate.key
                        DivineCameraLog.d(TAG, "Front ultra-wide camera detected: ${ultraWideCandidate.key}")
                    }
                }
            }
            
            // Analyze back cameras by focal length to determine type
            if (backCameraFocalLengths.isNotEmpty()) {
                // Sort by focal length
                val sorted = backCameraFocalLengths.entries.sortedBy { it.value }
                
                // Find the "normal" lens (typically around 4-6mm on smartphones)
                // This is usually the primary back camera
                val normalRange = 3.0f..8.0f
                val normalCamera = sorted.find { it.value in normalRange }
                
                if (normalCamera != null) {
                    hasBackCamera = true
                    backCameraId = normalCamera.key
                    mainCameraFocalLength = normalCamera.value

                    // Read main camera's max digital zoom
                    try {
                        val mainChars = cameraManager
                            .getCameraCharacteristics(normalCamera.key)
                        mainNativeMaxZoom = mainChars.get(
                            CameraCharacteristics
                                .SCALER_AVAILABLE_MAX_DIGITAL_ZOOM
                        ) ?: 10.0f
                    } catch (e: Exception) {
                        DivineCameraLog.w(TAG, "Could not read main camera max zoom", e)
                    }
                    
                    // Cameras with shorter focal length are ultra-wide
                    sorted.filter { it.value < normalCamera.value - 0.5f && it.key != normalCamera.key }
                        .maxByOrNull { it.value }?.let {
                            ultraWideCameraId = it.key
                            ultraWideCameraFocalLength = it.value
                            DivineCameraLog.d(TAG, "Ultra-wide camera detected: ${it.key} (focal=${it.value}mm)")
                            try {
                                val uwChars = cameraManager
                                    .getCameraCharacteristics(it.key)
                                ultraWideNativeMaxZoom = uwChars.get(
                                    CameraCharacteristics
                                        .SCALER_AVAILABLE_MAX_DIGITAL_ZOOM
                                ) ?: 8.0f
                            } catch (e: Exception) {
                                DivineCameraLog.w(TAG, "Could not read ultra-wide max zoom", e)
                            }
                        }
                    
                    // Cameras with longer focal length are telephoto
                    sorted.filter { it.value > normalCamera.value + 1.0f && it.key != normalCamera.key }
                        .minByOrNull { it.value }?.let {
                            telephotoCameraId = it.key
                            telephotoCameraFocalLength = it.value
                            DivineCameraLog.d(TAG, "Telephoto camera detected: ${it.key} (focal=${it.value}mm)")
                            try {
                                val teleChars = cameraManager
                                    .getCameraCharacteristics(it.key)
                                telephotoNativeMaxZoom = teleChars.get(
                                    CameraCharacteristics
                                        .SCALER_AVAILABLE_MAX_DIGITAL_ZOOM
                                ) ?: 10.0f
                            } catch (e: Exception) {
                                DivineCameraLog.w(TAG, "Could not read telephoto max zoom", e)
                            }
                        }
                } else if (sorted.isNotEmpty()) {
                    // Fallback: use the first back camera as main
                    hasBackCamera = true
                    backCameraId = sorted.first().key
                    mainCameraFocalLength = sorted.first().value
                }
                
                // Check for macro capability (often detected by very short minimum focus distance)
                for ((cameraId, _) in sorted) {
                    val chars = cameraManager.getCameraCharacteristics(cameraId)
                    val minFocusDistance = chars.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE)
                    // Macro cameras typically have minimum focus distance > 10 diopters (< 10cm focus)
                    if (minFocusDistance != null && minFocusDistance > 10.0f && cameraId != backCameraId) {
                        macroCameraId = cameraId
                        DivineCameraLog.d(TAG, "Macro camera detected: $cameraId (minFocusDist=$minFocusDistance)")
                        break
                    }
                }
            }
            
            DivineCameraLog.d(TAG, "Camera availability: front=$hasFrontCamera, " +
                "frontUltraWide=${frontUltraWideCameraId != null}, back=$hasBackCamera, " +
                "ultraWide=${ultraWideCameraId != null}, telephoto=${telephotoCameraId != null}, " +
                "macro=${macroCameraId != null}")

            // An empty scan is not cached: the camera service can briefly
            // report no cameras while it is still coming up.
            if (hasFrontCamera || hasBackCamera) {
                cachedInventory = CameraInventory(
                    hasFrontCamera = hasFrontCamera,
                    hasBackCamera = hasBackCamera,
                    frontCameraId = frontCameraId,
                    frontUltraWideCameraId = frontUltraWideCameraId,
                    backCameraId = backCameraId,
                    ultraWideCameraId = ultraWideCameraId,
                    telephotoCameraId = telephotoCameraId,
                    macroCameraId = macroCameraId,
                    mainCameraFocalLength = mainCameraFocalLength,
                    ultraWideCameraFocalLength = ultraWideCameraFocalLength,
                    telephotoCameraFocalLength = telephotoCameraFocalLength,
                    mainNativeMaxZoom = mainNativeMaxZoom,
                    ultraWideNativeMaxZoom = ultraWideNativeMaxZoom,
                    telephotoNativeMaxZoom = telephotoNativeMaxZoom,
                )
            }
        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Error checking camera availability", e)
        }
    }

    /** Restores the fields [checkCameraAvailability] derives from a scan. */
    private fun applyInventory(inventory: CameraInventory) {
        hasFrontCamera = inventory.hasFrontCamera
        hasBackCamera = inventory.hasBackCamera
        frontCameraId = inventory.frontCameraId
        frontUltraWideCameraId = inventory.frontUltraWideCameraId
        backCameraId = inventory.backCameraId
        ultraWideCameraId = inventory.ultraWideCameraId
        telephotoCameraId = inventory.telephotoCameraId
        macroCameraId = inventory.macroCameraId
        mainCameraFocalLength = inventory.mainCameraFocalLength
        ultraWideCameraFocalLength = inventory.ultraWideCameraFocalLength
        telephotoCameraFocalLength = inventory.telephotoCameraFocalLength
        mainNativeMaxZoom = inventory.mainNativeMaxZoom
        ultraWideNativeMaxZoom = inventory.ultraWideNativeMaxZoom
        telephotoNativeMaxZoom = inventory.telephotoNativeMaxZoom
    }

    /**
     * The stabilization mode the first bind should use: [mode] when it is a
     * recognised mode the opened lens supports, otherwise off — the same gate
     * the recorder applied when it restored the preference after start.
     */
    private fun initialStabilizationMode(mode: String): String {
        if (mode == STABILIZATION_OFF || !isCanonicalStabilizationMode(mode)) {
            return STABILIZATION_OFF
        }
        return if (mode in availableVideoStabilizationModesForCurrentLens()) {
            mode
        } else {
            DivineCameraLog.w(TAG, "Stabilization mode $mode unsupported on $currentLensType; opening with off")
            STABILIZATION_OFF
        }
    }
    
    /**
     * Returns a list of available lens types on this device.
     */
    private fun getAvailableLenses(): List<String> {
        val lenses = mutableListOf<String>()
        if (hasFrontCamera) lenses.add("front")
        if (frontUltraWideCameraId != null) lenses.add("frontUltraWide")
        if (hasBackCamera) lenses.add("back")
        if (ultraWideCameraId != null) lenses.add("ultraWide")
        if (telephotoCameraId != null) lenses.add("telephoto")
        if (macroCameraId != null) lenses.add("macro")
        return lenses
    }
    
    /**
     * Gets metadata for the currently active camera lens.
     */
    private fun getCurrentLensMetadata(): Map<String, Any?>? {
        val cameraId = getCameraIdForLens(currentLensType) ?: return null
        return try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val chars = cameraManager.getCameraCharacteristics(cameraId)
            extractCameraMetadata(chars, currentLensType, cameraId)
        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Failed to get metadata for current lens $currentLensType", e)
            null
        }
    }

    /**
     * Extracts metadata from CameraCharacteristics for a specific camera.
     */
    private fun extractCameraMetadata(
        chars: CameraCharacteristics,
        lensType: String,
        cameraId: String
    ): Map<String, Any?> {
        // Focal lengths (mm)
        val focalLengths = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
        val focalLength = focalLengths?.firstOrNull()?.toDouble()
        
        // Apertures (f-number)
        val apertures = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)
        val aperture = apertures?.firstOrNull()?.toDouble()
        
        // Sensor physical size (mm)
        val sensorSize = chars.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
        val sensorWidth = sensorSize?.width?.toDouble()
        val sensorHeight = sensorSize?.height?.toDouble()
        
        // Sensor pixel dimensions
        val pixelArraySize = chars.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)
        val pixelArrayWidth = pixelArraySize?.width
        val pixelArrayHeight = pixelArraySize?.height
        
        // Minimum focus distance (diopters: 1/distance in meters)
        val minFocusDistance = chars.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE)?.toDouble()
        
        // Calculate 35mm equivalent focal length
        // 35mm full frame diagonal = 43.27mm
        // Smartphone sensor diagonal = sqrt(width^2 + height^2)
        val focalLengthEquivalent35mm = if (focalLength != null && sensorWidth != null && sensorHeight != null) {
            val sensorDiagonal = kotlin.math.sqrt(sensorWidth * sensorWidth + sensorHeight * sensorHeight)
            val cropFactor = 43.27 / sensorDiagonal
            focalLength * cropFactor
        } else null
        
        // Calculate horizontal field of view (degrees)
        // FOV = 2 * arctan(sensor_width / (2 * focal_length))
        val fieldOfView = if (focalLength != null && sensorWidth != null && focalLength > 0) {
            val fovRadians = 2 * kotlin.math.atan(sensorWidth / (2 * focalLength))
            Math.toDegrees(fovRadians)
        } else null
        
        // Optical stabilization
        val oisModes = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION)
        val hasOpticalStabilization = oisModes?.contains(
            CameraCharacteristics.LENS_OPTICAL_STABILIZATION_MODE_ON
        ) == true
        
        // Logical camera (multi-camera system)
        val capabilities = chars.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
        val isLogicalCamera = capabilities?.contains(
            CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA
        ) == true
        
        // Physical camera IDs for logical cameras (Android 9+)
        val physicalCameraIds = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P && isLogicalCamera) {
            chars.physicalCameraIds.toList()
        } else {
            emptyList()
        }
        
        // Exposure time range (nanoseconds) - static capability, not live value
        val exposureTimeRange = chars.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
        val exposureTimeMin = exposureTimeRange?.lower?.toDouble()?.div(1_000_000_000.0)  // Convert ns to seconds
        val exposureTimeMax = exposureTimeRange?.upper?.toDouble()?.div(1_000_000_000.0)  // Convert ns to seconds
        
        // ISO sensitivity range - static capability, not live value
        val isoRange = chars.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
        val isoMin = isoRange?.lower
        val isoMax = isoRange?.upper
        
        return mapOf(
            "lensType" to lensType,
            "cameraId" to cameraId,
            "focalLength" to focalLength,
            "focalLengthEquivalent35mm" to focalLengthEquivalent35mm,
            "aperture" to aperture,
            "sensorWidth" to sensorWidth,
            "sensorHeight" to sensorHeight,
            "pixelArrayWidth" to pixelArrayWidth,
            "pixelArrayHeight" to pixelArrayHeight,
            "minFocusDistance" to minFocusDistance,
            "fieldOfView" to fieldOfView,
            "hasOpticalStabilization" to hasOpticalStabilization,
            "isLogicalCamera" to isLogicalCamera,
            "physicalCameraIds" to physicalCameraIds,
            "exposureTimeMin" to exposureTimeMin,
            "exposureTimeMax" to exposureTimeMax,
            "isoMin" to isoMin,
            "isoMax" to isoMax
        )
    }

    /**
     * Gets the camera ID for a given lens type.
     */
    private fun getCameraIdForLens(lensType: String): String? {
        return when (lensType) {
            "front" -> frontCameraId
            "frontUltraWide" -> frontUltraWideCameraId
            "back" -> backCameraId
            "ultraWide" -> ultraWideCameraId
            "telephoto" -> telephotoCameraId
            "macro" -> macroCameraId
            else -> backCameraId
        }
    }
    
    /**
     * Gets the lens facing value for CameraSelector based on lens type.
     */
    private fun getLensFacingForType(lensType: String): Int {
        return when (lensType) {
            "front", "frontUltraWide" -> CameraSelector.LENS_FACING_FRONT
            else -> CameraSelector.LENS_FACING_BACK
        }
    }
    
    /**
     * Builds a CameraSelector for the specified lens type.
     * For specialized lenses (ultraWide, telephoto, macro, frontUltraWide), uses Camera2Interop
     * to select a specific camera by ID.
     */
    @SuppressLint("UnsafeOptInUsageError")
    private fun buildCameraSelectorForLens(
        lensType: String,
        provider: ProcessCameraProvider
    ): CameraSelector {
        val cameraId = getCameraIdForLens(lensType)
        
        // For standard front/back cameras or if no specific ID found, use simple lens facing
        if (cameraId == null || (lensType == "front" && frontUltraWideCameraId == null) || lensType == "back") {
            return CameraSelector.Builder()
                .requireLensFacing(getLensFacingForType(lensType))
                .build()
        }
        
        // For specialized lenses (and front when multiple front cameras exist), filter by camera ID using Camera2Interop
        return CameraSelector.Builder()
            .addCameraFilter { cameras ->
                cameras.filter { cameraInfo ->
                    try {
                        val camera2Info = Camera2CameraInfo.from(cameraInfo)
                        camera2Info.cameraId == cameraId
                    } catch (e: Exception) {
                        DivineCameraLog.w(TAG, "Failed to get Camera2CameraInfo: ${e.message}")
                        false
                    }
                }
            }
            .build()
    }

    /**
     * Creates a Preview with Camera2Interop for exposure monitoring.
     * Uses CaptureCallback to track ISO and exposure time for auto-flash.
     *
     * [stabilizationMode] is the raw Camera2
     * `CONTROL_VIDEO_STABILIZATION_MODE` value (0=off, 1=on, 2=preview). We set
     * it directly on the session via Camera2 interop rather than CameraX's
     * `setPreviewStabilizationEnabled`, because some HALs (notably Samsung)
     * only honour the raw key — CameraX's abstraction produced no crop/effect
     * there. Setting it on the Preview builder applies it to the shared
     * capture session, so it covers the recording stream too.
     */
    @SuppressLint("UnsafeOptInUsageError")
    private fun buildPreviewWithExposureMonitoring(
        aspectRatio: Int,
        stabilizationMode: Int,
    ): Preview {
        val previewBuilder = Preview.Builder()
            .setTargetAspectRatio(aspectRatio)

        val camera2Extender = Camera2Interop.Extender(previewBuilder)
        // Add Camera2 capture callback to monitor exposure values
        camera2Extender.setSessionCaptureCallback(exposureCaptureCallback)
        camera2Extender.setCaptureRequestOption(
            CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE,
            stabilizationMode,
        )

        return previewBuilder.build()
    }

    /**
     * Reads `(basicEisSupported, previewStabilizationSupported)` from the
     * current lens's Camera2 `CONTROL_AVAILABLE_VIDEO_STABILIZATION_MODES`.
     *
     * Uses the static camera characteristics (not a pre-bind CameraX
     * `CameraInfo`/`PreviewCapabilities`, which on some devices/CameraX
     * versions throws or under-reports before the use cases are bound — that
     * was disabling stabilization entirely).
     */
    private fun stabilizationSupport(): Pair<Boolean, Boolean> {
        val cameraId = getCameraIdForLens(currentLensType) ?: return false to false
        return try {
            val cameraManager =
                context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val modes = cameraManager.getCameraCharacteristics(cameraId).get(
                CameraCharacteristics.CONTROL_AVAILABLE_VIDEO_STABILIZATION_MODES
            )
            val onSupported = modes?.contains(
                CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_ON
            ) == true
            val previewSupported = modes?.contains(
                CameraMetadata
                    .CONTROL_VIDEO_STABILIZATION_MODE_PREVIEW_STABILIZATION
            ) == true
            onSupported to previewSupported
        } catch (e: Exception) {
            DivineCameraLog.w(TAG, "Failed to read stabilization support", e)
            false to false
        }
    }

    /**
     * Resolves the requested stabilization mode into the raw Camera2
     * `CONTROL_VIDEO_STABILIZATION_MODE` value to apply at bind time
     * (0=off, 1=on/basic EIS, 2=preview stabilization), gated on the lens's
     * supported modes.
     */
    private fun resolvedCamera2StabilizationMode(): Int {
        val off = CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_OFF
        if (requestedStabilizationMode == STABILIZATION_OFF) return off

        val on = CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_ON
        val preview =
            CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_PREVIEW_STABILIZATION
        val (onSupported, previewSupported) = stabilizationSupport()

        val mode = when (requestedStabilizationMode) {
            STABILIZATION_STANDARD -> if (onSupported) on else off
            STABILIZATION_CINEMATIC,
            STABILIZATION_CINEMATIC_EXTENDED,
            STABILIZATION_PREVIEW_OPTIMIZED,
            STABILIZATION_LOW_LATENCY,
            STABILIZATION_AUTO -> when {
                previewSupported -> preview
                onSupported -> on
                else -> off
            }
            else -> off
        }
        DivineCameraLog.info(
            "Stabilization '$requestedStabilizationMode' -> camera2Mode=$mode " +
                "(0=off,1=on,2=preview) " +
                "(previewSupported=$previewSupported onSupported=$onSupported)",
            name = "DivineCamera.Stabilization",
        )
        return mode
    }

    /**
     * Returns a preview [Surface] to hand to a CameraX surface request,
     * fetching the current one from the Flutter [TextureRegistry.SurfaceProducer]
     * each time so a `setSize()` resolution change is picked up. Returns null
     * when no surface can be supplied (the producer was released), so the caller
     * declines the request via `willNotProvideSurface()`.
     */
    private fun resolvePreviewSurface(): Surface? {
        return when (decideSurfaceProvision(hasTexture = surfaceProducer != null)) {
            SurfaceProvision.CREATE -> surfaceProducer?.getSurface()
            SurfaceProvision.DECLINE -> null
        }
    }

    /**
     * Builds the video [Recorder] for the current [videoQuality].
     *
     * Sets an explicit target encoding bitrate — without it CameraX uses the
     * device encoder's default, which for FHD typically lands at 15–25 Mbit/s
     * instead of the intended 8 Mbit/s. Callers that lower [videoQuality]
     * (encoder-failure retry) pick up the matching lower bitrate on rebuild.
     *
     * The bitrate keys off the requested [videoQuality]; if [FallbackStrategy]
     * silently selects a lower resolution the device can actually record, the
     * target is a bounded overshoot for that tier (never above the requested
     * one) — still far below the uncapped device default, so acceptable.
     */
    @SuppressLint("RestrictedApi")
    private fun buildRecorder(aspectRatio: Int): Recorder = Recorder.Builder()
        .setQualitySelector(
            QualitySelector.from(
                videoQuality,
                FallbackStrategy.lowerQualityOrHigherThan(Quality.SD)
            )
        )
        .setAspectRatio(aspectRatio)
        .setExecutor(cameraExecutor)
        .setTargetVideoEncodingBitRate(videoEncodingBitRate(videoQuality))
        // setAudioSource is @RestrictTo(LIBRARY): CameraX 1.5.3 publishes no
        // supported way to choose the source, and no way at all to route
        // capture to a specific AudioDeviceInfo. Pinned by
        // AudioInputSourceTest so a CameraX bump that drops it fails the build.
        .setAudioSource(resolveAudioSource())
        .build()

    /**
     * Resolves the audio source for a new Recorder from the input devices
     * connected right now. Falls back to the CameraX default when the
     * AudioManager is unavailable.
     *
     * Evaluated per Recorder build, so initial bind and both lens switches pick
     * up a microphone attached since the last build; a mic plugged in while the
     * camera stays bound is picked up on the next switch or re-entry.
     *
     * Also honours the user's Music mode preference (#8079), which asks for
     * capture without the platform's speech-tuned processing. iOS answers that
     * with an audio-session mode; the audio source is Android's equivalent
     * lever, and this is the only place Android picks one.
     *
     * Logs the decision, both inputs to it, and the inputs the device
     * reported. A report that the external mic or Music mode was ignored is
     * only actionable if it says which source was chosen and from what, and a
     * device naming its mic something we do not route on leaves no other
     * trace (#6171).
     */
    private fun resolveAudioSource(): Int {
        val audioManager =
            context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                ?: run {
                    DivineCameraLog.warning(
                        "AudioManager unavailable — camera-default audio source",
                        name = "DivineCamera.Audio"
                    )
                    return AudioSpec.SOURCE_AUTO
                }
        val types = audioManager
            .getDevices(AudioManager.GET_DEVICES_INPUTS)
            .map { it.type }
            .toIntArray()
        // Only the exact string "true" means supported. The CDD requires an
        // unsupporting device to return null (§5.11 [C-2-1]) while AOSP's own
        // getProperty returns String.valueOf(false) and never null, so both
        // answers are in the field and both must read as unsupported.
        val unprocessedSupported = audioManager
            .getProperty(AudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED)
            .toBoolean()
        val source = audioSourceForInputDeviceTypes(
            types,
            preferUnprocessedAudio = prefersUnprocessedAudio,
            unprocessedSourceSupported = unprocessedSupported
        )
        val inputs = types
            .joinToString(", ") { audioInputTypeName(it) }
            .ifEmpty { "none" }
        DivineCameraLog.info(
            "Audio source: ${audioSourceName(source)} " +
                "(music mode: $prefersUnprocessedAudio, " +
                "unprocessed supported: $unprocessedSupported, " +
                "inputs: $inputs)",
            name = "DivineCamera.Audio"
        )
        return source
    }

    /**
     * Starts the camera with preview and video capture use cases.
     */
    private fun startCamera(callback: (Map<String, Any?>?, String?) -> Unit) {
        val provider = cameraProvider ?: run {
            DivineCameraLog.e(TAG, "Camera provider not available")
            callback(null, "Camera provider not available")
            return
        }

        // Check if activity is a LifecycleOwner
        if (activity !is LifecycleOwner) {
            DivineCameraLog.e(TAG, "Activity is not a LifecycleOwner: ${activity.javaClass.name}")
            callback(null, "Activity must be a LifecycleOwner (use FlutterFragmentActivity)")
            return
        }

        try {
            // Unbind all use cases before rebinding
            provider.unbindAll()
            DivineCameraLog.d(TAG, "Unbound all previous use cases")

            // Release previous resources only if not already handled (e.g., by switchCamera)
            if (surfaceProducer != null) {
                // The SurfaceProducer owns the Surface, so release() tears it
                // down.
                surfaceProducer?.release()
                surfaceProducer = null
            }
            // Drop any producer still retired from an interrupted switch.
            retiringSurfaceProducer?.release()
            retiringSurfaceProducer = null

            // Create the Flutter surface producer for the preview.
            surfaceProducer = textureRegistry.createSurfaceProducer()

            val textureId = surfaceProducer?.id() ?: run {
                DivineCameraLog.e(TAG, "Failed to create texture entry")
                callback(null, "Failed to create texture")
                return
            }

            DivineCameraLog.d(TAG, "Created Flutter texture with id: $textureId")

            // Build camera selector for the current lens type
            val cameraSelector = buildCameraSelectorForLens(currentLensType, provider)

            // Fixed 16:9 aspect ratio for portrait mode (9:16)
            val targetAspectRatio = AspectRatio.RATIO_16_9

            // Resolve stabilization at bind time (CameraX cannot change it on a
            // running session).
            val stabilizationMode = resolvedCamera2StabilizationMode()

            // Build preview with Camera2Interop for exposure monitoring
            preview = buildPreviewWithExposureMonitoring(
                targetAspectRatio,
                stabilizationMode,
            )

            // Variable to track if callback was already called
            var callbackCalled = false

            // Setup surface provider - provide the surface when CameraX requests it
            preview?.setSurfaceProvider(ContextCompat.getMainExecutor(context)) { request ->
                val resolution = request.resolution
                videoWidth = resolution.width
                videoHeight = resolution.height
                DivineCameraLog.d(
                    TAG,
                    "Surface provider called with resolution: ${videoWidth}x${videoHeight}"
                )

                // Update aspect ratio for portrait mode (height/width gives 9:16 ratio)
                aspectRatio = videoHeight.toFloat() / videoWidth.toFloat()
                DivineCameraLog.d(TAG, "Aspect ratio set to: $aspectRatio (portrait), video dimensions: ${videoWidth}x${videoHeight}")

                surfaceProducer?.setSize(videoWidth, videoHeight)

                val surface = resolvePreviewSurface()

                // Provide the surface
                if (surface != null && surface.isValid) {
                    request.provideSurface(
                        surface,
                        ContextCompat.getMainExecutor(context)
                    ) { result ->
                        DivineCameraLog.d(TAG, "Surface result code: ${result.resultCode}")
                    }

                    // Call the callback NOW after we have the correct resolution
                    if (!callbackCalled) {
                        callbackCalled = true
                        val state = getCameraState().toMutableMap()
                        state["textureId"] = textureId
                        DivineCameraLog.d(TAG, "Camera initialized successfully: $state")
                        callback(state, null)
                    }
                } else {
                    DivineCameraLog.w(TAG, "Preview texture unavailable; declining surface request")
                    request.willNotProvideSurface()
                    if (!callbackCalled) {
                        callbackCalled = true
                        callback(null, "Failed to create preview surface")
                    }
                }
            }

            // Build video capture with same aspect ratio as preview
            // Mirror front camera video to match preview
            val recorder = buildRecorder(targetAspectRatio)

            // Mirror front camera video output based on mirrorFrontCameraOutput setting
            videoCapture = VideoCapture.Builder(recorder)
                .setMirrorMode(
                    if (mirrorFrontCameraOutput && currentLens == CameraSelector.LENS_FACING_FRONT)
                        MirrorMode.MIRROR_MODE_ON_FRONT_ONLY
                    else
                        MirrorMode.MIRROR_MODE_OFF
                )
                .build()

            DivineCameraLog.d(TAG, "Binding use cases to lifecycle...")

            // Bind use cases to camera
            camera = bindUseCasesWithPhoto(provider, cameraSelector)

            DivineCameraLog.d(TAG, "Camera bound successfully")

            // Get camera info
            camera?.let { cam ->
                val cameraInfo = cam.cameraInfo
                val zoomState = cameraInfo.zoomState.value
                minZoom = zoomState?.minZoomRatio ?: 1.0f
                maxZoom = zoomState?.maxZoomRatio ?: 1.0f
                currentZoom = zoomState?.zoomRatio ?: 1.0f
                // Front camera has "flash" via screen brightness when feature is enabled
                hasFlash = cameraInfo.hasFlashUnit() || 
                    (screenFlashFeatureEnabled && currentLens == CameraSelector.LENS_FACING_FRONT)
                isFocusPointSupported = true
                isExposurePointSupported = true
                DivineCameraLog.d(TAG, "Camera info: zoom=$minZoom-$maxZoom, flash=$hasFlash")
            }

            // Compute virtual zoom ranges for auto lens switching
            computeVirtualZoomRanges()

        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Failed to start camera", e)
            mainHandler.post {
                callback(null, "Failed to start camera: ${e.message}")
            }
        }
    }

    /**
     * Switches to a different camera lens.
     * Uses a fresh preview texture for front/back facing flips so the outgoing
     * frozen frame cannot receive incoming-camera pixels with the wrong
     * rotation. Same-facing rebinds reuse the current texture because Dart keeps
     * displaying it.
     *
     * [onBound] runs synchronously once the new camera is bound, before the
     * switch is gated on settled frames and while the preview is still frozen
     * on the old frame. Use it for adjustments (e.g. restoring zoom) that must
     * already be in effect when the incoming frame becomes visible, so the
     * preview doesn't visibly unfreeze at the default and then jump.
     */
    fun switchCamera(
        lens: String,
        onBound: (() -> Unit)? = null,
        callback: (Map<String, Any?>?, String?) -> Unit
    ) {
        DivineCameraLog.d(TAG, "Switching camera to: $lens")
        
        // Disable screen flash when switching cameras
        disableScreenFlash()

        // Only a facing flip (front<->back) needs a fresh preview texture — that
        // sensor-orientation delta is what produced the upside-down flash. A
        // same-facing rebind (a stabilization toggle rebinds through this
        // method) must reuse the existing texture: it reports no new textureId
        // to Dart, so a fresh one would strand the preview on the retired
        // texture and freeze it.
        val previousLens = currentLens

        // Map lens string to lens type and facing
        currentLensType = lens
        currentLens = getLensFacingForType(lens)
        
        // Check if the requested lens is available
        val requestedCameraId = getCameraIdForLens(currentLensType)
        if (requestedCameraId == null) {
            DivineCameraLog.e(TAG, "Requested lens $lens is not available")
            callback(null, "Lens $lens is not available on this device")
            return
        }

        val provider = cameraProvider ?: run {
            DivineCameraLog.e(TAG, "Camera provider not available")
            callback(null, "Camera provider not available")
            return
        }

        if (activity !is LifecycleOwner) {
            DivineCameraLog.e(TAG, "Activity is not a LifecycleOwner")
            callback(null, "Activity must be a LifecycleOwner")
            return
        }

        var didSwapTexture = false
        try {
            // Unbind all use cases
            provider.unbindAll()

            // Give the incoming camera a brand-new texture and retire the
            // outgoing one (kept alive so the Dart freeze-gate keeps showing its
            // last frame until the swap). The outgoing texture never receives the
            // new camera's frames, so its rotation can't desync mid-switch — this
            // is the structural fix for the upside-down flash. Only done on a
            // facing flip; same-facing rebinds reuse the texture. The previous
            // switch's retired producer is safe to release now: Dart swapped off
            // it a switch ago.
            if (currentLens != previousLens) {
                // Created before the swap mutations: createSurfaceProducer()
                // can throw, and the catch rollback only covers a committed
                // swap — mutating first would alias retiringSurfaceProducer
                // to the live producer, so the next flip would release the
                // on-screen texture.
                val freshSurfaceProducer = textureRegistry.createSurfaceProducer()
                retiringSurfaceProducer?.release()
                retiringSurfaceProducer = surfaceProducer
                surfaceProducer = freshSurfaceProducer
                didSwapTexture = true
            }

            // Build camera selector for the requested lens
            // For specialized lenses (ultraWide, telephoto, macro), we need to use Camera2 interop
            val cameraSelector = buildCameraSelectorForLens(currentLensType, provider)

            // Fixed 16:9 aspect ratio for portrait mode (9:16)
            val targetAspectRatio = AspectRatio.RATIO_16_9

            val stabilizationMode = resolvedCamera2StabilizationMode()

            // Build preview with Camera2Interop for exposure monitoring
            preview = buildPreviewWithExposureMonitoring(
                targetAspectRatio,
                stabilizationMode,
            )

            // Drive the preview texture (fresh on a facing flip, reused on a
            // same-facing rebind); update its buffer size once we get the
            // incoming camera's resolution.
            preview?.setSurfaceProvider(ContextCompat.getMainExecutor(context)) { request ->
                val resolution = request.resolution
                videoWidth = resolution.width
                videoHeight = resolution.height
                DivineCameraLog.d(
                    TAG,
                    "Switch: Surface provider called with resolution: ${videoWidth}x${videoHeight}"
                )

                // Update aspect ratio for portrait mode (height/width gives 9:16 ratio)
                aspectRatio = videoHeight.toFloat() / videoWidth.toFloat()

                surfaceProducer?.setSize(videoWidth, videoHeight)

                val surface = resolvePreviewSurface()
                if (surface != null && surface.isValid) {
                    request.provideSurface(
                        surface,
                        ContextCompat.getMainExecutor(context)
                    ) { result ->
                        DivineCameraLog.d(TAG, "Switch: Surface result code: ${result.resultCode}")
                    }
                } else {
                    DivineCameraLog.w(TAG, "Switch: preview texture unavailable; declining surface request")
                    request.willNotProvideSurface()
                }
            }

            // Create recorder with same quality and aspect ratio
            val recorder = buildRecorder(targetAspectRatio)

            // Mirror front camera video output based on mirrorFrontCameraOutput setting
            videoCapture = VideoCapture.Builder(recorder)
                .setMirrorMode(
                    if (mirrorFrontCameraOutput && currentLens == CameraSelector.LENS_FACING_FRONT)
                        MirrorMode.MIRROR_MODE_ON_FRONT_ONLY
                    else
                        MirrorMode.MIRROR_MODE_OFF
                )
                .build()

            // Bind use cases to the new camera
            camera = bindUseCasesWithPhoto(provider, cameraSelector)

            // Get camera info from new camera
            camera?.let { cam ->
                val cameraInfo = cam.cameraInfo
                val zoomState = cameraInfo.zoomState.value
                minZoom = zoomState?.minZoomRatio ?: 1.0f
                maxZoom = zoomState?.maxZoomRatio ?: 1.0f
                currentZoom = 1.0f
                // Front camera has "flash" via screen brightness when feature is enabled
                hasFlash = cameraInfo.hasFlashUnit() || 
                    (screenFlashFeatureEnabled && currentLens == CameraSelector.LENS_FACING_FRONT)
                isFocusPointSupported = true
                isExposurePointSupported = true
            }

            // Compute virtual zoom ranges for auto lens switching
            computeVirtualZoomRanges()

            // Apply post-bind adjustments (e.g. zoom restore) while the preview
            // is still frozen, so the incoming frame is already correct when it
            // becomes visible instead of unfreezing at the reset default.
            onBound?.invoke()

            // Resolve the switch only once the incoming camera has produced
            // enough frames for its fresh texture to carry pixels. Until then
            // the SurfaceProducer keeps showing the old frame (frozen) and the
            // state (lens/rotation) stays on the old camera, so the frozen
            // frame never flips to the new rotation early. Whichever path runs
            // first (settled frames or the timeout) cancels the other queued
            // copy via removeCallbacks, so this runs exactly once and no stale
            // timeout lingers on the main looper afterwards.
            val finishSwitch = object : Runnable {
                override fun run() {
                    mainHandler.removeCallbacks(this)
                    onFirstFrameAfterSwitch = null
                    DivineCameraLog.d(TAG, "Camera switched successfully")
                    callback(getCameraState(), null)
                }
            }
            switchSettleFramesRemaining = SWITCH_SETTLE_FRAMES
            onFirstFrameAfterSwitch = { mainHandler.post(finishSwitch) }
            mainHandler.postDelayed(finishSwitch, SWITCH_FIRST_FRAME_TIMEOUT_MS)

        } catch (e: Exception) {
            // Roll back a fresh-texture swap so surfaceProducer again matches the
            // texture Dart is still showing; otherwise the next switch would
            // release that on-screen texture (black preview) or a later
            // getCameraState would swap the preview onto the empty producer.
            if (didSwapTexture) {
                surfaceProducer?.release()
                surfaceProducer = retiringSurfaceProducer
                retiringSurfaceProducer = null
            }
            DivineCameraLog.e(TAG, "Failed to switch camera", e)
            mainHandler.post {
                callback(null, "Failed to switch camera: ${e.message}")
            }
        }
    }

    /**
     * Sets the flash mode.
     * For front camera with torch mode, maximizes screen brightness instead.
     * For "auto" mode, brightness will be checked once when recording starts.
     */
    fun setFlashMode(mode: String): Boolean {
        val cam = camera ?: return false

        DivineCameraLog.d(TAG, "Setting flash mode: $mode (currentLens: ${if (currentLens == CameraSelector.LENS_FACING_FRONT) "front" else "back"})")

        return try {
            // Handle screen brightness for front camera "torch" mode
            if (currentLens == CameraSelector.LENS_FACING_FRONT) {
                if (mode == "torch") {
                    enableScreenFlash()
                    isTorchEnabled = true
                    isAutoFlashMode = false
                    currentFlashMode = ImageCapture.FLASH_MODE_OFF
                    applyPhotoFlashMode()
                    return true
                } else if (mode == "auto") {
                    // Auto mode for front camera - will check brightness when recording starts
                    disableScreenFlash()
                    isTorchEnabled = false
                    isAutoFlashMode = true
                    currentFlashMode = ImageCapture.FLASH_MODE_AUTO
                    applyPhotoFlashMode()
                    DivineCameraLog.d(TAG, "Auto flash mode enabled for front camera")
                    return true
                } else {
                    disableScreenFlash()
                    isAutoFlashMode = false
                }
            }

            when (mode) {
                "off" -> {
                    cam.cameraControl.enableTorch(false)
                    isTorchEnabled = false
                    isAutoFlashMode = false
                    autoFlashTorchEnabled = false
                    currentFlashMode = ImageCapture.FLASH_MODE_OFF
                }

                "auto" -> {
                    // Auto mode - will check brightness when recording starts
                    cam.cameraControl.enableTorch(false)
                    isTorchEnabled = false
                    isAutoFlashMode = true
                    autoFlashTorchEnabled = false
                    currentFlashMode = ImageCapture.FLASH_MODE_AUTO
                    DivineCameraLog.d(TAG, "Auto flash mode enabled - will check brightness when recording starts")
                }

                "on" -> {
                    cam.cameraControl.enableTorch(false)
                    isTorchEnabled = false
                    isAutoFlashMode = false
                    currentFlashMode = ImageCapture.FLASH_MODE_ON
                }

                "torch" -> {
                    cam.cameraControl.enableTorch(true)
                    isTorchEnabled = true
                    isAutoFlashMode = false
                    currentFlashMode = ImageCapture.FLASH_MODE_OFF
                }
            }
            applyPhotoFlashMode()
            true
        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Failed to set flash mode", e)
            false
        }
    }

    /**
     * Enables screen flash by setting brightness to maximum (for front camera).
     */
    private fun enableScreenFlash() {
        if (!screenFlashFeatureEnabled) return
        
        mainHandler.post {
            try {
                val window = activity.window
                val layoutParams = window.attributes
                
                // Set brightness to maximum (1.0 = 100%)
                layoutParams.screenBrightness = 1.0f
                window.attributes = layoutParams
                val wasEnabled = isScreenFlashEnabled
                isScreenFlashEnabled = true
                if (!wasEnabled) onScreenFlashChangedListener?.invoke(true)

                DivineCameraLog.d(TAG, "Screen flash enabled (brightness set to 100%)")
            } catch (e: Exception) {
                DivineCameraLog.e(TAG, "Failed to enable screen flash", e)
            }
        }
    }

    /**
     * Disables screen flash by restoring system brightness control.
     */
    private fun disableScreenFlash() {
        if (!isScreenFlashEnabled) return
        forceDisableScreenFlash()
    }
    
    /**
     * Forces screen brightness to be restored to system control.
     * Used when pausing/releasing to ensure brightness is always restored.
     */
    private fun forceDisableScreenFlash() {
        mainHandler.post {
            try {
                val window = activity.window
                val layoutParams = window.attributes
                
                layoutParams.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                window.attributes = layoutParams

                val wasEnabled = isScreenFlashEnabled
                isScreenFlashEnabled = false
                if (wasEnabled) onScreenFlashChangedListener?.invoke(false)

                DivineCameraLog.d(TAG, "Screen flash disabled (brightness restored to system control)")
            } catch (e: Exception) {
                DivineCameraLog.e(TAG, "Failed to disable screen flash", e)
            }
        }
    }

    /**
     * Checks if the current environment is dark based on Camera2 exposure values.
     * Uses ISO and exposure time as indicators.
     * Front camera has lower thresholds since screen flash is less intrusive.
     */
    private fun isEnvironmentDark(): Boolean {
        val isoThreshold = if (currentLens == CameraSelector.LENS_FACING_FRONT) 
            frontCameraIsoThreshold else backCameraIsoThreshold
        val exposureThreshold = if (currentLens == CameraSelector.LENS_FACING_FRONT) 
            frontCameraExposureThreshold else backCameraExposureThreshold
        
        // If ISO is high or exposure time is long, it's dark
        val isDark = currentIso >= isoThreshold || currentExposureTime >= exposureThreshold
        DivineCameraLog.d(TAG, "Auto flash: ISO=$currentIso (threshold=$isoThreshold), " +
                   "ExposureTime=${currentExposureTime/1_000_000}ms (threshold=${exposureThreshold/1_000_000}ms) -> isDark=$isDark")
        return isDark
    }
    
    /**
     * Checks the current exposure values and enables auto-flash if needed.
     * Uses Camera2 exposure data - no ImageAnalysis required.
     */
    private fun checkAndEnableAutoFlash() {
        if (!isAutoFlashMode) return
        
        if (isEnvironmentDark()) {
            DivineCameraLog.d(TAG, "Auto flash: Dark environment detected - enabling flash")
            enableAutoFlashTorch()
        } else {
            DivineCameraLog.d(TAG, "Auto flash: Bright environment - flash not needed")
        }
    }

    /**
     * Enables torch/screen flash for auto flash mode.
     */
    private fun enableAutoFlashTorch() {
        autoFlashTorchEnabled = true
        
        try {
            if (currentLens == CameraSelector.LENS_FACING_FRONT) {
                enableScreenFlash()
                DivineCameraLog.d(TAG, "Auto flash: Screen flash enabled for front camera")
            } else {
                camera?.cameraControl?.enableTorch(true)
                DivineCameraLog.d(TAG, "Auto flash: Torch enabled for back camera")
            }
        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Auto flash: Failed to enable torch", e)
        }
    }
    
    /**
     * Disables torch/screen flash if it was enabled by auto flash mode.
     * Called when recording stops.
     */
    private fun disableAutoFlashTorch() {
        if (!autoFlashTorchEnabled) return
        
        autoFlashTorchEnabled = false
        
        try {
            if (currentLens == CameraSelector.LENS_FACING_FRONT) {
                disableScreenFlash()
                DivineCameraLog.d(TAG, "Auto flash: Screen flash disabled for front camera")
            } else {
                camera?.cameraControl?.enableTorch(false)
                DivineCameraLog.d(TAG, "Auto flash: Torch disabled for back camera")
            }
        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Auto flash: Failed to disable torch", e)
        }
    }

    /**
     * Sets the focus point in normalized coordinates (0.0-1.0).
     * Uses CameraX FocusMeteringAction with explicit AF+AE flags and spot metering.
     * Focus is locked for 3 seconds, then returns to continuous auto-focus.
     */
    fun setFocusPoint(x: Float, y: Float): Boolean {
        val cam = camera ?: return false

        return try {
            // SurfaceOrientedMeteringPointFactory with (1f, 1f) accepts normalized 0-1 coordinates
            val factory = SurfaceOrientedMeteringPointFactory(1f, 1f)
            
            // Create a SMALL metering point (10% of frame) for spot-metering like native camera
            // The third parameter is the size of the metering region (0.0 to 1.0)
            // Smaller = more precise exposure adjustment at tap point
            val point = factory.createPoint(x, y, 0.1f)
            
            // Use all three flags for complete metering adjustment:
            // FLAG_AF = Autofocus (focus on tap point)
            // FLAG_AE = Auto Exposure (adjust brightness/contrast based on tap point)
            // FLAG_AWB = Auto White Balance (adjust color temperature)
            val action = FocusMeteringAction.Builder(
                point, 
                FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE or FocusMeteringAction.FLAG_AWB
            )
                .setAutoCancelDuration(3, java.util.concurrent.TimeUnit.SECONDS)
                .build()
            
            val future = cam.cameraControl.startFocusAndMetering(action)
            future.addListener({
                try {
                    val result = future.get()
                    DivineCameraLog.d(TAG, "Focus+AE ${if (result.isFocusSuccessful) "successful" else "adjusting"} at: ($x, $y)")
                } catch (e: Exception) {
                    DivineCameraLog.d(TAG, "Focus check: ${e.message}")
                }
            }, ContextCompat.getMainExecutor(context))
            
            DivineCameraLog.d(TAG, "Focus point set: ($x, $y) with FLAG_AF|FLAG_AE, 10% spot metering")
            true
        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Failed to set focus point", e)
            false
        }
    }

    /**
     * Sets the exposure point in normalized coordinates (0.0-1.0).
     * For exposure-only adjustment without changing focus.
     */
    fun setExposurePoint(x: Float, y: Float): Boolean {
        val cam = camera ?: return false

        return try {
            // SurfaceOrientedMeteringPointFactory with (1f, 1f) accepts normalized 0-1 coordinates
            val factory = SurfaceOrientedMeteringPointFactory(1f, 1f)
            val point = factory.createPoint(x, y)
            
            val action = FocusMeteringAction.Builder(point, FocusMeteringAction.FLAG_AE)
                // Keep exposure locked for 5 seconds before returning to auto
                .setAutoCancelDuration(5, java.util.concurrent.TimeUnit.SECONDS)
                .build()
            cam.cameraControl.startFocusAndMetering(action)
            DivineCameraLog.d(TAG, "Exposure point set: ($x, $y)")
            true
        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Failed to set exposure point", e)
            false
        }
    }
    
    /**
     * Cancels any active focus/metering lock and returns to continuous auto-focus.
     * Call this when you want to reset focus behavior after a tap-to-focus.
     */
    fun cancelFocusAndMetering(): Boolean {
        val cam = camera ?: return false
        
        return try {
            cam.cameraControl.cancelFocusAndMetering()
            DivineCameraLog.d(TAG, "Focus and metering cancelled - returning to continuous auto-focus")
            true
        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Failed to cancel focus and metering", e)
            false
        }
    }

    /**
     * Computes the virtual zoom range across all available back-facing lenses.
     * Virtual zoom 1.0 = main camera at native 1x.
     * Below 1.0 = ultra-wide territory.
     * Above telephotoRatio = telephoto territory.
     *
     * Call after camera binds to ensure accurate zoom ranges.
     */
    private fun computeVirtualZoomRanges() {
        // Only for back-facing cameras with multiple lenses
        if (currentLens == CameraSelector.LENS_FACING_FRONT
            || mainCameraFocalLength <= 0f
        ) {
            autoLensSwitchEnabled = false
            virtualMinZoom = minZoom
            virtualMaxZoom = maxZoom
            virtualCurrentZoom = currentZoom
            return
        }

        // If the bound camera already supports zooming below 1.0x,
        // it is a logical multi-camera whose HAL handles smooth
        // cross-fade transitions between physical sensors internally.
        // Skip manual auto-switching for a much smoother experience.
        if (minZoom < 1.0f) {
            autoLensSwitchEnabled = false
            virtualMinZoom = minZoom
            virtualMaxZoom = maxZoom
            virtualCurrentZoom = currentZoom
            DivineCameraLog.d(
                TAG,
                "Logical multi-camera detected " +
                    "(native minZoom=$minZoom, maxZoom=$maxZoom), " +
                    "using native zoom for smooth transitions"
            )
            return
        }

        // Refine max zoom estimates with actual CameraX values
        when (currentLensType) {
            "back" -> mainNativeMaxZoom = maxZoom
            "ultraWide" -> ultraWideNativeMaxZoom = maxZoom
            "telephoto" -> telephotoNativeMaxZoom = maxZoom
        }

        // Focal length ratios relative to main camera
        if (ultraWideCameraFocalLength > 0f
            && ultraWideCameraId != null
        ) {
            ultraWideZoomRatio =
                ultraWideCameraFocalLength / mainCameraFocalLength
        }
        if (telephotoCameraFocalLength > 0f
            && telephotoCameraId != null
        ) {
            telephotoZoomRatio =
                telephotoCameraFocalLength / mainCameraFocalLength
        }

        // Virtual min: ultra-wide at native 1x, or main camera's min
        virtualMinZoom = if (
            ultraWideCameraId != null && ultraWideZoomRatio > 0f
        ) {
            ultraWideZoomRatio
        } else {
            minZoom
        }

        // Virtual max: telephoto at max zoom, or main camera's max
        virtualMaxZoom = if (
            telephotoCameraId != null && telephotoZoomRatio > 0f
        ) {
            telephotoZoomRatio * telephotoNativeMaxZoom
        } else {
            mainNativeMaxZoom
        }

        // Current virtual zoom derived from active lens
        virtualCurrentZoom = when (currentLensType) {
            "ultraWide" -> currentZoom * ultraWideZoomRatio
            "telephoto" -> currentZoom * telephotoZoomRatio
            else -> currentZoom
        }

        autoLensSwitchEnabled = autoLensSwitchRequested &&
            (ultraWideCameraId != null || telephotoCameraId != null)

        DivineCameraLog.d(
            TAG,
            "Virtual zoom: min=$virtualMinZoom, max=$virtualMaxZoom, " +
                "current=$virtualCurrentZoom, uwRatio=$ultraWideZoomRatio, " +
                "teleRatio=$telephotoZoomRatio, enabled=$autoLensSwitchEnabled"
        )
    }

    /**
     * Converts a virtual zoom level to the target lens type and native zoom.
     * Uses hysteresis to prevent oscillation at transition points.
     */
    private fun virtualToNativeZoom(
        virtualZoom: Float
    ): Pair<String, Float> {
        // Ultra-wide range: below 1.0x (with hysteresis)
        if (ultraWideCameraId != null) {
            val useUltraWide = if (currentLensType == "ultraWide") {
                // Stay on ultra-wide until clearly above 1.0
                virtualZoom < 1.0f + LENS_SWITCH_HYSTERESIS
            } else {
                virtualZoom < 1.0f
            }
            if (useUltraWide) {
                return Pair(
                    "ultraWide",
                    virtualZoom / ultraWideZoomRatio
                )
            }
        }

        // Telephoto range (with hysteresis)
        if (telephotoCameraId != null && telephotoZoomRatio > 1.0f) {
            val useTelephoto = if (currentLensType == "telephoto") {
                // Stay on telephoto until clearly below ratio
                virtualZoom >= telephotoZoomRatio - LENS_SWITCH_HYSTERESIS
            } else {
                virtualZoom >= telephotoZoomRatio
            }
            if (useTelephoto) {
                return Pair(
                    "telephoto",
                    virtualZoom / telephotoZoomRatio
                )
            }
        }

        return Pair("back", virtualZoom)
    }

    /**
     * Internally switches the camera lens for zoom-based auto-switching.
     * Reuses the existing Flutter texture for minimal visual disruption.
     * Does NOT switch during recording to avoid interruption.
     */
    private fun autoSwitchToLens(
        targetLensType: String,
        targetNativeZoom: Float
    ) {
        if (isAutoSwitching || isRecording) return

        val provider = cameraProvider ?: return
        if (activity !is LifecycleOwner) return

        isAutoSwitching = true
        DivineCameraLog.d(
            TAG,
            "Auto-switching $currentLensType -> $targetLensType " +
                "(nativeZoom=$targetNativeZoom)"
        )

        try {
            currentLensType = targetLensType
            currentLens = getLensFacingForType(targetLensType)

            provider.unbindAll()

            val cameraSelector =
                buildCameraSelectorForLens(targetLensType, provider)
            val targetAspectRatio = AspectRatio.RATIO_16_9

            val stabilizationMode = resolvedCamera2StabilizationMode()

            preview = buildPreviewWithExposureMonitoring(
                targetAspectRatio,
                stabilizationMode,
            )
            // Delay surface provision so the zoom is fully applied
            // before the first frame renders. The Flutter texture keeps
            // the last frame from the previous camera (natural freeze)
            // during the brief delay, preventing a visible zoom jump.
            preview?.setSurfaceProvider(
                ContextCompat.getMainExecutor(context)
            ) { request ->
                val resolution = request.resolution
                videoWidth = resolution.width
                videoHeight = resolution.height
                aspectRatio =
                    videoHeight.toFloat() / videoWidth.toFloat()
                surfaceProducer?.setSize(
                    videoWidth,
                    videoHeight
                )

                // Post surface provision to let setZoomRatio settle
                // in the camera pipeline before any frames flow.
                mainHandler.postDelayed({
                    val surface =
                        resolvePreviewSurface()
                    if (surface != null && surface.isValid) {
                        request.provideSurface(
                            surface,
                            ContextCompat.getMainExecutor(
                                context
                            )
                        ) { result ->
                            DivineCameraLog.d(
                                TAG,
                                "AutoSwitch surface: " +
                                    "${result.resultCode}"
                            )
                        }
                        DivineCameraLog.d(
                            TAG,
                            "AutoSwitch surface provided " +
                                "(delayed)"
                        )
                    } else {
                        DivineCameraLog.w(
                            TAG,
                            "AutoSwitch: preview texture " +
                                "unavailable; declining request"
                        )
                        request.willNotProvideSurface()
                    }
                    isAutoSwitching = false
                }, 100)
            }

            val recorder = buildRecorder(targetAspectRatio)

            videoCapture = VideoCapture.Builder(recorder)
                .setMirrorMode(
                    if (mirrorFrontCameraOutput &&
                        currentLens ==
                        CameraSelector.LENS_FACING_FRONT
                    ) {
                        MirrorMode.MIRROR_MODE_ON_FRONT_ONLY
                    } else {
                        MirrorMode.MIRROR_MODE_OFF
                    }
                )
                .build()

            camera = bindUseCasesWithPhoto(provider, cameraSelector)

            camera?.let { cam ->
                val zoomState =
                    cam.cameraInfo.zoomState.value
                minZoom = zoomState?.minZoomRatio ?: 1.0f
                maxZoom = zoomState?.maxZoomRatio ?: 1.0f
                hasFlash = cam.cameraInfo.hasFlashUnit() ||
                    (screenFlashFeatureEnabled &&
                        currentLens ==
                        CameraSelector.LENS_FACING_FRONT)

                val clampedZoom =
                    targetNativeZoom.coerceIn(minZoom, maxZoom)
                cam.cameraControl.setZoomRatio(clampedZoom)
                currentZoom = clampedZoom
            }

            computeVirtualZoomRanges()

            DivineCameraLog.d(
                TAG,
                "Auto-switch done: $targetLensType " +
                    "native=$currentZoom virtual=$virtualCurrentZoom"
            )
        } catch (e: Exception) {
            DivineCameraLog.e(
                TAG,
                "Failed to auto-switch to $targetLensType",
                e
            )
            isAutoSwitching = false
        }
    }

    /**
     * Sets the zoom level. When auto lens switching is enabled,
     * accepts a virtual zoom level spanning all available back lenses.
     * 1.0 = main at native 1x. Below 1.0 = ultra-wide. Above
     * telephoto ratio = telephoto.
     *
     * Returns the applied zoom plus the currently available range as a
     * map for the platform channel (shared contract with iOS, where the
     * OS can silently clamp the request), or null on failure.
     */
    fun setZoomLevel(level: Float): Map<String, Double>? {
        // Without auto lens switching, use direct camera zoom
        if (!autoLensSwitchEnabled) {
            val cam = camera ?: return null
            return try {
                // When auto lens switch is disabled, clamp to 1.0 minimum
                // to prevent native HAL from switching to ultra-wide on
                // logical multi-cameras.
                val effectiveMin = if (!autoLensSwitchRequested && minZoom < 1.0f) 1.0f else minZoom
                val clampedLevel =
                    level.coerceIn(effectiveMin, maxZoom)
                cam.cameraControl.setZoomRatio(clampedLevel)
                currentZoom = clampedLevel
                DivineCameraLog.d(TAG, "Zoom level set: $clampedLevel")
                zoomStateMap(clampedLevel, effectiveMin, maxZoom)
            } catch (e: Exception) {
                DivineCameraLog.e(TAG, "Failed to set zoom level", e)
                null
            }
        }

        // Virtual zoom: map across all back lenses
        val clampedVirtual =
            level.coerceIn(virtualMinZoom, virtualMaxZoom)
        virtualCurrentZoom = clampedVirtual

        val (targetLens, nativeZoom) =
            virtualToNativeZoom(clampedVirtual)

        // Switch lens if needed (skip during recording)
        if (targetLens != currentLensType && !isRecording) {
            autoSwitchToLens(targetLens, nativeZoom)
            return zoomStateMap(clampedVirtual, virtualMinZoom, virtualMaxZoom)
        }

        // Same lens: adjust native zoom directly
        val cam = camera ?: return null
        return try {
            val clampedNative =
                nativeZoom.coerceIn(minZoom, maxZoom)
            cam.cameraControl.setZoomRatio(clampedNative)
            currentZoom = clampedNative
            zoomStateMap(clampedVirtual, virtualMinZoom, virtualMaxZoom)
        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Failed to set zoom level", e)
            null
        }
    }

    private fun zoomStateMap(
        zoom: Float,
        min: Float,
        max: Float
    ): Map<String, Double> = mapOf(
        "zoomLevel" to zoom.toDouble(),
        "minZoomLevel" to min.toDouble(),
        "maxZoomLevel" to max.toDouble()
    )

    /**
     * Sets the requested video stabilization mode.
     *
     * CameraX configures stabilization at bind time only (it cannot be changed
     * on a running session), so a mode change while the camera is live rebinds
     * the use cases via [switchCamera] on the same lens. Returns true once the
     * mode is recorded; the rebind reflects it in both preview and recording.
     */
    fun setVideoStabilizationMode(mode: String): Boolean {
        if (!isCanonicalStabilizationMode(mode)) {
            DivineCameraLog.w(TAG, "Unknown video stabilization mode: $mode")
            return false
        }
        if (mode == requestedStabilizationMode) return true
        if (isRecording) {
            DivineCameraLog.w(
                TAG,
                "Ignoring stabilization mode change while recording: $mode"
            )
            return false
        }
        requestedStabilizationMode = mode

        // Not bound yet — the mode is applied on the next bind (initialize).
        if (camera == null || isAutoSwitching) return true

        // Rebind the current lens so CameraX reconfigures the session with the
        // new stabilization setting. The switch path resets zoom to 1.0x like a
        // lens switch, but a stabilization toggle should not move the framing —
        // capture the current (reported) zoom and restore it in onBound (right
        // after the rebind, before the frozen preview releases) so the preview
        // never unfreezes at 1.0x and then jumps back. This also keeps the
        // Dart-side zoom (not re-fetched after this call) consistent with the
        // native zoom.
        val zoomToRestore =
            if (autoLensSwitchEnabled) virtualCurrentZoom else currentZoom
        DivineCameraLog.d(TAG, "Rebinding to apply stabilization mode: $mode")
        switchCamera(
            currentLensType,
            onBound = {
                if (zoomToRestore != 1.0f) {
                    setZoomLevel(zoomToRestore)
                }
            }
        ) { _, _ -> }
        return true
    }

    /**
     * Returns the stabilization modes the active camera supports, as
     * cross-platform strings, read from the lens's Camera2 capabilities.
     */
    private fun availableVideoStabilizationModesForCurrentLens(): List<String> {
        val (onSupported, previewSupported) = stabilizationSupport()
        return buildStabilizationModeList(onSupported, previewSupported)
    }

    /**
     * Forwards a diagnostic when the CameraX audio-source state changes during
     * recording. Only transitions are reported (Status fires continuously):
     * [AudioStats.AUDIO_STATE_ACTIVE] is info, anything else is a warning
     * because it means the saved clip loses (or never gets) sound.
     */
    private fun logAudioStateTransition(audioStats: AudioStats) {
        val state = audioStats.audioState
        if (state == lastAudioState) return
        lastAudioState = state
        val stateName = audioStateName(state)
        if (state == AudioStats.AUDIO_STATE_ACTIVE) {
            DivineCameraLog.info(
                "Audio source state: $stateName",
                name = "DivineCamera.Audio"
            )
        } else {
            DivineCameraLog.warning(
                "Audio source state: $stateName — clip may have no sound",
                name = "DivineCamera.Audio"
            )
        }
    }

    private fun audioStateName(state: Int): String = when (state) {
        AudioStats.AUDIO_STATE_ACTIVE -> "ACTIVE"
        AudioStats.AUDIO_STATE_DISABLED -> "DISABLED"
        AudioStats.AUDIO_STATE_SOURCE_SILENCED -> "SOURCE_SILENCED"
        AudioStats.AUDIO_STATE_ENCODER_ERROR -> "ENCODER_ERROR"
        AudioStats.AUDIO_STATE_SOURCE_ERROR -> "SOURCE_ERROR"
        else -> "UNKNOWN($state)"
    }

    /**
     * Binds Preview + VideoCapture + ImageCapture, falling back to
     * Preview + VideoCapture when the device cannot support all three
     * concurrently. When the photo use case is dropped, [imageCapture] is left
     * null (photo capture unavailable) and video recording keeps working.
     */
    private fun bindUseCasesWithPhoto(
        provider: ProcessCameraProvider,
        cameraSelector: CameraSelector
    ): Camera? {
        // Any full bind (initialize, lens switch, stabilization change) leaves
        // the camera running, which supersedes a pause.
        isPaused = false
        val owner = activity as LifecycleOwner
        val photo = ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
            .setTargetAspectRatio(AspectRatio.RATIO_16_9)
            .setTargetRotation(currentTargetRotation())
            .setFlashMode(currentFlashMode)
            .build()
        return try {
            val bound = provider.bindToLifecycle(
                owner, cameraSelector, preview, videoCapture, photo
            )
            imageCapture = photo
            bound
        } catch (e: Exception) {
            DivineCameraLog.e(
                TAG,
                "Cannot bind ImageCapture with Preview+VideoCapture; photo " +
                    "capture disabled on this device: ${e.message}"
            )
            imageCapture = null
            provider.unbindAll()
            provider.bindToLifecycle(owner, cameraSelector, preview, videoCapture)
        }
    }

    /**
     * Captures a single still photo and writes it to disk as JPEG.
     * @param outputDirectory If provided, saves the photo there; otherwise uses
     *   the cache or files directory per [useCache].
     * @param useCache If true, saves to the cache directory (temporary),
     *   otherwise the files directory (permanent).
     * @param callback Result map (`filePath`, `width`, `height`) on success, or
     *   null plus an error message on failure. Invoked on the main thread.
     */
    fun capturePhoto(
        outputDirectory: String?,
        useCache: Boolean,
        callback: (Map<String, Any?>?, String?) -> Unit
    ) {
        val capture = imageCapture
        if (capture == null) {
            callback(null, "Photo capture not available")
            return
        }
        if (isRecording) {
            callback(null, "Cannot capture photo while recording")
            return
        }

        capture.targetRotation = currentTargetRotation()
        capture.flashMode = currentFlashMode

        val outputDir = when {
            outputDirectory != null -> File(outputDirectory)
            useCache -> context.cacheDir
            else -> context.filesDir
        }
        if (!outputDir.exists()) outputDir.mkdirs()
        val photoFile = File(outputDir, "IMG_${System.currentTimeMillis()}.jpg")
        val options = ImageCapture.OutputFileOptions.Builder(photoFile).build()

        capture.takePicture(
            options,
            cameraExecutor,
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    val bounds = BitmapFactory.Options().apply {
                        inJustDecodeBounds = true
                    }
                    BitmapFactory.decodeFile(photoFile.absolutePath, bounds)
                    val map = mapOf(
                        "filePath" to photoFile.absolutePath,
                        "width" to bounds.outWidth.takeIf { it > 0 },
                        "height" to bounds.outHeight.takeIf { it > 0 }
                    )
                    mainHandler.post { callback(map, null) }
                }

                override fun onError(exception: ImageCaptureException) {
                    mainHandler.post {
                        callback(null, exception.message ?: "Photo capture failed")
                    }
                }
            }
        )
    }

    @Suppress("DEPRECATION")
    private fun currentTargetRotation(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display?.rotation ?: Surface.ROTATION_0
        } else {
            activity.windowManager.defaultDisplay.rotation
        }
    }

    private fun applyPhotoFlashMode() {
        imageCapture?.flashMode = currentFlashMode
    }

    /**
     * Starts video recording.
     * @param maxDurationMs Optional maximum duration in milliseconds. Recording stops automatically when reached.
     * @param useCache If true, saves video to cache directory (temporary). If false, saves to external files directory (permanent).
     * @param outputDirectory If provided, saves video to this directory (overrides useCache when false). Should be Flutter's getApplicationDocumentsDirectory() path.
     */
    @SuppressLint("MissingPermission")
    fun startRecording(maxDurationMs: Int?, useCache: Boolean = true, outputDirectory: String? = null, callback: (String?) -> Unit) {
        val videoCap = videoCapture ?: run {
            callback("Video capture not initialized")
            return
        }

        if (isRecording) {
            callback("Already recording")
            return
        }

        // Reset retry counter for a fresh recording attempt initiated by the user
        encoderRetryCount = 0
        pendingRecordingParams = RecordingParams(maxDurationMs, useCache, outputDirectory, callback)

        // Check audio permission
        if (ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.RECORD_AUDIO
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            DivineCameraLog.warning(
                "RECORD_AUDIO permission not granted — recording blocked",
                name = "DivineCamera.Recording"
            )
            callback("Audio permission not granted")
            return
        }

        startRecordingInternal(maxDurationMs, useCache, outputDirectory, callback)
    }

    /**
     * Internal recording start — also used for encoder-fallback retries.
     */
    @SuppressLint("MissingPermission")
    private fun startRecordingInternal(
        maxDurationMs: Int?,
        useCache: Boolean,
        outputDirectory: String?,
        callback: (String?) -> Unit
    ) {
        val videoCap = videoCapture ?: run {
            callback("Video capture not initialized")
            return
        }

        // Check brightness and enable auto-flash if needed (instant, uses Camera2 exposure values)
        checkAndEnableAutoFlash()

        try {
            // Create output file - use cache, provided directory, or default to filesDir
            val outputDir = when {
                outputDirectory != null -> File(outputDirectory)
                useCache -> context.cacheDir
                else -> context.filesDir
            }
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val outputFile = File(outputDir, "VID_$timestamp.mp4")
            currentRecordingFile = outputFile

            DivineCameraLog.d(
                TAG, "Starting recording to: ${outputFile.absolutePath}" +
                        " (useCache: $useCache)" +
                        if (maxDurationMs != null) " (max duration: ${maxDurationMs}ms)" else ""
            )

            val outputOptions = FileOutputOptions.Builder(outputFile).build()

            // Store callback so it can be called from Finalize if recording is stopped early
            startRecordingCallback = callback

            recording = videoCap.output
                .prepareRecording(context, outputOptions)
                .withAudioEnabled()
                .start(ContextCompat.getMainExecutor(context)) { event ->
                    when (event) {
                        is VideoRecordEvent.Start -> {
                            isRecording = true
                            lastAudioState = Int.MIN_VALUE
                            DivineCameraLog.d(
                                TAG,
                                "VideoRecordEvent.Start received - waiting for first frame..."
                            )
                        }

                        is VideoRecordEvent.Status -> {
                            // Forward audio-source state transitions: a mid-
                            // recording switch to SILENCED / SOURCE_ERROR is the
                            // direct cause of clips saved without sound (#4779).
                            logAudioStateTransition(event.recordingStats.audioStats)

                            // Status events are sent continuously during recording
                            // When recordedDurationNanos > 0, the encoder is truly recording frames
                            val durationNanos = event.recordingStats.recordedDurationNanos
                            if (startRecordingCallback != null && durationNanos > 0) {
                                recordingTrulyStarted = true
                                recordingStartTime = System.currentTimeMillis()
                                // Encoder succeeded — clear retry state
                                encoderRetryCount = 0
                                pendingRecordingParams = null
                                DivineCameraLog.d(
                                    TAG,
                                    "Recording truly started - first frame recorded (duration: ${durationNanos / 1_000_000}ms)"
                                )

                                // Schedule auto-stop if maxDuration is set
                                if (maxDurationMs != null && maxDurationMs > 0) {
                                    maxDurationRunnable = Runnable {
                                        DivineCameraLog.d(
                                            TAG,
                                            "Max duration reached (${maxDurationMs}ms) - auto-stopping recording"
                                        )
                                        autoStopRecording()
                                    }
                                    mainHandler.postDelayed(
                                        maxDurationRunnable!!,
                                        maxDurationMs.toLong()
                                    )
                                }

                                // Notify Flutter that recording truly started
                                startRecordingCallback?.invoke(null)
                                startRecordingCallback = null
                            }
                        }

                        is VideoRecordEvent.Finalize -> {
                            isRecording = false
                            recordingTrulyStarted = false
                            // Cancel any pending auto-stop
                            maxDurationRunnable?.let { mainHandler.removeCallbacks(it) }
                            maxDurationRunnable = null

                            if (event.hasError()) {
                                DivineCameraLog.error(
                                    "Recording finalized with error code ${event.error}",
                                    name = "DivineCamera.Recording"
                                )
                            } else {
                                val hadAudio =
                                    event.recordingStats.audioStats.audioState ==
                                        AudioStats.AUDIO_STATE_ACTIVE
                                DivineCameraLog.info(
                                    "Recording finalized (audioActive=$hadAudio)",
                                    name = "DivineCamera.Recording"
                                )
                            }

                            // If startRecordingCallback is still set, recording was stopped before first keyframe.
                            // This typically means the hardware encoder rejected the resolution.
                            // Try to reinitialize with a lower quality before giving up.
                            if (startRecordingCallback != null && event.hasError()) {
                                val lower = lowerQuality(videoQuality)
                                if (lower != null && encoderRetryCount < MAX_ENCODER_RETRIES) {
                                    encoderRetryCount++
                                    DivineCameraLog.warning(
                                        "Encoder failed at $videoQuality, retrying with $lower " +
                                            "(attempt $encoderRetryCount/$MAX_ENCODER_RETRIES)",
                                        name = "DivineCamera.Recording"
                                    )
                                    videoQuality = lower

                                    // Clean up failed recording file
                                    currentRecordingFile?.let { f ->
                                        if (f.exists()) f.delete()
                                    }
                                    currentRecordingFile = null
                                    recording = null

                                    // Consume the startRecordingCallback so it is not called yet
                                    val savedCallback = startRecordingCallback!!
                                    startRecordingCallback = null

                                    // Re-initialize camera with lower quality, then retry recording
                                    val params = pendingRecordingParams
                                    startCamera { _, error ->
                                        if (error != null) {
                                            DivineCameraLog.e(TAG, "Failed to reinitialize camera at $lower: $error")
                                            savedCallback("Recording failed: encoder not supported")
                                        } else {
                                            DivineCameraLog.d(TAG, "Camera reinitialized at $lower, retrying recording")
                                            startRecordingInternal(
                                                params?.maxDurationMs,
                                                params?.useCache ?: true,
                                                params?.outputDirectory,
                                                savedCallback
                                            )
                                        }
                                    }
                                    return@start
                                }

                                // No more fallback options — report failure
                                startRecordingCallback?.let { startCallback ->
                                    DivineCameraLog.w(TAG, "Recording stopped before first keyframe - no more quality fallbacks")
                                    startCallback("Recording stopped before first keyframe")
                                    startRecordingCallback = null
                                }
                            } else {
                                // Normal finalize — either successful or user-stopped
                                startRecordingCallback?.let { startCallback ->
                                    DivineCameraLog.w(TAG, "Recording stopped before first keyframe - notifying Flutter")
                                    startCallback("Recording stopped before first keyframe")
                                    startRecordingCallback = null
                                }
                            }

                            // Build the result map once
                            val file = currentRecordingFile
                            val result = if (file != null && file.exists() && file.length() > 0) {
                                val duration = System.currentTimeMillis() - recordingStartTime
                                mapOf(
                                    "filePath" to file.absolutePath,
                                    "durationMs" to duration.toInt(),
                                    "width" to videoWidth,
                                    "height" to videoHeight
                                )
                            } else null

                            // Handle manual stop callback (from stopRecording)
                            manualStopCallback?.let { manualCallback ->
                                if (result != null) {
                                    DivineCameraLog.d(TAG, "Manual stop recording result: $result")
                                    manualCallback(result, null)
                                } else {
                                    DivineCameraLog.w(TAG, "Manual stop: Recording file not found or empty")
                                    manualCallback(null, "Recording file not found or empty")
                                }
                                manualStopCallback = null
                            }

                            // Handle auto-stop callback (from max duration)
                            autoStopCallback?.let { autoCallback ->
                                if (result != null) {
                                    DivineCameraLog.d(TAG, "Auto-stop recording result: $result")
                                    autoCallback(result, null)
                                } else {
                                    autoCallback(null, "Recording file not found")
                                }
                                autoStopCallback = null
                            }

                            currentRecordingFile = null
                            recording = null
                        }
                    }
                }
            // Callback is now called in Status event when recording truly starts

        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Failed to start recording", e)
            startRecordingCallback = null
            callback("Failed to start recording: ${e.message}")
        }
    }

    /**
     * Auto-stops recording when max duration is reached.
     * This is called internally and notifies Flutter via method channel.
     */
    private fun autoStopRecording() {
        val currentRecording = recording

        if (currentRecording == null || !isRecording) {
            return
        }

        DivineCameraLog.d(TAG, "Auto-stopping recording...")
        
        // Disable auto-flash torch if it was enabled
        disableAutoFlashTorch()

        // Set the callback that will be invoked when Finalize event fires
        autoStopCallback = { result, error ->
            if (result != null) {
                DivineCameraLog.d(TAG, "Auto-stop completed, notifying listener: $result")
            } else {
                DivineCameraLog.error(
                    "Auto-stop finished with nothing to save: $error",
                    name = "DivineCamera.Recording"
                )
            }
            // Sent even when nothing was saved: an empty map has no filePath,
            // which tells Dart the recording is over (#9261).
            onAutoStopListener?.invoke(result ?: emptyMap())
        }

        currentRecording.stop()
        // The Finalize event will handle the callback via autoStopCallback
    }

    // Callback for manual stop recording - will be invoked when Finalize event fires
    private var manualStopCallback: ((Map<String, Any?>?, String?) -> Unit)? = null

    /**
     * Stops video recording and returns the result.
     * Waits for the Finalize event to ensure the file is fully written.
     */
    fun stopRecording(callback: (Map<String, Any?>?, String?) -> Unit) {
        val currentRecording = recording

        if (currentRecording == null || !isRecording) {
            callback(null, "Not recording")
            return
        }

        // If recording hasn't truly started yet (no keyframe), we need to handle this
        if (!recordingTrulyStarted) {
            DivineCameraLog.w(TAG, "Stopping recording before first keyframe - will return empty result")
            // The startRecordingCallback will be notified via Finalize event
            // We still need to call manualStopCallback, but it will get null result
        }

        try {
            DivineCameraLog.d(TAG, "Stopping recording...")
            
            // Disable auto-flash torch if it was enabled
            disableAutoFlashTorch()
            // Store callback to be invoked when Finalize event fires
            manualStopCallback = callback
            
            currentRecording.stop()
            // The Finalize event handler will call the callback when file is ready

        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Failed to stop recording", e)
            manualStopCallback = null
            callback(null, "Failed to stop recording: ${e.message}")
        }
    }

    /**
     * Pauses the camera preview.
     *
     * With [releaseCamera] the use cases are unbound, which closes the camera
     * and stops the capture stream, so a recorder screen that stays in the
     * foreground without a preview (the Upload tab) stops burning the sensor,
     * the ISP and the battery, and the OS camera indicator goes out. A
     * transient interruption (`releaseCamera = false`, e.g. the notification
     * shade) keeps the camera running: rebinding costs a visible restart on
     * every pull.
     *
     * A recording in progress is never interrupted — the pause is skipped.
     */
    fun pausePreview(releaseCamera: Boolean = true) {
        DivineCameraLog.d(TAG, "Pausing preview (releaseCamera=$releaseCamera)")
        forceDisableScreenFlash()
        if (!releaseCamera || isPaused) return
        if (isRecording || recording != null) {
            DivineCameraLog.d(TAG, "Recording in progress — keeping the camera bound")
            return
        }
        val provider = cameraProvider ?: return
        if (camera == null) return
        try {
            provider.unbindAll()
            isPaused = true
        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Failed to unbind camera for pause", e)
        }
    }

    /**
     * Resumes the camera preview, rebinding the use cases a releasing
     * [pausePreview] unbound. The preview keeps its Flutter texture, so the
     * Dart side needs no rebuild; zoom and torch are restored because
     * reopening the camera resets both.
     */
    fun resumePreview(callback: (Map<String, Any?>?, String?) -> Unit) {
        DivineCameraLog.d(TAG, "Resuming preview")

        // Re-enable screen flash if front camera torch mode was active
        if (currentLens == CameraSelector.LENS_FACING_FRONT && isTorchEnabled) {
            enableScreenFlash()
        }

        val provider = cameraProvider
        if (provider == null || camera == null) {
            isPaused = false
            callback(null, "Camera not initialized")
            return
        }

        if (isPaused) {
            try {
                rebindAfterPause(provider)
            } catch (e: Exception) {
                DivineCameraLog.e(TAG, "Failed to rebind camera on resume", e)
                callback(null, "Failed to resume preview: ${e.message}")
                return
            }
        }
        callback(getCameraState(), null)
    }

    /**
     * Binds the existing use cases again after a releasing [pausePreview].
     * Clears [isPaused] only once the bind succeeded, so a failed resume can
     * be retried.
     */
    private fun rebindAfterPause(provider: ProcessCameraProvider) {
        val owner = activity as LifecycleOwner
        val selector = buildCameraSelectorForLens(currentLensType, provider)
        val photo = imageCapture
        val bound = if (photo != null) {
            provider.bindToLifecycle(owner, selector, preview, videoCapture, photo)
        } else {
            provider.bindToLifecycle(owner, selector, preview, videoCapture)
        }
        camera = bound
        isPaused = false

        if (currentZoom != 1.0f) {
            bound.cameraControl.setZoomRatio(currentZoom)
        }
        if (isTorchEnabled && currentLens != CameraSelector.LENS_FACING_FRONT) {
            bound.cameraControl.enableTorch(true)
        }
        DivineCameraLog.d(TAG, "Camera rebound after pause")
    }

    // SENSOR_ORIENTATION is immutable per camera id, so cache it and avoid a
    // fresh getCameraCharacteristics() lookup on every getCameraState() call.
    private val sensorOrientationByCameraId = mutableMapOf<String, Int>()

    /**
     * Reads the clockwise sensor orientation (degrees) of the current lens.
     * The recorder is portrait-locked, so this doubles as the rotation the UI
     * must apply to the preview when the surface producer does not rotate it.
     * Returns 0 if the characteristic is unavailable.
     */
    private fun currentSensorOrientation(): Int {
        return try {
            val cameraId = getCameraIdForLens(currentLensType) ?: return 0
            sensorOrientationByCameraId.getOrPut(cameraId) {
                val cameraManager =
                    context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                cameraManager
                    .getCameraCharacteristics(cameraId)
                    .get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
            }
        } catch (e: Exception) {
            DivineCameraLog.w(TAG, "Failed to read sensor orientation: ${e.message}")
            0
        }
    }

    /**
     * Gets the current camera state as a map.
     */
    fun getCameraState(): MutableMap<String, Any?> {
        val textureId = surfaceProducer?.id() ?: -1L
        // When the surface producer applies its transform matrix itself (the
        // API<29 SurfaceTexture path), that matrix already carries both the
        // preview rotation and the front-camera mirror, so Flutter must apply
        // neither. Otherwise (API 29+ ImageReader path) frames arrive raw and
        // the UI reconstructs both (issue #5865).
        val handlesTransform = surfaceProducer?.handlesCropAndRotation() == true
        val previewRotation =
            if (handlesTransform) 0 else currentSensorOrientation()
        val stabilizationModes = availableVideoStabilizationModesForCurrentLens()
        return mutableMapOf(
            "isInitialized" to (camera != null),
            "isRecording" to isRecording,
            "flashMode" to getFlashModeString(),
            "lens" to currentLensType,
            "zoomLevel" to (if (autoLensSwitchEnabled) virtualCurrentZoom else currentZoom).toDouble(),
            "minZoomLevel" to (if (autoLensSwitchEnabled) virtualMinZoom
                else if (!autoLensSwitchRequested && minZoom < 1.0f) 1.0f
                else minZoom).toDouble(),
            "maxZoomLevel" to (if (autoLensSwitchEnabled) virtualMaxZoom else maxZoom).toDouble(),
            "aspectRatio" to aspectRatio.toDouble(),
            "hasFlash" to hasFlash,
            "hasFrontCamera" to hasFrontCamera,
            "hasBackCamera" to hasBackCamera,
            "isFocusPointSupported" to isFocusPointSupported,
            "isExposurePointSupported" to isExposurePointSupported,
            "textureId" to textureId,
            "previewRotationDegrees" to previewRotation,
            "previewHandlesTransform" to handlesTransform,
            "availableLenses" to getAvailableLenses(),
            "currentLensMetadata" to getCurrentLensMetadata(),
            "videoStabilizationMode" to requestedStabilizationMode,
            "availableVideoStabilizationModes" to stabilizationModes,
            "isVideoStabilizationSupported" to (stabilizationModes.size > 1)
        )
    }

    /**
     * Gets the current flash mode as a string.
     */
    private fun getFlashModeString(): String {
        if (isTorchEnabled) return "torch"
        return when (currentFlashMode) {
            ImageCapture.FLASH_MODE_OFF -> "off"
            ImageCapture.FLASH_MODE_AUTO -> "auto"
            ImageCapture.FLASH_MODE_ON -> "on"
            else -> "off"
        }
    }

    /**
     * Releases all camera resources.
     */
    fun release() {
        DivineCameraLog.d(TAG, "Releasing camera resources")
        
        // Always restore screen brightness
        forceDisableScreenFlash()
        
        try {
            recording?.stop()
            recording = null
            isRecording = false

            cameraProvider?.unbindAll()
            cameraProvider = null
            camera = null
            preview = null
            videoCapture = null

            // The SurfaceProducer owns the Surface; release() tears it down.
            surfaceProducer?.release()
            surfaceProducer = null
            retiringSurfaceProducer?.release()
            retiringSurfaceProducer = null

            // Delay shutdown so CameraX can drain in-flight encoder/muxer
            // tasks. cameraExecutor is rejection-tolerant, so any callback
            // that still arrives after shutdown is dropped, not crashed.
            if (!cameraExecutor.isShutdown) {
                mainHandler.postDelayed({
                    try {
                        if (!cameraExecutor.isShutdown) {
                            cameraExecutor.shutdown()
                        }
                    } catch (e: Exception) {
                        DivineCameraLog.w(TAG, "Error shutting down executor: ${e.message}")
                    }
                }, 500)
            }
        } catch (e: Exception) {
            DivineCameraLog.e(TAG, "Error releasing camera", e)
        }
    }
}
