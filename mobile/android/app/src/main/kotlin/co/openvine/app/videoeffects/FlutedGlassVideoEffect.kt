package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Fluted glass: the picture is seen through ribbed glass, each rib showing a
 * squeezed slice of it.
 *
 * Upright ribs, each 8% of the frame's shorter side wide and one centred on
 * the frame, show a slice of the picture up to two and a half ribs wide, so
 * neighbouring ribs repeat parts of it. A slice reaching past the left or
 * right edge of the frame is mirrored back, rather than smearing the edge
 * pixels. Each rib darkens towards its edges, by up to 15%, and carries a
 * soft highlight left of its middle, so it reads as rounded glass.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * much the ribs squeeze and shade the picture).
 */
class FlutedGlassVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
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

void main() {
  vec2 p = vTexCoord * uSize;
  float rib = 0.08 * min(uSize.x, uSize.y);
  float across = fract((p.x - 0.5 * uSize.x) / rib + 0.5) - 0.5;
  float x = abs(p.x + 1.5 * uIntensity * across * rib);
  vec3 color = tap(vec2(uSize.x - abs(uSize.x - x), p.y));
  color *= 1.0 - 0.6 * uIntensity * across * across;
  color += 0.1 * uIntensity * (1.0 - smoothstep(0.0, 0.15, abs(across + 0.22)));
  gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
"""
    }
}
