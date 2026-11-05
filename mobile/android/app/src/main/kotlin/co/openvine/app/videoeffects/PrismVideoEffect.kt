package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Prism: a rainbow falls across the top-right corner, as when a prism or a
 * crystal is held in front of the lens.
 *
 * The band runs diagonally, from the top edge to the right edge. Across it
 * the colour runs from red to violet, at full strength in its middle and
 * fading out at both sides. Under the band the picture splits into red and
 * blue edges across it, the further the stronger the band, and the rainbow
 * is added with a screen blend. The band drifts and breathes slowly, at the
 * same strength all the time, so the picture never pulses brighter and
 * darker.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * strong the rainbow and the split are). The band moves with the time since
 * the effect started, so it follows the same path in the preview and in the
 * export.
 */
class PrismVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uTime", (effectTimeUs / 1_000_000.0).toFloat())
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.prism"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> PrismVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> PrismVideoEffect(params) }
        }

        // `across` runs from 0 at the bottom-left corner to 1 at the top-right
        // one; the band's centre and width are on it. `hue` 0 is red, 0.75
        // violet. `l` is the frame's longer side.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uTime;

void main() {
  vec2 p = vTexCoord * uSize;
  float l = max(uSize.x, uSize.y);
  vec2 uv = p / uSize;
  float across = 0.45 * uv.x + 0.55 * uv.y;
  float centre = 0.72 + 0.06 * sin(0.31 * uTime + 1.3);
  float width = 0.14 + 0.02 * sin(0.23 * uTime + 0.4);
  float b = (across - centre) / width;
  float band = 1.0 - smoothstep(0.55, 1.0, abs(b));
  float hue = 0.375 * (b + 1.0);
  vec3 rainbow = clamp(abs(fract(hue + vec3(1.0, 0.6667, 0.3333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
  vec2 shift = normalize(vec2(0.45 / uSize.x, 0.55 / uSize.y)) * (0.008 * l * uIntensity * band);
  vec3 base = vec3(tap(p + shift).r, tap(p).g, tap(p - shift).b);
  vec3 lit = clamp(rainbow * (0.75 * band * uIntensity), 0.0, 1.0);
  gl_FragColor = vec4(1.0 - (1.0 - base) * (1.0 - lit), 1.0);
}
"""
    }
}
