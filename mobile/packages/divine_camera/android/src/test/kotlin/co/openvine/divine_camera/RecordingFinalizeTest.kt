package co.openvine.divine_camera

import androidx.camera.video.VideoRecordEvent.Finalize
import org.junit.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/*
 * Pins what a CameraX Finalize means for the controller when the app goes to
 * the background mid-recording (#10199): the captured part must reach
 * Flutter, and the Recorder that lost its source must not be reused. Pure
 * decision logic, so it runs on the plain JUnit runner.
 */
internal class RecordingFinalizeTest {
    @Test
    fun unrequestedFinalizeOfAStartedRecording_isReportedToFlutter() {
        assertTrue(
            CameraController.isUnsolicitedFinalize(
                trulyStarted = true,
                stopRequested = false,
            ),
        )
    }

    @Test
    fun requestedStop_reportsThroughItsOwnCallback() {
        assertFalse(
            CameraController.isUnsolicitedFinalize(
                trulyStarted = true,
                stopRequested = true,
            ),
        )
    }

    @Test
    fun recordingThatNeverStarted_reportsThroughTheStartCallback() {
        // Flutter is still waiting on startRecording; reporting a stop too
        // would end a recording it never saw begin.
        assertFalse(
            CameraController.isUnsolicitedFinalize(
                trulyStarted = false,
                stopRequested = false,
            ),
        )
    }

    @Test
    fun lostVideoSourceBeforeFirstFrame_isNotRetriedAsAnEncoderFailure() {
        assertFalse(
            CameraController.shouldRetryStartAtLowerQuality(
                Finalize.ERROR_SOURCE_INACTIVE,
            ),
        )
    }

    @Test
    fun encoderFailureBeforeFirstFrame_isRetriedAtLowerQuality() {
        assertTrue(
            CameraController.shouldRetryStartAtLowerQuality(
                Finalize.ERROR_ENCODING_FAILED,
            ),
        )
        assertTrue(
            CameraController.shouldRetryStartAtLowerQuality(
                Finalize.ERROR_NO_VALID_DATA,
            ),
        )
    }

    @Test
    fun cleanFinalize_isNotRetried() {
        assertFalse(
            CameraController.shouldRetryStartAtLowerQuality(Finalize.ERROR_NONE),
        )
    }

    @Test
    fun currentRecorderThatLostItsSource_isReplaced() {
        assertTrue(
            CameraController.isRecorderUnusableAfterFinalize(
                finalizeError = Finalize.ERROR_SOURCE_INACTIVE,
                isCurrentRecorder = true,
            ),
        )
    }

    @Test
    fun recorderAlreadySwappedOut_isNotReplacedAgain() {
        // A lens switch rebinds with a fresh Recorder before the old one's
        // Finalize lands; replacing again would restart the new camera.
        assertFalse(
            CameraController.isRecorderUnusableAfterFinalize(
                finalizeError = Finalize.ERROR_SOURCE_INACTIVE,
                isCurrentRecorder = false,
            ),
        )
    }

    @Test
    fun recorderStoppedForAnotherReason_isKept() {
        assertFalse(
            CameraController.isRecorderUnusableAfterFinalize(
                finalizeError = Finalize.ERROR_NONE,
                isCurrentRecorder = true,
            ),
        )
    }
}
