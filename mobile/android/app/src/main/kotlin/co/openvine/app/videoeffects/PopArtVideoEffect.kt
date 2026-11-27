package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects
import kotlin.math.roundToInt

/**
 * Pop art: the picture four times in a 2×2 grid, each copy screen-printed in
 * three flat tones of its own bold colour scheme.
 *
 * Each copy is the whole picture at half size. Its brightness is cut into a
 * dark, a middle and a light tone, with a narrow blend between them that
 * keeps the edges from crawling as the picture moves, and each tone takes
 * that copy's colour.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
 * the copies turn into the print), `grid` (1–4: how many copies line up along
 * each side). The grid shows at any intensity above zero, so at zero the
 * picture is left as it is.
 */
class PopArtVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val grid = numberOf(params, "grid", 2f, 1f, 4f).roundToInt().toFloat()

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uGrid", grid)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.popArt"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> PopArtVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> PopArtVideoEffect(params) }
        }

        // Copy 0 is at the bottom left, 1 at the bottom right, 2 at the top
        // left and 3 at the top right; `pick` chooses among four colours by
        // the copy's number without an array, which GLSL ES 1.00 cannot
        // initialise.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uGrid;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

// The colour of copy `i` among `a`, `b`, `c` and `d`.
vec3 pick(float i, vec3 a, vec3 b, vec3 c, vec3 d) {
  return mix(mix(a, b, step(0.5, i)), mix(c, d, step(2.5, i)), step(1.5, i));
}

void main() {
  vec2 p = vTexCoord * uSize;
  vec2 tile = uSize / uGrid;
  vec2 quadrant = min(floor(p / tile), uGrid - 1.0);
  vec2 local = mix(p, (p - tile * quadrant) * uGrid, step(0.0001, uIntensity));
  vec3 copy = tap(local);
  float l = luma(copy);
  float level = smoothstep(0.28, 0.32, l) + smoothstep(0.58, 0.62, l);
  float i = quadrant.x + 2.0 * quadrant.y;
  i -= 4.0 * floor(i / 4.0);
  vec3 dark = pick(i, vec3(0.1, 0.1, 0.35), vec3(0.3, 0.05, 0.4), vec3(0.55, 0.0, 0.1),
    vec3(0.0, 0.25, 0.3));
  vec3 mid = pick(i, vec3(1.0, 0.2, 0.6), vec3(1.0, 0.5, 0.1), vec3(0.45, 0.85, 0.2),
    vec3(1.0, 0.85, 0.0));
  vec3 light = pick(i, vec3(1.0, 0.9, 0.2), vec3(0.3, 0.9, 1.0), vec3(1.0, 0.75, 0.85),
    vec3(0.8, 0.7, 1.0));
  vec3 print = mix(mix(dark, mid, clamp(level, 0.0, 1.0)), light, clamp(level - 1.0, 0.0, 1.0));
  gl_FragColor = vec4(mix(copy, print, uIntensity), 1.0);
}
"""
    }
}
