package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Tilt-shift: the top and bottom of the picture blur while a band across the
 * middle stays sharp, and the colours turn a little brighter and punchier, so
 * the scene looks like a miniature.
 *
 * The blur grows from nothing at a tenth of the height from the middle to its
 * full radius at 42%. Each pixel averages 32 taps spread over a disc, on a
 * golden-angle spiral that is turned by interleaved gradient noise from pixel
 * to pixel, so the taps leave a fine grain rather than ghost copies.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * strongly the edges blur and the colours lift).
 */
class TiltShiftVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.tiltShift"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> TiltShiftVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> TiltShiftVideoEffect(params) }
        }

        // `s` is the frame's shorter side.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  float away = abs(p.y / uSize.y - 0.5);
  float r = 0.03 * s * uIntensity * smoothstep(0.1, 0.42, away);
  vec3 color = tap(p);
  if (r > 0.5) {
    float spin = 6.2832 * fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
    for (int i = 0; i < 32; i++) {
      float n = float(i);
      float angle = n * 2.399963 + spin;
      color += tap(p + r * sqrt((n + 0.5) / 32.0) * vec2(cos(angle), sin(angle)));
    }
    color /= 33.0;
  }
  float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
  color = mix(vec3(luma), color, 1.0 + 0.4 * uIntensity);
  color = (color - 0.5) * (1.0 + 0.12 * uIntensity) + 0.5;
  gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
"""
    }
}
