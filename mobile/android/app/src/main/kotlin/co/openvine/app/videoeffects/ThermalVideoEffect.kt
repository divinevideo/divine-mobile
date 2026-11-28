package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Thermal camera: the picture as a thermal camera shows it, from cold black
 * and purple through red and orange to hot yellow and white.
 *
 * A camera cannot see heat, so the warmth is mostly how much redder than
 * green and blue the picture is, plus some of its brightness: skin, lips and
 * warm lights run hot, pale walls lukewarm, and blue, green and dark things
 * cold. A thermal camera's picture is soft, so the warmth is averaged over
 * five taps first, then stretched and run through an ironbow palette.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
 * the picture turns into the thermal view), `sensitivity` (0–1: how warm a spot
 * must be to glow; 0.5 by default, higher glows sooner).
 */
class ThermalVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val sensitivity = numberOf(params, "sensitivity", 0.5f, 0f, 1f)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uSensitivity", sensitivity)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.thermal"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> ThermalVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> ThermalVideoEffect(params) }
        }

        // `s` is the frame's shorter side, `e` the taps' distance in pixels.
        // The ironbow palette runs through six colours, one stretch of it
        // after another.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uSensitivity;

float warmth(vec3 c) {
  return 0.3 * dot(c, vec3(0.299, 0.587, 0.114)) + 1.6 * max(c.r - 0.5 * (c.g + c.b), 0.0);
}

vec3 ironbow(float t) {
  vec3 c = mix(vec3(0.0, 0.0, 0.12), vec3(0.35, 0.0, 0.55), clamp(t / 0.25, 0.0, 1.0));
  c = mix(c, vec3(0.85, 0.1, 0.25), clamp((t - 0.25) / 0.25, 0.0, 1.0));
  c = mix(c, vec3(1.0, 0.5, 0.0), clamp((t - 0.5) / 0.2, 0.0, 1.0));
  c = mix(c, vec3(1.0, 0.85, 0.1), clamp((t - 0.7) / 0.15, 0.0, 1.0));
  return mix(c, vec3(1.0, 1.0, 0.9), clamp((t - 0.85) / 0.15, 0.0, 1.0));
}

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  float e = max(1.0, s / 270.0);
  vec3 color = tap(p);
  float heat = (2.0 * warmth(color) + warmth(tap(p + vec2(e, 0.0))) +
    warmth(tap(p - vec2(e, 0.0))) + warmth(tap(p + vec2(0.0, e))) +
    warmth(tap(p - vec2(0.0, e)))) / 6.0;
  float shift = 0.6 * (uSensitivity - 0.5);
  vec3 thermal = ironbow(smoothstep(0.1 - shift, 0.75 - shift, heat));
  gl_FragColor = vec4(mix(color, thermal, uIntensity), 1.0);
}
"""
    }
}
