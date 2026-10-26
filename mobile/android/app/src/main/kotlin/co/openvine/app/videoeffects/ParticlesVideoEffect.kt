package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Particles over the picture in one of four [Style]s: snow falling, confetti
 * tumbling down, hearts floating up, or sparkles twinkling in place.
 *
 * The picture is covered by a grid of cells in three layers, a far one with
 * small, slow particles and nearer ones with larger, faster ones. Each grid
 * moves with time, and each cell holds at most one particle, whose place,
 * size, sway, spin and colour come from a hash of the cell. A particle stays
 * inside its cell however it sways or spins, so each pixel only looks at the
 * cell it lies in, in each layer.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * many of the cells hold a particle). The particles move with the time since
 * the effect started, so they follow the same path in the preview and in the
 * export.
 */
class ParticlesVideoEffect(private val style: Style, params: Map<String, Any?>) :
    ShaderVideoEffect(FRAGMENT_SHADER) {

    /** What the particles are; [shaderValue] is what the shader branches on. */
    enum class Style(val id: String, val shaderValue: Float) {
        SNOW("divine.snow", 0f),
        CONFETTI("divine.confetti", 1f),
        HEARTS("divine.hearts", 2f),
        SPARKLES("divine.sparkles", 3f),
    }

    private val intensity = intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uTime", (effectTimeUs / 1_000_000.0).toFloat())
        shader.setFloat("uStyle", style.shaderValue)
    }

    companion object {
        /** Registers every style, each under its own id, for exports and for the editor preview. */
        fun register() {
            for (style in Style.values()) {
                CustomVideoEffects.register(style.id) { params -> ParticlesVideoEffect(style, params) }
                VideoFrameEffects.register(style.id) { params -> ParticlesVideoEffect(style, params) }
            }
        }

        // Sizes within a cell are in cells; `s` is the frame's shorter side.
        // The hash is Dave Hoskins' "hash without sine" with 3.33 in place of
        // its 33.33, which keeps its values small enough for 32-bit floats to
        // land within a thousandth of the exact result. The heart is Inigo
        // Quilez's `sdHeart`.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uTime;
uniform float uStyle;

vec3 hash3(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  q += dot(q, q.yxz + 3.33);
  return fract((q.xxy + q.yzz) * q.zyx);
}

// Signed distance to a heart with its tip at the origin, one unit tall.
float heart(vec2 p) {
  p.x = abs(p.x);
  if (p.y + p.x > 1.0) {
    return length(p - vec2(0.25, 0.75)) - 0.353553;
  }
  vec2 a = p - vec2(0.0, 1.0);
  vec2 b = p - 0.5 * max(p.x + p.y, 0.0);
  return sqrt(min(dot(a, a), dot(b, b))) * sign(p.x - p.y);
}

vec2 turn(vec2 d, float angle) {
  float c = cos(angle);
  float n = sin(angle);
  return vec2(c * d.x + n * d.y, c * d.y - n * d.x);
}

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  float t = uTime;
  vec3 color = tap(p);
  // Snow, the default: per style the cell size, how fast and which way the
  // cells move, how far a particle sways and how many cells hold one.
  float cell = 0.14;
  float speed = -0.22;
  float sway = 0.1;
  float density = 0.75;
  if (uStyle > 2.5) {
    cell = 0.15;
    speed = 0.03;
    sway = 0.0;
    density = 0.45;
  } else if (uStyle > 1.5) {
    cell = 0.17;
    speed = 0.12;
    sway = 0.1;
    density = 0.35;
  } else if (uStyle > 0.5) {
    cell = 0.13;
    speed = -0.32;
    sway = 0.08;
    density = 0.6;
  }
  for (int k = 0; k < 3; k++) {
    float depth = 0.55 + 0.225 * float(k);
    vec2 q = (p - vec2(0.0, speed * depth * t * s)) / (s * cell * depth) + vec2(0.37 * float(k), 0.0);
    vec2 id = floor(q) + vec2(131.0, 71.0) * float(k);
    vec3 h = hash3(id);
    if (h.z >= density * uIntensity) continue;
    vec3 g = hash3(id + 17.0);
    vec2 d = fract(q) - (0.25 + 0.5 * h.xy);
    d.x -= sway * sin(t * (0.6 + 0.6 * g.x) + 6.2832 * g.y);
    float alpha = 0.55 + 0.45 * depth;
    if (uStyle > 2.5) {
      float twinkle = 0.5 + 0.5 * sin(t * (1.6 + 1.6 * g.x) + 6.2832 * g.y);
      float reach = (0.1 + 0.1 * g.z) * (0.3 + 0.7 * twinkle);
      vec2 m = abs(d);
      float rays = exp(-m.x / 0.016) * max(1.0 - m.y / reach, 0.0) + exp(-m.y / 0.016) * max(1.0 - m.x / reach, 0.0);
      float core = exp(-dot(d, d) / (reach * reach * 0.05));
      color = mix(color, vec3(1.0, 0.93, 0.75), alpha * twinkle * min(rays + core, 1.0));
    } else if (uStyle > 1.5) {
      float size = 0.13 + 0.04 * g.z;
      float edge = heart(turn(d, 0.3 * sin(t * (1.0 + g.x) + 6.2832 * g.y)) / size + vec2(0.0, 0.5)) * size;
      vec3 pink = mix(vec3(0.93, 0.13, 0.3), vec3(1.0, 0.45, 0.65), fract(g.z * 7.31));
      color = mix(color, pink, alpha * 0.92 * (1.0 - smoothstep(-0.012, 0.012, edge)));
    } else if (uStyle > 0.5) {
      float tumble = cos(t * (3.0 + 3.0 * g.y) + 6.2832 * h.y);
      vec2 b = abs(turn(d, 6.2832 * g.z + t * (1.5 + 2.5 * g.x) * sign(h.x - 0.5))) - vec2(0.11 * abs(tumble) + 0.01, 0.05);
      float edge = length(max(b, vec2(0.0))) + min(max(b.x, b.y), 0.0);
      vec3 paper = (0.55 + 0.45 * cos(6.2832 * (fract(g.z * 7.31) + vec3(0.0, 0.33, 0.67)))) * (0.65 + 0.35 * abs(tumble));
      color = mix(color, paper, alpha * (1.0 - smoothstep(-0.012, 0.012, edge)));
    } else {
      float r = 0.07 + 0.05 * g.z;
      color = mix(color, vec3(0.97, 0.98, 1.0), alpha * (1.0 - smoothstep(r * 0.3, r, length(d))));
    }
  }
  gl_FragColor = vec4(color, 1.0);
}
"""
    }
}
