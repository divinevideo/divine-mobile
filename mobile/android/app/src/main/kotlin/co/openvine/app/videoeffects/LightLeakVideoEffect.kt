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
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
 * strong the light is), `hue` (0–360: how far the light's colours turn around
 * the colour wheel, in degrees), `size` (0.5–2: how large the patches of light
 * are, as a share of the default) and `speed` (0–3: how fast they drift, as a
 * share of the default; 0 holds them still). The lights move with the time
 * since the effect started, so they follow the same path in the preview and in
 * the export.
 */
class LightLeakVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val hue = turnOf(numberOf(params, "hue", 0f, 0f, 360f))

    private val spread = numberOf(params, "size", 1f, 0.5f, 2f)

    private val speed = numberOf(params, "speed", 1f, 0f, 3f)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uTime", (effectTimeUs / 1_000_000.0).toFloat())
        shader.setFloats("uHue", hue)
        shader.setFloat("uSpread", spread)
        shader.setFloat("uSpeed", speed)
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
uniform vec2 uHue;
uniform float uSpread;
uniform float uSpeed;

// c turned around the grey axis of the colour cube by the angle whose cosine
// and sine hue holds.
vec3 turnHue(vec3 c, vec2 hue) {
  vec3 k = vec3(0.57735);
  return c * hue.x + cross(k, c) * hue.y + k * dot(k, c) * (1.0 - hue.x);
}

vec3 light(vec2 p, vec2 centre, vec2 reach, vec3 color) {
  vec2 d = (p - centre) / reach;
  return color * exp(-dot(d, d));
}

void main() {
  vec2 p = vTexCoord * uSize;
  float l = max(uSize.x, uSize.y);
  float t = uTime * uSpeed;
  float reach = l * uSpread;
  vec3 base = tap(p);
  vec3 glow =
    light(p, uSize * vec2(-0.06 + 0.16 * sin(0.37 * t + 0.4), 0.62 + 0.3 * sin(0.21 * t + 1.1)),
      reach * vec2(0.32, 0.6), vec3(0.95, 0.49, 0.17)) +
    light(p, uSize * vec2(0.45 + 0.4 * sin(0.18 * t + 2.2), 1.04 + 0.08 * sin(0.31 * t + 0.3)),
      reach * vec2(0.55, 0.26), vec3(0.75, 0.21, 0.24)) +
    light(p, uSize * vec2(0.18 + 0.42 * sin(0.27 * t + 4.0), 0.8 + 0.18 * sin(0.47 * t + 2.6)),
      reach * vec2(0.24, 0.24), vec3(0.55, 0.45, 0.28));
  vec3 leak = clamp(turnHue(glow, uHue) * uIntensity, 0.0, 1.0);
  gl_FragColor = vec4(1.0 - (1.0 - base) * (1.0 - leak), 1.0);
}
"""
    }
}
