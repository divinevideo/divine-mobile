package co.openvine.divine_camera

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
            )
        )

        assertTrue(map.getBoolean("available"))
        assertEquals(2500L, map.getLong("recordedMs"))
        assertEquals(1_800_000_000_000L, map.getLong("activeTakeStartedAtMs"))
        assertEquals(6300L, map.getLong("budgetMs"))
        assertEquals("Capture", map.getString("modeName"))
        assertTrue(map.getBoolean("shutterActive"))
        assertFalse(map.getBoolean("shutterEnabled", true))
        assertEquals(3, map.getInt("stillShutterCount"))
    }

    @Test
    fun recorderDataMap_leavesOutTheStartOfATakeThatIsNotRunning() {
        val map = WearRemoteProtocol.recorderDataMap(
            mapOf("recordedMs" to 0, "activeTakeStartedAtMs" to null)
        )

        assertTrue(map.getBoolean("available"))
        assertFalse(map.containsKey("activeTakeStartedAtMs"))
    }

    @Test
    fun recorderDataMap_forAClosedRecorder_saysOnlyThatItIsClosed() {
        val map = WearRemoteProtocol.recorderDataMap(null)

        assertEquals(setOf("available"), map.keySet())
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

    @Test
    fun shutterAction_acceptsOnlyTheWatchActions() {
        assertEquals("watchStart", WearRemoteProtocol.shutterAction("watchStart".toByteArray()))
        assertEquals("watchStop", WearRemoteProtocol.shutterAction("watchStop".toByteArray()))
        assertNull(WearRemoteProtocol.shutterAction("volumeUp".toByteArray()))
        assertNull(WearRemoteProtocol.shutterAction(ByteArray(0)))
    }
}
