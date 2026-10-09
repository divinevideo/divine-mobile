package com.divinevideo.divine_video_player

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.log10
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Pins the preview's filters to the export's.
 *
 * The coefficients are the literals `pro_video_editor`'s Android and Apple
 * tests pin, so the editor preview keeps sounding like the posted video.
 */
class AudioEqualizerTest {

    @Test
    fun `low shelf coefficients match the export's`() {
        val biquad = Biquad.lowShelf(200.0, 6.0, 48000)

        assertEquals(1.0064455778511419, biquad.b0, 1e-12)
        assertEquals(-1.9686123523200318, biquad.b1, 1e-12)
        assertEquals(0.9631200582728409, biquad.b2, 1e-12)
        assertEquals(-1.9688501073857254, biquad.a1, 1e-12)
        assertEquals(0.9693278810582894, biquad.a2, 1e-12)
    }

    @Test
    fun `high shelf coefficients match the export's`() {
        val biquad = Biquad.highShelf(3000.0, 6.0, 48000)

        assertEquals(1.815113185412132, biquad.b0, 1e-12)
        assertEquals(-2.790024630355969, biquad.b1, 1e-12)
        assertEquals(1.13571665291146, biquad.b2, 1e-12)
        assertEquals(-1.358218880923325, biquad.a1, 1e-12)
        assertEquals(0.519024088890948, biquad.a2, 1e-12)
    }

    @Test
    fun `peak coefficients match the export's`() {
        val boost = Biquad.peak(1000.0, 6.0, 0.7071067811865475, 48000)

        assertEquals(1.0610424252634374, boost.b0, 1e-12)
        assertEquals(-1.8612731439964758, boost.b1, 1e-12)
        assertEquals(0.816291571321481, boost.b2, 1e-12)
        assertEquals(-1.8612731439964758, boost.a1, 1e-12)
        assertEquals(0.8773339965849185, boost.a2, 1e-12)

        val cut = Biquad.peak(250.0, -6.0, 0.7071067811865475, 44100)

        assertEquals(0.9828670212502347, cut.b0, 1e-12)
        assertEquals(-1.930079966863433, cut.b1, 1e-12)
        assertEquals(0.9484379496535652, cut.b2, 1e-12)
        assertEquals(-1.930079966863433, cut.a1, 1e-12)
        assertEquals(0.9313049709037998, cut.a2, 1e-12)
    }

    @Test
    fun `a corner near half the sample rate is lowered as the export's is`() {
        // Lowered to 45 % of the rate, the 16 kHz shelf stays stable at 32
        // and 22.05 kHz: both poles inside the unit circle.
        for (rate in intArrayOf(32000, 22050)) {
            val shelf = Biquad.highShelf(16000.0, 6.0, rate)
            val lowered = Biquad.highShelf(rate * 0.45, 6.0, rate)
            assertEquals(lowered.b0, shelf.b0, 0.0)
            assertEquals(lowered.b1, shelf.b1, 0.0)
            assertEquals(lowered.b2, shelf.b2, 0.0)
            assertEquals(lowered.a1, shelf.a1, 0.0)
            assertEquals(lowered.a2, shelf.a2, 0.0)
            assertTrue(abs(shelf.a2) < 1 && abs(shelf.a1) < 1 + shelf.a2)
        }
    }

    @Test
    fun `a band without gain passes the signal through`() {
        assertSame(Biquad.IDENTITY, Biquad.lowShelf(200.0, 0.0, 48000))
        assertSame(Biquad.IDENTITY, Biquad.peak(1000.0, 0.0, 1.0, 48000))
    }

    @Test
    fun `parses every band in order and drops a flat equalizer`() {
        val equalizer = AudioEqualizer.fromMap(
            mapOf(
                "bands" to listOf(
                    mapOf("type" to "highShelf", "frequencyHz" to 3000, "gainDb" to -2.5, "q" to 1),
                    mapOf("type" to "peak", "frequencyHz" to 1000.0, "gainDb" to 4),
                ),
            ),
        )

        assertEquals(
            AudioEqualizer(
                listOf(
                    AudioEqualizerBand(AudioEqualizerBandType.HIGH_SHELF, 3000.0, -2.5, 1.0),
                    AudioEqualizerBand(AudioEqualizerBandType.PEAK, 1000.0, 4.0),
                ),
            ),
            equalizer,
        )
        assertEquals(AudioEqualizerBand.DEFAULT_Q, equalizer!!.bands[1].q, 0.0)
        assertNull(
            AudioEqualizer.fromMap(
                mapOf("bands" to listOf(mapOf("type" to "lowShelf", "frequencyHz" to 200))),
            ),
        )
        assertNull(AudioEqualizer.fromMap(mapOf<String, Any>()))
        assertNull(AudioEqualizer.fromMap(null))
    }

    @Test
    fun `skips a band it cannot filter`() {
        val equalizer = AudioEqualizer.fromMap(
            mapOf(
                "bands" to listOf(
                    mapOf("type" to "notch", "frequencyHz" to 1000, "gainDb" to 6),
                    mapOf("type" to "peak", "frequencyHz" to 0, "gainDb" to 6),
                    mapOf("type" to "peak", "gainDb" to 6),
                    mapOf("type" to "peak", "frequencyHz" to 1000, "gainDb" to Double.NaN),
                    mapOf(
                        "type" to "peak",
                        "frequencyHz" to Double.POSITIVE_INFINITY,
                        "gainDb" to 6,
                    ),
                    mapOf("type" to "lowShelf", "frequencyHz" to 200, "gainDb" to 6),
                ),
            ),
        )

        assertEquals(
            listOf(AudioEqualizerBand(AudioEqualizerBandType.LOW_SHELF, 200.0, 6.0)),
            equalizer?.bands,
        )
    }

    @Test
    fun `raising a low shelf lifts low tones and leaves high ones alone`() {
        val equalizer = equalizerOf(AudioEqualizerBand(AudioEqualizerBandType.LOW_SHELF, 200.0, 6.0))

        assertEquals(6.0, gainDb(equalizer, frequency = 40.0), 0.2)
        assertEquals(0.0, gainDb(equalizer, frequency = 5000.0), 0.2)
    }

    @Test
    fun `a peak lifts its own frequency and leaves one three octaves away alone`() {
        val equalizer = equalizerOf(AudioEqualizerBand(AudioEqualizerBandType.PEAK, 1000.0, 6.0))

        assertEquals(6.0, gainDb(equalizer, frequency = 1000.0), 0.2)
        assertEquals(0.0, gainDb(equalizer, frequency = 8000.0), 0.3)
        assertEquals(0.0, gainDb(equalizer, frequency = 125.0), 0.3)
    }

    @Test
    fun `bands add up one after the other`() {
        val equalizer = equalizerOf(
            AudioEqualizerBand(AudioEqualizerBandType.LOW_SHELF, 200.0, 6.0),
            AudioEqualizerBand(AudioEqualizerBandType.PEAK, 1000.0, -6.0),
            AudioEqualizerBand(AudioEqualizerBandType.HIGH_SHELF, 3000.0, 3.0),
        )

        assertEquals(6.0, gainDb(equalizer, frequency = 40.0), 0.3)
        assertEquals(-6.0, gainDb(equalizer, frequency = 1000.0), 0.6)
        assertEquals(3.0, gainDb(equalizer, frequency = 15000.0), 0.3)
    }

    @Test
    fun `retuning keeps the history so the stream goes on without a jump`() {
        val filters = BandEqualizer(48000, 1).apply { retune(bassBoost(6.0)) }
        val played = tone(0 until 4800)
        filters.process(played)

        filters.retune(bassBoost(5.0))
        val next = tone(4800 until 4801)
        filters.process(next)

        // Restarted from silence, the filter would put out the dry 0.2.
        val last = played.last()
        assertTrue("jumped from $last to ${next[0]}", abs(next[0] - last) < 0.01f)
    }

    @Test
    fun `a band turned to 0 dB plays dry at once and comes back without its old history`() {
        val filters = BandEqualizer(48000, 1).apply { retune(bassBoost(12.0)) }
        filters.process(tone(0 until 4800))

        filters.retune(bassBoost(0.0))
        val dry = tone(4800 until 4900)
        filters.process(dry)

        assertTrue(dry.contentEquals(tone(4800 until 4900)))

        filters.retune(bassBoost(1.0))
        val next = tone(4900 until 4901)
        filters.process(next)

        assertEquals(tone(4900 until 4901)[0], next[0], 0.01f)
    }

    @Test
    fun `pcm equalized for a loop is limited where a boost would clip`() {
        val loud = ShortArray(9600) { (30000 * sin(2 * PI * 60.0 * it / 48000)).toInt().toShort() }

        EqualizerPcm.apply(loud, 1, 48000, bassBoost(12.0))

        val ceiling = (PeakLimiter.CEILING * 32768).toInt()
        assertTrue(loud.all { abs(it.toInt()) <= ceiling + 1 })
    }

    @Test
    fun `pcm equalized a block at a time matches one pass over the whole decode`() {
        val equalizer = bassBoost(12.0)
        val channels = 2
        // A loud 60 Hz tone in both channels, long enough for several blocks,
        // that the boost pushes into the limiter.
        val pcm = ShortArray(channels * 20_000) {
            (28000 * sin(2 * PI * 60.0 * (it / channels) / 48000)).toInt().toShort()
        }
        val floats = FloatArray(pcm.size) { EqualizerPcm.toFloat(pcm[it]) }
        BandEqualizer(48000, channels).apply { retune(equalizer) }.process(floats)
        PeakLimiter(48000).process(floats, channels)
        val expected = ShortArray(floats.size) { EqualizerPcm.toShort(floats[it]) }

        EqualizerPcm.apply(pcm, channels, 48000, equalizer)

        assertTrue(pcm.contentEquals(expected))
    }

    @Test
    fun `pcm is left alone without an equalizer`() {
        val pcm = shortArrayOf(1000, -1000, 30000)

        EqualizerPcm.apply(pcm, 1, 48000, null)

        assertTrue(pcm.contentEquals(shortArrayOf(1000, -1000, 30000)))
    }

    /** A 100 Hz tone at 0.2, peaking at every multiple of 4800 samples. */
    private fun tone(samples: IntRange): FloatArray =
        samples.map { (0.2 * cos(2 * PI * 100.0 * it / 48000)).toFloat() }.toFloatArray()

    private fun equalizerOf(vararg bands: AudioEqualizerBand) = AudioEqualizer(bands.toList())

    private fun bassBoost(gainDb: Double) =
        equalizerOf(AudioEqualizerBand(AudioEqualizerBandType.LOW_SHELF, 200.0, gainDb))

    private fun gainDb(equalizer: AudioEqualizer, frequency: Double): Double {
        val sampleRate = 48000
        val input = FloatArray(sampleRate) {
            (0.25 * sin(2 * PI * frequency * it / sampleRate)).toFloat()
        }
        val output = input.copyOf()
        BandEqualizer(sampleRate, 1).apply { retune(equalizer) }.process(output)
        return 20 * log10(rms(output) / rms(input))
    }

    private fun rms(samples: FloatArray): Double {
        val settled = samples.size / 2
        var sum = 0.0
        for (i in settled until samples.size) sum += samples[i].toDouble() * samples[i]
        return sqrt(sum / (samples.size - settled))
    }
}
