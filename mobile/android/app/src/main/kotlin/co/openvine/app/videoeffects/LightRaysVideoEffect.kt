package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Light rays: shafts of warm light fall from a sun just above the top edge,
 * through the gaps between trees, windows or hair.
 *
 * Each pixel reads 32 taps on the way from it halfway to the sun. A tap only
 * counts as far as it is a highlight, and nearer taps count more, so the
 * bright parts of the picture streak away from the sun and the dark parts
 * between them leave shadows. The taps start at a different point from pixel
 * to pixel, by interleaved gradient noise, as the zoom blur's do. A soft glow
 * around the sun lights the top of the picture even where nothing is bright,
 * and everything is added warm with a screen blend.
 *
 * The sun drifts slowly along the top edge, at the same strength all the
 * time, so the picture never pulses brighter and darker.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * strong the light is). The sun moves with the time since the effect started,
 * so it follows the same path in the preview and in the export.
 */
class LightRaysVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uTime", (effectTimeUs / 1_000_000.0).toFloat())
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.lightRays"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> LightRaysVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> LightRaysVideoEffect(params) }
        }

        // `l` is the frame's longer side; the sun's glow reaches a share of it.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uTime;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
  vec2 p = vTexCoord * uSize;
  float l = max(uSize.x, uSize.y);
  vec2 sun = uSize * vec2(0.3 + 0.25 * sin(0.23 * uTime + 0.8), 1.06);
  vec2 toSun = sun - p;
  float jitter = fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
  vec3 rays = vec3(0.0);
  for (int i = 0; i < 32; i++) {
    float share = (float(i) + jitter) / 32.0;
    vec3 c = tap(p + toSun * (0.5 * share));
    rays += c * (smoothstep(0.7, 1.0, luma(c)) * (1.0 - share));
  }
  vec2 d = toSun / l;
  float sunGlow = exp(-5.0 * dot(d, d));
  vec3 glow = vec3(1.0, 0.86, 0.62) * (rays * (2.0 / 16.0) + 0.35 * sunGlow);
  vec3 lit = clamp(glow * uIntensity, 0.0, 1.0);
  vec3 base = tap(p);
  gl_FragColor = vec4(1.0 - (1.0 - base) * (1.0 - lit), 1.0);
}
"""
    }
}
