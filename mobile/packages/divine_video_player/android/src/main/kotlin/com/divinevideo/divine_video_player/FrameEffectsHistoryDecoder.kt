package com.divinevideo.divine_video_player

import android.graphics.Bitmap
import android.graphics.SurfaceTexture
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.opengl.EGL14
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.view.Surface
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.UnstableApi
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.TimeoutException

/**
 * Decodes the earlier frames frame effects need after a seek, in one pass
 * through the clip from the keyframe before the oldest of them.
 * [android.media.MediaMetadataRetriever] decodes every frame on its own
 * from its keyframe, which took about a second for a five-frame echo trail.
 *
 * Frames are drawn through a [SurfaceTexture], so the decoder applies the
 * clip's crop and rotation, and are read back bottom row first, the way a
 * frame texture is laid out. Each is [width] x [height].
 *
 * Runs on the calling thread, which must not have a GL context current.
 */
@UnstableApi
internal class FrameEffectsHistoryDecoder(private val width: Int, private val height: Int) {

    /**
     * Decodes, for each time in [targetsUs], the last frame of the file at
     * [path] shown at or before it, the frame playback would have kept for
     * it. Returns nothing once [isCancelled] says the frames are useless.
     *
     * Throws when the clip cannot be decoded this way.
     */
    fun decode(
        path: String,
        targetsUs: List<Long>,
        isCancelled: () -> Boolean,
    ): List<FrameEffectsState.DecodedFrame> {
        val wanted = targetsUs.sorted()
        if (wanted.isEmpty()) return emptyList()
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        var output: Output? = null
        try {
            extractor.setDataSource(path)
            val track = (0 until extractor.trackCount).firstOrNull { index ->
                extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true
            } ?: throw IllegalStateException("no video track")
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            output = Output(width, height)
            codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            codec.configure(format, output.surface, null, 0)
            codec.start()
            extractor.seekTo(wanted.first(), MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            return run(extractor, codec, output, wanted, isCancelled)
        } finally {
            try {
                codec?.stop()
            } catch (e: IllegalStateException) {
                // A codec that failed to start has nothing to stop.
            }
            codec?.release()
            extractor.release()
            output?.release()
        }
    }

    private fun run(
        extractor: MediaExtractor,
        codec: MediaCodec,
        output: Output,
        wanted: List<Long>,
        isCancelled: () -> Boolean,
    ): List<FrameEffectsState.DecodedFrame> {
        val frames = ArrayList<FrameEffectsState.DecodedFrame>()
        val info = MediaCodec.BufferInfo()
        val deadline = SystemClock.uptimeMillis() + TIMEOUT_MS
        val lastUs = wanted.last()
        val matcher = HistoryTargetMatcher(wanted)
        var inputDone = false
        var heldIndex = NONE
        var heldUs = 0L
        while (!matcher.isDone) {
            if (isCancelled()) return emptyList()
            if (SystemClock.uptimeMillis() > deadline) throw TimeoutException("decoding took too long")
            if (!inputDone) {
                val inIndex = codec.dequeueInputBuffer(DEQUEUE_TIMEOUT_US)
                if (inIndex >= 0) {
                    val size = extractor.readSampleData(codec.getInputBuffer(inIndex)!!, 0)
                    val timeUs = extractor.sampleTime
                    // Past the newest target the frames only matter until the
                    // decoder has reordered the ones before it out.
                    if (size < 0 || timeUs > lastUs + LOOKAHEAD_US) {
                        codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(inIndex, 0, size, timeUs, 0)
                        extractor.advance()
                    }
                }
            }
            val outIndex = codec.dequeueOutputBuffer(info, DEQUEUE_TIMEOUT_US)
            if (outIndex < 0) continue
            val ended = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
            val timeUs = info.presentationTimeUs
            if (heldIndex != NONE) {
                val served = matcher.servedBy(heldUs, nextUs = if (ended) null else timeUs)
                if (served.isEmpty()) {
                    codec.releaseOutputBuffer(heldIndex, false)
                } else {
                    codec.releaseOutputBuffer(heldIndex, true)
                    val bitmap = output.capture()
                    served.forEach { frames += FrameEffectsState.DecodedFrame(it, heldUs, bitmap) }
                }
                heldIndex = NONE
            }
            if (ended) {
                codec.releaseOutputBuffer(outIndex, false)
                break
            }
            heldIndex = outIndex
            heldUs = timeUs
        }
        return frames
    }

    /** The surface the decoder draws into, and the GL that reads it back. */
    private class Output(private val width: Int, private val height: Int) {
        private val display: EGLDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        private val context: EGLContext
        private val eglSurface: EGLSurface
        private val thread = HandlerThread("FrameEffectsHistoryDecoder").apply { start() }
        private val lock = Object()
        private var frameAvailable = false
        private val externalTexture: Int
        private val surfaceTexture: SurfaceTexture
        val surface: Surface
        private val program: GlProgram
        private val texture: Int
        private val fbo: Int
        private val pixels = ByteBuffer.allocateDirect(width * height * 4).order(ByteOrder.nativeOrder())
        private val matrix = FloatArray(16)

        init {
            val version = IntArray(2)
            check(EGL14.eglInitialize(display, version, 0, version, 1)) { "eglInitialize failed" }
            val configs = arrayOfNulls<android.opengl.EGLConfig>(1)
            val count = IntArray(1)
            val attributes = intArrayOf(
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8, EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT, EGL14.EGL_NONE,
            )
            check(EGL14.eglChooseConfig(display, attributes, 0, configs, 0, 1, count, 0) && count[0] > 0) {
                "no EGL config"
            }
            context = EGL14.eglCreateContext(
                display, configs[0], EGL14.EGL_NO_CONTEXT,
                intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0,
            )
            eglSurface = EGL14.eglCreatePbufferSurface(
                display, configs[0], intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0,
            )
            check(EGL14.eglMakeCurrent(display, eglSurface, eglSurface, context)) { "eglMakeCurrent failed" }
            externalTexture = GlUtil.createExternalTexture()
            surfaceTexture = SurfaceTexture(externalTexture)
            surfaceTexture.setOnFrameAvailableListener({
                synchronized(lock) {
                    frameAvailable = true
                    lock.notifyAll()
                }
            }, Handler(thread.looper))
            surface = Surface(surfaceTexture)
            program = GlProgram(VERTEX_SHADER, FRAGMENT_SHADER)
            texture = GlUtil.createTexture(width, height, false)
            fbo = GlUtil.createFboForTexture(texture)
        }

        /** Waits for the frame the decoder just released and reads it back. */
        fun capture(): Bitmap {
            synchronized(lock) {
                val deadline = SystemClock.uptimeMillis() + FRAME_TIMEOUT_MS
                while (!frameAvailable) {
                    val wait = deadline - SystemClock.uptimeMillis()
                    if (wait <= 0) throw TimeoutException("decoded frame never arrived")
                    lock.wait(wait)
                }
                frameAvailable = false
            }
            surfaceTexture.updateTexImage()
            surfaceTexture.getTransformMatrix(matrix)
            GlUtil.focusFramebufferUsingCurrentContext(fbo, width, height)
            program.use()
            program.setSamplerTexIdUniform("uTexSampler", externalTexture, 0)
            program.setFloatsUniform("uTexTransform", matrix)
            val vertices = GlUtil.getNormalizedCoordinateBounds()
            program.setBufferAttribute("aFramePosition", vertices, if (vertices.size == 8) 2 else 4)
            program.bindAttributesAndUniforms()
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            pixels.rewind()
            GLES20.glReadPixels(0, 0, width, height, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, pixels)
            GlUtil.checkGlError()
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            pixels.rewind()
            bitmap.copyPixelsFromBuffer(pixels)
            return bitmap
        }

        fun release() {
            try {
                program.delete()
                GlUtil.deleteFbo(fbo)
                GlUtil.deleteTexture(texture)
                GlUtil.deleteTexture(externalTexture)
            } catch (e: GlUtil.GlException) {
                // The context goes away below, and its objects with it.
            }
            surface.release()
            surfaceTexture.release()
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            EGL14.eglDestroySurface(display, eglSurface)
            EGL14.eglDestroyContext(display, context)
            // Not eglTerminate: the display is the process's own, shared
            // with Flutter and the player.
            EGL14.eglReleaseThread()
            thread.quitSafely()
        }
    }

    private companion object {
        const val NONE = -1
        const val DEQUEUE_TIMEOUT_US = 10_000L
        const val LOOKAHEAD_US = 300_000L
        const val TIMEOUT_MS = 3_000L
        const val FRAME_TIMEOUT_MS = 500L

        const val VERTEX_SHADER =
            "attribute vec4 aFramePosition;\n" +
                "uniform mat4 uTexTransform;\n" +
                "varying vec2 vTexCoord;\n" +
                "void main() {\n" +
                "  gl_Position = aFramePosition;\n" +
                "  vTexCoord = (uTexTransform * vec4(aFramePosition.xy * 0.5 + 0.5, 0.0, 1.0)).xy;\n" +
                "}"

        const val FRAGMENT_SHADER =
            "#extension GL_OES_EGL_image_external : require\n" +
                "precision mediump float;\n" +
                "uniform samplerExternalOES uTexSampler;\n" +
                "varying vec2 vTexCoord;\n" +
                "void main() {\n" +
                "  gl_FragColor = texture2D(uTexSampler, vTexCoord);\n" +
                "}"
    }
}

/**
 * Decides which target times each decoded frame serves: for every target,
 * the last frame shown at or before it, as playback would have kept it.
 * Frames arrive in presentation order, and a frame is only known to be the
 * last one for a target once the frame after it lies past that target.
 */
internal class HistoryTargetMatcher(targetsUs: List<Long>) {
    private val wanted = targetsUs.sorted()
    private var next = 0

    /** Whether every target has been decided. */
    val isDone: Boolean get() = next >= wanted.size

    /**
     * The targets the frame at [heldUs] serves, now that the frame after it
     * lies at [nextUs], or the stream ended when that is null. A target
     * before the first decoded frame gets none.
     */
    fun servedBy(heldUs: Long, nextUs: Long?): List<Long> {
        val served = ArrayList<Long>()
        while (next < wanted.size && (nextUs == null || nextUs > wanted[next] + TOLERANCE_US)) {
            if (heldUs <= wanted[next] + TOLERANCE_US) served += wanted[next]
            next++
        }
        return served
    }

    private companion object {
        /** Timestamps rounded to the millisecond still count as on time. */
        const val TOLERANCE_US = 1_000L
    }
}
