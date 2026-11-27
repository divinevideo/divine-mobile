package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Stained glass: the picture as panes of coloured glass, each filled with the
 * colour under its middle, held by dark lead.
 *
 * The panes are the cells of a Voronoi diagram: a grid with one point placed
 * at random in each square, every pixel belonging to the nearest point. The
 * lead runs where two cells meet, found as the distance to the nearest border
 * with Inigo Quilez's two passes over the squares around. The panes are
 * brighter and more colourful than the picture, a little lighter in the
 * middle, and each slightly lighter or darker than its neighbours. The panes
 * stay in place while the picture moves under them.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
 * the picture turns into glass), `size` (0.5–2.5: how large the panes are, as a
 * share of the default) and `outline` (0.3–3: how wide the lead between them
 * is, as a share of the default).
 */
class StainedGlassVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val pane = numberOf(params, "size", 1f, 0.5f, 2.5f)

    private val lead = numberOf(params, "outline", 1f, 0.3f, 3f)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uPane", pane)
        shader.setFloat("uLead", lead)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.stainedGlass"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> StainedGlassVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> StainedGlassVideoEffect(params) }
        }

        // `s` is the frame's shorter side, `g` a grid square's side and
        // `lead` half the lead's width, in pixels. The hash is Dave Hoskins'
        // "hash without sine" with 3.33 in place of its 33.33, as the
        // particles use it.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uPane;
uniform float uLead;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

vec2 hash2(vec2 q) {
  vec3 r = fract(vec3(q.xyx) * vec3(0.1031, 0.1030, 0.0973));
  r += dot(r, r.yzx + 3.33);
  return fract((r.xx + r.yz) * r.zy);
}

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  float g = max(8.0, s / 16.0 * uPane);
  vec2 q = p / g;
  vec2 cell = floor(q);
  vec2 inSquare = q - cell;
  vec2 best = vec2(0.0);
  vec2 toBest = vec2(0.0);
  float nearest = 8.0;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 o = vec2(float(i), float(j));
      vec2 r = o + 0.1 + 0.8 * hash2(cell + o) - inSquare;
      float d = dot(r, r);
      if (d < nearest) {
        nearest = d;
        toBest = r;
        best = o;
      }
    }
  }
  float border = 8.0;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 o = best + vec2(float(i), float(j));
      vec2 r = o + 0.1 + 0.8 * hash2(cell + o) - inSquare;
      vec2 between = r - toBest;
      if (dot(between, between) > 0.00001) {
        border = min(border, dot(0.5 * (toBest + r), normalize(between)));
      }
    }
  }
  vec3 color = tap(p);
  vec3 pane = tap(p + toBest * g);
  float tint = 0.9 + 0.2 * hash2(cell + best + 17.0).x;
  float shine = 1.15 - 0.35 * sqrt(nearest);
  vec3 glass = clamp(mix(vec3(luma(pane)), pane, 1.4) * tint * shine, 0.0, 1.0);
  float lead = max(1.0, s / 400.0) * uLead;
  float edge = 1.0 - smoothstep(lead - 0.75, lead + 0.75, border * g);
  vec3 window = mix(glass, vec3(0.06, 0.06, 0.07), edge);
  gl_FragColor = vec4(mix(color, window, uIntensity), 1.0);
}
"""
    }
}
