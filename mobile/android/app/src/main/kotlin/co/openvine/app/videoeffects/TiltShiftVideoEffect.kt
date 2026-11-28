package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Tilt-shift: the picture blurs on both sides of a sharp band, across the
 * middle unless the user moves or turns it, and the colours turn a little
 * brighter and punchier, so the scene looks like a miniature.
 *
 * The blur grows from nothing at a tenth of the height from the band's middle
 * to its full radius at 42%, both scaled by the band's width. Each pixel
 * averages 32 taps spread over a disc, on a golden-angle spiral that is turned
 * by interleaved gradient noise from pixel to pixel, so the taps leave a fine
 * grain rather than ghost copies.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
 * strongly the edges blur and the colours lift), `focus` (0–1: where the band
 * lies, as a share of the height from the top, or of the width from the left
 * for an upright band), `width` (0.2–3: how wide the band and the ramp are, 1
 * by default) and `orientation` (1 for an upright band, 0 for one across).
 */
class TiltShiftVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val focus = numberOf(params, "focus", 0.5f, 0f, 1f)

    private val band = numberOf(params, "width", 1f, 0.2f, 3f)

    private val vertical = (params["orientation"] as? Number)?.toInt() == 1

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uFocus", focus)
        shader.setFloat("uBand", band)
        shader.setFloat("uVertical", if (vertical) 1f else 0f)
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
uniform float uFocus;
uniform float uBand;
uniform float uVertical;

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  float along = uVertical > 0.5 ? p.x / uSize.x : 1.0 - p.y / uSize.y;
  float away = abs(along - uFocus);
  float r = 0.03 * s * uIntensity * smoothstep(0.1 * uBand, 0.1 * uBand + 0.32, away);
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
