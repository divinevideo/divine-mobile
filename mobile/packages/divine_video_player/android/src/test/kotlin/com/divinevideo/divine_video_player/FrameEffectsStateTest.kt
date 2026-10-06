package com.divinevideo.divine_video_player

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Which frame effects are on at a position on the player's timeline. */
class FrameEffectsStateTest {

    private fun config(startMs: Long?, endMs: Long?) =
        FrameEffectsState.Config(id = "effect", params = emptyMap(), startMs = startMs, endMs = endMs)

    private fun stateOf(vararg configs: FrameEffectsState.Config) =
        FrameEffectsState().also { it.setConfigs(configs.toList()) }

    @Test
    fun `a window opens at its start and closes before its end`() {
        val state = stateOf(config(1_050, 1_150))

        assertArrayEquals(booleanArrayOf(false), state.enabledAt(1_049))
        assertArrayEquals(booleanArrayOf(true), state.enabledAt(1_050))
        assertArrayEquals(booleanArrayOf(true), state.enabledAt(1_149))
        assertArrayEquals(booleanArrayOf(false), state.enabledAt(1_150))
    }

    @Test
    fun `a window shorter than a position update is only seen by checking every frame`() {
        val state = stateOf(config(1_050, 1_150))

        // Position updates 200 ms apart land either side of the window.
        assertTrue(listOf(1_000L, 1_200L).none { state.enabledAt(it)[0] })
        // Checked once a frame, some check lands inside it.
        assertTrue((1_000L..1_200L step 16L).any { state.enabledAt(it)[0] })
    }

    @Test
    fun `an open bound never closes that side of the window`() {
        val state = stateOf(config(null, 500), config(500, null), config(null, null))

        assertArrayEquals(booleanArrayOf(true, false, true), state.enabledAt(499))
        assertArrayEquals(booleanArrayOf(false, true, true), state.enabledAt(500))
    }

    @Test
    fun `only an effect with a bound has a window`() {
        assertFalse(stateOf().hasWindows)
        assertFalse(stateOf(config(null, null)).hasWindows)
        assertTrue(stateOf(config(null, null), config(10, null)).hasWindows)
        assertTrue(stateOf(config(null, 10)).hasWindows)
    }
}
