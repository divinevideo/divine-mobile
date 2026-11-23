package co.openvine.app.wear

import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ShutterRequestTest {
    @Test
    fun forTap_sendsTheActionTheShutterShows() {
        assertEquals("watchStart", ShutterRequest.forTap(RecorderSnapshot()).command)
        assertEquals(
            "watchStop",
            ShutterRequest.forTap(RecorderSnapshot(isShutterActive = true)).command,
        )
    }

    @Test
    fun aVideoPress_isAnsweredWhenTheShutterFlips() {
        val idle = RecorderSnapshot()
        val request = ShutterRequest.forTap(idle)

        assertFalse(request.isAnsweredBy(idle))
        assertTrue(request.isAnsweredBy(idle.copy(isShutterActive = true)))
    }

    // A still leaves the shutter as it was, so only the count of finished
    // stills tells the watch the phone took it.
    @Test
    fun aStill_isAnsweredOnceThePhoneHasTakenIt() {
        val stopMotion = RecorderSnapshot(modeName = "Stop Motion", stillShutterCount = 3)
        val request = ShutterRequest.forTap(stopMotion)

        assertFalse(request.isAnsweredBy(stopMotion.copy(recordedMs = 100)))
        assertTrue(request.isAnsweredBy(stopMotion.copy(stillShutterCount = 4)))
    }

    @Test
    fun aRecorderThatClosed_answersThePress() {
        assertTrue(ShutterRequest.forTap(RecorderSnapshot()).isAnsweredBy(null))
    }
}
