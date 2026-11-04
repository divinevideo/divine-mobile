package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * 8-bit: the picture as early console pixel art, in chunky pixels and 8-bit
 * colour.
 *
 * The shorter side is cut into 100 pixels, each the average of four taps
 * inside it. Its colour is cut down to 256: eight levels of red and of green
 * and four of blue, three bits, three and two. A 4 × 4 ordered dither mixes
 * neighbouring levels, so gradients turn into the regular dot patterns such
 * games showed. Where the shorter side is a multiple of four, as in every
 * common video size, no pixel centre lands right on a cell's edge, so no
 * cell depends on how the GPU rounds there.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * far the picture turns into pixel art).
 */
class EightBitVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.eightBit"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> EightBitVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> EightBitVideoEffect(params) }
        }

        // `s` is the frame's shorter side, `cell` one game pixel's size in
        // frame pixels. `bayer` is one step of the ordered dither, 0, 0.5,
        // 0.75 or 0.25 by where a cell sits in its 2 × 2 square; two steps
        // make the 4 × 4 threshold.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;

float bayer(vec2 a) {
  a = floor(a);
  return fract(a.x * 0.5 + a.y * a.y * 0.75);
}

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  float cell = max(1.0, s / 100.0);
  vec2 index = floor(p / cell);
  vec2 centre = (index + 0.5) * cell;
  float q = 0.25 * cell;
  vec3 color = tap(p);
  vec3 block = 0.25 * (tap(centre + vec2(-q, -q)) + tap(centre + vec2(q, -q)) +
    tap(centre + vec2(-q, q)) + tap(centre + vec2(q, q)));
  float threshold = 0.25 * bayer(0.5 * index) + bayer(index);
  vec3 levels = vec3(7.0, 7.0, 3.0);
  vec3 shade = clamp(floor(block * levels + threshold), vec3(0.0), levels) / levels;
  gl_FragColor = vec4(mix(color, shade, uIntensity), 1.0);
}
"""
    }
}
