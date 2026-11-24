package co.openvine.app.wear

import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class RecorderMirrorTest {
    private val phone = "phone-node"
    private val open = RecorderSnapshot(isShutterActive = true)

    // The data item outlives the phone app: a change can reach the watch
    // after the app is gone, and then no one answers the hello.
    @Test
    fun aDelayedDataChange_staysDisplayOnlyUntilTheHelloTimesOut() {
        val mirror = RecorderMirror()
        mirror.helloStarted(1)
        mirror.helloSent(1, setOf(phone))

        mirror.show(RecorderUpdate(open, revision = 10))

        assertFalse(mirror.isPhoneReachable)
        assertTrue(mirror.helloUnanswered(1))
        assertFalse(mirror.isPhoneReachable)
        assertEquals(open, mirror.recorder)
    }

    @Test
    fun aStoredStateReadFirst_givesWayToTheLiveAnswer() {
        val mirror = RecorderMirror()
        mirror.helloStarted(1)
        mirror.helloSent(1, setOf(phone))

        mirror.show(RecorderUpdate(open, revision = 10))
        mirror.answered(RecorderUpdate(null, revision = 20), helloId = 1, fromNode = phone)

        assertNull(mirror.recorder)
        assertTrue(mirror.isPhoneReachable)
    }

    @Test
    fun aStoredStateReadAfterTheLiveAnswer_doesNotBringBackAnOlderRecorder() {
        val mirror = RecorderMirror()
        mirror.helloStarted(1)
        mirror.helloSent(1, setOf(phone))

        mirror.answered(RecorderUpdate(null, revision = 20), helloId = 1, fromNode = phone)
        mirror.show(RecorderUpdate(open, revision = 10))

        assertNull(mirror.recorder)
        assertNull(mirror.tap())
    }

    @Test
    fun anAnswerToAnEarlierHello_orFromAnotherNode_doesNotMakeThePhoneReachable() {
        val mirror = RecorderMirror()
        mirror.helloStarted(2)
        mirror.helloSent(2, setOf(phone))

        mirror.answered(RecorderUpdate(open, revision = 10), helloId = 1, fromNode = phone)
        mirror.answered(RecorderUpdate(open, revision = 11), helloId = 2, fromNode = "other-node")

        assertFalse(mirror.isPhoneReachable)
        assertTrue(mirror.isAwaitingHello)
    }

    @Test
    fun aTap_namesTheStateItWasMadeOn() {
        val mirror = RecorderMirror()
        mirror.helloStarted(1)
        mirror.helloSent(1, setOf(phone))
        mirror.answered(RecorderUpdate(open, revision = 20), helloId = 1, fromNode = phone)

        val request = mirror.tap()

        assertEquals(ShutterRequest(stops = true, stillShutterCount = 0, revision = 20), request)
        assertEquals(phone, mirror.phoneNodeId)
    }

    @Test
    fun aSentPress_isAnsweredByTheStateItCaused() {
        val mirror = RecorderMirror()
        mirror.show(RecorderUpdate(open, revision = 20))
        val request = mirror.tap()!!
        mirror.sent(request)

        mirror.show(RecorderUpdate(open.copy(isShutterActive = false), revision = 21))

        assertNull(mirror.pending)
        assertFalse(mirror.release(request))
    }
}
