package com.divinevideo.divine_video_player

import kotlin.math.abs

/**
 * Keeps a static loop track on the picture.
 *
 * The loop track and the picture run on two clocks: ExoPlayer's video follows
 * the system clock once its audio renderer is switched off, the track plays in
 * the HAL. They share a period to the sample, so they do not drift apart
 * measurably — measured on an SM-S942B, the gap held within ±4 ms over six laps
 * — but they do not *start* together. A frame written at `play()` is heard only
 * after the output pipeline has carried it to the speaker, 40–56 ms later on
 * that device's speaker and far more over Bluetooth, and the picture has moved
 * on by then. Uncorrected, every lap's sound restarts that much after its
 * picture does.
 *
 * So the head is placed ahead of the picture by [startLatencyUs], learned from
 * what the track reports once it is audible, and whatever remains is steered
 * out through the playback rate — a fraction of a percent, far below what
 * anyone hears as pitch.
 *
 * All the arithmetic lives here, apart from the [android.media.AudioTrack],
 * because it is the part that has to be right to the frame.
 *
 * The track's two counters are *cumulative*: `getPlaybackHeadPosition` counts
 * frames consumed and `AudioTimestamp.framePosition` frames presented, both
 * across loop wraps and pauses. Where in the loop a presented frame sits
 * follows from where the head was placed when playback last started.
 */
internal class LoopAudioSync(
    private val loopFrames: Long,
    private val sampleRate: Int,
) {

    private var anchorBufferFrame = 0L
    private var anchorCounterFrame = 0L
    private var anchorNanos = Long.MIN_VALUE

    /** What the head placed last allowed for the pipeline. */
    var anchorLatencyUs = 0L
        private set

    /**
     * The measured gap, smoothed. A single reading scatters by a few
     * milliseconds — the picture's position is read to the millisecond — and
     * steering on each one would wobble the rate on noise.
     */
    private var smoothedErrorUs: Double? = null

    /**
     * Whether the next measurement is the first since a start that should
     * teach [startLatencyUs]. See [anchor].
     */
    private var awaitingFirstMeasurement = false

    /** The playback-rate factor the track should run at. */
    var rateFactor = 1.0
        private set

    /**
     * Where to place the head so that the picture at [videoPositionUs] and
     * the sound heard [startLatencyUs] from now line up.
     *
     * [counterFrame] is the track's consumed-frame counter at the moment of
     * placing, [nowNanos] the `System.nanoTime()` it was read at.
     *
     * [latencyUs] overrides the allowance for a head placed again against a
     * measured gap: the last allowance, less what it was off by.
     *
     * Only an audible start teaches [startLatencyUs] ([learn]). A muted loop
     * lining up under ExoPlayer's audio is placed again until it fits, starts
     * with another track already driving the output, and would teach every
     * later start a latency that is not theirs — measured on an SM-S942B, a
     * preloaded tile then started 19 ms early.
     */
    fun anchor(
        videoPositionUs: Long,
        counterFrame: Long,
        nowNanos: Long,
        learn: Boolean = true,
        latencyUs: Long = startLatencyUs,
    ): Long {
        anchorLatencyUs = latencyUs
        smoothedErrorUs = null
        anchorBufferFrame = floorMod(framesFor(videoPositionUs + anchorLatencyUs), loopFrames)
        anchorCounterFrame = counterFrame
        anchorNanos = nowNanos
        awaitingFirstMeasurement = learn
        rateFactor = 1.0
        return anchorBufferFrame
    }

    /**
     * How far the sound heard at [nowNanos] is ahead of the picture at
     * [videoPositionUs] — negative when it is behind — or `null` when the
     * track has not reported a frame presented since the head was placed.
     *
     * [presentedFrame] and [presentedNanos] are an `AudioTimestamp`.
     */
    fun errorUs(
        presentedFrame: Long,
        presentedNanos: Long,
        videoPositionUs: Long,
        nowNanos: Long,
    ): Long? {
        if (presentedNanos <= anchorNanos || presentedFrame < anchorCounterFrame) return null
        // The first reports after a start describe an output still filling:
        // measured on an SM-S942B they put a sound that was in step 49 ms
        // early, and the head was moved for nothing.
        if (presentedFrame - anchorCounterFrame < framesFor(SETTLE_US)) return null
        val presentedNow = presentedFrame +
            (nowNanos - presentedNanos) * sampleRate * rateFactor / NANOS_PER_SECOND
        val audibleFrame = floorMod(
            anchorBufferFrame + presentedNow - anchorCounterFrame,
            loopFrames.toDouble(),
        )
        val loopUs = loopFrames * MICROS_PER_SECOND / sampleRate
        val audibleUs = audibleFrame * MICROS_PER_SECOND / sampleRate
        val pictureUs = floorMod(videoPositionUs.toDouble(), loopUs)
        var errorUs = audibleUs - pictureUs
        if (errorUs >= loopUs / 2) errorUs -= loopUs
        if (errorUs < -loopUs / 2) errorUs += loopUs
        return errorUs.toLong()
    }

    /**
     * Folds a measured [errorUs] into the learned start latency and the rate
     * the track should run at, and says whether the gap is too wide to steer
     * and the head has to be placed again.
     */
    fun correct(errorUs: Long): Correction {
        if (awaitingFirstMeasurement) {
            awaitingFirstMeasurement = false
            // The sound came out errorUs early: the pipeline took that much
            // less than was allowed for. Blend rather than replace, so one
            // odd start does not throw the next one off — and a start too far
            // off to steer teaches nothing at all. That is an output waking
            // from standby after a pause, ~200 ms on an SM-S942B's speaker
            // against ~50 warm; learnt, it put the next two placements 67 ms
            // early and then 24 ms late, each one an audible jump.
            if (abs(errorUs) <= REANCHOR_THRESHOLD_US) {
                val observedUs = (anchorLatencyUs - errorUs).coerceIn(0L, MAX_START_LATENCY_US)
                startLatencyUs = (startLatencyUs + observedUs) / 2
            }
        }
        if (abs(errorUs) > REANCHOR_THRESHOLD_US) {
            rateFactor = 1.0
            smoothedErrorUs = null
            return Correction.REANCHOR
        }
        val smoothed = smoothedErrorUs?.let { it + SMOOTHING * (errorUs - it) }
            ?: errorUs.toDouble()
        smoothedErrorUs = smoothed
        rateFactor = if (abs(smoothed) <= DEADBAND_US) {
            1.0
        } else {
            1.0 - (smoothed / STEER_HORIZON_US).coerceIn(-MAX_RATE_DEVIATION, MAX_RATE_DEVIATION)
        }
        return Correction.STEER
    }

    /**
     * How long a frame the track consumes now takes to be heard, measured on
     * the running output, or `null` when the readings do not fit together.
     *
     * [headFrame] is the consumed-frame counter read at [nowNanos];
     * [presentedFrame] and [presentedNanos] are an `AudioTimestamp`. What has
     * been consumed but not yet presented is in the pipeline, and a head
     * placed again on a running output waits behind exactly that — unlike a
     * start after a pause, which can also wait for the output to wake up.
     */
    fun pipelineLatencyUs(
        headFrame: Long,
        presentedFrame: Long,
        presentedNanos: Long,
        nowNanos: Long,
    ): Long? {
        val presentedNow = presentedFrame +
            (nowNanos - presentedNanos) * sampleRate * rateFactor / NANOS_PER_SECOND
        val inFlightUs = (headFrame - presentedNow) * MICROS_PER_SECOND / sampleRate
        if (inFlightUs < 0 || inFlightUs > MAX_START_LATENCY_US) return null
        return inFlightUs.toLong()
    }

    private fun framesFor(us: Long): Long = Math.round(us.toDouble() * sampleRate / MICROS_PER_SECOND)

    enum class Correction { STEER, REANCHOR }

    companion object {
        private const val NANOS_PER_SECOND = 1_000_000_000.0
        private const val MICROS_PER_SECOND = 1_000_000.0

        /** A few milliseconds is measurement noise, not a gap to close. */
        const val DEADBAND_US = 4_000L

        /** How much has to have been heard since a start before it is measured. */
        const val SETTLE_US = 30_000L

        /**
         * Past this the sound is audibly apart from the picture and steering
         * would take seconds, so the head is placed again instead. Only an
         * output that changed under the track — headphones plugged in, a
         * Bluetooth route — gets here once the latency has been learned.
         */
        const val REANCHOR_THRESHOLD_US = 40_000L

        /** Weight of a new reading in [smoothedErrorUs]. */
        private const val SMOOTHING = 0.3

        /** A gap is steered out over about this long, within the rate cap. */
        private const val STEER_HORIZON_US = 2_000_000.0

        /** 0.3 % of the rate is 5 cents of pitch: nobody hears it move. */
        const val MAX_RATE_DEVIATION = 0.003

        private const val MAX_START_LATENCY_US = 500_000L

        /**
         * What a newly placed head allows for the pipeline, shared by every
         * loop in the process. Starts at what the speaker path measured on an
         * SM-S942B and learns from every start after.
         */
        @Volatile
        var startLatencyUs: Long = 50_000L

        private fun floorMod(value: Long, modulus: Long): Long = Math.floorMod(value, modulus)

        private fun floorMod(value: Double, modulus: Double): Double {
            val r = value % modulus
            return if (r < 0) r + modulus else r
        }
    }
}
