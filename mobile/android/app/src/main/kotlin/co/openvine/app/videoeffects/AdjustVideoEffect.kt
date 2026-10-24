package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectFrame
import ch.waio.pro_video_editor.effects.CustomVideoEffectRenderer
import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffect
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * The Adjust controls a colour matrix cannot draw (#10392): highlights,
 * shadows, vibrance and sharpening.
 *
 * A matrix changes every pixel the same way, but these depend on each pixel's
 * own brightness or saturation, or on its neighbours. Sharpening adds back the
 * difference between a pixel's brightness and a small blur of it, but never
 * past the brightest or darkest pixel it sampled, so hard edges get no halo.
 * Shadows and
 * highlights move the brightness along a curve that leaves black and white in
 * place, scaling red, green and blue alike so the colour stays. Vibrance
 * saturates dull colours more than strong ones and mostly spares skin tones.
 *
 * The shader is the Swift `AdjustVideoEffect`'s Metal kernel, line for line,
 * so both platforms draw the same picture. Only the Metal copy runs in a test
 * (`AdjustVideoEffectTests` in `RunnerTests`), so a change here has to be made
 * there as well.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `highlights`, `shadows`
 * and `vibrance` (-1 to 1) and `sharpen` (0 to 1); a missing one is 0.
 */
class AdjustVideoEffect(params: Map<String, Any?>) : CustomVideoEffectRenderer(), VideoFrameEffect {

    private val values = floatArrayOf(
        params.unit("highlights", -1f),
        params.unit("shadows", -1f),
        params.unit("vibrance", -1f),
        params.unit("sharpen", 0f),
    )

    override val historyOffsetsUs = LongArray(0)

    override val historyScale = 1f

    private val shader = CustomVideoEffectShader(FRAGMENT_SHADER)

    override fun render(frame: CustomVideoEffectFrame) {
        draw(frame.textureId, frame.width, frame.height)
    }

    override fun render(frameTextureId: Int, width: Int, height: Int, history: List<Int?>) {
        draw(frameTextureId, width, height)
    }

    private fun draw(frameTexture: Int, width: Int, height: Int) {
        shader.use()
        shader.setTexture("uFrame", frameTexture, 0)
        shader.setFloats("uSize", floatArrayOf(width.toFloat(), height.toFloat()))
        shader.setFloats("uAdjust", values)
        shader.draw()
    }

    override fun release() {
        shader.release()
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.adjust"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> AdjustVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> AdjustVideoEffect(params) }
        }

        private fun Map<String, Any?>.unit(key: String, min: Float): Float =
            (this[key] as? Number)?.toFloat()?.coerceIn(min, 1f) ?: 0f

        // `p` is in pixels from the bottom left. The sharpening blur samples
        // a ring that grows with the frame, 1.5 px on a 1080p one, so a
        // video looks as sharp after it at any resolution. Pixel coordinates
        // need highp: mediump cannot address a 1080p frame to the pixel.
        private const val FRAGMENT_SHADER =
            "#ifdef GL_FRAGMENT_PRECISION_HIGH\n" +
            "precision highp float;\n" +
            "#else\n" +
            "precision mediump float;\n" +
            "#endif\n" +
            "uniform sampler2D uFrame;\n" +
            "uniform vec2 uSize;\n" +
            "uniform vec4 uAdjust;\n" +
            "varying vec2 vTexCoord;\n" +
            "const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);\n" +
            "vec3 tap(vec2 q) {\n" +
            "  return texture2D(uFrame, clamp(q, vec2(0.5), uSize - 0.5) / uSize).rgb;\n" +
            "}\n" +
            "float luma(vec2 q) {\n" +
            "  return dot(tap(q), kLuma);\n" +
            "}\n" +
            "void main() {\n" +
            "  vec2 p = vTexCoord * uSize;\n" +
            "  float highlights = uAdjust.x;\n" +
            "  float shadows = uAdjust.y;\n" +
            "  float vibrance = uAdjust.z;\n" +
            "  float sharpen = uAdjust.w;\n" +
            "  vec3 color = tap(p);\n" +
            "  if (sharpen > 0.0) {\n" +
            "    float r = max(1.0, 1.5 * min(uSize.x, uSize.y) / 1080.0);\n" +
            "    float y = dot(color, kLuma);\n" +
            "    float e0 = luma(p + vec2(r, 0.0));\n" +
            "    float e1 = luma(p - vec2(r, 0.0));\n" +
            "    float e2 = luma(p + vec2(0.0, r));\n" +
            "    float e3 = luma(p - vec2(0.0, r));\n" +
            "    float c0 = luma(p + vec2(r, r));\n" +
            "    float c1 = luma(p + vec2(-r, r));\n" +
            "    float c2 = luma(p + vec2(r, -r));\n" +
            "    float c3 = luma(p - vec2(r, r));\n" +
            "    float blur = (4.0 * y + 2.0 * (e0 + e1 + e2 + e3) + c0 + c1 + c2 + c3) / 16.0;\n" +
            "    float lo = min(y, min(min(min(e0, e1), min(e2, e3)), min(min(c0, c1), min(c2, c3))));\n" +
            "    float hi = max(y, max(max(max(e0, e1), max(e2, e3)), max(max(c0, c1), max(c2, c3))));\n" +
            "    float sharp = clamp(y + 3.0 * sharpen * (y - blur), lo, hi);\n" +
            "    color = clamp(color + (sharp - y), 0.0, 1.0);\n" +
            "  }\n" +
            "  float l = dot(color, kLuma);\n" +
            "  float dark = 1.0 - l;\n" +
            "  float lows = l * dark * dark * dark * dark * 12.20703125;\n" +
            "  float highs = l * l * l * l * dark * 12.20703125;\n" +
            "  float toned = l\n" +
            "    + shadows * (shadows > 0.0 ? 0.2 : 0.065) * lows\n" +
            "    + highlights * (highlights < 0.0 ? 0.2 : 0.065) * highs;\n" +
            "  color = clamp(l > 0.0001 ? color * (toned / l) : color + (toned - l), 0.0, 1.0);\n" +
            "  if (vibrance != 0.0) {\n" +
            "    float chroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));\n" +
            "    float skin = 0.0;\n" +
            "    if (color.r >= color.g && color.g >= color.b && chroma > 0.0001) {\n" +
            "      float hue = (color.g - color.b) / chroma;\n" +
            "      skin = smoothstep(0.05, 0.25, hue) * (1.0 - smoothstep(0.6, 0.85, hue))\n" +
            "        * smoothstep(0.02, 0.08, chroma) * (1.0 - smoothstep(0.5, 0.75, chroma));\n" +
            "    }\n" +
            "    float keep = 1.0 - 0.85 * skin;\n" +
            "    float amount = vibrance > 0.0\n" +
            "      ? vibrance * 1.25 * (1.0 - chroma) * (1.0 - chroma) * keep\n" +
            "      : vibrance * (0.4 + 0.6 * chroma) * keep;\n" +
            "    float grey = dot(color, kLuma);\n" +
            "    color = clamp(grey + (color - grey) * (1.0 + amount), 0.0, 1.0);\n" +
            "  }\n" +
            "  gl_FragColor = vec4(color, 1.0);\n" +
            "}\n"
    }
}
