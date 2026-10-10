package com.divinevideo.divine_video_player

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.util.UnstableApi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin

/**
 * Pins that each clip plays through its own equalizer, that a change is heard
 * from the next buffer, and that nothing changes the audio without one.
 */
@UnstableApi
class EqualizerAudioProcessorTest {

    private val bassBoost = AudioEqualizer(
        listOf(AudioEqualizerBand(AudioEqualizerBandType.LOW_SHELF, 200.0, 12.0)),
    )

    private fun <T : EqualizerAudioProcessor> T.started(): T = apply {
        configure(AudioProcessor.AudioFormat(48_000, 1, C.ENCODING_PCM_16BIT))
        flush(AudioProcessor.StreamMetadata.DEFAULT)
    }

    /** A 60 Hz tone at a fifth of full scale. */
    private fun tone(): ShortArray =
        ShortArray(4800) { (6000 * sin(2 * PI * 60.0 * it / 48_000)).toInt().toShort() }

    private fun EqualizerAudioProcessor.push(samples: ShortArray): ShortArray {
        val input = ByteBuffer.allocateDirect(samples.size * 2).order(ByteOrder.nativeOrder())
        samples.forEach { input.putShort(it) }
        input.flip()
        queueInput(input)
        val output = output
        return ShortArray(output.remaining() / 2) { output.short }
    }

    private fun ShortArray.peak(): Int = maxOf { abs(it.toInt()) }

    @Test
    fun `stays out of the chain for audio that is not 16-bit`() {
        val processor = TrackEqualizerAudioProcessor()

        processor.configure(AudioProcessor.AudioFormat(48_000, 1, C.ENCODING_PCM_FLOAT))

        assertFalse(processor.isActive)
    }

    @Test
    fun `copies a track through untouched while it has no equalizer`() {
        val processor = TrackEqualizerAudioProcessor().started()
        val input = tone()

        assertTrue(processor.push(input).contentEquals(input))
    }

    @Test
    fun `hears a track's new equalizer from the next buffer`() {
        val processor = TrackEqualizerAudioProcessor().started()
        val flat = processor.push(tone()).peak()

        processor.equalizer = bassBoost
        processor.push(tone())
        val boosted = processor.push(tone()).peak()

        assertTrue("flat $flat, boosted $boosted", boosted > flat * 3)
    }

    @Test
    fun `plays each clip through its own equalizer`() {
        val processor = ClipEqualizerAudioProcessor().apply {
            equalizers = listOf(null, bassBoost)
        }

        processor.nextClipIndex = 0
        processor.started()
        val input = tone()
        val first = processor.push(input)

        processor.nextClipIndex = 1
        processor.flush(AudioProcessor.StreamMetadata.DEFAULT)
        processor.push(tone())
        val second = processor.push(tone())

        assertTrue(first.contentEquals(input))
        assertEquals(1, processor.clipIndex)
        assertTrue(second.peak() > input.peak() * 3)
    }

    @Test
    fun `switches clips only where the sink flushes for the next stream`() {
        val processor = ClipEqualizerAudioProcessor().apply {
            equalizers = listOf(bassBoost, null)
        }
        processor.nextClipIndex = 0
        processor.started()
        processor.push(tone())

        // Told the next clip while the current one still plays out.
        processor.nextClipIndex = 1
        val stillFirst = processor.push(tone())

        assertNotEquals(tone().peak(), stillFirst.peak())
        assertEquals(0, processor.clipIndex)
    }

    @Test
    fun `plays a clip it cannot place unchanged`() {
        val processor = ClipEqualizerAudioProcessor().apply {
            equalizers = listOf(bassBoost)
        }.started()
        val input = tone()

        assertTrue(processor.push(input).contentEquals(input))
    }
}
