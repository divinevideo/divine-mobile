package co.openvine.divine_camera

import android.app.Activity
import android.content.Context
import android.hardware.camera2.CameraMetadata
import androidx.camera.video.Quality
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

@RunWith(RobolectricTestRunner::class)
internal class DivineCameraPluginTest {
    @Test
    fun onMethodCall_getPlatformVersion_returnsExpectedValue() {
        val plugin = DivineCameraPlugin()

        val call = MethodCall("getPlatformVersion", null)
        val result = RecordingResult()
        plugin.onMethodCall(call, result)

        assertEquals(1, result.successCount)
        assertEquals("Android " + android.os.Build.VERSION.RELEASE, result.lastSuccessValue)
        assertEquals(0, result.errorCount)
        assertEquals(0, result.notImplementedCount)
    }

    @Test
    fun onMethodCall_audioCaptureSuspension_answersWithoutACamera() {
        // CameraX opens the mic per recording, so both calls are no-ops on
        // Android — but they must still answer, or Dart would surface a
        // MissingPluginException in the middle of every countdown.
        val plugin = DivineCameraPlugin()

        for (method in listOf("suspendAudioCapture", "resumeAudioCapture")) {
            val result = RecordingResult()
            plugin.onMethodCall(MethodCall(method, null), result)

            assertEquals(1, result.successCount, method)
            assertNull(result.lastSuccessValue, method)
            assertEquals(0, result.errorCount, method)
            assertEquals(0, result.notImplementedCount, method)
        }
    }

    @Test
    fun oneShotResult_initializeStyleFlow_answersFlutterOnlyOnce() {
        val result = RecordingResult()
        val oneShot = OneShotMethodResult(result)

        oneShot.success(mapOf("textureId" to 42L))
        oneShot.error("INIT_ERROR", "late failure", null)

        assertEquals(1, result.successCount)
        assertEquals(mapOf("textureId" to 42L), result.lastSuccessValue)
        assertEquals(0, result.errorCount)
        assertEquals(0, result.notImplementedCount)
    }

    @Test
    fun oneShotResult_switchStyleFlow_answersFlutterOnlyOnce() {
        val result = RecordingResult()
        val oneShot = OneShotMethodResult(result)

        oneShot.error("SWITCH_ERROR", "first failure", null)
        oneShot.success(mapOf("camera" to "back"))

        assertEquals(0, result.successCount)
        assertEquals(1, result.errorCount)
        assertEquals("SWITCH_ERROR", result.lastErrorCode)
        assertEquals("first failure", result.lastErrorMessage)
        assertEquals(0, result.notImplementedCount)
    }

    @Test
    fun oneShotResult_recordStyleFlow_answersFlutterOnlyOnce() {
        val result = RecordingResult()
        val oneShot = OneShotMethodResult(result)

        oneShot.success(null)
        oneShot.success(mapOf("filePath" to "/tmp/video.mp4"))

        assertEquals(1, result.successCount)
        assertNull(result.lastSuccessValue)
        assertEquals(0, result.errorCount)
        assertEquals(0, result.notImplementedCount)
    }

    private class RecordingResult : MethodChannel.Result {
        var successCount: Int = 0
            private set
        var errorCount: Int = 0
            private set
        var notImplementedCount: Int = 0
            private set
        var lastSuccessValue: Any? = null
            private set
        var lastErrorCode: String? = null
            private set
        var lastErrorMessage: String? = null
            private set
        var lastErrorDetails: Any? = null
            private set

        override fun success(result: Any?) {
            successCount += 1
            lastSuccessValue = result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            errorCount += 1
            lastErrorCode = errorCode
            lastErrorMessage = errorMessage
            lastErrorDetails = errorDetails
        }

        override fun notImplemented() {
            notImplementedCount += 1
        }
    }
}

/**
 * Verifies that the process-wide [DivineCameraLog.sink] is owned by the UI
 * engine and bound to the Activity attachment lifecycle, so a background
 * FlutterEngine (e.g. the FCM isolate that runs GeneratedPluginRegistrant)
 * can never own camera diagnostics — not even transiently for a native-only
 * event such as a volume-key callback. Regression coverage for #5128.
 */
@RunWith(RobolectricTestRunner::class)
internal class DivineCameraLogSinkOwnershipTest {
    @Before
    fun resetBefore() {
        DivineCameraLog.sink = null
    }

    @After
    fun resetAfter() {
        DivineCameraLog.sink = null
    }

    private fun engineBinding(): FlutterPlugin.FlutterPluginBinding {
        val binding = Mockito.mock(FlutterPlugin.FlutterPluginBinding::class.java)
        Mockito.`when`(binding.binaryMessenger)
            .thenReturn(Mockito.mock(BinaryMessenger::class.java))
        Mockito.`when`(binding.applicationContext)
            .thenReturn(Mockito.mock(Context::class.java))
        Mockito.`when`(binding.textureRegistry)
            .thenReturn(Mockito.mock(TextureRegistry::class.java))
        return binding
    }

    private fun activityBinding(): ActivityPluginBinding {
        val binding = Mockito.mock(ActivityPluginBinding::class.java)
        Mockito.`when`(binding.activity).thenReturn(Mockito.mock(Activity::class.java))
        return binding
    }

    @Test
    fun attachingToEngine_doesNotClaimSink() {
        val plugin = DivineCameraPlugin()
        plugin.onAttachedToEngine(engineBinding())

        // Engine attachment alone (the only lifecycle a background engine
        // reaches) must not install the sink.
        assertNull(DivineCameraLog.sink)
    }

    @Test
    fun attachingToActivity_claimsSink() {
        val plugin = DivineCameraPlugin()
        plugin.onAttachedToEngine(engineBinding())
        // Guard the actual transition the fix introduces: engine attachment
        // alone must NOT claim the sink (the old behavior claimed it here, so
        // this assertion is what makes the test discriminate the fix).
        assertNull(DivineCameraLog.sink)

        plugin.onAttachedToActivity(activityBinding())

        // Only Activity attachment installs the sink.
        assertNotNull(DivineCameraLog.sink)
    }

    @Test
    fun backgroundEngineAttach_cannotStealUiOwnership() {
        val ui = DivineCameraPlugin()
        ui.onAttachedToEngine(engineBinding())
        ui.onAttachedToActivity(activityBinding())
        val uiSink = DivineCameraLog.sink
        assertNotNull(uiSink)

        // A second engine that only ever attaches to the engine (never an
        // Activity) must not overwrite the UI engine's sink.
        val background = DivineCameraPlugin()
        background.onAttachedToEngine(engineBinding())

        assertSame(uiSink, DivineCameraLog.sink)
    }

    @Test
    fun detachFromActivity_relinquishesOwnedSink() {
        val ui = DivineCameraPlugin()
        ui.onAttachedToEngine(engineBinding())
        ui.onAttachedToActivity(activityBinding())
        assertNotNull(DivineCameraLog.sink)

        ui.onDetachedFromActivity()

        assertNull(DivineCameraLog.sink)
    }

    @Test
    fun detachFromActivity_doesNotClearAnotherOwnersSink() {
        val ui = DivineCameraPlugin()
        ui.onAttachedToEngine(engineBinding())
        ui.onAttachedToActivity(activityBinding())
        val uiSink = DivineCameraLog.sink
        assertNotNull(uiSink)

        // A different instance that never owned the sink must not be able to
        // clear it on teardown.
        val other = DivineCameraPlugin()
        other.onAttachedToEngine(engineBinding())
        other.onDetachedFromActivity()

        assertSame(uiSink, DivineCameraLog.sink)
    }

    @Test
    fun configChangeDetach_keepsSink() {
        val ui = DivineCameraPlugin()
        ui.onAttachedToEngine(engineBinding())
        ui.onAttachedToActivity(activityBinding())
        val uiSink = DivineCameraLog.sink
        assertNotNull(uiSink)

        ui.onDetachedFromActivityForConfigChanges()

        // The engine and its channel survive a config change, so the sink
        // stays installed across it.
        assertSame(uiSink, DivineCameraLog.sink)
    }

    @Test
    fun reattachAfterConfigChange_reclaimsSink() {
        val ui = DivineCameraPlugin()
        ui.onAttachedToEngine(engineBinding())
        ui.onAttachedToActivity(activityBinding())
        val uiSink = DivineCameraLog.sink
        assertNotNull(uiSink)

        ui.onDetachedFromActivityForConfigChanges()
        // Simulate the sink being lost while detached, then prove reattach
        // restores UI ownership.
        DivineCameraLog.sink = null
        ui.onReattachedToActivityForConfigChanges(activityBinding())

        assertSame(uiSink, DivineCameraLog.sink)
    }
}

@RunWith(RobolectricTestRunner::class)
internal class QualityFallbackTest {
    @Test
    fun lowerQuality_fromUHD_returnsFHD() {
        assertEquals(Quality.FHD, CameraController.lowerQuality(Quality.UHD))
    }

    @Test
    fun lowerQuality_fromFHD_returnsHD() {
        assertEquals(Quality.HD, CameraController.lowerQuality(Quality.FHD))
    }

    @Test
    fun lowerQuality_fromHIGHEST_returnsFHD() {
        assertEquals(Quality.FHD, CameraController.lowerQuality(Quality.HIGHEST))
    }

    @Test
    fun lowerQuality_fromHD_returnsSD() {
        assertEquals(Quality.SD, CameraController.lowerQuality(Quality.HD))
    }

    @Test
    fun lowerQuality_fromSD_returnsNull() {
        assertNull(CameraController.lowerQuality(Quality.SD))
    }

    @Test
    fun lowerQuality_fromLOWEST_returnsNull() {
        assertNull(CameraController.lowerQuality(Quality.LOWEST))
    }

    @Test
    fun fullFallbackChain_coversThreeSteps() {
        var quality: Quality? = Quality.UHD
        val chain = mutableListOf<Quality>()
        while (quality != null) {
            chain.add(quality)
            quality = CameraController.lowerQuality(quality)
        }
        assertEquals(
            listOf(Quality.UHD, Quality.FHD, Quality.HD, Quality.SD),
            chain
        )
    }
}

@RunWith(RobolectricTestRunner::class)
internal class VideoStabilizationTest {
    private val off = CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_OFF
    private val on = CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_ON
    private val preview =
        CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_PREVIEW_STABILIZATION

    @Test
    fun isCanonicalStabilizationMode_recognisesKnownModes() {
        assertTrue(CameraController.isCanonicalStabilizationMode("off"))
        assertTrue(CameraController.isCanonicalStabilizationMode("standard"))
        assertTrue(CameraController.isCanonicalStabilizationMode("cinematic"))
        assertTrue(
            CameraController.isCanonicalStabilizationMode("cinematicExtended")
        )
        assertTrue(
            CameraController.isCanonicalStabilizationMode("previewOptimized")
        )
        assertTrue(CameraController.isCanonicalStabilizationMode("lowLatency"))
        assertTrue(CameraController.isCanonicalStabilizationMode("auto"))
        assertFalse(CameraController.isCanonicalStabilizationMode("bogus"))
    }

    @Test
    fun buildList_noSupport_onlyOff() {
        assertEquals(
            listOf("off"),
            CameraController.buildStabilizationModeList(
                onSupported = false,
                previewStabilizationSupported = false,
            ),
        )
    }

    @Test
    fun buildList_onlyBasicEis_addsStandard() {
        assertEquals(
            listOf("off", "standard"),
            CameraController.buildStabilizationModeList(
                onSupported = true,
                previewStabilizationSupported = false,
            ),
        )
    }

    @Test
    fun buildList_previewSupported_addsStandardAndCinematic() {
        // cinematicExtended/auto are omitted on Android: they map to the same
        // PREVIEW_STABILIZATION as "cinematic".
        assertEquals(
            listOf("off", "standard", "cinematic"),
            CameraController.buildStabilizationModeList(
                onSupported = true,
                previewStabilizationSupported = true,
            ),
        )
    }

    @Test
    fun buildList_previewOnly_addsCinematic() {
        assertEquals(
            listOf("off", "cinematic"),
            CameraController.buildStabilizationModeList(
                onSupported = false,
                previewStabilizationSupported = true,
            ),
        )
    }

    @Test
    fun availableModes_nullCapabilities_onlyOff() {
        assertEquals(
            listOf("off"),
            CameraController.availableVideoStabilizationModes(null),
        )
    }

    @Test
    fun availableModes_onSupported_addsStandard() {
        assertEquals(
            listOf("off", "standard"),
            CameraController.availableVideoStabilizationModes(
                intArrayOf(off, on),
            ),
        )
    }

    @Test
    fun availableModes_previewSupported_addsCinematic() {
        assertEquals(
            listOf("off", "standard", "cinematic"),
            CameraController.availableVideoStabilizationModes(
                intArrayOf(off, on, preview),
            ),
        )
    }
}

// Pure decision logic with no Android framework dependency, so it runs on
// the plain JUnit runner rather than Robolectric.
internal class SurfaceProvisionTest {
    @Test
    fun texturePresent_createsFromProducer() {
        // The surface is always re-fetched from the producer so a cross-lens
        // setSize() resolution change is picked up instead of stranding the
        // preview on the previous lens's reader.
        assertEquals(
            SurfaceProvision.CREATE,
            CameraController.decideSurfaceProvision(hasTexture = true),
        )
    }

    @Test
    fun noTexture_declinesInsteadOfBuildingFromNull() {
        // Regression for the "surfaceTexture must not be null" crash: when the
        // Flutter texture was released before the surface request lands, the
        // request must be declined, never turned into Surface(null).
        assertEquals(
            SurfaceProvision.DECLINE,
            CameraController.decideSurfaceProvision(hasTexture = false),
        )
    }
}

@RunWith(RobolectricTestRunner::class)
internal class RejectionTolerantExecutorServiceTest {
    @Test
    fun execute_beforeShutdown_runsTaskOnDelegate() {
        val executor =
            RejectionTolerantExecutorService(Executors.newSingleThreadExecutor())
        val latch = CountDownLatch(1)

        executor.execute { latch.countDown() }

        assertTrue(latch.await(2, TimeUnit.SECONDS))
        executor.shutdown()
    }

    @Test
    fun execute_afterShutdown_dropsTaskWithoutThrowing() {
        // Regression for the encoder-teardown RejectedExecutionException: a
        // MediaCodec callback that posts after release()'s shutdown must be
        // dropped, not crash on the codec thread.
        val executor =
            RejectionTolerantExecutorService(Executors.newSingleThreadExecutor())
        executor.shutdown()
        assertTrue(executor.isShutdown)

        val ran = AtomicBoolean(false)
        executor.execute { ran.set(true) }

        assertFalse(ran.get())
    }

    @Test
    fun lifecycleMethods_delegateToWrappedExecutor() {
        val executor =
            RejectionTolerantExecutorService(Executors.newSingleThreadExecutor())
        assertFalse(executor.isShutdown)

        executor.shutdown()

        assertTrue(executor.isShutdown)
        assertTrue(executor.awaitTermination(2, TimeUnit.SECONDS))
        assertTrue(executor.isTerminated)
    }
}
