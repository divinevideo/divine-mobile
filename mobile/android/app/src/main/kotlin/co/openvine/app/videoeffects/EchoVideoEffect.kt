package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectFrame
import ch.waio.pro_video_editor.effects.CustomVideoEffectRenderer
import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffect
import com.divinevideo.divine_video_player.VideoFrameEffects
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * The echo trail (#9708): moving subjects leave fading copies of where they
 * were 100 ms, 200 ms, ... ago, as many as the intensity asks for.
 *
 * Every copy is an earlier source frame of the same clip, which
 * pro_video_editor hands over, so the export looks the same however the clip
 * was played or seeked before. The editor preview draws the same shader
 * through divine_video_player, whose earlier frames come from what the
 * player showed, or are decoded after a seek.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1):
 * more and stronger copies. Each copy lightens the frame, so the subject
 * stays solid where the copies overlap it.
 */
class EchoVideoEffect(params: Map<String, Any?>) : CustomVideoEffectRenderer(), VideoFrameEffect {

    private val intensity = (params["intensity"] as? Number)?.toFloat()?.coerceIn(0f, 1f)
        ?: DEFAULT_INTENSITY
    private val copies = (1 + 6 * intensity).roundToInt().coerceIn(1, MAX_COPIES)

    /** The weight of each copy, newest first: stronger copies, fading slower. */
    private val weights = FloatArray(copies) { k ->
        (0.25f + 0.55f * intensity) * (0.55f + 0.25f * intensity).pow(k)
    }

    override val historyOffsetsUs = LongArray(copies) { (it + 1) * SPACING_US }

    // The copies fade anyway; half size takes a quarter of the memory.
    override val historyScale = 0.5f

    private val shader = CustomVideoEffectShader(fragmentShader(copies))

    override fun render(frame: CustomVideoEffectFrame) {
        draw(frame.textureId, frame.history.map { it?.textureId })
    }

    override fun render(frameTextureId: Int, width: Int, height: Int, history: List<Int?>) {
        draw(frameTextureId, history)
    }

    private fun draw(frameTexture: Int, copies: List<Int?>) {
        shader.use()
        shader.setTexture("uFrame", frameTexture, 0)
        copies.forEachIndexed { k, copy ->
            // A sampler must be bound even when the clip has not played that
            // far yet; its weight of 0 leaves it out.
            shader.setTexture("uCopy$k", copy ?: frameTexture, k + 1)
            shader.setFloat("uWeight$k", if (copy == null) 0f else weights[k])
        }
        shader.draw()
    }

    override fun release() {
        shader.release()
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.echo"

        private const val DEFAULT_INTENSITY = 0.7f
        private const val SPACING_US = 100_000L

        // The frame and its copies each take a texture unit, and OpenGL ES 2.0
        // guarantees eight.
        private const val MAX_COPIES = 7

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> EchoVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> EchoVideoEffect(params) }
        }

        private fun fragmentShader(copies: Int): String = buildString {
            append("#ifdef GL_FRAGMENT_PRECISION_HIGH\n")
            append("precision highp float;\n")
            append("#else\n")
            append("precision mediump float;\n")
            append("#endif\n")
            append("uniform sampler2D uFrame;\n")
            for (k in 0 until copies) {
                append("uniform sampler2D uCopy$k;\n")
                append("uniform float uWeight$k;\n")
            }
            append("varying vec2 vTexCoord;\n")
            append("void main() {\n")
            append("  vec4 color = texture2D(uFrame, vTexCoord);\n")
            // Oldest copy first, so newer copies layer over older ones.
            for (k in copies - 1 downTo 0) {
                append("  color = mix(color, max(color, texture2D(uCopy$k, vTexCoord)), uWeight$k);\n")
            }
            append("  gl_FragColor = color;\n")
            append("}\n")
        }
    }
}
