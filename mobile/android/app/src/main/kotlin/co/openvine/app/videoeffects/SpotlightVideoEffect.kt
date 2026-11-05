package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Spotlight: the picture is dimmed, and two round stage lights, one warm and
 * one cool, wander slowly over it and light it back up.
 *
 * Each light has a flat top and a short, soft edge, `exp(-r⁶)` of the
 * distance from its centre in shares of its reach. Where both fall, the
 * brighter one wins, so the picture never gets brighter than in one light.
 * The lights follow slow paths of their own, `a + b · sin(f · t + phase)`
 * along each axis, through the middle of the frame, so about as much of the
 * picture is lit all the time and it never pulses brighter and darker.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * dark the picture is outside the lights). The lights move with the time
 * since the effect started, so they follow the same path in the preview and
 * in the export.
 */
class SpotlightVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uTime", (effectTimeUs / 1_000_000.0).toFloat())
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.spotlight"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> SpotlightVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> SpotlightVideoEffect(params) }
        }

        // `l` is the frame's longer side; each light's reach is a share of it.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uTime;

float spot(vec2 p, vec2 centre, float reach) {
  vec2 d = (p - centre) / reach;
  float r2 = dot(d, d);
  return exp(-r2 * r2 * r2);
}

void main() {
  vec2 p = vTexCoord * uSize;
  float l = max(uSize.x, uSize.y);
  float t = uTime;
  vec2 warmCentre = uSize * vec2(0.5 + 0.28 * sin(0.41 * t + 0.3), 0.56 + 0.2 * sin(0.53 * t + 1.7));
  vec2 coolCentre = uSize * vec2(0.5 + 0.3 * sin(0.33 * t + 3.4), 0.44 + 0.22 * sin(0.47 * t + 0.6));
  vec3 light = max(
    vec3(1.12, 1.04, 0.9) * spot(p, warmCentre, 0.2 * l),
    vec3(0.92, 0.98, 1.12) * spot(p, coolCentre, 0.17 * l));
  float dark = 0.8 * uIntensity;
  vec3 base = tap(p);
  gl_FragColor = vec4(clamp(base * (1.0 - dark + dark * light), 0.0, 1.0), 1.0);
}
"""
    }
}
