package co.openvine.app.wear

import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class RemoteProtocolTest {
    @Test
    fun snapshot_readsWhatThePhoneSent() {
        val recorder = RemoteProtocol.snapshot(
            mapOf(
                "available" to true,
                "recordedMs" to 2_500L,
                "activeTakeStartedAtMs" to 1_800_000_000_000L,
                "budgetMs" to 4_000L,
                "modeName" to "Stop Motion",
                "shutterActive" to true,
                "shutterEnabled" to false,
                "stillShutterCount" to 7,
            )
        )

        assertEquals(
            RecorderSnapshot(
                recordedMs = 2_500,
                activeTakeStartedAtMs = 1_800_000_000_000L,
                budgetMs = 4_000,
                modeName = "Stop Motion",
                isShutterActive = true,
                isShutterEnabled = false,
                stillShutterCount = 7,
            ),
            recorder,
        )
    }

    @Test
    fun snapshot_ofAClosedRecorder_isNull() {
        assertNull(RemoteProtocol.snapshot(mapOf("available" to false, "recordedMs" to 900L)))
        // A deleted data item arrives as no values at all.
        assertNull(RemoteProtocol.snapshot(emptyMap()))
    }

    @Test
    fun snapshot_keepsAnExhaustedBudget() {
        val recorder = RemoteProtocol.snapshot(mapOf("available" to true, "budgetMs" to 0L))

        assertEquals(0, recorder?.budgetMs)
    }

    @Test
    fun snapshot_withoutShutterState_followsTheRunningTake() {
        val running = RemoteProtocol.snapshot(
            mapOf("available" to true, "activeTakeStartedAtMs" to 5L)
        )
        val idle = RemoteProtocol.snapshot(mapOf("available" to true))

        assertTrue(running?.isShutterActive == true)
        assertFalse(idle?.isShutterActive == true)
        assertEquals(RecorderSnapshot.DEFAULT_BUDGET_MS, idle?.budgetMs)
        assertTrue(idle?.isShutterEnabled == true)
    }
}
