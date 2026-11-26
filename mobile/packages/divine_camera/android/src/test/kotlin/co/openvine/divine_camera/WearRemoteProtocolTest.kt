package co.openvine.divine_camera

import com.google.android.gms.wearable.DataMap
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The recorder state Dart sends must reach the Wear OS remote with every key
 * the watch reads, in a form a data map can hold.
 */
@RunWith(RobolectricTestRunner::class)
internal class WearRemoteProtocolTest {
    @Test
    fun recorderDataMap_carriesTheRecorderState() {
        // Method channels deliver small Dart ints as Int and epoch
        // milliseconds as Long.
        val map = WearRemoteProtocol.recorderDataMap(
            mapOf(
                "recordedMs" to 2500,
                "activeTakeStartedAtMs" to 1_800_000_000_000L,
                "budgetMs" to 6300,
                "modeName" to "Capture",
                "shutterActive" to true,
                "shutterEnabled" to false,
                "stillShutterCount" to 3,
            ),
            revision = 1_800_000_000_123L,
        )

        assertEquals(1_800_000_000_123L, map.getLong("revision"))
        assertTrue(map.getBoolean("available"))
        assertEquals(2500L, map.getLong("recordedMs"))
        assertEquals(1_800_000_000_000L, map.getLong("activeTakeStartedAtMs"))
        assertEquals(6300L, map.getLong("budgetMs"))
        assertEquals("Capture", map.getString("modeName"))
        assertTrue(map.getBoolean("shutterActive"))
        assertFalse(map.getBoolean("shutterEnabled", true))
        assertEquals(3, map.getInt("stillShutterCount"))
    }

    // Dart's number stays on the phone: the watch orders states by revision.
    @Test
    fun stateId_isReadFromDartsStateButNotSentToTheWatch() {
        val state = mapOf("recordedMs" to 0, "stateId" to 12)

        assertEquals(12L, WearRemoteProtocol.stateId(state))
        assertNull(WearRemoteProtocol.stateId(null))
        assertFalse(WearRemoteProtocol.recorderDataMap(state, revision = 1).containsKey("stateId"))
    }

    @Test
    fun recorderDataMap_leavesOutTheStartOfATakeThatIsNotRunning() {
        val map = WearRemoteProtocol.recorderDataMap(
            mapOf("recordedMs" to 0, "activeTakeStartedAtMs" to null),
            revision = 1,
        )

        assertTrue(map.getBoolean("available"))
        assertFalse(map.containsKey("activeTakeStartedAtMs"))
    }

    @Test
    fun recorderDataMap_forAClosedRecorder_saysOnlyThatItIsClosed() {
        val map = WearRemoteProtocol.recorderDataMap(null, revision = 7)

        assertEquals(setOf("available", "revision"), map.keySet())
        assertFalse(map.getBoolean("available", true))
    }

    // The watch looks the phone up by this capability; a typo in the
    // resource leaves every press unanswered.
    @Test
    fun phoneCapability_isDeclaredForTheDataLayer() {
        val declared = RuntimeEnvironment.getApplication().resources
            .getStringArray(R.array.android_wear_capabilities)

        assertEquals(listOf(WearRemoteProtocol.PHONE_CAPABILITY), declared.toList())
    }

    // A restarted app must publish above what the watch still shows from the
    // run before, or the watch would keep the old state.
    @Test
    fun nextRevision_staysAboveAnEarlierRun() {
        assertEquals(5_001L, WearRemoteProtocol.nextRevision(previous = 5_000, nowMs = 4_000))
        assertEquals(9_000L, WearRemoteProtocol.nextRevision(previous = 5_000, nowMs = 9_000))
    }

    @Test
    fun shutterPress_readsTheActionAndTheStateItWasMadeOn() {
        assertEquals(
            WearRemoteProtocol.ShutterPress("watchStop", 42),
            WearRemoteProtocol.shutterPress(press(action = "watchStop", revision = 42)),
        )
        assertEquals("watchStart", WearRemoteProtocol.shutterPress(press("watchStart", 1))?.action)
    }

    @Test
    fun shutterPress_refusesAnythingButAWatchActionOnAKnownState() {
        assertNull(WearRemoteProtocol.shutterPress(press(action = "volumeUp", revision = 1)))
        assertNull(WearRemoteProtocol.shutterPress(press(action = "watchStop", revision = null)))
        // The action alone does not say which take it was meant for.
        assertNull(WearRemoteProtocol.shutterPress("watchStop".toByteArray()))
        assertNull(WearRemoteProtocol.shutterPress(ByteArray(0)))
    }

    @Test
    fun helloAnswer_carriesTheStateAndRepeatsTheHello() {
        val state = WearRemoteProtocol.recorderDataMap(null, revision = 3)
        val hello = DataMap().apply { putLong("helloId", 99) }.toByteArray()

        val answer = WearRemoteProtocol.helloAnswer(state, hello)

        assertEquals(99L, answer.getLong("helloId"))
        assertEquals(3L, answer.getLong("revision"))
        assertFalse(answer.getBoolean("available", true))
    }

    private fun press(action: String, revision: Long?): ByteArray = DataMap().apply {
        putString("action", action)
        revision?.let { putLong("revision", it) }
    }.toByteArray()
}
