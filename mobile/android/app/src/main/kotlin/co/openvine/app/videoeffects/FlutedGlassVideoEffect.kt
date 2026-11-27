package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects
import kotlin.math.cos
import kotlin.math.sin

/**
 * Fluted glass: the picture is seen through ribbed glass, each rib showing a
 * squeezed slice of it.
 *
 * Upright ribs, each 8% of the frame's shorter side wide and one centred on the
 * frame, unless the user widens or turns them, show a slice of the picture up
 * to two and a half ribs wide, so neighbouring ribs repeat parts of it. A slice
 * reaching past an edge of the frame is mirrored back, rather than smearing the
 * edge pixels. Each rib darkens towards its edges, by up to 15%, and carries a
 * soft highlight beside its middle, so it reads as rounded glass.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how much
 * the ribs squeeze and shade the picture), `width` (0.3–3: how wide the ribs
 * are, as a share of the default) and `angle` (0–180: how far the ribs are
 * turned from upright, in degrees, anticlockwise).
 */
class FlutedGlassVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val rib = numberOf(params, "width", 1f, 0.3f, 3f)

    /** The direction across the ribs, with y up. */
    private val axis = Math.toRadians(numberOf(params, "angle", 0f, 0f, 180f).toDouble()).let {
        floatArrayOf(cos(it).toFloat(), sin(it).toFloat())
    }

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uRib", rib)
        shader.setFloats("uAxis", axis)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.flutedGlass"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> FlutedGlassVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> FlutedGlassVideoEffect(params) }
        }

        // `across` runs from -0.5 to 0.5 across a rib, 0 at its middle.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uRib;
uniform vec2 uAxis;

void main() {
  vec2 p = vTexCoord * uSize;
  float rib = 0.08 * uRib * min(uSize.x, uSize.y);
  float across = fract(dot(p - 0.5 * uSize, uAxis) / rib + 0.5) - 0.5;
  vec2 q = abs(p + 1.5 * uIntensity * across * rib * uAxis);
  vec3 color = tap(uSize - abs(uSize - q));
  color *= 1.0 - 0.6 * uIntensity * across * across;
  color += 0.1 * uIntensity * (1.0 - smoothstep(0.0, 0.15, abs(across + 0.22)));
  gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
"""
    }
}
