// ABOUTME: Routes video frames through a GL copy on MediaTek devices with a newer Mali GPU,
// ABOUTME: whose hardware-decoded frames Impeller's Vulkan import shears into a staircase

package com.divinevideo.divine_video_player

import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.GLES20
import android.content.Context
import android.os.Build
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram

/**
 * Works around flutter/flutter#193551: on MediaTek SoCs with a Mali GPU of
 * the G310 generation and newer (Dimensity 7200 and up), Impeller's Vulkan
 * import of a hardware decoder's frame ignores the row padding the decoder
 * adds when the video width is not a multiple of 32. Each 16-row block then
 * lands one 16-pixel block further right: a diagonal staircase with a green
 * band through the picture. Divine's 720-wide renditions are padded to 736
 * and hit it on every video.
 *
 * The same buffer reads correctly through EGL, so on those devices the
 * player sends its frames through [StrideCopyGlEffect]: Media3 samples the
 * decoder's frame in GL and draws it into a plain RGBA buffer, whose padding
 * the Vulkan driver does account for. Older Mali (G52, G57: moto g 2025,
 * Galaxy A15) plays correctly and keeps the direct path, as does every other
 * GPU.
 *
 * A software decoder is no way out: its frames show their row padding as a
 * green band at the right edge (flutter/flutter#193444).
 *
 * Remove once the engine fix for flutter/flutter#193551 ships in the Flutter
 * version Divine builds with; tracked in divinevideo/divine-mobile#10060.
 */
@UnstableApi
internal object MaliStrideWorkaround {
    /**
     * `adb shell setprop debug.divine.gl_video_copy 1` forces the GL copy on
     * any device and `0` forces it off; anything else leaves the choice to
     * the device check. Read once, when the first player is built, so
     * restart the app after changing it.
     */
    private const val OVERRIDE_PROPERTY = "debug.divine.gl_video_copy"

    private val deviceAffected: Boolean by lazy {
        val affected = isAffected(socManufacturer(), Build.HARDWARE, ::readGlRenderer)
        DivineVideoPlayerLog.info(
            "GL copy of video frames ${if (affected) "on" else "not needed"} " +
                "(soc=${socManufacturer()}, hardware=${Build.HARDWARE})",
        )
        affected
    }

    private val override: Boolean? by lazy {
        when (systemProperty(OVERRIDE_PROPERTY)) {
            "1" -> true
            "0" -> false
            else -> null
        }
    }

    /** Whether new players on this device should send their frames through [StrideCopyGlEffect]. */
    fun applies(): Boolean = override ?: deviceAffected

    /**
     * Whether a device with this SoC and GPU is affected. [renderer] is only
     * asked for on MediaTek SoCs, so no other device pays for reading it.
     */
    fun isAffected(socManufacturer: String?, hardware: String?, renderer: () -> String?): Boolean {
        val mediaTek = socManufacturer?.equals("mediatek", ignoreCase = true)
            ?: hardware?.lowercase()?.startsWith("mt")
            ?: false
        if (!mediaTek) return false
        val generation = maliGeneration(renderer()) ?: return false
        return generation >= FIRST_AFFECTED_MALI
    }

    /**
     * The model number of a Mali GPU from its GL renderer string, such as
     * 610 for "Mali-G610 MC6" or 715 for "Mali-G715-Immortalis MC11"; null
     * for any other GPU.
     */
    fun maliGeneration(renderer: String?): Int? =
        renderer?.let { MALI_RENDERER.find(it) }?.groupValues?.get(1)?.toIntOrNull()

    /**
     * The upright display size the GL stage draws a [width] x [height] frame
     * at: Media3 applies the track's rotation and pixel aspect ratio in that
     * stage. Null while the track has no size yet.
     */
    fun outputSize(width: Int, height: Int, rotationDegrees: Int, pixelWidthHeightRatio: Float): Size? {
        if (width <= 0 || height <= 0) return null
        val ratio = pixelWidthHeightRatio.takeIf { it.isFinite() && it > 0f } ?: 1f
        // Like Media3, stretch the longer pixel side rather than squeeze the other.
        val scaledWidth = if (ratio > 1f) Math.round(width * ratio) else width
        val scaledHeight = if (ratio < 1f) Math.round(height / ratio) else height
        return if (rotationDegrees % 180 != 0) Size(scaledHeight, scaledWidth) else Size(scaledWidth, scaledHeight)
    }

    /**
     * Mali's three-digit models (G310, G510, G610 and later) are the
     * generation the issue was seen on; the two-digit ones before them
     * (G52, G57, G68, G78) were not.
     */
    private const val FIRST_AFFECTED_MALI = 310

    private val MALI_RENDERER = Regex("""Mali-G(\d+)""")

    private fun socManufacturer(): String? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) Build.SOC_MANUFACTURER else null

    /**
     * Reads a system property through `getprop`; the hidden
     * `SystemProperties` API is closed to apps.
     */
    private fun systemProperty(key: String): String? = try {
        val process = ProcessBuilder("getprop", key).redirectErrorStream(true).start()
        process.inputStream.bufferedReader().use { it.readText().trim() }.takeIf { it.isNotEmpty() }
    } catch (e: Exception) {
        null
    }

    /**
     * Reads the GL renderer string through a throwaway 1x1 pbuffer context,
     * on a thread of its own so no caller's EGL context is disturbed.
     */
    private fun readGlRenderer(): String? {
        var renderer: String? = null
        val thread = Thread({ renderer = queryGlRenderer() }, "DivineVideoPlayer.GpuProbe")
        thread.start()
        thread.join(GPU_PROBE_TIMEOUT_MS)
        return renderer
    }

    private const val GPU_PROBE_TIMEOUT_MS = 2_000L

    private fun queryGlRenderer(): String? {
        val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (display == EGL14.EGL_NO_DISPLAY) return null
        val version = IntArray(2)
        if (!EGL14.eglInitialize(display, version, 0, version, 1)) return null
        val configs = arrayOfNulls<EGLConfig>(1)
        val count = IntArray(1)
        val configAttributes = intArrayOf(
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
            EGL14.EGL_NONE,
        )
        if (!EGL14.eglChooseConfig(display, configAttributes, 0, configs, 0, 1, count, 0) || count[0] == 0) {
            return null
        }
        val config = configs[0]
        val context = EGL14.eglCreateContext(
            display, config, EGL14.EGL_NO_CONTEXT,
            intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0,
        )
        val surface = EGL14.eglCreatePbufferSurface(
            display, config, intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0,
        )
        return try {
            if (context == EGL14.EGL_NO_CONTEXT || surface == EGL14.EGL_NO_SURFACE) return null
            if (!EGL14.eglMakeCurrent(display, surface, surface, context)) return null
            GLES20.glGetString(GLES20.GL_RENDERER)
        } finally {
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            if (surface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, surface)
            if (context != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, context)
        }
    }
}

/**
 * Copies each frame unchanged. Its only job is to put Media3's GL stage
 * between the decoder and the Flutter texture; see [MaliStrideWorkaround].
 *
 * The copy does not interpret colours, so it serves HDR output too: Media3
 * asks for it with [useHdr] whenever an HDR clip keeps its HDR output, and
 * rejecting that would stop such a clip from playing on the very devices
 * the copy is for.
 */
@UnstableApi
internal object StrideCopyGlEffect : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram {
        android.util.Log.d("DivineVideoPlayer.Effects", "GL copy stage built (hdr=$useHdr)")
        return Program(useHdr)
    }

    // A no-op would let Media3 drop the stage, and the stage is the point.
    override fun isNoOp(inputWidth: Int, inputHeight: Int): Boolean = false

    @UnstableApi
    private class Program(useHdr: Boolean) :
        BaseGlShaderProgram(/* useHighPrecisionColorComponents= */ useHdr, /* texturePoolCapacity= */ 1) {
        // Built with the first frame, so building the stage needs no GL call.
        private var copy: GlProgram? = null

        override fun configure(inputWidth: Int, inputHeight: Int): Size = Size(inputWidth, inputHeight)

        override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
            try {
                val copy = copy ?: GlProgram(VERTEX_SHADER, COPY_SHADER).also { copy = it }
                copy.use()
                copy.setSamplerTexIdUniform("uTexSampler", inputTexId, 0)
                val vertices = GlUtil.getNormalizedCoordinateBounds()
                copy.setBufferAttribute("aFramePosition", vertices, if (vertices.size == 8) 2 else 4)
                copy.bindAttributesAndUniforms()
                android.opengl.GLES20.glDrawArrays(android.opengl.GLES20.GL_TRIANGLE_STRIP, 0, 4)
                GlUtil.checkGlError()
            } catch (e: Exception) {
                throw VideoFrameProcessingException(e, presentationTimeUs)
            }
        }

        override fun release() {
            super.release()
            copy?.delete()
            copy = null
        }
    }

    private const val VERTEX_SHADER =
        "attribute vec4 aFramePosition;\n" +
            "varying vec2 vTexCoord;\n" +
            "void main() {\n" +
            "  gl_Position = aFramePosition;\n" +
            "  vTexCoord = aFramePosition.xy * 0.5 + 0.5;\n" +
            "}"

    private const val COPY_SHADER =
        "precision mediump float;\n" +
            "uniform sampler2D uTexSampler;\n" +
            "varying vec2 vTexCoord;\n" +
            "void main() {\n" +
            "  gl_FragColor = texture2D(uTexSampler, vTexCoord);\n" +
            "}"
}
