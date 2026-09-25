package com.divinevideo.divine_video_player

import android.media.AudioTimestamp
import android.media.AudioTrack
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

/**
 * Drives the real state machine against a fake [AudioTrack], the way
 * [DivineVideoPlayerInstanceTest]'s mid-lap-takeover tests drive it
 * indirectly through a fully mocked [ClipAudioLoopTrack].
 *
 * [ClipAudioLoopTrack.create] decodes real media and is out of scope here;
 * [ClipAudioLoopTrack.forTesting] is the seam these tests use instead.
 * [lastOutputNanos] (private, process-shared, real-clock-driven) decides
 * whether a `play()` call mutes itself for warm-output detection. A scenario
 * that depends on landing on one side of that decision pins it explicitly
 * with [ClipAudioLoopTrack.setLastOutputNanosForTesting] (and restores it in
 * a `finally`) rather than racing the real clock or a previous test's
 * leftover value; one that doesn't care leaves it alone.
 */
class ClipAudioLoopTrackTest {

    private val sampleRate = 44_100
    private val loopFrames = 278_888 // matches LoopAudioSyncTest's example clip

    private lateinit var track: AudioTrack
    private var playing = false
    private var headFrame = 0
    private var timestampFrame = 0L
    private var timestampNanos = 0L

    @Before
    fun setUp() {
        playing = false
        headFrame = 0
        timestampFrame = 0L
        timestampNanos = 0L
        track = mockk(relaxed = true)
        every { track.playState } answers {
            if (playing) AudioTrack.PLAYSTATE_PLAYING else AudioTrack.PLAYSTATE_STOPPED
        }
        every { track.play() } answers { playing = true }
        every { track.pause() } answers { playing = false }
        every { track.playbackHeadPosition } answers { headFrame }
        every { track.getTimestamp(any()) } answers {
            val ts = firstArg<AudioTimestamp>()
            ts.framePosition = timestampFrame
            ts.nanoTime = timestampNanos
            true
        }
        LoopAudioSync.startLatencyUs = 50_000L
    }

    @After
    fun tearDown() {
        LoopAudioSync.startLatencyUs = 50_000L
    }

    private fun frames(us: Long): Long = Math.round(us.toDouble() * sampleRate / 1_000_000.0)

    @Test
    fun `a reanchor while still silent after a muted takeover start does not teach the shared start latency`() {
        val loop = ClipAudioLoopTrack.forTesting(track, sampleRate, loopFrames)

        // Exactly how adoptClipAudioLoop hands the sound over mid-lap: muted,
        // so ClipAudioTakeover can line it up before anyone hears it.
        loop.play(positionUs = 0L, volume = 0f)
        val afterPlay = System.nanoTime()

        // A reading 200 ms off the picture — a reanchor, not a steer — while
        // still silent because nothing has revealed the loop yet.
        timestampFrame = frames(150_000L)
        timestampNanos = afterPlay + 150_000_000L
        loop.sync(videoPositionUs = 50_000L, nowNanos = afterPlay + 200_000_000L)
        val afterReanchor = System.nanoTime()

        // A second, moderate reading. If the reanchor above wrongly taught
        // the shared latency, this measurement folds a different value in.
        timestampFrame = 2_000L
        timestampNanos = afterReanchor + 10_000_000L
        loop.sync(videoPositionUs = 6_249_342L, nowNanos = afterReanchor + 10_000_000L)

        assertEquals(50_000L, LoopAudioSync.startLatencyUs)
    }

    @Test
    fun `a reanchor while a cold-start output is still aligning does not teach the shared start latency`() {
        // Deterministic stand-in for "an output idle long enough to be in
        // standby" — see [ClipAudioLoopTrack.setLastOutputNanosForTesting].
        ClipAudioLoopTrack.setLastOutputNanosForTesting(Long.MIN_VALUE / 2)
        try {
            val loop = ClipAudioLoopTrack.forTesting(track, sampleRate, loopFrames)

            // volume > 0f on that idle-forever output triggers `aligining`
            // the same way a genuine cold start does: muted until sync()
            // measures it in step, exactly like the takeover case above, but
            // reached through installClipAudioLoop's non-takeover path
            // instead — the two are different callers hitting the same
            // "still silent" state this REANCHOR branch must respect.
            loop.play(positionUs = 0L, volume = 1f)
            val afterPlay = System.nanoTime()

            // Output waking from standby: ~200 ms off, the exact shape
            // LoopAudioSync's own docs use as the motivating example for why
            // a first-measurement-driven reanchor must not teach.
            timestampFrame = frames(150_000L)
            timestampNanos = afterPlay + 150_000_000L
            loop.sync(videoPositionUs = 50_000L, nowNanos = afterPlay + 200_000_000L)
            val afterReanchor = System.nanoTime()

            // A second, moderate reading, well before ALIGN_TIMEOUT_NS would
            // reveal the loop on its own.
            timestampFrame = 2_000L
            timestampNanos = afterReanchor + 10_000_000L
            loop.sync(videoPositionUs = 6_249_342L, nowNanos = afterReanchor + 10_000_000L)

            assertEquals(50_000L, LoopAudioSync.startLatencyUs)
        } finally {
            ClipAudioLoopTrack.setLastOutputNanosForTesting(Long.MIN_VALUE / 2)
        }
    }

    @Test
    fun `a reanchor once the loop is audible does teach the shared start latency`() {
        // Pin the output as recently active so play() below takes the
        // not-aligning branch deterministically, the same way the cold-start
        // test above pins it idle-forever for the opposite branch. Without
        // this, whether this test observes learning depends on whatever
        // lastOutputNanos a previous test happened to leave behind.
        ClipAudioLoopTrack.setLastOutputNanosForTesting(System.nanoTime())
        try {
            val loop = ClipAudioLoopTrack.forTesting(track, sampleRate, loopFrames)

            // Same shape as the muted case above, but started at full volume —
            // installClipAudioLoop's non-takeover path. The reanchor this time
            // is allowed to teach, and this pins that it still does.
            loop.play(positionUs = 0L, volume = 1f)
            val afterPlay = System.nanoTime()

            timestampFrame = frames(150_000L)
            timestampNanos = afterPlay + 150_000_000L
            loop.sync(videoPositionUs = 50_000L, nowNanos = afterPlay + 200_000_000L)
            val afterReanchor = System.nanoTime()

            timestampFrame = 2_000L
            timestampNanos = afterReanchor + 10_000_000L
            loop.sync(videoPositionUs = 6_249_342L, nowNanos = afterReanchor + 10_000_000L)

            // ~40_000 in exact arithmetic; the reanchor's own pipeline-latency
            // read uses the real clock (see placeOnRunningOutput), so a few
            // microseconds of real test-execution time land in the result.
            assertEquals(40_000.0, LoopAudioSync.startLatencyUs.toDouble(), 2_000.0)
        } finally {
            ClipAudioLoopTrack.setLastOutputNanosForTesting(Long.MIN_VALUE / 2)
        }
    }

    @Test
    fun `seekTo repositions the head through realign, which never teaches`() {
        val loop = ClipAudioLoopTrack.forTesting(track, sampleRate, loopFrames)
        loop.play(positionUs = 0L, volume = 1f)

        loop.seekTo(positionUs = 500_000L)
        val afterSeek = System.nanoTime()

        // realign() anchors with learn = false unconditionally, so no
        // measurement afterwards can teach the shared latency.
        timestampFrame = 5_000L
        timestampNanos = afterSeek + 10_000_000L
        loop.sync(videoPositionUs = 500_000L, nowNanos = afterSeek + 10_000_000L)

        assertEquals(50_000L, LoopAudioSync.startLatencyUs)
    }

    @Test
    fun `sync returns null once the track has been released`() {
        val loop = ClipAudioLoopTrack.forTesting(track, sampleRate, loopFrames)
        loop.play(positionUs = 0L, volume = 1f)

        loop.release()

        assertNull(loop.sync(videoPositionUs = 0L, nowNanos = System.nanoTime()))
    }

    @Test
    fun `sync returns null while the track is not playing`() {
        val loop = ClipAudioLoopTrack.forTesting(track, sampleRate, loopFrames)

        assertNull(loop.sync(videoPositionUs = 0L, nowNanos = System.nanoTime()))
    }

    @Test
    fun `release is idempotent`() {
        val loop = ClipAudioLoopTrack.forTesting(track, sampleRate, loopFrames)
        loop.play(positionUs = 0L, volume = 1f)

        loop.release()
        loop.release()

        verify(exactly = 1) { track.release() }
    }
}
