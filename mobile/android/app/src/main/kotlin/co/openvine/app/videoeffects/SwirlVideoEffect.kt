package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Swirl: the picture twists around its centre, most in the middle and not at
 * all from half its shorter side out.
 *
 * Each pixel samples the picture turned around the centre by
 * `3 · intensity · w²` radians, where `w` falls from 1 at the centre to 0 at
 * half the shorter side. A pixel only turns within that circle, so it samples
 * as far from the centre as it is and never outside the frame.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * far the middle turns).
 */
class SwirlVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.swirl"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> SwirlVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> SwirlVideoEffect(params) }
        }

        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;

void main() {
  vec2 p = vTexCoord * uSize;
  vec2 c = uSize * 0.5;
  vec2 d = p - c;
  float w = max(1.0 - length(d) / (0.5 * min(uSize.x, uSize.y)), 0.0);
  float angle = 3.0 * uIntensity * w * w;
  float co = cos(angle);
  float si = sin(angle);
  vec3 color = tap(c + vec2(co * d.x - si * d.y, si * d.x + co * d.y));
  gl_FragColor = vec4(color, 1.0);
}
"""
    }
}
