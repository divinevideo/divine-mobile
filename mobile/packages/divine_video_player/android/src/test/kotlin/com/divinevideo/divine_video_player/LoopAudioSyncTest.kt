package com.divinevideo.divine_video_player

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Pins the arithmetic that keeps the Android loop track on the picture.
 *
 * The numbers come from an SM-S942B: a static track's first frame is heard
 * 40–56 ms after `play`, and its counters are cumulative across loop wraps
 * and pauses.
 */
class LoopAudioSyncTest {

    private val sampleRate = 44_100
    private val loopFrames = 278_888L // 6324 ms, a feed clip
    private val t0 = 1_000_000_000L

    @Before
    fun setUp() {
        LoopAudioSync.startLatencyUs = 50_000L
    }

    @After
    fun tearDown() {
        LoopAudioSync.startLatencyUs = 50_000L
    }

    private fun frames(us: Long): Long = us * sampleRate / 1_000_000L

    private fun ms(us: Long): Long = us * 1_000_000L

    @Test
    fun `places the head ahead of the picture by the start latency`() {
        val sync = LoopAudioSync(loopFrames, sampleRate)

        val bufferFrame = sync.anchor(videoPositionUs = 1_000_000L, counterFrame = 0L, nowNanos = t0)

        assertEquals(frames(1_050_000L), bufferFrame)
    }

    @Test
    fun `a sound that comes out on the picture measures in step`() {
        val sync = LoopAudioSync(loopFrames, sampleRate)
        sync.anchor(videoPositionUs = 1_000_000L, counterFrame = 0L, nowNanos = t0)

        // The pipeline took exactly the 50 ms allowed: 150 ms after play the
        // speaker has played 100 ms of the loop, and the picture moved 150.
        val errorUs = sync.errorUs(
            presentedFrame = frames(100_000L),
            presentedNanos = t0 + 150_000_000L,
            videoPositionUs = 1_150_000L,
            nowNanos = t0 + 150_000_000L,
        )!!

        assertTrue("was $errorUs us", kotlin.math.abs(errorUs) < 100)
    }

    @Test
    fun `a pipeline slower than allowed for measures the sound as late`() {
        val sync = LoopAudioSync(loopFrames, sampleRate)
        sync.anchor(videoPositionUs = 1_000_000L, counterFrame = 0L, nowNanos = t0)

        // 80 ms to the speaker instead of 50: the sound is 30 ms behind.
        val errorUs = sync.errorUs(
            presentedFrame = frames(70_000L),
            presentedNanos = t0 + 150_000_000L,
            videoPositionUs = 1_150_000L,
            nowNanos = t0 + 150_000_000L,
        )!!

        assertEquals(-30_000.0, errorUs.toDouble(), 100.0)
    }

    @Test
    fun `counts from where the head was placed, not from the counter's zero`() {
        // The counter keeps running across pauses; a resume places the head
        // anew, and only frames presented since then belong to that place.
        val sync = LoopAudioSync(loopFrames, sampleRate)
        sync.anchor(videoPositionUs = 2_000_000L, counterFrame = 3_153_150L, nowNanos = t0)

        val errorUs = sync.errorUs(
            presentedFrame = 3_153_150L + frames(100_000L),
            presentedNanos = t0 + 150_000_000L,
            videoPositionUs = 2_150_000L,
            nowNanos = t0 + 150_000_000L,
        )!!

        assertTrue("was $errorUs us", kotlin.math.abs(errorUs) < 100)
    }

    @Test
    fun `extrapolates a timestamp to the moment the picture was read`() {
        val sync = LoopAudioSync(loopFrames, sampleRate)
        sync.anchor(videoPositionUs = 0L, counterFrame = 0L, nowNanos = t0)

        // The same presentation, reported 20 ms before the picture was read.
        val errorUs = sync.errorUs(
            presentedFrame = frames(80_000L),
            presentedNanos = t0 + 130_000_000L,
            videoPositionUs = 150_000L,
            nowNanos = t0 + 150_000_000L,
        )!!

        assertTrue("was $errorUs us", kotlin.math.abs(errorUs) < 100)
    }

    @Test
    fun `measures across the loop wrap rather than calling it a lap apart`() {
        val sync = LoopAudioSync(loopFrames, sampleRate)
        val loopUs = loopFrames * 1_000_000L / sampleRate
        sync.anchor(videoPositionUs = loopUs - 100_000L, counterFrame = 0L, nowNanos = t0)

        // The sound has wrapped 10 ms into the loop while the picture is still
        // 5 ms short of its end: 15 ms early, not a whole lap late.
        val errorUs = sync.errorUs(
            presentedFrame = frames(60_000L),
            presentedNanos = t0 + 110_000_000L,
            videoPositionUs = loopUs - 5_000L,
            nowNanos = t0 + 110_000_000L,
        )!!

        assertEquals(15_000.0, errorUs.toDouble(), 100.0)
    }

    @Test
    fun `a timestamp from before the head was placed is not a measurement`() {
        val sync = LoopAudioSync(loopFrames, sampleRate)
        sync.anchor(videoPositionUs = 0L, counterFrame = 5_000L, nowNanos = t0)

        // Right after a resume the track still reports where it paused.
        assertNull(
            sync.errorUs(
                presentedFrame = 5_000L,
                presentedNanos = t0 - 1_000_000L,
                videoPositionUs = 10_000L,
                nowNanos = t0 + 10_000_000L,
            ),
        )
    }

    @Test
    fun `the first measurement after a start teaches the start latency`() {
        val sync = LoopAudioSync(loopFrames, sampleRate)
        sync.anchor(videoPositionUs = 0L, counterFrame = 0L, nowNanos = t0)

        // Allowed 50 ms, came out 30 ms late: this start took 80.
        sync.correct(errorUs = -30_000L)

        assertEquals(65_000L, LoopAudioSync.startLatencyUs)

        // Later measurements are steering, not starts.
        sync.correct(errorUs = -30_000L)
        assertEquals(65_000L, LoopAudioSync.startLatencyUs)
    }

    @Test
    fun `a gap within the noise is left alone`() {
        val sync = LoopAudioSync(loopFrames, sampleRate)
        sync.anchor(videoPositionUs = 0L, counterFrame = 0L, nowNanos = t0)

        assertEquals(LoopAudioSync.Correction.STEER, sync.correct(errorUs = 3_000L))
        assertEquals(1.0, sync.rateFactor, 0.0)
    }

    @Test
    fun `a steady early sound is slowed and a steady late one hurried, within the cap`() {
        val sync = LoopAudioSync(loopFrames, sampleRate)
        sync.anchor(videoPositionUs = 0L, counterFrame = 0L, nowNanos = t0)
        sync.correct(errorUs = 0L)

        repeat(10) { sync.correct(errorUs = 10_000L) }
        assertEquals(1.0 - LoopAudioSync.MAX_RATE_DEVIATION, sync.rateFactor, 1e-9)

        repeat(20) { sync.correct(errorUs = -10_000L) }
        assertEquals(1.0 + LoopAudioSync.MAX_RATE_DEVIATION, sync.rateFactor, 1e-9)
    }

    @Test
    fun `a single scattered reading does not move the rate`() {
        // The picture's position is read to the millisecond; one reading a
        // few milliseconds out is noise, and steering on it would wobble the
        // pitch of a sound that is already in step.
        val sync = LoopAudioSync(loopFrames, sampleRate)
        sync.anchor(videoPositionUs = 0L, counterFrame = 0L, nowNanos = t0)
        sync.correct(errorUs = 0L)

        sync.correct(errorUs = 9_000L)

        assertEquals(1.0, sync.rateFactor, 0.0)
    }

    @Test
    fun `a gap too wide to steer asks for the head to be placed again`() {
        val sync = LoopAudioSync(loopFrames, sampleRate)
        sync.anchor(videoPositionUs = 0L, counterFrame = 0L, nowNanos = t0)
        sync.correct(errorUs = 0L)

        // Headphones plugged in under a playing loop.
        assertEquals(LoopAudioSync.Correction.REANCHOR, sync.correct(errorUs = -180_000L))
        assertEquals(1.0, sync.rateFactor, 0.0)
    }

    @Test
    fun `a placed head starts at the nominal rate`() {
        val sync = LoopAudioSync(loopFrames, sampleRate)
        sync.anchor(videoPositionUs = 0L, counterFrame = 0L, nowNanos = t0)
        repeat(10) { sync.correct(errorUs = 10_000L) }

        sync.anchor(videoPositionUs = 0L, counterFrame = 0L, nowNanos = ms(2_000L))

        assertEquals(1.0, sync.rateFactor, 0.0)
    }
}
