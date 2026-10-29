package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Particles over the picture in one of its [Style]s: snow, rain, autumn
 * leaves, cherry blossom petals, confetti and banknotes falling; hearts,
 * balloons, soap bubbles, music notes and embers rising; stars tumbling
 * down; or sparkles, bokeh and fireflies glowing where they are.
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
        RAIN("divine.rain", 4f),
        LEAVES("divine.leaves", 5f),
        BLOSSOMS("divine.blossoms", 6f),
        BUBBLES("divine.bubbles", 7f),
        BOKEH("divine.bokeh", 8f),
        NOTES("divine.notes", 9f),
        STARS("divine.stars", 10f),
        FIREFLIES("divine.fireflies", 11f),
        EMBERS("divine.embers", 12f),
        MONEY("divine.money", 13f),
        BALLOONS("divine.balloons", 14f),
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
        // land within a thousandth of the exact result. The heart, the lens
        // and the star are Inigo Quilez's `sdHeart`, `sdVesica` and `sdStar5`.
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

// Signed distance to a box of half-size b around the origin.
float box(vec2 p, vec2 b) {
  vec2 q = abs(p) - b;
  return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}

// Distance to the segment from a to b.
float segment(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h);
}

// Signed distance to a lens around the origin, pointed at y = ±b and w wide
// on either side of its middle.
float lens(vec2 p, float b, float w) {
  float d = 0.5 * (b * b / w - w);
  p = abs(p);
  if ((p.y - b) * d > p.x * b) {
    return length(p - vec2(0.0, b));
  }
  return length(p - vec2(-d, 0.0)) - d - w;
}

// Signed distance to a five-pointed star around the origin with its points r
// out and its inner corners rf of the way there.
float star(vec2 p, float r, float rf) {
  vec2 k1 = vec2(0.809017, -0.587785);
  vec2 k2 = vec2(-0.809017, -0.587785);
  p.x = abs(p.x);
  p -= 2.0 * max(dot(k1, p), 0.0) * k1;
  p -= 2.0 * max(dot(k2, p), 0.0) * k2;
  p.x = abs(p.x);
  p.y -= r;
  vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
  float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
  return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

vec2 turn(vec2 d, float angle) {
  float c = cos(angle);
  float n = sin(angle);
  return vec2(c * d.x + n * d.y, c * d.y - n * d.x);
}

// Light added to the picture the way a screen blend does, so it never goes
// past white.
vec3 glow(vec3 color, vec3 light) {
  return 1.0 - (1.0 - color) * (1.0 - clamp(light, 0.0, 1.0));
}

// Per style: the cell size, how fast and which way the cells move, how far a
// particle sways and how many cells hold one. Snow is the default.
vec4 lookOf(int style) {
  if (style == 1) return vec4(0.13, -0.32, 0.08, 0.6);
  if (style == 2) return vec4(0.17, 0.12, 0.1, 0.35);
  if (style == 3) return vec4(0.15, 0.03, 0.0, 0.45);
  if (style == 4) return vec4(0.2, -1.5, 0.0, 0.7);
  if (style == 5) return vec4(0.2, -0.14, 0.1, 0.4);
  if (style == 6) return vec4(0.15, -0.12, 0.1, 0.45);
  if (style == 7) return vec4(0.18, 0.09, 0.08, 0.35);
  if (style == 8) return vec4(0.32, 0.025, 0.05, 0.45);
  if (style == 9) return vec4(0.2, 0.1, 0.06, 0.35);
  if (style == 10) return vec4(0.15, -0.1, 0.08, 0.45);
  if (style == 11) return vec4(0.18, 0.015, 0.06, 0.4);
  if (style == 12) return vec4(0.13, 0.35, 0.09, 0.55);
  if (style == 13) return vec4(0.2, -0.2, 0.1, 0.45);
  if (style == 14) return vec4(0.3, 0.1, 0.06, 0.35);
  return vec4(0.14, -0.22, 0.1, 0.75);
}

vec3 snowflake(vec3 color, vec2 d, vec3 g, float alpha) {
  float r = 0.07 + 0.05 * g.z;
  return mix(color, vec3(0.97, 0.98, 1.0), alpha * (1.0 - smoothstep(r * 0.3, r, length(d))));
}

vec3 confetti(vec3 color, vec2 d, vec3 h, vec3 g, float alpha, float t) {
  float tumble = cos(t * (3.0 + 3.0 * g.y) + 6.2832 * h.y);
  float edge = box(turn(d, 6.2832 * g.z + t * (1.5 + 2.5 * g.x) * sign(h.x - 0.5)), vec2(0.11 * abs(tumble) + 0.01, 0.05));
  vec3 paper = (0.55 + 0.45 * cos(6.2832 * (fract(g.z * 7.31) + vec3(0.0, 0.33, 0.67)))) * (0.65 + 0.35 * abs(tumble));
  return mix(color, paper, alpha * (1.0 - smoothstep(-0.012, 0.012, edge)));
}

vec3 heartParticle(vec3 color, vec2 d, vec3 g, float alpha, float t) {
  float size = 0.13 + 0.04 * g.z;
  float edge = heart(turn(d, 0.3 * sin(t * (1.0 + g.x) + 6.2832 * g.y)) / size + vec2(0.0, 0.5)) * size;
  vec3 pink = mix(vec3(0.93, 0.13, 0.3), vec3(1.0, 0.45, 0.65), fract(g.z * 7.31));
  return mix(color, pink, alpha * 0.92 * (1.0 - smoothstep(-0.012, 0.012, edge)));
}

vec3 sparkle(vec3 color, vec2 d, vec3 g, float alpha, float t) {
  float twinkle = 0.5 + 0.5 * sin(t * (1.6 + 1.6 * g.x) + 6.2832 * g.y);
  float reach = (0.1 + 0.1 * g.z) * (0.3 + 0.7 * twinkle);
  vec2 m = abs(d);
  float rays = exp(-m.x / 0.016) * max(1.0 - m.y / reach, 0.0) + exp(-m.y / 0.016) * max(1.0 - m.x / reach, 0.0);
  float core = exp(-dot(d, d) / (reach * reach * 0.05));
  return mix(color, vec3(1.0, 0.93, 0.75), alpha * twinkle * min(rays + core, 1.0));
}

// A streak along the way the drops fall, brightest at its leading end.
vec3 raindrop(vec3 color, vec2 d, vec3 g, float alpha, vec2 fall) {
  float along = dot(d, fall);
  float across = abs(fall.x * d.y - fall.y * d.x);
  float reach = 0.14 + 0.08 * g.z;
  float line = 1.0 - smoothstep(0.004, 0.011, length(vec2(across, max(abs(along) - reach, 0.0))));
  return mix(color, vec3(0.82, 0.88, 0.96), alpha * 0.7 * line * (0.25 + 0.75 * smoothstep(-reach, reach, along)));
}

// A lens-shaped leaf on a stalk that rocks with its sway and turns over as it
// falls, in reds, oranges, yellows and the odd brown.
vec3 leaf(vec3 color, vec2 d, vec3 h, vec3 g, float alpha, float t) {
  float tumble = cos(t * (1.2 + 1.2 * g.z) + 6.2832 * h.y);
  vec2 u = turn(d, 2.0 * g.z - 1.0 + 0.6 * cos(t * (0.6 + 0.6 * g.x) + 6.2832 * g.y));
  float blade = lens(u, 0.11, 0.05 * abs(tumble) + 0.006);
  float stalk = segment(u, vec2(0.0, -0.11), vec2(0.0, -0.128)) - 0.006;
  float hue = fract(g.z * 7.31);
  vec3 tone = mix(vec3(0.78, 0.2, 0.08), vec3(0.95, 0.5, 0.1), smoothstep(0.0, 0.5, hue));
  tone = mix(tone, vec3(0.92, 0.72, 0.18), smoothstep(0.5, 1.0, hue));
  tone = mix(tone, vec3(0.5, 0.28, 0.12), step(0.8, fract(g.z * 13.7)));
  tone *= (0.6 + 0.4 * abs(tumble)) * (1.0 - 0.35 * (1.0 - smoothstep(0.003, 0.007, abs(u.x))));
  tone = mix(tone, tone * 0.6, step(stalk, blade));
  return mix(color, tone, alpha * (1.0 - smoothstep(-0.012, 0.012, min(blade, stalk))));
}

// A cherry blossom petal: an egg with a notch in its wide end, fluttering and
// turning as the wind carries it, pale at the tip and pinker at the base.
vec3 petal(vec3 color, vec2 d, vec3 h, vec3 g, float alpha, float t) {
  float flutter = cos(t * (2.0 + 2.0 * g.y) + 6.2832 * h.y);
  vec2 u = turn(d, 6.2832 * g.z + t * (0.8 + 1.2 * g.x) * sign(h.x - 0.5));
  float w = 0.075 * (0.25 + 0.75 * abs(flutter));
  vec2 e = vec2(u.x / (w * (0.8 + 0.25 * clamp(u.y / 0.1, -1.0, 1.0))), u.y / 0.1);
  float edge = max(max((length(e) - 1.0) * w, max(abs(u.y) - 0.1, abs(u.x) - 0.08)), 0.03 - length(u - vec2(0.0, 0.11)));
  vec3 tone = mix(vec3(0.96, 0.55, 0.7), vec3(1.0, 0.87, 0.91), smoothstep(-1.0, 1.0, e.y)) * (0.75 + 0.25 * abs(flutter));
  return mix(color, tone, alpha * 0.95 * (1.0 - smoothstep(-0.012, 0.012, edge)));
}

// A soap bubble: a clear film that shimmers in rainbow colours, more so
// towards its rim, with a highlight up on its left.
vec3 bubble(vec3 color, vec2 d, vec3 g, float alpha, float t) {
  float r = 0.08 + 0.07 * g.z;
  float wobble = 0.04 * sin(t * (2.0 + 2.0 * g.x) + 6.2832 * g.y);
  vec2 u = d * vec2(1.0 + wobble, 1.0 - wobble);
  float l = length(u);
  float film = 1.0 - smoothstep(-0.006, 0.006, l - r);
  float rim = pow(clamp(l / r, 0.0, 1.0), 6.0) * film;
  vec3 iris = 0.6 + 0.4 * cos(6.2832 * (g.x + 0.12 * t + 0.5 * (u.x - 0.6 * u.y) / r + vec3(0.0, 0.33, 0.67)));
  vec2 shine = u - vec2(-0.4, 0.45) * r;
  color = mix(color, iris, alpha * (0.08 * film + 0.6 * rim));
  return glow(color, vec3(alpha * film * 0.8 * exp(-dot(shine, shine) / (0.04 * r * r))));
}

// A soft disc of out-of-focus light, brighter at its edge, slowly brightening
// and dimming.
vec3 bokeh(vec3 color, vec2 d, vec3 g, float alpha, float t) {
  float r = 0.11 + 0.08 * g.z;
  float l = length(d);
  float disc = (1.0 - smoothstep(r - 0.025, r, l)) * (0.6 + 0.4 * smoothstep(0.5 * r, r, l));
  float pulse = 0.5 + 0.5 * sin(t * (0.5 + 0.5 * g.x) + 6.2832 * g.y);
  vec3 tint = 0.75 + 0.25 * cos(6.2832 * (fract(g.z * 7.31) + vec3(0.0, 0.2, 0.45)));
  return glow(color, tint * (alpha * disc * (0.2 + 0.35 * pulse)));
}

// A note, single or two beamed together, rocking as it rises: pale, in a dark
// outline so it shows on light pictures too.
vec3 note(vec3 color, vec2 d, vec3 g, float alpha, float t) {
  float size = 0.155;
  bool pair = fract(g.z * 13.7) > 0.5;
  vec2 u = turn(d, 0.35 * sin(t * (1.0 + g.x) + 6.2832 * g.y)) / size + (pair ? vec2(0.36, 0.48) : vec2(0.14, 0.4));
  float edge = (length(turn(u, 0.4) / vec2(0.3, 0.21)) - 1.0) * 0.21;
  edge = min(edge, segment(u, vec2(0.27, 0.06), vec2(0.27, 1.0)) - 0.045);
  if (pair) {
    vec2 v = u - vec2(0.72, 0.16);
    edge = min(edge, (length(turn(v, 0.4) / vec2(0.3, 0.21)) - 1.0) * 0.21);
    edge = min(edge, segment(v, vec2(0.27, 0.06), vec2(0.27, 1.0)) - 0.045);
    edge = min(edge, segment(u, vec2(0.27, 0.93), vec2(0.99, 1.09)) - 0.075);
  } else {
    edge = min(edge, segment(u, vec2(0.27, 1.0), vec2(0.55, 0.62)) - 0.05);
    edge = min(edge, segment(u, vec2(0.55, 0.62), vec2(0.5, 0.42)) - 0.045);
  }
  edge *= size;
  float fill = 1.0 - smoothstep(-0.012, 0.012, edge);
  float ink = 1.0 - smoothstep(0.0, 0.03, edge);
  vec3 tint = 0.82 + 0.18 * cos(6.2832 * (fract(g.z * 7.31) + vec3(0.0, 0.33, 0.67)));
  color = mix(color, color * 0.35, alpha * 0.6 * max(ink - fill, 0.0));
  return mix(color, tint, alpha * fill);
}

// A spinning five-pointed star, gold or now and then silver, lighter towards
// its middle and glinting.
vec3 starParticle(vec3 color, vec2 d, vec3 h, vec3 g, float alpha, float t) {
  float r = 0.1 + 0.04 * g.z;
  float edge = star(turn(d, 6.2832 * g.z + t * (0.6 + 0.8 * g.x) * sign(h.x - 0.5)), r, 0.45);
  float inner = clamp(-edge / (0.35 * r), 0.0, 1.0);
  float glint = 0.5 + 0.5 * sin(t * (2.0 + 2.0 * g.y) + 6.2832 * h.y);
  vec3 tone = mix(vec3(0.93, 0.6, 0.1), vec3(1.0, 0.95, 0.6), inner);
  tone = mix(tone, vec3(0.72, 0.76, 0.84) + 0.24 * inner, step(0.75, fract(g.z * 7.31)));
  tone = min(tone * (0.85 + 0.25 * glint), vec3(1.0));
  return mix(color, tone, alpha * 0.95 * (1.0 - smoothstep(-0.012, 0.012, edge)));
}

// A firefly: a small yellow-green light wandering about, glowing up and
// fading away again.
vec3 firefly(vec3 color, vec2 d, vec3 g, float alpha, float t) {
  d.y -= 0.06 * sin(t * (0.5 + 0.5 * g.z) + 6.2832 * g.x);
  float blink = smoothstep(0.25, 0.9, 0.5 + 0.5 * sin(t * (0.9 + 0.9 * g.x) + 6.2832 * g.y));
  float r2 = dot(d, d);
  float core = exp(-r2 / 0.0008);
  vec3 tint = mix(vec3(0.75, 1.0, 0.3), vec3(1.0, 1.0, 0.85), core);
  return glow(color, tint * (blink * alpha * (core + 0.55 * exp(-r2 / 0.006))));
}

// An ember: a flickering spark streaked by its rise, dimming the higher it
// gets, height being 0 at the bottom of the picture and 1 at its top.
vec3 ember(vec3 color, vec2 d, vec3 g, float alpha, float t, float height) {
  d.x -= 0.03 * sin(t * (3.0 + 2.0 * g.z) + 6.2832 * g.x);
  float flicker = 0.6 + 0.4 * sin(t * (6.0 + 6.0 * g.x) + 6.2832 * g.y);
  vec2 e = d * vec2(1.0, 0.45);
  float core = exp(-dot(e, e) / 0.0006);
  vec3 tint = mix(mix(vec3(1.0, 0.32, 0.06), vec3(1.0, 0.72, 0.25), fract(g.z * 7.31)), vec3(1.0, 0.92, 0.7), 0.6 * core);
  return glow(color, tint * (alpha * flicker * (1.0 - 0.7 * height) * (1.3 * core + 0.5 * exp(-dot(d, d) / 0.0036))));
}

// A banknote, spinning and turning over as it falls: green paper with a dark
// frame and an oval in the middle.
vec3 banknote(vec3 color, vec2 d, vec3 h, vec3 g, float alpha, float t) {
  float tumble = cos(t * (2.0 + 2.0 * g.y) + 6.2832 * h.y);
  vec2 u = turn(d, 6.2832 * g.z + t * (0.6 + 1.0 * g.x) * sign(h.x - 0.5));
  float breadth = 0.062 * abs(tumble) + 0.004;
  float edge = box(u, vec2(0.12, breadth));
  float frame = box(u, vec2(0.106, breadth - 0.014 * abs(tumble)));
  float oval = length(vec2(u.x / 0.12 / 0.3, u.y / breadth / 0.62));
  vec3 dark = vec3(0.18, 0.42, 0.24);
  vec3 tone = mix(vec3(0.6, 0.8, 0.55), dark, smoothstep(-0.003, 0.003, frame));
  tone = mix(tone, vec3(0.78, 0.9, 0.72), 0.6 * (1.0 - smoothstep(0.8, 0.9, oval)));
  tone = mix(tone, dark, 0.85 * (1.0 - smoothstep(0.08, 0.16, abs(oval - 1.0))));
  tone *= 0.6 + 0.4 * abs(tumble);
  return mix(color, tone, alpha * (1.0 - smoothstep(-0.012, 0.012, edge)));
}

// A shiny balloon swinging on its string as it rises.
vec3 balloon(vec3 color, vec2 d, vec3 g, float alpha, float t) {
  float size = 0.16;
  vec2 u = turn(d, 0.12 * sin(t * (0.6 + 0.6 * g.x) + 6.2832 * g.y)) / size;
  vec2 q = u - vec2(0.0, 0.38);
  vec2 n = vec2(q.x * (1.0 - 0.15 * clamp(q.y / 0.72, -1.0, 1.0)) / 0.6, q.y / 0.72);
  float body = (length(n) - 1.0) * 0.6;
  float knot = length(u - vec2(0.0, -0.41)) - 0.08;
  float line = abs(u.x - 0.06 * sin(6.0 * u.y + 2.0 * t + 6.2832 * g.y)) - 0.02;
  line = max(line, max(-1.12 - u.y, u.y + 0.45));
  vec3 hue = clamp(abs(fract(fract(g.z * 7.31) + vec3(0.0, 0.6667, 0.3333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
  vec3 tone = mix(vec3(1.0), hue, 0.8) * 0.92;
  vec2 shine = q - vec2(-0.25, 0.3);
  vec3 skin = tone * (1.0 - 0.35 * smoothstep(0.3, 1.0, length(n)));
  skin = mix(skin, vec3(1.0), 0.7 * exp(-dot(shine, shine) / 0.02));
  color = mix(color, vec3(0.9), alpha * 0.7 * (1.0 - smoothstep(0.0, 0.06, line)));
  color = mix(color, tone * 0.7, alpha * (1.0 - smoothstep(-0.075, 0.075, knot)));
  return mix(color, skin, alpha * 0.95 * (1.0 - smoothstep(-0.075, 0.075, body)));
}

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  float t = uTime;
  int style = int(uStyle + 0.5);
  vec3 color = tap(p);
  vec4 look = lookOf(style);
  // How fast the cells move sideways, for the rain and petals the wind slants.
  float drift = style == 4 ? 0.22 : (style == 6 ? 0.08 : 0.0);
  vec2 fall = normalize(vec2(drift, look.y));
  for (int k = 0; k < 3; k++) {
    float depth = 0.55 + 0.225 * float(k);
    vec2 q = (p - vec2(drift * depth * t * s, look.y * depth * t * s)) / (s * look.x * depth) + vec2(0.37 * float(k), 0.0);
    vec2 id = floor(q) + vec2(131.0, 71.0) * float(k);
    vec3 h = hash3(id);
    if (h.z >= look.w * uIntensity) continue;
    vec3 g = hash3(id + 17.0);
    vec2 d = fract(q) - (0.25 + 0.5 * h.xy);
    d.x -= look.z * sin(t * (0.6 + 0.6 * g.x) + 6.2832 * g.y);
    float alpha = 0.55 + 0.45 * depth;
    if (style == 1) {
      color = confetti(color, d, h, g, alpha, t);
    } else if (style == 2) {
      color = heartParticle(color, d, g, alpha, t);
    } else if (style == 3) {
      color = sparkle(color, d, g, alpha, t);
    } else if (style == 4) {
      color = raindrop(color, d, g, alpha, fall);
    } else if (style == 5) {
      color = leaf(color, d, h, g, alpha, t);
    } else if (style == 6) {
      color = petal(color, d, h, g, alpha, t);
    } else if (style == 7) {
      color = bubble(color, d, g, alpha, t);
    } else if (style == 8) {
      color = bokeh(color, d, g, alpha, t);
    } else if (style == 9) {
      color = note(color, d, g, alpha, t);
    } else if (style == 10) {
      color = starParticle(color, d, h, g, alpha, t);
    } else if (style == 11) {
      color = firefly(color, d, g, alpha, t);
    } else if (style == 12) {
      color = ember(color, d, g, alpha, t, p.y / uSize.y);
    } else if (style == 13) {
      color = banknote(color, d, h, g, alpha, t);
    } else if (style == 14) {
      color = balloon(color, d, g, alpha, t);
    } else {
      color = snowflake(color, d, g, alpha);
    }
  }
  gl_FragColor = vec4(color, 1.0);
}

"""
    }
}
