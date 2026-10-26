package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Light leak: warm light washes in from the left and top edges and drifts
 * across the picture, the way stray light fogs a strip of film.
 *
 * Three soft lights, orange, red and gold, each follow a slow path of their
 * own, `a + b · sin(f · t + phase)` along each axis, and brighten the picture
 * with a screen blend. Each light keeps its strength while it moves, so the
 * picture never pulses brighter and darker: a flashing effect would need the
 * flashing lights warning.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * strong the light is). The lights move with the time since the effect
 * started, so they follow the same path in the preview and in the export.
 */
class LightLeakVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uTime", (effectTimeUs / 1_000_000.0).toFloat())
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.lightLeak"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> LightLeakVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> LightLeakVideoEffect(params) }
        }

        // `l` is the frame's longer side; each light's reach is a share of it
        // across and up.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uTime;

vec3 light(vec2 p, vec2 centre, vec2 reach, vec3 color) {
  vec2 d = (p - centre) / reach;
  return color * exp(-dot(d, d));
}

void main() {
  vec2 p = vTexCoord * uSize;
  float l = max(uSize.x, uSize.y);
  float t = uTime;
  vec3 base = tap(p);
  vec3 glow =
    light(p, uSize * vec2(-0.06 + 0.16 * sin(0.37 * t + 0.4), 0.62 + 0.3 * sin(0.21 * t + 1.1)),
      l * vec2(0.32, 0.6), vec3(0.95, 0.49, 0.17)) +
    light(p, uSize * vec2(0.45 + 0.4 * sin(0.18 * t + 2.2), 1.04 + 0.08 * sin(0.31 * t + 0.3)),
      l * vec2(0.55, 0.26), vec3(0.75, 0.21, 0.24)) +
    light(p, uSize * vec2(0.18 + 0.42 * sin(0.27 * t + 4.0), 0.8 + 0.18 * sin(0.47 * t + 2.6)),
      l * vec2(0.24, 0.24), vec3(0.55, 0.45, 0.28));
  vec3 leak = clamp(glow * uIntensity, 0.0, 1.0);
  gl_FragColor = vec4(1.0 - (1.0 - base) * (1.0 - leak), 1.0);
}
"""
    }
}
