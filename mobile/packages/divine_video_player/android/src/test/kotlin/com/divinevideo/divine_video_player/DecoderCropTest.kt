package com.divinevideo.divine_video_player

import android.media.MediaFormat
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins how a codec's output format becomes the part of the texture Dart
 * draws, the 1080-coded-as-1088 padding H.264 decoders hand out (#10584).
 */
class DecoderCropTest {

    @Test
    fun `of reads padding columns from inclusive crop values`() {
        val crop = DecoderCrop.of(
            width = 1088,
            height = 1920,
            cropLeft = 0,
            cropTop = 0,
            cropRight = 1079,
            cropBottom = 1919,
        )

        assertEquals(DecoderCrop(1088, 1920, 0, 0, 1080, 1920), crop)
        assertEquals(listOf(0.0, 0.0, 1080.0 / 1088, 1.0), crop!!.toFractions())
    }

    @Test
    fun `of keeps a crop that does not start at the buffer origin`() {
        val crop = DecoderCrop.of(
            width = 1920,
            height = 1088,
            cropLeft = 0,
            cropTop = 4,
            cropRight = 1919,
            cropBottom = 1083,
        )

        assertEquals(listOf(0.0, 4.0 / 1088, 1.0, 1084.0 / 1088), crop!!.toFractions())
    }

    @Test
    fun `of returns null when the picture fills the buffer`() {
        assertNull(DecoderCrop.of(720, 1280, 0, 0, 719, 1279))
    }

    @Test
    fun `of returns null for a crop outside the buffer or without area`() {
        assertNull(DecoderCrop.of(1088, 1920, 0, 0, 1088, 1919))
        assertNull(DecoderCrop.of(1088, 1920, -1, 0, 1079, 1919))
        assertNull(DecoderCrop.of(1088, 1920, 0, 0, 1079, 1920))
        assertNull(DecoderCrop.of(1088, 1920, 500, 0, 499, 1919))
        assertNull(DecoderCrop.of(0, 0, 0, 0, -1, -1))
    }

    @Test
    fun `of reads the codec output format`() {
        val format = mediaFormat(
            MediaFormat.KEY_WIDTH to 1088,
            MediaFormat.KEY_HEIGHT to 1920,
            "crop-left" to 0,
            "crop-top" to 0,
            "crop-right" to 1079,
            "crop-bottom" to 1919,
        )

        assertEquals(DecoderCrop(1088, 1920, 0, 0, 1080, 1920), DecoderCrop.of(format))
    }

    @Test
    fun `of returns null for a format without crop keys`() {
        val format = mediaFormat(
            MediaFormat.KEY_WIDTH to 1088,
            MediaFormat.KEY_HEIGHT to 1920,
        )

        assertNull(DecoderCrop.of(format))
    }

    private fun mediaFormat(vararg values: Pair<String, Int>): MediaFormat {
        val map = values.toMap()
        val format = mockk<MediaFormat>()
        every { format.containsKey(any()) } answers { firstArg<String>() in map }
        every { format.getInteger(any()) } answers { map.getValue(firstArg()) }
        return format
    }
}
