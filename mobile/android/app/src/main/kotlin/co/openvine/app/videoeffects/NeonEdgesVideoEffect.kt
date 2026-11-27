package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Neon edges: the picture's outlines glow on black.
 *
 * An outline is where the brightness changes sharply, found from taps on
 * either side at three distances: the nearest draws a thin, white-hot core,
 * the further ones a glow fading out around it. Each outline glows in the
 * picture's own colour there; where the picture has little colour, in a
 * colour that turns with the outline's direction, so a grey picture glows in
 * every colour.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
 * the picture turns into neon), `width` (0.5–3: how wide the glow reaches, as a
 * share of the default), `single` (1 to glow in one colour rather than the
 * picture's own) and `color` (that colour, as an ARGB integer).
 */
class NeonEdgesVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val width = numberOf(params, "width", 1f, 0.5f, 3f)

    private val single = if ((params["single"] as? Number)?.toInt() == 1) 1f else 0f

    private val color = colorOf(params, "color", 0xFF00E5FF)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uWidth", width)
        shader.setFloat("uSingle", single)
        shader.setFloats("uColor", color)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.neonEdges"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> NeonEdgesVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> NeonEdgesVideoEffect(params) }
        }

        // `s` is the frame's shorter side, `e` the nearest taps' distance in
        // pixels. Where the brightness does not change at all the direction
        // has no angle, so the shader falls back to one rather than read
        // `atan(0, 0)`, which GLSL leaves undefined.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uWidth;
uniform float uSingle;
uniform vec3 uColor;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

// How the brightness changes across `p`, from taps `d` pixels to each side.
vec2 slope(vec2 p, float d) {
  return vec2(
    luma(tap(p + vec2(d, 0.0))) - luma(tap(p - vec2(d, 0.0))),
    luma(tap(p + vec2(0.0, d))) - luma(tap(p - vec2(0.0, d))));
}

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  float e = max(1.0, s / 540.0) * uWidth;
  vec3 color = tap(p);
  vec2 near = slope(p, e);
  vec2 mid = slope(p, 3.0 * e);
  vec2 far = slope(p, 7.0 * e);
  float core = smoothstep(0.08, 0.35, length(near));
  float glow = 0.9 * core + 0.4 * smoothstep(0.08, 0.45, length(mid)) +
    0.2 * smoothstep(0.08, 0.55, length(far));
  vec2 direction = near + mid + far;
  float size = length(direction);
  vec2 axis = size > 0.0001 ? direction / size : vec2(1.0, 0.0);
  float hue = atan(axis.y, axis.x) / 6.2831853 + 0.5;
  vec3 turning = clamp(abs(fract(hue + vec3(0.0, 0.6666667, 0.3333333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
  float lo = min(min(color.r, color.g), color.b);
  float hi = max(max(color.r, color.g), color.b);
  vec3 own = (color - lo) / max(hi - lo, 0.001);
  vec3 tint = uSingle > 0.5 ? uColor : mix(turning, own, smoothstep(0.08, 0.25, hi - lo));
  vec3 neon = clamp(tint * glow + 0.6 * core * core, 0.0, 1.0);
  gl_FragColor = vec4(mix(color, neon, uIntensity), 1.0);
}
"""
    }
}
