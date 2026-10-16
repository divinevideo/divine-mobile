package co.openvine.divine_camera

import android.os.Handler
import android.os.Looper
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import java.time.Duration
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/*
 * A Stop tap that landed within ~150 ms before the recording limit used to
 * stop the take twice: the max-duration timer still fired while CameraX
 * finalized the manual stop, and Finalize handed the one file to both stops,
 * so Dart added the take as two clips (#10194).
 */
@RunWith(RobolectricTestRunner::class)
internal class RecordingStopArbiterTest {
    private val arbiter = RecordingStopArbiter(Handler(Looper.getMainLooper()))
    private val take = mapOf<String, Any?>("filePath" to "/takes/VID_1.mp4")

    private fun advanceMs(ms: Long) {
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms))
    }

    @Test
    fun maxDuration_withoutAStop_reachesTheLimit() {
        var limitReached = false
        arbiter.scheduleMaxDuration(6300) { limitReached = true }

        advanceMs(6300)

        assertTrue(limitReached)
    }

    @Test
    fun manualStopJustBeforeTheLimit_cancelsTheMaxDurationTimer() {
        var limitReached = false
        arbiter.scheduleMaxDuration(6300) { limitReached = true }
        advanceMs(6200)

        assertTrue(arbiter.beginStop { _, _ -> })
        advanceMs(200)

        assertFalse(limitReached)
    }

    @Test
    fun finish_handsTheTakeOnlyToTheStopThatBeganFirst() {
        val manualResults = mutableListOf<Map<String, Any?>?>()
        val autoResults = mutableListOf<Map<String, Any?>?>()

        assertTrue(arbiter.beginStop { result, _ -> manualResults += result })
        assertFalse(arbiter.beginStop { result, _ -> autoResults += result })
        arbiter.finish(take, null)

        assertEquals(listOf<Map<String, Any?>?>(take), manualResults)
        assertTrue(autoResults.isEmpty())
    }

    @Test
    fun finish_letsTheNextRecordingBeStopped() {
        assertFalse(arbiter.isStopping)
        arbiter.beginStop { _, _ -> }
        assertTrue(arbiter.isStopping)
        arbiter.finish(take, null)
        assertFalse(arbiter.isStopping)

        var nextResult: Map<String, Any?>? = null
        assertTrue(arbiter.beginStop { result, _ -> nextResult = result })
        arbiter.finish(take, null)

        assertEquals(take, nextResult)
    }

    @Test
    fun abandonStop_releasesTheRequestedStop() {
        arbiter.beginStop { _, _ -> }
        assertTrue(arbiter.isStopping)

        arbiter.abandonStop()

        assertFalse(arbiter.isStopping)
    }
}
