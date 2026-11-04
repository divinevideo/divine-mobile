package com.divinevideo.divine_video_player

import android.media.MediaFormat

/**
 * Where the picture sits inside the decoder's output buffers, when they are
 * larger than the picture.
 *
 * H.264 codes in 16-pixel macroblocks, so a 1080-pixel side is decoded as
 * 1088 and the SPS crops the extra 8 rows or columns off. The legacy
 * SurfaceTexture and a Media3 GL stage apply that crop; Flutter's
 * `ImageReaderSurfaceProducer` hands the whole buffer to the engine, which
 * draws the padding as part of the picture, so Dart has to draw only this
 * part of the texture. See [DivineVideoPlayerInstance.dartAppliesCrop].
 *
 * [right] and [bottom] are exclusive, in buffer pixels before rotation.
 */
internal data class DecoderCrop(
    val bufferWidth: Int,
    val bufferHeight: Int,
    val left: Int,
    val top: Int,
    val right: Int,
    val bottom: Int,
) {
    /** The crop as fractions of the buffer, left, top, right, bottom, as Dart reads it. */
    fun toFractions(): List<Double> = listOf(
        left.toDouble() / bufferWidth,
        top.toDouble() / bufferHeight,
        right.toDouble() / bufferWidth,
        bottom.toDouble() / bufferHeight,
    )

    override fun toString(): String =
        "buffer ${bufferWidth}x$bufferHeight, picture $left,$top-$right,$bottom"

    companion object {
        // The MediaFormat.KEY_CROP_* constants only exist from API 33; the
        // keys themselves are older, and Media3 reads them by name too.
        private const val KEY_CROP_LEFT = "crop-left"
        private const val KEY_CROP_TOP = "crop-top"
        private const val KEY_CROP_RIGHT = "crop-right"
        private const val KEY_CROP_BOTTOM = "crop-bottom"

        /**
         * Reads the crop from a codec's output [format], or returns `null`
         * when it has none or the picture fills the whole buffer.
         */
        fun of(format: MediaFormat): DecoderCrop? {
            val keys = listOf(
                MediaFormat.KEY_WIDTH,
                MediaFormat.KEY_HEIGHT,
                KEY_CROP_LEFT,
                KEY_CROP_TOP,
                KEY_CROP_RIGHT,
                KEY_CROP_BOTTOM,
            )
            if (!keys.all(format::containsKey)) return null
            return of(
                width = format.getInteger(MediaFormat.KEY_WIDTH),
                height = format.getInteger(MediaFormat.KEY_HEIGHT),
                cropLeft = format.getInteger(KEY_CROP_LEFT),
                cropTop = format.getInteger(KEY_CROP_TOP),
                cropRight = format.getInteger(KEY_CROP_RIGHT),
                cropBottom = format.getInteger(KEY_CROP_BOTTOM),
            )
        }

        /**
         * Builds the crop from MediaCodec's output-format values, whose
         * `crop-right` and `crop-bottom` are inclusive. Returns `null` when
         * the picture fills the buffer or the values do not describe a
         * rectangle inside it.
         */
        fun of(
            width: Int,
            height: Int,
            cropLeft: Int,
            cropTop: Int,
            cropRight: Int,
            cropBottom: Int,
        ): DecoderCrop? {
            val right = cropRight + 1
            val bottom = cropBottom + 1
            val insideBuffer = cropLeft >= 0 && cropTop >= 0 &&
                right <= width && bottom <= height
            if (!insideBuffer || cropLeft >= right || cropTop >= bottom) return null
            if (cropLeft == 0 && cropTop == 0 && right == width && bottom == height) return null
            return DecoderCrop(width, height, cropLeft, cropTop, right, bottom)
        }
    }
}
