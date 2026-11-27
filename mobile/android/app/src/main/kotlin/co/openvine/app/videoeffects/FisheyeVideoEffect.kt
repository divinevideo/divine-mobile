package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectFrame
import ch.waio.pro_video_editor.effects.CustomVideoEffectRenderer
import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffect
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * The fisheye: the middle of the picture bulges out, as through a wide-angle
 * lens, while the corners stay where they are.
 *
 * iOS and macOS draw it with Core Image's `CIBumpDistortion`, the only bulge
 * available there without a custom kernel. This shader is that filter's
 * mapping, measured to within 0.002 px, so both platforms look the same:
 * every pixel samples the picture closer to the centre,
 *
 *     source = centre + offset * (1 - scale * (1 - smoothstep(0, 1, t)))
 *
 * where t is the pixel's distance from the centre over the radius, half the
 * frame's diagonal at the default size. Mirrors the Swift
 * `FisheyeVideoEffect`.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
 * the middle bulges out), `centerX` and `centerY` (0–1: where the bulge sits,
 * as shares of the width from the left and of the height from the top; the
 * middle by default) and `size` (0.3–1.5: the radius, as a share of half the
 * diagonal).
 */
class FisheyeVideoEffect(params: Map<String, Any?>) : CustomVideoEffectRenderer(), VideoFrameEffect {

    private val scale = MAX_SCALE *
        ((params["intensity"] as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: DEFAULT_INTENSITY)

    private val center = ShaderVideoEffect.centerOf(params)

    private val radius = ShaderVideoEffect.numberOf(params, "size", 1f, 0.3f, 1.5f)

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
        shader.setFloat("uScale", scale)
        // The shader counts y up from the bottom, the param down from the top.
        shader.setFloats("uCenter", floatArrayOf(center[0], 1f - center[1]))
        shader.setFloat("uRadius", radius)
        shader.draw()
    }

    override fun release() {
        shader.release()
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.fisheye"

        private const val DEFAULT_INTENSITY = 0.7f

        /** The `CIBumpDistortion` scale at intensity 1; 1 would pinch the centre to a point. */
        private const val MAX_SCALE = 0.8f

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> FisheyeVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> FisheyeVideoEffect(params) }
        }

        // Pixel coordinates need highp: mediump cannot address a 1080p frame
        // to the pixel.
        private const val FRAGMENT_SHADER =
            "#ifdef GL_FRAGMENT_PRECISION_HIGH\n" +
            "precision highp float;\n" +
            "#else\n" +
            "precision mediump float;\n" +
            "#endif\n" +
            "uniform sampler2D uFrame;\n" +
            "uniform vec2 uSize;\n" +
            "uniform float uScale;\n" +
            "uniform vec2 uCenter;\n" +
            "uniform float uRadius;\n" +
            "varying vec2 vTexCoord;\n" +
            "void main() {\n" +
            "  vec2 center = uCenter * uSize;\n" +
            "  vec2 offset = vTexCoord * uSize - center;\n" +
            "  float t = length(offset) / (uRadius * length(0.5 * uSize));\n" +
            "  float pull = 1.0 - uScale * (1.0 - smoothstep(0.0, 1.0, t));\n" +
            "  gl_FragColor = texture2D(uFrame, (center + offset * pull) / uSize);\n" +
            "}\n"
    }
}
