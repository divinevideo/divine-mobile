package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectFrame
import ch.waio.pro_video_editor.effects.CustomVideoEffectRenderer
import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import com.divinevideo.divine_video_player.VideoFrameEffect
import kotlin.math.cos
import kotlin.math.sin

/**
 * An effect Divine draws with one fragment shader over the current frame, in
 * the export (pro_video_editor) and in the editor preview
 * (divine_video_player) alike.
 *
 * The shader gets the frame as `uFrame` and its size in pixels as `uSize`;
 * [setUniforms] sets the rest for each frame. [PRELUDE] declares both, and a
 * `tap` that reads the frame at a point in pixels with y up from the bottom
 * left, clamped to the frame's edge pixels.
 *
 * Each subclass's shader is the Swift effect's Metal kernel of the same name,
 * line for line, and the picker tile's `shaders/<name>.frag`.
 */
abstract class ShaderVideoEffect(fragmentShader: String) :
    CustomVideoEffectRenderer(), VideoFrameEffect {

    override val historyOffsetsUs = LongArray(0)

    override val historyScale = 1f

    private val shader = CustomVideoEffectShader(fragmentShader)

    /**
     * Sets the shader's uniforms beyond `uFrame` and `uSize`, for a frame
     * [effectTimeUs] after the effect started.
     */
    protected abstract fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long)

    override fun render(frame: CustomVideoEffectFrame) {
        draw(frame.textureId, frame.width, frame.height, frame.effectTimeUs)
    }

    override fun render(
        frameTextureId: Int,
        width: Int,
        height: Int,
        history: List<Int?>,
        timeUs: Long,
        effectTimeUs: Long,
    ) {
        draw(frameTextureId, width, height, effectTimeUs)
    }

    // The player calls the timed render; this draws the effect as it starts.
    override fun render(frameTextureId: Int, width: Int, height: Int, history: List<Int?>) {
        draw(frameTextureId, width, height, 0L)
    }

    private fun draw(frameTexture: Int, width: Int, height: Int, effectTimeUs: Long) {
        shader.use()
        shader.setTexture("uFrame", frameTexture, 0)
        shader.setFloats("uSize", floatArrayOf(width.toFloat(), height.toFloat()))
        setUniforms(shader, effectTimeUs)
        shader.draw()
    }

    override fun release() {
        shader.release()
    }

    companion object {
        /** Reads `intensity` from [params], clamped to 0–1, or [fallback]. */
        fun intensityOf(params: Map<String, Any?>, fallback: Float = DEFAULT_INTENSITY): Float =
            (params["intensity"] as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: fallback

        /** The intensity a new effect starts at, as in the Dart editor. */
        const val DEFAULT_INTENSITY = 0.7f

        /**
         * Reads the number [key] from [params], clamped to [min]–[max], or
         * [fallback] when it is missing. The Dart effect settings catalog
         * stores each setting with the same range and default.
         */
        fun numberOf(
            params: Map<String, Any?>,
            key: String,
            fallback: Float,
            min: Float,
            max: Float,
        ): Float =
            (params[key] as? Number)?.toFloat()?.takeUnless { it.isNaN() }?.coerceIn(min, max)
                ?: fallback

        /**
         * Where the effect sits, from `centerX` and `centerY`: shares of the
         * frame's width from its left edge and of its height from its top
         * edge, the middle unless the user moved it.
         */
        fun centerOf(params: Map<String, Any?>): FloatArray = floatArrayOf(
            numberOf(params, "centerX", 0.5f, 0f, 1f),
            numberOf(params, "centerY", 0.5f, 0f, 1f),
        )

        /**
         * Reads the colour [key] from [params], an ARGB integer, as red, green
         * and blue from 0 to 1, or those of [fallback] when it is missing.
         */
        fun colorOf(params: Map<String, Any?>, key: String, fallback: Long): FloatArray {
            val argb = (params[key] as? Number)?.toLong() ?: fallback
            return floatArrayOf(
                ((argb shr 16) and 0xFF) / 255f,
                ((argb shr 8) and 0xFF) / 255f,
                (argb and 0xFF) / 255f,
            )
        }

        /** The cosine and sine of [degrees]. */
        fun turnOf(degrees: Float): FloatArray {
            val radians = Math.toRadians(degrees.toDouble())
            return floatArrayOf(cos(radians).toFloat(), sin(radians).toFloat())
        }

        /** `direction`: -1 for an effect the user turned the other way, 1 otherwise. */
        fun directionOf(params: Map<String, Any?>): Float =
            if (((params["direction"] as? Number)?.toFloat() ?: 1f) < 0f) -1f else 1f

        // Pixel coordinates need highp: mediump cannot address a 1080p frame
        // to the pixel.
        const val PRELUDE = """
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
uniform sampler2D uFrame;
uniform vec2 uSize;
varying vec2 vTexCoord;

vec3 tap(vec2 q) {
  return texture2D(uFrame, clamp(q, vec2(0.5), uSize - 0.5) / uSize).rgb;
}
"""
    }
}
