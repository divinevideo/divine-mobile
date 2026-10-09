package com.divinevideo.divine_video_player

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/** The shape of an [AudioEqualizerBand]'s filter, by its platform-channel name. */
internal enum class AudioEqualizerBandType(val key: String) {
    LOW_SHELF("lowShelf"),
    PEAK("peak"),
    HIGH_SHELF("highShelf");

    companion object {
        /** The type named [key]; null for a name this player does not know. */
        fun fromKey(key: Any?): AudioEqualizerBandType? = entries.firstOrNull { it.key == key }
    }
}

/** One filter of an [AudioEqualizer]: a shelf or a peak at [frequencyHz]. */
internal data class AudioEqualizerBand(
    val type: AudioEqualizerBandType,
    val frequencyHz: Double,
    val gainDb: Double = 0.0,
    val q: Double = DEFAULT_Q,
) {
    /** The section that filters this band at [sampleRate]. */
    fun biquad(sampleRate: Int): Biquad = when (type) {
        AudioEqualizerBandType.LOW_SHELF -> Biquad.lowShelf(frequencyHz, gainDb, sampleRate)
        AudioEqualizerBandType.PEAK -> Biquad.peak(frequencyHz, gainDb, q, sampleRate)
        AudioEqualizerBandType.HIGH_SHELF -> Biquad.highShelf(frequencyHz, gainDb, sampleRate)
    }

    companion object {
        /** 1/√2. Only a peak reads q; a shelf's slope is 1. */
        const val DEFAULT_Q = 0.7071067811865476

        /**
         * Parses a band from a platform-channel map; null for one this player
         * cannot filter, which is skipped rather than failing the equalizer.
         */
        fun fromMap(map: Any?): AudioEqualizerBand? {
            if (map !is Map<*, *>) return null
            val type = AudioEqualizerBandType.fromKey(map["type"]) ?: return null
            val frequency = (map["frequencyHz"] as? Number)?.toDouble()
                ?.takeIf { it > 0 } ?: return null
            return AudioEqualizerBand(
                type = type,
                frequencyHz = frequency,
                gainDb = (map["gainDb"] as? Number)?.toDouble() ?: 0.0,
                q = (map["q"] as? Number)?.toDouble()?.takeIf { it > 0 } ?: DEFAULT_Q,
            )
        }
    }
}

/**
 * What a clip or an overlay track plays through: [bands], one filter after
 * the other in that order.
 *
 * The preview has to sound like the export, which `pro_video_editor` renders
 * with the same filters: [Biquad], [BandEqualizer] and [PeakLimiter] here are
 * twins of that plugin's, down to the coefficients their tests pin.
 */
internal data class AudioEqualizer(val bands: List<AudioEqualizerBand> = emptyList()) {
    /** Whether the equalizer leaves the audio unchanged. */
    val isFlat: Boolean
        get() = bands.all { it.gainDb == 0.0 }

    /** Whether any band raises its frequencies, which can cross full scale. */
    val boosts: Boolean
        get() = bands.any { it.gainDb > 0.0 }

    companion object {
        /**
         * Parses an equalizer from a platform-channel map; null when the map
         * is absent or leaves the audio unchanged, so a flat one costs nothing.
         */
        fun fromMap(map: Map<*, *>?): AudioEqualizer? {
            val bands = (map?.get("bands") as? List<*>)
                ?.mapNotNull(AudioEqualizerBand::fromMap)
                ?: return null
            return AudioEqualizer(bands).takeUnless { it.isFlat }
        }
    }
}

/** One second-order section, normalised so `a0` is 1. */
internal class Biquad(
    val b0: Double,
    val b1: Double,
    val b2: Double,
    val a1: Double,
    val a2: Double,
) {
    companion object {
        /**
         * The highest frequency a band gets, as a fraction of the sample rate:
         * close to half of it the bilinear transform squeezes the filter flat.
         */
        private const val MAX_CORNER_RATIO = 0.45

        private fun corner(frequencyHz: Double, rate: Double): Double =
            frequencyHz.coerceIn(1.0, rate * MAX_CORNER_RATIO)

        /** A section that passes the signal through unchanged. */
        val IDENTITY = Biquad(1.0, 0.0, 0.0, 0.0, 0.0)

        /** The cookbook's peak at [frequencyHz], [q] wide. */
        fun peak(frequencyHz: Double, gainDb: Double, q: Double, sampleRate: Int): Biquad {
            if (gainDb == 0.0) return IDENTITY
            val rate = sampleRate.coerceAtLeast(1).toDouble()
            val a = 10.0.pow(gainDb / 40.0)
            val w0 = 2.0 * PI * corner(frequencyHz, rate) / rate
            val cosW0 = cos(w0)
            val alpha = sin(w0) / (2.0 * q)
            val a0 = 1 + alpha / a
            return Biquad(
                (1 + alpha * a) / a0,
                -2 * cosW0 / a0,
                (1 - alpha * a) / a0,
                -2 * cosW0 / a0,
                (1 - alpha / a) / a0,
            )
        }

        /** The cookbook's low shelf at [frequencyHz], slope 1. */
        fun lowShelf(frequencyHz: Double, gainDb: Double, sampleRate: Int): Biquad =
            shelf(frequencyHz, gainDb, sampleRate, high = false)

        /** The cookbook's high shelf at [frequencyHz], slope 1. */
        fun highShelf(frequencyHz: Double, gainDb: Double, sampleRate: Int): Biquad =
            shelf(frequencyHz, gainDb, sampleRate, high = true)

        private fun shelf(
            frequencyHz: Double,
            gainDb: Double,
            sampleRate: Int,
            high: Boolean,
        ): Biquad {
            if (gainDb == 0.0) return IDENTITY
            val rate = sampleRate.coerceAtLeast(1).toDouble()
            val a = 10.0.pow(gainDb / 40.0)
            val w0 = 2.0 * PI * corner(frequencyHz, rate) / rate
            val cosW0 = cos(w0)
            // alpha = sin(w0) / 2 * sqrt((A + 1/A) * (1/S - 1) + 2) with S = 1.
            val alpha = sin(w0) / 2.0 * sqrt(2.0)
            val twoSqrtAAlpha = 2.0 * sqrt(a) * alpha
            val b0: Double
            val b1: Double
            val b2: Double
            val a0: Double
            val a1: Double
            val a2: Double
            if (high) {
                b0 = a * ((a + 1) + (a - 1) * cosW0 + twoSqrtAAlpha)
                b1 = -2 * a * ((a - 1) + (a + 1) * cosW0)
                b2 = a * ((a + 1) + (a - 1) * cosW0 - twoSqrtAAlpha)
                a0 = (a + 1) - (a - 1) * cosW0 + twoSqrtAAlpha
                a1 = 2 * ((a - 1) - (a + 1) * cosW0)
                a2 = (a + 1) - (a - 1) * cosW0 - twoSqrtAAlpha
            } else {
                b0 = a * ((a + 1) - (a - 1) * cosW0 + twoSqrtAAlpha)
                b1 = 2 * a * ((a - 1) - (a + 1) * cosW0)
                b2 = a * ((a + 1) - (a - 1) * cosW0 - twoSqrtAAlpha)
                a0 = (a + 1) + (a - 1) * cosW0 + twoSqrtAAlpha
                a1 = -2 * ((a - 1) + (a + 1) * cosW0)
                a2 = (a + 1) + (a - 1) * cosW0 - twoSqrtAAlpha
            }
            return Biquad(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)
        }
    }
}

/**
 * Runs interleaved float PCM through one [Biquad] per band of an
 * [AudioEqualizer], in band order, each channel with its own filter state.
 *
 * [retune] moves a playing stream to new settings, as a slider is dragged:
 * with as many bands as before, every section keeps the history it holds and
 * only its coefficients move, so the change does not click.
 */
internal class BandEqualizer(
    private val sampleRate: Int,
    channelCount: Int,
) {
    private val channels = channelCount.coerceAtLeast(1)
    private var sections = emptyArray<Biquad>()

    /** The sections that change the signal; a band at 0 dB costs nothing. */
    private var active = IntArray(0)

    /** Two delay elements per section per channel, a channel's together. */
    private var state = DoubleArray(0)

    /** Moves the filters to [equalizer], or to none when it is null. */
    fun retune(equalizer: AudioEqualizer?) {
        val bands = equalizer?.bands.orEmpty()
        val next = Array(bands.size) { bands[it].biquad(sampleRate) }
        if (next.size != sections.size) {
            // Another band count leaves no section whose history still fits.
            state = DoubleArray(channels * next.size * 2)
        } else {
            // A band turned to 0 dB drops its history: played out through an
            // identity it would spike, and kept it would come back stale.
            for (s in next.indices) {
                if (next[s] !== Biquad.IDENTITY) continue
                for (c in 0 until channels) {
                    val offset = (c * next.size + s) * 2
                    state[offset] = 0.0
                    state[offset + 1] = 0.0
                }
            }
        }
        sections = next
        active = next.indices.filter { next[it] !== Biquad.IDENTITY }.toIntArray()
    }

    /** Filters the first [sampleCount] interleaved [samples] in place. */
    fun process(samples: FloatArray, sampleCount: Int = samples.size) {
        val sections = sections
        val active = active
        if (active.isEmpty()) return
        val stride = sections.size * 2
        val end = sampleCount.coerceAtMost(samples.size)
        var frame = 0
        while (frame + channels <= end) {
            for (c in 0 until channels) {
                var x = samples[frame + c].toDouble()
                for (s in active) x = step(sections[s], x, c * stride + s * 2)
                samples[frame + c] = x.toFloat()
            }
            frame += channels
        }
    }

    /** One sample through [biquad], transposed direct form II. */
    private fun step(biquad: Biquad, x: Double, offset: Int): Double {
        val y = biquad.b0 * x + state[offset]
        state[offset] = biquad.b1 * x - biquad.a1 * y + state[offset + 1]
        state[offset + 1] = biquad.b2 * x - biquad.a2 * y
        return y
    }
}

/**
 * Keeps a boosted signal under full scale by turning it down where it would
 * cross [CEILING], instantly, and letting the gain recover over
 * [RELEASE_SECONDS]. All channels of a frame share one gain.
 *
 * The twin of `pro_video_editor`'s, which limits an equalizer's boost in the
 * export at the same ceiling.
 */
internal class PeakLimiter(sampleRate: Int) {

    private val releaseCoefficient =
        exp(-1.0 / (RELEASE_SECONDS * sampleRate.coerceAtLeast(1))).toFloat()

    private var gain = 1f

    /** Limits the first [sampleCount] interleaved [samples] in place. */
    fun process(samples: FloatArray, channelCount: Int, sampleCount: Int = samples.size) {
        val channels = channelCount.coerceAtLeast(1)
        val end = sampleCount.coerceAtMost(samples.size)
        var frame = 0
        while (frame + channels <= end) {
            var peak = 0f
            for (c in 0 until channels) peak = maxOf(peak, abs(samples[frame + c]))
            val target = if (peak > CEILING) CEILING / peak else 1f
            gain = if (target < gain) target else target + (gain - target) * releaseCoefficient
            if (gain < 1f) {
                for (c in 0 until channels) samples[frame + c] *= gain
            }
            frame += channels
        }
    }

    /** Forgets any reduction in progress. */
    fun reset() {
        gain = 1f
    }

    companion object {
        /** -1 dBFS, the export's ceiling. */
        const val CEILING = 0.891251f

        /** How long the gain takes to recover by ~63 % after a peak. */
        const val RELEASE_SECONDS = 0.05
    }
}

/** Runs PCM held in memory through an equalizer, as the export would. */
internal object EqualizerPcm {

    /** Full scale of 16-bit PCM as a float sample of 1.0. */
    private const val SHORT_SCALE = 32768f

    /**
     * Equalizes interleaved 16-bit [samples] of [channels] channels in place,
     * limiting a boost at the export's ceiling. A null [equalizer] leaves
     * them as they are.
     */
    fun apply(
        samples: ShortArray,
        channels: Int,
        sampleRate: Int,
        equalizer: AudioEqualizer?,
    ) {
        if (equalizer == null || equalizer.isFlat || samples.isEmpty()) return
        val floats = FloatArray(samples.size) { samples[it] / SHORT_SCALE }
        BandEqualizer(sampleRate, channels).apply { retune(equalizer) }.process(floats)
        if (equalizer.boosts) PeakLimiter(sampleRate).process(floats, channels)
        for (i in samples.indices) samples[i] = toShort(floats[i])
    }

    /** [sample] as 16-bit PCM, rounded and clamped. */
    fun toShort(sample: Float): Short =
        (sample * SHORT_SCALE).roundToInt()
            .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
            .toShort()

    /** 16-bit [sample] as a float in -1..1. */
    fun toFloat(sample: Short): Float = sample / SHORT_SCALE
}
