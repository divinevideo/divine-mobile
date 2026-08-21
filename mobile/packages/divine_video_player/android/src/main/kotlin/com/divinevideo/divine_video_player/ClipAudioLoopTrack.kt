package com.divinevideo.divine_video_player

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Plays a looping clip's audio outside ExoPlayer, through a static
 * [AudioTrack] that repeats sample-exact in the audio HAL.
 *
 * While the media item carries an audio track, media3 drains and re-anchors
 * its audio sink at every loop discontinuity, on the same thread that releases
 * video frames. Measured on an SM-S942B: the same clip with its audio track
 * stripped loops cleanly, with it the seam is plainly visible. Taking the audio
 * out of the player and looping it here keeps the sound without paying that.
 *
 * Two details decide whether this holds up, both learned the hard way:
 *
 *  * The PCM has to be exactly as long as the **video's** loop, not as long as
 *    whatever end the caller asked for. The feed passes its maximum playback
 *    duration, which is far past the clip; cutting to that leaves nothing to
 *    blend with and drifts the two clocks apart every lap.
 *  * The seam is closed with the material that lies *past* the loop point
 *    rather than by fading both ends to silence. Fading kills the click but
 *    leaves an audible restart; blending makes the last sample of the loop and
 *    its first two consecutive samples of the recording.
 *
 * The remaining cost is that video and audio now run on two clocks. They start
 * together and share a period to the sample, but nothing locks them.
 */
internal class ClipAudioLoopTrack private constructor(
    private val track: AudioTrack,
    private val sampleRate: Int,
    private val frameCount: Int,
) {

    private var released = false

    /**
     * Starts or resumes the loop at [positionMs] of the clip.
     *
     * A static track can only be repositioned while it is not playing, so the
     * head moves first and playback starts after.
     */
    fun play(positionMs: Long, volume: Float) {
        if (released) return
        runCatching {
            track.setVolume(volume)
            if (track.playState != AudioTrack.PLAYSTATE_PLAYING) {
                if (frameCount > 0) {
                    val frame = ((positionMs * sampleRate) / 1000L).toInt()
                    track.setPlaybackHeadPosition(frame % frameCount)
                }
                track.play()
            }
        }
    }

    fun pause() {
        if (released) return
        runCatching { track.pause() }
    }

    fun setVolume(volume: Float) {
        if (released) return
        runCatching { track.setVolume(volume) }
    }

    fun release() {
        if (released) return
        released = true
        runCatching {
            track.pause()
            track.flush()
            track.release()
        }
    }

    companion object {

        /** A feed clip is seconds long; this only bounds a pathological file. */
        private const val MAX_PCM_BYTES = 16 * 1024 * 1024

        private const val DEQUEUE_TIMEOUT_US = 10_000L

        /** Blend length at the seam, taken from beyond the loop point. */
        private const val CROSSFADE_MS = 100L

        /** Fallback when nothing lies beyond it: enough to kill the click. */
        private const val RAMP_MS = 5L

        /**
         * Decodes [uri]'s audio to 16-bit PCM, cut to [loopMs] and blended at
         * the seam, and wraps it in a looping [AudioTrack].
         *
         * [loopMs] must be the duration the player presents, not the media
         * duration of any track.
         *
         * Returns null when there is nothing to play or anything goes wrong;
         * the caller then leaves the audio with ExoPlayer. Blocks on I/O and on
         * the decoder, so it must not run on the platform thread.
         */
        fun create(
            uri: String,
            headers: Map<String, String>,
            loopMs: Long,
        ): ClipAudioLoopTrack? {
            val extractor = MediaExtractor()
            var codec: MediaCodec? = null
            try {
                when {
                    uri.startsWith("http://") || uri.startsWith("https://") ->
                        extractor.setDataSource(uri, headers)
                    uri.startsWith("file://") ->
                        extractor.setDataSource(uri.removePrefix("file://"))
                    else -> extractor.setDataSource(uri)
                }

                var audioIndex = -1
                for (index in 0 until extractor.trackCount) {
                    val format = extractor.getTrackFormat(index)
                    val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                    if (mime.startsWith("audio/") && audioIndex < 0) audioIndex = index
                }
                if (audioIndex < 0 || loopMs <= 0) return null

                val inputFormat = extractor.getTrackFormat(audioIndex)
                val mime = inputFormat.getString(MediaFormat.KEY_MIME) ?: return null
                extractor.selectTrack(audioIndex)
                // The decoder applies the container's gapless trimming and
                // hands back exactly the presented length, which leaves nothing
                // past the loop point to blend with. Dropping those keys is the
                // equivalent of ffmpeg's -ignore_editlist, which is how the
                // prototype gets the material for its crossfade.
                inputFormat.setInteger(MediaFormat.KEY_ENCODER_DELAY, 0)
                inputFormat.setInteger(MediaFormat.KEY_ENCODER_PADDING, 0)
                codec = MediaCodec.createDecoderByType(mime).apply {
                    configure(inputFormat, null, null, 0)
                    start()
                }

                val pcm = ByteArrayOutputStream()
                var sampleRate = inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                var channels = inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                val info = MediaCodec.BufferInfo()
                var sawInputEnd = false
                var sawOutputEnd = false

                while (!sawOutputEnd && pcm.size() < MAX_PCM_BYTES) {
                    if (!sawInputEnd) {
                        val inputIndex = codec.dequeueInputBuffer(DEQUEUE_TIMEOUT_US)
                        if (inputIndex >= 0) {
                            val buffer = codec.getInputBuffer(inputIndex)!!
                            val size = extractor.readSampleData(buffer, 0)
                            if (size < 0) {
                                codec.queueInputBuffer(
                                    inputIndex, 0, 0, 0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                )
                                sawInputEnd = true
                            } else {
                                codec.queueInputBuffer(
                                    inputIndex, 0, size, extractor.sampleTime, 0,
                                )
                                extractor.advance()
                            }
                        }
                    }
                    when (val out = codec.dequeueOutputBuffer(info, DEQUEUE_TIMEOUT_US)) {
                        MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            val outputFormat = codec.outputFormat
                            sampleRate = outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                            channels = outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        }
                        MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                        else -> if (out >= 0) {
                            val buffer = codec.getOutputBuffer(out)!!
                            if (info.size > 0) {
                                val chunk = ByteArray(info.size)
                                buffer.position(info.offset)
                                buffer.get(chunk)
                                pcm.write(chunk)
                            }
                            codec.releaseOutputBuffer(out, false)
                            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                sawOutputEnd = true
                            }
                        }
                    }
                }

                val raw = pcm.toByteArray()
                if (raw.isEmpty() || sampleRate <= 0 || channels <= 0) return null

                val samples = ShortArray(raw.size / 2)
                ByteBuffer.wrap(raw).order(ByteOrder.LITTLE_ENDIAN)
                    .asShortBuffer().get(samples)
                val decodedFrames = samples.size / channels

                // [loopMs] is the length the player presents, which is what the
                // picture loops on. The extractor's track duration is the media
                // length and ignores the edit list -- for a clip whose edit list
                // was corrected those differ, and looping on the media length
                // walks the sound away from the picture every lap.
                val loopFrames = minOf(
                    (loopMs * sampleRate / 1000L).toInt(),
                    decodedFrames,
                )
                if (loopFrames <= 0) return null

                // Blend the seam shut. The prototype takes the material that
                // lies past the loop point, which is the better source: the
                // wrap then lands on two consecutive samples of the recording.
                // Android's decoder applies the container's gapless trimming
                // and hands back exactly the presented length, so there usually
                // is none -- measured as "0 frames spare" on every fixture. The
                // loop's own tail is then blended into its head instead, which
                // is not the same material but closes the same step.
                // Blend the seam shut with the material that lies past the
                // loop point: the wrap then lands on two consecutive samples of
                // the recording, which is what makes the prototype's loop sound
                // closed rather than restarted.
                //
                // Folding the loop's own tail into its head instead was tried
                // and is worse than doing nothing: the tail has to fade out or
                // it is heard twice, so the seam becomes a dip to near-silence
                // followed by material that jumps back. Without spare material
                // the only honest option is a short ramp, which kills the click
                // and leaves the restart audible.
                val spare = decodedFrames - loopFrames
                val fadeFrames = minOf(
                    (CROSSFADE_MS * sampleRate / 1000L).toInt(),
                    spare,
                )
                for (i in 0 until fadeFrames) {
                    val a = i.toFloat() / fadeFrames
                    for (channel in 0 until channels) {
                        val head = samples[i * channels + channel].toFloat()
                        val past = samples[(loopFrames + i) * channels + channel]
                            .toFloat()
                        samples[i * channels + channel] =
                            (past * (1f - a) + head * a)
                                .coerceIn(-32768f, 32767f).toInt().toShort()
                    }
                }
                if (fadeFrames == 0) {
                    val rampFrames = minOf(
                        (RAMP_MS * sampleRate / 1000L).toInt(),
                        loopFrames / 8,
                    )
                    for (i in 0 until rampFrames) {
                        val gain = i.toFloat() / rampFrames
                        for (channel in 0 until channels) {
                            val head = i * channels + channel
                            val tail = (loopFrames - 1 - i) * channels + channel
                            samples[head] = (samples[head] * gain).toInt().toShort()
                            samples[tail] = (samples[tail] * gain).toInt().toShort()
                        }
                    }
                }

                val bytes = ByteArray(loopFrames * channels * 2)
                ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
                    .asShortBuffer().put(samples, 0, loopFrames * channels)

                val track = AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                            .build(),
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(
                                if (channels >= 2) {
                                    AudioFormat.CHANNEL_OUT_STEREO
                                } else {
                                    AudioFormat.CHANNEL_OUT_MONO
                                },
                            )
                            .build(),
                    )
                    .setBufferSizeInBytes(bytes.size)
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .build()

                if (track.write(bytes, 0, bytes.size) < bytes.size) {
                    track.release()
                    return null
                }
                // -1 repeats forever. Loop points count frames, not bytes.
                track.setLoopPoints(0, loopFrames, -1)

                DivineVideoPlayerLog.debug(
                    "Looping clip audio outside ExoPlayer: ${loopFrames} frames " +
                        "at ${sampleRate}Hz, ${fadeFrames} frame crossfade " +
                        "(${if (fadeFrames > 0) "crossfade" else "ramp only"}), " +
                        "${spare} frames spare",
                    name = "DivineVideoPlayer.AudioLoop",
                )
                return ClipAudioLoopTrack(track, sampleRate, loopFrames)
            } catch (e: Exception) {
                DivineVideoPlayerLog.warning(
                    "Could not build looping audio for $uri: $e",
                    name = "DivineVideoPlayer.AudioLoop",
                )
                return null
            } finally {
                runCatching { codec?.stop() }
                runCatching { codec?.release() }
                runCatching { extractor.release() }
            }
        }
    }
}
