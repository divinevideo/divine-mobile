package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects
import kotlin.math.roundToInt

/**
 * Comic: the picture as a printed comic, with flat poster colours, halftone
 * dots in the darker tones and ink outlines.
 *
 * The colours are saturated and their brightness cut into four bands, each
 * colour keeping its hue. The dots sit on a grid turned 45 degrees and grow
 * where the picture is darker. The ink follows where the brightness changes
 * sharply, found with a Sobel filter whose taps stay about the same share of
 * the frame at every resolution.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
 * the picture turns into the comic), `size` (0.5–2.5: how large the printed
 * dots are, as a share of the default), `outline` (0–2: how dark the inked
 * outlines are, as a share of the default) and `levels` (2–6: how many bands of
 * shade the colours fall into).
 */
class ComicVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val dot = numberOf(params, "size", 1f, 0.5f, 2.5f)

    private val ink = numberOf(params, "outline", 1f, 0f, 2f)

    private val levels = numberOf(params, "levels", 4f, 2f, 6f).roundToInt().toFloat()

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uDot", dot)
        shader.setFloat("uInk", ink)
        shader.setFloat("uLevels", levels)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.comic"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> ComicVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> ComicVideoEffect(params) }
        }

        // `s` is the frame's shorter side, `e` the Sobel filter's step in
        // pixels.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uDot;
uniform float uInk;
uniform float uLevels;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  float e = max(1.0, s / 540.0);
  vec3 color = tap(p);
  float tl = luma(tap(p + vec2(-e, e)));
  float tc = luma(tap(p + vec2(0.0, e)));
  float tr = luma(tap(p + vec2(e, e)));
  float ml = luma(tap(p + vec2(-e, 0.0)));
  float mr = luma(tap(p + vec2(e, 0.0)));
  float bl = luma(tap(p + vec2(-e, -e)));
  float bc = luma(tap(p + vec2(0.0, -e)));
  float br = luma(tap(p + vec2(e, -e)));
  float gx = tr + 2.0 * mr + br - tl - 2.0 * ml - bl;
  float gy = tl + 2.0 * tc + tr - bl - 2.0 * bc - br;
  float ink = smoothstep(0.3, 0.8, length(vec2(gx, gy)));
  float l = luma(color);
  vec3 vivid = mix(vec3(l), color, 1.4);
  float band = 0.2 + 0.81 * min(floor(l * uLevels), uLevels - 1.0) / (uLevels - 1.0);
  vec3 poster = clamp(vivid * band / max(l, 0.04), 0.0, 1.0);
  float cell = 0.018 * uDot * s;
  vec2 grid = vec2(p.x + p.y, p.y - p.x) * 0.70710678 / cell;
  vec2 d = (fract(grid) - 0.5) * cell;
  float radius = 0.6 * cell * sqrt(max(0.7 - l, 0.0));
  float spot = clamp(radius - length(d), 0.0, 1.0);
  vec3 comic = poster * (1.0 - 0.35 * spot) * (1.0 - min(0.85 * ink * uInk, 1.0));
  gl_FragColor = vec4(mix(color, comic, uIntensity), 1.0);
}
"""
    }
}
