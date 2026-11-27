package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Swirl: the picture twists around a centre, the middle unless the user moves
 * it, most there and not at all from the radius out.
 *
 * Each pixel samples the picture turned around the centre by `3 · intensity ·
 * w²` radians, clockwise unless the user turns it the other way, where `w`
 * falls from 1 at the centre to 0 at the radius: half the shorter side at the
 * default size.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
 * the middle turns), `centerX` and `centerY` (0–1: where its centre sits, as
 * shares of the width from the left and of the height from the top; the middle
 * by default), `size` (0.3–2: the radius, as a share of half the shorter side)
 * and `direction` (-1 to turn it anticlockwise).
 */
class SwirlVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val center = centerOf(params)

    private val radius = numberOf(params, "size", 1f, 0.3f, 2f)

    private val direction = directionOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloats("uCenter", center)
        shader.setFloat("uRadius", radius)
        shader.setFloat("uDirection", direction)
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
uniform vec2 uCenter;
uniform float uRadius;
uniform float uDirection;

void main() {
  vec2 p = vTexCoord * uSize;
  vec2 c = vec2(uCenter.x, 1.0 - uCenter.y) * uSize;
  vec2 d = p - c;
  float w = max(1.0 - length(d) / (0.5 * uRadius * min(uSize.x, uSize.y)), 0.0);
  float angle = 3.0 * uIntensity * uDirection * w * w;
  float co = cos(angle);
  float si = sin(angle);
  vec3 color = tap(c + vec2(co * d.x - si * d.y, si * d.x + co * d.y));
  gl_FragColor = vec4(color, 1.0);
}
"""
    }
}
