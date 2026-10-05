package com.divinevideo.divine_video_player

import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class AudioSessionBoostTest {

    private val created = mutableListOf<Pair<Int, AudioSessionBoost.GainEffect>>()
    private lateinit var boost: AudioSessionBoost

    @Before
    fun setUp() {
        created.clear()
        boost = AudioSessionBoost { sessionId ->
            mockk<AudioSessionBoost.GainEffect>(relaxed = true).also { created += sessionId to it }
        }
    }

    @Test
    fun `never puts an effect on session 0, the device output mix`() {
        boost.attach(0)
        boost.setGain(3f)

        assertTrue(created.isEmpty())
    }

    @Test
    fun `creates no effect until a gain above 1 is asked for`() {
        boost.attach(42)
        boost.setGain(1f)

        assertTrue(created.isEmpty())
    }

    @Test
    fun `boosts the attached session by the gain in decibels`() {
        boost.attach(42)
        boost.setGain(3f)

        val (sessionId, effect) = created.single()
        assertEquals(42, sessionId)
        verify { effect.setGainDb(AudioSessionBoost.decibelsOf(3f)) }
        verify { effect.setEnabled(true) }
    }

    @Test
    fun `boosts once the session arrives after the gain`() {
        boost.attach(0)
        boost.setGain(2f)
        boost.attach(42)

        assertEquals(42, created.single().first)
    }

    @Test
    fun `stays on at 0 dB when the gain falls back to 1`() {
        boost.attach(42)
        boost.setGain(2f)
        boost.setGain(1f)

        val effect = created.single().second
        verify { effect.setGainDb(0f) }
        verify(exactly = 0) { effect.setEnabled(false) }
    }

    @Test
    fun `moves to a new session and releases the old effect`() {
        boost.attach(42)
        boost.setGain(2f)
        boost.attach(43)

        assertEquals(listOf(42, 43), created.map { it.first })
        verify { created.first().second.release() }
    }

    @Test
    fun `leaves the audio unboosted when the device refuses the effect`() {
        val refusing = AudioSessionBoost { throw UnsupportedOperationException("no effect") }

        refusing.attach(42)
        refusing.setGain(3f)
    }

    @Test
    fun `splits a volume into the player's part and the boost`() {
        assertEquals(1f, AudioSessionBoost.attenuationOf(2.5f))
        assertEquals(2.5f, AudioSessionBoost.boostOf(2.5f))
        assertEquals(0.4f, AudioSessionBoost.attenuationOf(0.4f))
        assertEquals(1f, AudioSessionBoost.boostOf(0.4f))
        assertEquals(9.54f, AudioSessionBoost.decibelsOf(3f), 0.01f)
    }
}
