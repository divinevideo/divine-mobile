package com.divinevideo.divine_video_player

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTimestamp
import android.media.AudioTrack
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
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
 * Video and audio run on two clocks. They share a period to the sample, and
 * [LoopAudioSync] places the head against the picture at every start and
 * steers out whatever gap remains.
 */
internal class ClipAudioLoopTrack private constructor(
    private val track: AudioTrack,
    private val sampleRate: Int,
    private val frameCount: Int,
) {

    private var released = false

    private val sync = LoopAudioSync(frameCount.toLong(), sampleRate)
    private val timestamp = AudioTimestamp()

    /**
     * Starts or resumes the loop in step with the picture at [positionUs].
     *
     * The head is placed ahead of the picture by what the output takes to
     * carry a frame to the speaker (see [LoopAudioSync]), so the first sound
     * heard belongs to the frame on screen at that moment rather than to the
     * one `play` was called on. A static track can only be repositioned while
     * it is not playing, so the head moves first and playback starts after.
     */
    fun play(positionUs: Long, volume: Float) {
        if (released) return
        runCatching {
            track.setVolume(volume)
            if (track.playState != AudioTrack.PLAYSTATE_PLAYING) {
                startAt(positionUs, learn = volume > 0f)
            }
        }
    }

    /**
     * Moves the loop to [positionUs] of the clip.
     *
     * The player's own seek only moves the picture; without this the sound
     * keeps running from wherever it had got to. A paused loop needs nothing:
     * [play] places the head against the picture when it resumes.
     */
    fun seekTo(positionUs: Long) = realign(positionUs)

    /**
     * Places a running loop again against the picture at [positionUs].
     *
     * [measuredErrorUs] is how far the placement being replaced was found to
     * be off; the new one allows for the pipeline that much less, rather than
     * guessing again.
     *
     * Teaches nothing: it is used on a muted loop lining up under another
     * sound, and on a seek, neither of which starts like a play does.
     */
    fun realign(positionUs: Long, measuredErrorUs: Long = 0L) {
        if (released) return
        runCatching {
            if (track.playState != AudioTrack.PLAYSTATE_PLAYING) return
            track.pause()
            startAt(
                positionUs,
                learn = false,
                latencyUs = if (measuredErrorUs == 0L) {
                    LoopAudioSync.startLatencyUs
                } else {
                    sync.anchorLatencyUs - measuredErrorUs
                },
            )
        }
    }

    /**
     * Measures how far the sound is from the picture at [videoPositionUs],
     * sampled at [nowNanos], and steers it back.
     *
     * Returns the gap in microseconds — positive when the sound is ahead — or
     * `null` when the track has not yet reported a frame heard since it last
     * started.
     */
    fun sync(videoPositionUs: Long, nowNanos: Long): Long? {
        if (released) return null
        return runCatching {
            if (track.playState != AudioTrack.PLAYSTATE_PLAYING) return null
            if (!track.getTimestamp(timestamp)) return null
            val errorUs = sync.errorUs(
                presentedFrame = timestamp.framePosition,
                presentedNanos = timestamp.nanoTime,
                videoPositionUs = videoPositionUs,
                nowNanos = nowNanos,
            ) ?: return null
            when (sync.correct(errorUs)) {
                LoopAudioSync.Correction.REANCHOR -> {
                    DivineVideoPlayerLog.info(
                        "Loop audio ${errorUs / 1000} ms off the picture; placing it again",
                        name = "DivineVideoPlayer.AudioLoop",
                    )
                    val elapsedUs = (System.nanoTime() - nowNanos) / 1000L
                    track.pause()
                    startAt(videoPositionUs + elapsedUs, learn = true)
                }
                LoopAudioSync.Correction.STEER -> applyRate()
            }
            errorUs
        }.getOrNull()
    }

    private fun startAt(
        positionUs: Long,
        learn: Boolean,
        latencyUs: Long = LoopAudioSync.startLatencyUs,
    ) {
        val counterFrame = track.playbackHeadPosition.toLong() and UNSIGNED_INT_MASK
        val bufferFrame = sync.anchor(
            positionUs,
            counterFrame,
            System.nanoTime(),
            learn,
            latencyUs.coerceAtLeast(0L),
        )
        applyRate()
        track.setPlaybackHeadPosition(bufferFrame.toInt())
        track.play()
    }

    private fun applyRate() {
        val rate = Math.round(sampleRate * sync.rateFactor).toInt()
        if (rate != track.playbackRate) track.setPlaybackRate(rate)
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

        /** The consumed-frame counter is an unsigned 32-bit value in an `int`. */
        private const val UNSIGNED_INT_MASK = 0xFFFF_FFFFL

        /** A feed clip is seconds long; this only bounds a pathological file. */
        private const val MAX_PCM_BYTES = 16 * 1024 * 1024

        private const val DEQUEUE_TIMEOUT_US = 10_000L

        /**
         * Decodes [uri]'s audio to 16-bit PCM, cut to [loopUs] and blended at
         * the seam, and wraps it in a looping [AudioTrack].
         *
         * [loopUs] must be the duration the player presents, not the media
         * duration of any track.
         *
         * A remote [uri] is read through [remoteSourceFactory] when one is
         * given — the player's own cache-backed factory, so the bytes the
         * player has already downloaded are not fetched a second time — and
         * with the extractor's own HTTP stack otherwise. Local sources are
         * opened directly either way; there is nothing to cache for them.
         *
         * Returns null when there is nothing to play or anything goes wrong;
         * the caller then leaves the audio with ExoPlayer. Blocks on I/O and on
         * the decoder, so it must not run on the platform thread.
         */
        @UnstableApi
        fun create(
            uri: String,
            headers: Map<String, String>,
            loopUs: Long,
            remoteSourceFactory: DataSource.Factory? = null,
        ): ClipAudioLoopTrack? {
            val extractor = MediaExtractor()
            var codec: MediaCodec? = null
            var remoteSource: DataSourceMediaDataSource? = null
            try {
                when {
                    uri.startsWith("http://") || uri.startsWith("https://") ->
                        if (remoteSourceFactory != null) {
                            remoteSource =
                                DataSourceMediaDataSource(remoteSourceFactory, Uri.parse(uri))
                            extractor.setDataSource(remoteSource)
                        } else {
                            extractor.setDataSource(uri, headers)
                        }
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
                if (audioIndex < 0 || loopUs <= 0) return null

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
                // Where the sound begins on the clip's timeline. The buffers
                // are concatenated, so only their first timestamp can say; a
                // track that starts late, or one stamped before zero by its
                // gapless edit, is placed by [LoopPcm.prepare] from this.
                var firstPresentationUs: Long? = null
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
                                if (firstPresentationUs == null) {
                                    firstPresentationUs = info.presentationTimeUs
                                }
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
                // A wider decode would be written to a stereo track as it
                // stands and played as interleaved nonsense, so it stays with
                // ExoPlayer.
                if (raw.isEmpty() || sampleRate <= 0 || channels !in 1..2) return null

                val samples = ShortArray(raw.size / 2)
                ByteBuffer.wrap(raw).order(ByteOrder.LITTLE_ENDIAN)
                    .asShortBuffer().get(samples)

                val startUs = firstPresentationUs ?: 0L
                val prepared = LoopPcm.prepare(
                    samples = samples,
                    channels = channels,
                    sampleRate = sampleRate,
                    loopUs = loopUs,
                    startUs = startUs,
                ) ?: return null
                val loopFrames = prepared.loopFrames
                val fadeFrames = prepared.fadeFrames
                val fromPast = prepared.blendedFromPastTheLoop

                val bytes = ByteArray(loopFrames * channels * 2)
                ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
                    .asShortBuffer().put(prepared.samples, 0, loopFrames * channels)

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
                                if (channels == 2) {
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
                // A rejected loop reports its failure in the return value
                // rather than throwing, and the caller has already taken the
                // audio away from the renderer — so an unchecked failure here
                // plays the clip once and leaves it silent for good.
                if (track.setLoopPoints(0, loopFrames, -1) != AudioTrack.SUCCESS) {
                    DivineVideoPlayerLog.warning(
                        "Could not loop clip audio for $uri; leaving it with ExoPlayer",
                        name = "DivineVideoPlayer.AudioLoop",
                    )
                    track.release()
                    return null
                }

                DivineVideoPlayerLog.debug(
                    "Looping clip audio outside ExoPlayer: ${loopFrames} frames " +
                        "at ${sampleRate}Hz for ${loopUs} us presented, " +
                        "${samples.size / channels} decoded from ${startUs} us, " +
                        "${fadeFrames} frame ${if (fromPast) "crossfade" else "ramp"}",
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
                runCatching { remoteSource?.close() }
            }
        }
    }
}
