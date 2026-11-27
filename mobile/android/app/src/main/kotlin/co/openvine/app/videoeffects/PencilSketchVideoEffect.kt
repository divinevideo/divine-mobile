package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Pencil sketch: the picture drawn in graphite on off-white paper, with
 * outlines and cross-hatching.
 *
 * The outlines follow where the brightness changes sharply, found with a
 * Sobel filter whose taps stay about the same share of the frame at every
 * resolution. The hatching comes in three layers of slightly wavy lines at
 * different angles, each drawn where the picture is darker than its
 * threshold, so the shadows get the most lines.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
 * the picture turns into the sketch), `density` (0.5–2: how close together the
 * hatching lies, as a share of the default) and `outline` (0–2: how dark the
 * outlines are, as a share of the default).
 */
class PencilSketchVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val density = numberOf(params, "density", 1f, 0.5f, 2f)

    private val outline = numberOf(params, "outline", 1f, 0f, 2f)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uDensity", density)
        shader.setFloat("uOutline", outline)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.pencilSketch"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> PencilSketchVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> PencilSketchVideoEffect(params) }
        }

        // `s` is the frame's shorter side, `e` the Sobel filter's step, `g`
        // the gap between hatching lines and `w` their width, all in pixels.
        // The tone is the mean brightness of the nine taps, which steadies
        // the hatching against noise. Each line's wave keeps its phase within
        // one turn, where the GPU's sine stays exact.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uDensity;
uniform float uOutline;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

float grain(vec2 q) {
  return fract(52.9829189 * fract(dot(q, vec2(0.06711056, 0.00583715))));
}

// How much of the pixel at `p` the lines across `n` cover, `g` apart and `w`
// wide. The wave keeps its phase within one turn, where the GPU's sine stays
// exact.
float hatch(vec2 p, vec2 n, float g, float w) {
  float along = dot(p, vec2(-n.y, n.x)) / g;
  float across = dot(p, n) / g + 0.12 * sin(6.2831853 * fract(along * 0.07));
  float d = abs(fract(across) - 0.5) * g;
  return clamp(0.5 * w - d + 0.5, 0.0, 1.0);
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
  float outline = smoothstep(0.2, 0.7, length(vec2(gx, gy)));
  float l = (luma(color) + tl + tc + tr + ml + mr + bl + bc + br) / 9.0;
  float g = max(3.0, s / 160.0 / uDensity);
  float w = max(1.0, s / 900.0);
  float a = hatch(p, vec2(0.70710678, 0.70710678), g, w) * (1.0 - smoothstep(0.62, 0.82, l));
  float b = hatch(p, vec2(0.70710678, -0.70710678), g, w) * (1.0 - smoothstep(0.35, 0.55, l));
  float c = hatch(p, vec2(0.25881905, 0.96592583), g, w) * (1.0 - smoothstep(0.12, 0.3, l));
  float shade = 1.0 - (1.0 - a) * (1.0 - b) * (1.0 - c);
  float tooth = grain(floor(p / e));
  float mark = 1.0 - (1.0 - 0.7 * shade * (0.8 + 0.2 * tooth)) * (1.0 - min(0.85 * outline * uOutline, 1.0));
  vec3 paper = vec3(0.97, 0.95, 0.91) * (0.97 + 0.03 * tooth);
  vec3 sketch = mix(paper, vec3(0.2, 0.2, 0.22), mark);
  gl_FragColor = vec4(mix(color, sketch, uIntensity), 1.0);
}
"""
    }
}
