package co.openvine.divine_camera

import android.view.KeyEvent
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * A headset or Bluetooth press while Divine is in the background must not
 * start a recording (#10196): the media session only receives presses while
 * the activity is in the foreground.
 */
@RunWith(RobolectricTestRunner::class)
internal class VolumeKeyHandlerTest {
    private var now = 10_000L
    private val triggers = mutableListOf<String>()

    private fun handler() = VolumeKeyHandler(
        context = RuntimeEnvironment.getApplication(),
        activity = null,
        clock = { now },
    ) { triggers += it }

    // Past the activation cooldown and the debounce, so only the
    // foreground scoping decides whether the press triggers.
    private fun press(handler: VolumeKeyHandler) {
        now += 4_000L
        handler.handleMediaButtonEvent(
            KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
        )
    }

    @Test
    fun mediaButton_whileBackgrounded_doesNotTrigger() {
        val handler = handler()
        handler.enable(appActive = true)
        press(handler)
        assertEquals(listOf("bluetooth"), triggers)

        handler.onEnterBackground()
        press(handler)

        assertFalse(handler.isMediaSessionClaimed())
        assertEquals(listOf("bluetooth"), triggers)

        handler.onBecomeActive()
        press(handler)

        assertEquals(listOf("bluetooth", "bluetooth"), triggers)
    }

    @Test
    fun mediaButton_rightAfterReturning_isIgnored() {
        // A connected headset sends PAUSE when the session reappears; on a
        // Galaxy S26 it arrived up to 640 ms after the claim.
        val handler = handler()
        handler.enable(appActive = true)
        handler.onEnterBackground()
        now += 60_000L
        handler.onBecomeActive()
        assertTrue(handler.isMediaSessionClaimed())
        now += 1_000L

        val consumed = handler.handleMediaButtonEvent(
            KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PAUSE)
        )

        assertTrue(consumed)
        assertTrue(triggers.isEmpty())

        // Positive control: the same press records once the cooldown is over.
        now += 2_000L
        handler.handleMediaButtonEvent(
            KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PAUSE)
        )
        assertEquals(listOf("bluetooth"), triggers)
    }

    @Test
    fun onBecomeActive_afterDisable_leavesTheSessionReleased() {
        val handler = handler()
        handler.enable(appActive = true)
        handler.disable()
        handler.onEnterBackground()

        handler.onBecomeActive()

        assertFalse(handler.isMediaSessionClaimed())
    }
}
