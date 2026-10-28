// ABOUTME: Scales video frames up in Media3's GL stage to the size the texture is
// ABOUTME: shown at, so Flutter draws them 1:1 instead of stretching them bilinearly

package com.divinevideo.divine_video_player

import android.app.ActivityManager
import android.content.Context
import android.opengl.GLES20
import androidx.media3.common.GlObjectsProvider
import androidx.media3.common.GlTextureInfo
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram
import java.util.concurrent.Executor

/**
 * Flutter draws a video texture into its on-screen rectangle with bilinear
 * sampling, so a 720p rendition shown across a 1080-wide screen is
 * stretched about 1.6x and its edges go soft. This stage does that upscale
 * itself, before Flutter sees the frame, to the exact pixel size Dart
 * measured for the texture, so Flutter's draw becomes a 1:1 copy.
 *
 * [Mode.LANCZOS] resamples with a separable Lanczos-3 filter, the same
 * baseline Meta runs at playback; on a Galaxy S26 it raised VMAF from 76.9
 * to 83.9 for a 720p rendition shown full screen. [Mode.BILINEAR] is the
 * same stage with a plain bilinear upscale and only exists to measure what
 * the stage itself costs.
 *
 * The stage follows a new target without restarting playback: Media3 sizes
 * a stage only when its input size changes, so this program keeps its own
 * output texture and resizes it whenever the wanted size differs.
 */
@UnstableApi
internal object VideoUpscale {
    enum class Mode {
        OFF,
        LANCZOS,
        BILINEAR,
        ;

        companion object {
            /** Reads the value Dart sends at creation and the debug property takes. */
            fun fromWire(value: String?): Mode = when (value) {
                "lanczos" -> LANCZOS
                "bilinear" -> BILINEAR
                else -> OFF
            }
        }
    }

    /**
     * `adb shell setprop debug.divine.video_upscale lanczos|bilinear|off`
     * overrides what the app asks for, on every device. Read once, when the
     * first player asks, so restart the app after changing it.
     */
    private const val OVERRIDE_PROPERTY = "debug.divine.video_upscale"

    /**
     * `1` waits for the GPU around every frame and logs the stage's time per
     * frame. That wait stalls the pipeline, so never leave it on while
     * judging smoothness.
     */
    private const val TIMING_PROPERTY = "debug.divine.video_upscale_timing"

    /**
     * Devices with less memory than this, which covers every phone sold
     * with less than 6 GB, keep Flutter's own scaling. On a Galaxy S26 the
     * GL stage cost about 70 MB of graphics memory per player even at the
     * frame's own size, and about 110 MB for a full-screen upscale; a feed
     * keeps three players. The low-memory devices this excludes are also
     * the ones with the weakest GPUs, where Meta falls back to simpler
     * scaling too.
     */
    const val MIN_TOTAL_MEMORY_BYTES = 5_500L * 1024 * 1024

    /**
     * The largest output, in pixels, the stage draws: a 1440x3200 phone
     * screen. A tablet-sized target keeps the frame at its own size rather
     * than allocating buffers twice that big.
     */
    const val MAX_OUTPUT_PIXELS = 1440L * 3200

    private val override: Mode? by lazy { systemProperty(OVERRIDE_PROPERTY)?.let(Mode::fromWire) }

    private val timing: Boolean by lazy { systemProperty(TIMING_PROPERTY) == "1" }

    /** The mode a new texture player runs with on this device. */
    fun resolveMode(requested: Mode, context: Context): Mode =
        resolveMode(requested, override, totalMemoryBytes(context))

    /**
     * The debug [override] wins, so the stage can be measured on any device;
     * otherwise [requested] holds unless the device has too little memory.
     * An unknown memory size counts as enough.
     */
    fun resolveMode(requested: Mode, override: Mode?, totalMemoryBytes: Long?): Mode = when {
        override != null -> override
        totalMemoryBytes != null && totalMemoryBytes < MIN_TOTAL_MEMORY_BYTES -> Mode.OFF
        else -> requested
    }

    /**
     * The size the stage draws a [source]-sized frame at: [target] when it
     * is larger in both directions and within [MAX_OUTPUT_PIXELS],
     * otherwise the source size, since the stage only ever scales up.
     */
    fun outputSize(source: Size, target: Size?): Size = when {
        target == null -> source
        target.width <= source.width || target.height <= source.height -> source
        target.width.toLong() * target.height > MAX_OUTPUT_PIXELS -> source
        else -> target
    }

    /** The on-screen size Dart measured for the texture, shared with the GL thread. */
    class Target {
        @Volatile
        var size: Size? = null
    }

    fun effect(mode: Mode, target: Target): GlEffect = UpscaleEffect(mode, target, timing)

    private class UpscaleEffect(
        private val mode: Mode,
        private val target: Target,
        private val timing: Boolean,
    ) : GlEffect {
        override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram =
            UpscaleProgram(mode, target, timing, useHdr)

        // The stage has to exist before the first target arrives, so it is
        // never dropped as a no-op even while it only copies.
        override fun isNoOp(inputWidth: Int, inputHeight: Int): Boolean = false
    }

    /**
     * A one-texture GL stage, like Media3's BaseGlShaderProgram with a
     * capacity of one, except that it picks its output size per frame: the
     * base class sizes its texture pool only when the input size changes.
     * Media3 asks for the next frame only after the previous output was
     * released, so a texture is never resized while the next stage reads it.
     */
    private class UpscaleProgram(
        private val mode: Mode,
        private val target: Target,
        private val timing: Boolean,
        private val useHdr: Boolean,
    ) : GlShaderProgram {
        private var inputListener: GlShaderProgram.InputListener = object : GlShaderProgram.InputListener {}
        private var outputListener: GlShaderProgram.OutputListener = object : GlShaderProgram.OutputListener {}
        private var errorListener = GlShaderProgram.ErrorListener { }
        private var errorExecutor = Executor { it.run() }

        private var output: GlTextureInfo? = null
        private var intermediate: GlTextureInfo? = null
        private var outputInUse = false

        private var copyProgram: GlProgram? = null
        private var horizontalProgram: GlProgram? = null
        private var verticalProgram: GlProgram? = null

        private var loggedSize: Pair<Size, Size>? = null
        private val samples = LongArray(TIMING_WINDOW)
        private var sampleCount = 0

        override fun setInputListener(listener: GlShaderProgram.InputListener) {
            inputListener = listener
            if (!outputInUse) listener.onReadyToAcceptInputFrame()
        }

        override fun setOutputListener(listener: GlShaderProgram.OutputListener) {
            outputListener = listener
        }

        override fun setErrorListener(executor: Executor, listener: GlShaderProgram.ErrorListener) {
            errorExecutor = executor
            errorListener = listener
        }

        override fun queueInputFrame(
            glObjectsProvider: GlObjectsProvider,
            inputTexture: GlTextureInfo,
            presentationTimeUs: Long,
        ) {
            try {
                if (timing) GLES20.glFinish()
                val start = System.nanoTime()
                val source = Size(inputTexture.width, inputTexture.height)
                val size = outputSize(source, target.size)
                logSize(source, size)
                val out = ensureTexture(output, glObjectsProvider, size).also { output = it }
                outputInUse = true
                when {
                    size == source -> draw(copy(), inputTexture.texId, source, out)
                    mode == Mode.LANCZOS -> {
                        val between = ensureTexture(intermediate, glObjectsProvider, Size(size.width, source.height))
                            .also { intermediate = it }
                        draw(horizontal(), inputTexture.texId, source, between)
                        draw(vertical(), between.texId, Size(between.width, between.height), out)
                    }
                    else -> draw(copy(), inputTexture.texId, source, out)
                }
                if (timing) {
                    GLES20.glFinish()
                    record(System.nanoTime() - start, source, size)
                }
                inputListener.onInputFrameProcessed(inputTexture)
                outputListener.onOutputFrameAvailable(out, presentationTimeUs)
            } catch (e: Exception) {
                errorExecutor.execute { errorListener.onError(VideoFrameProcessingException.from(e, presentationTimeUs)) }
            }
        }

        override fun releaseOutputFrame(outputTexture: GlTextureInfo) {
            outputInUse = false
            inputListener.onReadyToAcceptInputFrame()
        }

        override fun signalEndOfCurrentInputStream() {
            outputListener.onCurrentOutputStreamEnded()
        }

        override fun flush() {
            outputInUse = false
            inputListener.onFlush()
            inputListener.onReadyToAcceptInputFrame()
        }

        override fun release() {
            try {
                output?.release()
                intermediate?.release()
                copyProgram?.delete()
                horizontalProgram?.delete()
                verticalProgram?.delete()
            } catch (e: GlUtil.GlException) {
                throw VideoFrameProcessingException(e)
            } finally {
                output = null
                intermediate = null
                copyProgram = null
                horizontalProgram = null
                verticalProgram = null
            }
        }

        /** Returns [existing] when it already has [size], else a new texture of that size. */
        private fun ensureTexture(existing: GlTextureInfo?, provider: GlObjectsProvider, size: Size): GlTextureInfo {
            if (existing != null && existing.width == size.width && existing.height == size.height) return existing
            existing?.release()
            val texId = GlUtil.createTexture(size.width, size.height, useHdr)
            return provider.createBuffersForTexture(texId, size.width, size.height)
        }

        private fun copy(): GlProgram = copyProgram ?: GlProgram(VERTEX_SHADER, COPY_SHADER).also { copyProgram = it }

        private fun horizontal(): GlProgram =
            horizontalProgram ?: GlProgram(VERTEX_SHADER, lanczosShader("x", "y")).also { horizontalProgram = it }

        private fun vertical(): GlProgram =
            verticalProgram ?: GlProgram(VERTEX_SHADER, lanczosShader("y", "x")).also { verticalProgram = it }

        private fun draw(program: GlProgram, texId: Int, source: Size, into: GlTextureInfo) {
            GlUtil.focusFramebufferUsingCurrentContext(into.fboId, into.width, into.height)
            program.use()
            program.setSamplerTexIdUniform("uTexSampler", texId, 0)
            program.setFloatsUniformIfPresent("uSrcSize", floatArrayOf(source.width.toFloat(), source.height.toFloat()))
            val vertices = GlUtil.getNormalizedCoordinateBounds()
            program.setBufferAttribute("aFramePosition", vertices, if (vertices.size == 8) 2 else 4)
            program.bindAttributesAndUniforms()
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            GlUtil.checkGlError()
        }

        private fun logSize(source: Size, size: Size) {
            val current = source to size
            if (current == loggedSize) return
            loggedSize = current
            DivineVideoPlayerLog.info(
                "Upscale stage ($mode) draws ${source.width}x${source.height} at ${size.width}x${size.height}",
                name = "DivineVideoPlayer.Upscale",
            )
        }

        private fun record(nanos: Long, source: Size, size: Size) {
            samples[sampleCount++] = nanos
            if (sampleCount < TIMING_WINDOW) return
            sampleCount = 0
            val sorted = samples.sorted()
            DivineVideoPlayerLog.info(
                "Upscale stage ($mode) ${source.width}x${source.height} -> ${size.width}x${size.height} " +
                    "over $TIMING_WINDOW frames: mean %.2f ms, p95 %.2f ms, max %.2f ms".format(
                        sorted.average() / 1e6,
                        sorted[(TIMING_WINDOW * 95) / 100] / 1e6,
                        sorted.last() / 1e6,
                    ),
                name = "DivineVideoPlayer.Upscale",
            )
        }
    }

    private const val TIMING_WINDOW = 120

    private const val VERTEX_SHADER =
        "attribute vec4 aFramePosition;\n" +
            "varying vec2 vTexCoord;\n" +
            "void main() {\n" +
            "  gl_Position = aFramePosition;\n" +
            "  vTexCoord = aFramePosition.xy * 0.5 + 0.5;\n" +
            "}"

    /** Bilinear: the GL texture's own filtering does the scaling, if any. */
    private const val COPY_SHADER =
        "precision highp float;\n" +
            "uniform sampler2D uTexSampler;\n" +
            "varying vec2 vTexCoord;\n" +
            "void main() {\n" +
            "  gl_FragColor = texture2D(uTexSampler, vTexCoord);\n" +
            "}"

    /**
     * One axis of a Lanczos-3 resample: six taps around the source position,
     * each read at a texel centre so the texture's own filtering adds
     * nothing, normalised by the weight sum so flat areas keep their level.
     * Positions need highp: at mediump a 1280-texel axis is off by more than
     * half a texel.
     */
    fun lanczosShader(axis: String, other: String): String =
        "precision highp float;\n" +
            "uniform sampler2D uTexSampler;\n" +
            "uniform vec2 uSrcSize;\n" +
            "varying vec2 vTexCoord;\n" +
            "const float PI = 3.141592653589793;\n" +
            "float lanczos3(float x) {\n" +
            "  x = abs(x);\n" +
            "  if (x < 1e-5) return 1.0;\n" +
            "  if (x >= 3.0) return 0.0;\n" +
            "  float px = PI * x;\n" +
            "  return 3.0 * sin(px) * sin(px / 3.0) / (px * px);\n" +
            "}\n" +
            "void main() {\n" +
            "  float p = vTexCoord.$axis * uSrcSize.$axis - 0.5;\n" +
            "  float base = floor(p);\n" +
            "  float f = p - base;\n" +
            "  vec4 sum = vec4(0.0);\n" +
            "  float weights = 0.0;\n" +
            "  for (int i = -2; i <= 3; i++) {\n" +
            "    float w = lanczos3(float(i) - f);\n" +
            "    float t = (clamp(base + float(i), 0.0, uSrcSize.$axis - 1.0) + 0.5) / uSrcSize.$axis;\n" +
            "    vec2 uv = vec2(0.0);\n" +
            "    uv.$axis = t;\n" +
            "    uv.$other = vTexCoord.$other;\n" +
            "    sum += w * texture2D(uTexSampler, uv);\n" +
            "    weights += w;\n" +
            "  }\n" +
            "  gl_FragColor = clamp(sum / weights, 0.0, 1.0);\n" +
            "}"

    private fun totalMemoryBytes(context: Context): Long? = try {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        manager?.let { ActivityManager.MemoryInfo().also(it::getMemoryInfo).totalMem }
    } catch (e: Exception) {
        null
    }

    /** Reads a system property through `getprop`; the hidden API is closed to apps. */
    private fun systemProperty(key: String): String? = try {
        val process = ProcessBuilder("getprop", key).redirectErrorStream(true).start()
        process.inputStream.bufferedReader().use { it.readText().trim() }.takeIf { it.isNotEmpty() }
    } catch (e: Exception) {
        null
    }
}
