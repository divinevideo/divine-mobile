package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Spin blur: the picture streaks around its centre, as if the camera turned
 * during the exposure.
 *
 * Each pixel averages 32 taps along the arc through it around the centre,
 * reaching up to 0.11 radians either way, so the picture stays where it is
 * while its edges smear the most. The taps start at a different point from
 * pixel to pixel, by interleaved gradient noise, so they leave a fine grain
 * rather than rings. A frame without streaks, such as one between two hits
 * on the beat, reads each pixel once.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
 * long the streaks are) and, for an effect on the beat, `beatsUs`: the beats,
 * in microseconds after the effect's start. On the beat the streaks only show
 * on each hit and fade out over half a second; see [BlurHits].
 */
class SpinBlurVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val beatsUs = BlurHits.beatsOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uStrength", BlurHits.strength(intensity, beatsUs, effectTimeUs))
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.spinBlur"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> SpinBlurVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> SpinBlurVideoEffect(params) }
        }

        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uStrength;

void main() {
  vec2 p = vTexCoord * uSize;
  if (uStrength <= 0.0) {
    gl_FragColor = vec4(tap(p), 1.0);
    return;
  }
  vec2 c = uSize * 0.5;
  vec2 d = p - c;
  float jitter = fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
  vec3 color = vec3(0.0);
  for (int i = 0; i < 32; i++) {
    float a = 0.22 * uStrength * ((float(i) + jitter) / 32.0 - 0.5);
    float s = sin(a);
    float k = cos(a);
    color += tap(c + vec2(d.x * k - d.y * s, d.x * s + d.y * k));
  }
  gl_FragColor = vec4(color / 32.0, 1.0);
}
"""
    }
}
