package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Anamorphic: lamps, headlights and the sun throw long, thin blue streaks to
 * both sides, as through an anamorphic cinema lens.
 *
 * Each pixel reads 48 taps along its row, up to a quarter of the frame's
 * width to each side. A tap counts by the square of how far its brightness is
 * above a threshold near white, so only real highlights streak, not a bright
 * sky or a white wall, and by the square of how near it is. The taps start at
 * a different point from pixel to pixel, by interleaved gradient noise, as
 * the zoom blur's do. The streak is tinted blue and added with a screen blend.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * long and bright the streaks are, and how bright a highlight must be to
 * streak). The streaks follow the picture, so they need no time.
 */
class AnamorphicVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.anamorphic"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> AnamorphicVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> AnamorphicVideoEffect(params) }
        }

        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
  vec2 p = vTexCoord * uSize;
  float reach = (0.08 + 0.17 * uIntensity) * uSize.x;
  float threshold = 0.85 - 0.1 * uIntensity;
  float jitter = fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
  float streak = 0.0;
  for (int i = 0; i < 48; i++) {
    float x = 2.0 * (float(i) + jitter) / 48.0 - 1.0;
    float w = 1.0 - abs(x);
    float h = max(luma(tap(p + vec2(x * reach, 0.0))) - threshold, 0.0) / (1.0 - threshold);
    streak += h * h * w * w;
  }
  streak *= 3.0 / 48.0;
  vec3 lit = clamp(vec3(0.3, 0.62, 1.0) * (5.0 * streak * uIntensity), 0.0, 1.0);
  vec3 base = tap(p);
  gl_FragColor = vec4(1.0 - (1.0 - base) * (1.0 - lit), 1.0);
}
"""
    }
}
