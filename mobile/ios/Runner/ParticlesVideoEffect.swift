import Foundation
import divine_video_player
import pro_video_editor

/// Particles over the picture in one of its ``Style``s: snow, rain, autumn
/// leaves, cherry blossom petals, confetti and banknotes falling; hearts,
/// balloons, soap bubbles, music notes and embers rising; stars tumbling
/// down; or sparkles, bokeh and fireflies glowing where they are.
///
/// The picture is covered by a grid of cells in three layers, a far one with
/// small, slow particles and nearer ones with larger, faster ones. Each grid
/// moves with time, and each cell holds at most one particle, whose place,
/// size, sway, spin and colour come from a hash of the cell. A particle stays
/// inside its cell however it sways or spins, so each pixel only looks at the
/// cell it lies in, in each layer.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// many of the cells hold a particle). The particles move with the time since
/// the effect started, so they follow the same path in the preview and in the
/// export.
final class ParticlesVideoEffect: ShaderVideoEffect {
  /// What the particles are; the raw value is what the shader branches on.
  enum Style: Double, CaseIterable {
    case snow = 0
    case confetti = 1
    case hearts = 2
    case sparkles = 3
    case rain = 4
    case leaves = 5
    case blossoms = 6
    case bubbles = 7
    case bokeh = 8
    case notes = 9
    case stars = 10
    case fireflies = 11
    case embers = 12
    case money = 13
    case balloons = 14

    /// The id the Dart `CustomVideoEffect` names.
    var id: String {
      switch self {
      case .snow: return "divine.snow"
      case .confetti: return "divine.confetti"
      case .hearts: return "divine.hearts"
      case .sparkles: return "divine.sparkles"
      case .rain: return "divine.rain"
      case .leaves: return "divine.leaves"
      case .blossoms: return "divine.blossoms"
      case .bubbles: return "divine.bubbles"
      case .bokeh: return "divine.bokeh"
      case .notes: return "divine.notes"
      case .stars: return "divine.stars"
      case .fireflies: return "divine.fireflies"
      case .embers: return "divine.embers"
      case .money: return "divine.money"
      case .balloons: return "divine.balloons"
      }
    }
  }

  private let style: Style
  private let intensity: Double

  init(style: Style, params: [String: Any]) {
    self.style = style
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers every style, each under its own id, for exports and for the
  /// editor preview, and compiles the shader ahead of the first frame.
  static func register() {
    for style in Style.allCases {
      CustomVideoEffects.register(style.id) { params in
        ParticlesVideoEffect(style: style, params: params)
      }
      VideoFrameEffects.register(style.id) { params in
        ParticlesVideoEffect(style: style, params: params)
      }
    }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity, Double(effectTimeUs) / 1_000_000, style.rawValue] : nil
  }

  static let function = "divineParticles"

  /// Sizes within a cell are in cells; `s` is the frame's shorter side. The
  /// hash is Dave Hoskins' "hash without sine" with 3.33 in place of its
  /// 33.33, which keeps its values small enough for 32-bit floats to land
  /// within a thousandth of the exact result. The heart, the lens and the
  /// star are Inigo Quilez's `sdHeart`, `sdVesica` and `sdStar5`.
  static let source = """
    static float3 hash3(float2 p) {
      float3 q = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
      q += dot(q, q.yxz + 3.33);
      return fract((q.xxy + q.yzz) * q.zyx);
    }

    // Signed distance to a heart with its tip at the origin, one unit tall.
    static float heart(float2 p) {
      p.x = abs(p.x);
      if (p.y + p.x > 1.0) {
        return length(p - float2(0.25, 0.75)) - 0.353553;
      }
      float2 a = p - float2(0.0, 1.0);
      float2 b = p - 0.5 * max(p.x + p.y, 0.0);
      return sqrt(min(dot(a, a), dot(b, b))) * sign(p.x - p.y);
    }

    // Signed distance to a box of half-size b around the origin.
    static float box(float2 p, float2 b) {
      float2 q = abs(p) - b;
      return length(max(q, float2(0.0))) + min(max(q.x, q.y), 0.0);
    }

    // Distance to the segment from a to b.
    static float segment(float2 p, float2 a, float2 b) {
      float2 pa = p - a;
      float2 ba = b - a;
      float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
      return length(pa - ba * h);
    }

    // Signed distance to a lens around the origin, pointed at y = ±b and w wide
    // on either side of its middle.
    static float lens(float2 p, float b, float w) {
      float d = 0.5 * (b * b / w - w);
      p = abs(p);
      if ((p.y - b) * d > p.x * b) {
        return length(p - float2(0.0, b));
      }
      return length(p - float2(-d, 0.0)) - d - w;
    }

    // Signed distance to a five-pointed star around the origin with its points r
    // out and its inner corners rf of the way there.
    static float star(float2 p, float r, float rf) {
      float2 k1 = float2(0.809017, -0.587785);
      float2 k2 = float2(-0.809017, -0.587785);
      p.x = abs(p.x);
      p -= 2.0 * max(dot(k1, p), 0.0) * k1;
      p -= 2.0 * max(dot(k2, p), 0.0) * k2;
      p.x = abs(p.x);
      p.y -= r;
      float2 ba = rf * float2(-k1.y, k1.x) - float2(0.0, 1.0);
      float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
      return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
    }

    static float2 turn(float2 d, float angle) {
      float c = cos(angle);
      float n = sin(angle);
      return float2(c * d.x + n * d.y, c * d.y - n * d.x);
    }

    // Light added to the picture the way a screen blend does, so it never goes
    // past white.
    static float3 glow(float3 color, float3 light) {
      return 1.0 - (1.0 - color) * (1.0 - clamp(light, 0.0, 1.0));
    }

    // Per style: the cell size, how fast and which way the cells move, how far a
    // particle sways and how many cells hold one. Snow is the default.
    static float4 lookOf(int style) {
      if (style == 1) return float4(0.13, -0.32, 0.08, 0.6);
      if (style == 2) return float4(0.17, 0.12, 0.1, 0.35);
      if (style == 3) return float4(0.15, 0.03, 0.0, 0.45);
      if (style == 4) return float4(0.2, -1.5, 0.0, 0.7);
      if (style == 5) return float4(0.2, -0.14, 0.1, 0.4);
      if (style == 6) return float4(0.15, -0.12, 0.1, 0.45);
      if (style == 7) return float4(0.18, 0.09, 0.08, 0.35);
      if (style == 8) return float4(0.32, 0.025, 0.05, 0.45);
      if (style == 9) return float4(0.2, 0.1, 0.06, 0.35);
      if (style == 10) return float4(0.15, -0.1, 0.08, 0.45);
      if (style == 11) return float4(0.18, 0.015, 0.06, 0.4);
      if (style == 12) return float4(0.13, 0.35, 0.09, 0.55);
      if (style == 13) return float4(0.2, -0.2, 0.1, 0.45);
      if (style == 14) return float4(0.3, 0.1, 0.06, 0.35);
      return float4(0.14, -0.22, 0.1, 0.75);
    }

    static float3 snowflake(float3 color, float2 d, float3 g, float alpha) {
      float r = 0.07 + 0.05 * g.z;
      return mix(color, float3(0.97, 0.98, 1.0), alpha * (1.0 - smoothstep(r * 0.3, r, length(d))));
    }

    static float3 confetti(float3 color, float2 d, float3 h, float3 g, float alpha, float t) {
      float tumble = cos(t * (3.0 + 3.0 * g.y) + 6.2832 * h.y);
      float edge = box(turn(d, 6.2832 * g.z + t * (1.5 + 2.5 * g.x) * sign(h.x - 0.5)), float2(0.11 * abs(tumble) + 0.01, 0.05));
      float3 paper = (0.55 + 0.45 * cos(6.2832 * (fract(g.z * 7.31) + float3(0.0, 0.33, 0.67)))) * (0.65 + 0.35 * abs(tumble));
      return mix(color, paper, alpha * (1.0 - smoothstep(-0.012, 0.012, edge)));
    }

    static float3 heartParticle(float3 color, float2 d, float3 g, float alpha, float t) {
      float size = 0.13 + 0.04 * g.z;
      float edge = heart(turn(d, 0.3 * sin(t * (1.0 + g.x) + 6.2832 * g.y)) / size + float2(0.0, 0.5)) * size;
      float3 pink = mix(float3(0.93, 0.13, 0.3), float3(1.0, 0.45, 0.65), fract(g.z * 7.31));
      return mix(color, pink, alpha * 0.92 * (1.0 - smoothstep(-0.012, 0.012, edge)));
    }

    static float3 sparkle(float3 color, float2 d, float3 g, float alpha, float t) {
      float twinkle = 0.5 + 0.5 * sin(t * (1.6 + 1.6 * g.x) + 6.2832 * g.y);
      float reach = (0.1 + 0.1 * g.z) * (0.3 + 0.7 * twinkle);
      float2 m = abs(d);
      float rays = exp(-m.x / 0.016) * max(1.0 - m.y / reach, 0.0) + exp(-m.y / 0.016) * max(1.0 - m.x / reach, 0.0);
      float core = exp(-dot(d, d) / (reach * reach * 0.05));
      return mix(color, float3(1.0, 0.93, 0.75), alpha * twinkle * min(rays + core, 1.0));
    }

    // A streak along the way the drops fall, brightest at its leading end.
    static float3 raindrop(float3 color, float2 d, float3 g, float alpha, float2 fall) {
      float along = dot(d, fall);
      float across = abs(fall.x * d.y - fall.y * d.x);
      float reach = 0.14 + 0.08 * g.z;
      float line = 1.0 - smoothstep(0.004, 0.011, length(float2(across, max(abs(along) - reach, 0.0))));
      return mix(color, float3(0.82, 0.88, 0.96), alpha * 0.7 * line * (0.25 + 0.75 * smoothstep(-reach, reach, along)));
    }

    // A lens-shaped leaf on a stalk that rocks with its sway and turns over as it
    // falls, in reds, oranges, yellows and the odd brown.
    static float3 leaf(float3 color, float2 d, float3 h, float3 g, float alpha, float t) {
      float tumble = cos(t * (1.2 + 1.2 * g.z) + 6.2832 * h.y);
      float2 u = turn(d, 2.0 * g.z - 1.0 + 0.6 * cos(t * (0.6 + 0.6 * g.x) + 6.2832 * g.y));
      float blade = lens(u, 0.11, 0.05 * abs(tumble) + 0.006);
      float stalk = segment(u, float2(0.0, -0.11), float2(0.0, -0.128)) - 0.006;
      float hue = fract(g.z * 7.31);
      float3 tone = mix(float3(0.78, 0.2, 0.08), float3(0.95, 0.5, 0.1), smoothstep(0.0, 0.5, hue));
      tone = mix(tone, float3(0.92, 0.72, 0.18), smoothstep(0.5, 1.0, hue));
      tone = mix(tone, float3(0.5, 0.28, 0.12), step(0.8, fract(g.z * 13.7)));
      tone *= (0.6 + 0.4 * abs(tumble)) * (1.0 - 0.35 * (1.0 - smoothstep(0.003, 0.007, abs(u.x))));
      tone = mix(tone, tone * 0.6, step(stalk, blade));
      return mix(color, tone, alpha * (1.0 - smoothstep(-0.012, 0.012, min(blade, stalk))));
    }

    // A cherry blossom petal: an egg with a notch in its wide end, fluttering and
    // turning as the wind carries it, pale at the tip and pinker at the base.
    static float3 petal(float3 color, float2 d, float3 h, float3 g, float alpha, float t) {
      float flutter = cos(t * (2.0 + 2.0 * g.y) + 6.2832 * h.y);
      float2 u = turn(d, 6.2832 * g.z + t * (0.8 + 1.2 * g.x) * sign(h.x - 0.5));
      float w = 0.075 * (0.25 + 0.75 * abs(flutter));
      float2 e = float2(u.x / (w * (0.8 + 0.25 * clamp(u.y / 0.1, -1.0, 1.0))), u.y / 0.1);
      float edge = max(max((length(e) - 1.0) * w, max(abs(u.y) - 0.1, abs(u.x) - 0.08)), 0.03 - length(u - float2(0.0, 0.11)));
      float3 tone = mix(float3(0.96, 0.55, 0.7), float3(1.0, 0.87, 0.91), smoothstep(-1.0, 1.0, e.y)) * (0.75 + 0.25 * abs(flutter));
      return mix(color, tone, alpha * 0.95 * (1.0 - smoothstep(-0.012, 0.012, edge)));
    }

    // A soap bubble: a clear film that shimmers in rainbow colours, more so
    // towards its rim, with a highlight up on its left.
    static float3 bubble(float3 color, float2 d, float3 g, float alpha, float t) {
      float r = 0.08 + 0.07 * g.z;
      float wobble = 0.04 * sin(t * (2.0 + 2.0 * g.x) + 6.2832 * g.y);
      float2 u = d * float2(1.0 + wobble, 1.0 - wobble);
      float l = length(u);
      float film = 1.0 - smoothstep(-0.006, 0.006, l - r);
      float rim = pow(clamp(l / r, 0.0, 1.0), 6.0) * film;
      float3 iris = 0.6 + 0.4 * cos(6.2832 * (g.x + 0.12 * t + 0.5 * (u.x - 0.6 * u.y) / r + float3(0.0, 0.33, 0.67)));
      float2 shine = u - float2(-0.4, 0.45) * r;
      color = mix(color, iris, alpha * (0.08 * film + 0.6 * rim));
      return glow(color, float3(alpha * film * 0.8 * exp(-dot(shine, shine) / (0.04 * r * r))));
    }

    // A soft disc of out-of-focus light, brighter at its edge, slowly brightening
    // and dimming.
    static float3 bokeh(float3 color, float2 d, float3 g, float alpha, float t) {
      float r = 0.11 + 0.08 * g.z;
      float l = length(d);
      float disc = (1.0 - smoothstep(r - 0.025, r, l)) * (0.6 + 0.4 * smoothstep(0.5 * r, r, l));
      float pulse = 0.5 + 0.5 * sin(t * (0.5 + 0.5 * g.x) + 6.2832 * g.y);
      float3 tint = 0.75 + 0.25 * cos(6.2832 * (fract(g.z * 7.31) + float3(0.0, 0.2, 0.45)));
      return glow(color, tint * (alpha * disc * (0.2 + 0.35 * pulse)));
    }

    // A note, single or two beamed together, rocking as it rises: pale, in a dark
    // outline so it shows on light pictures too.
    static float3 note(float3 color, float2 d, float3 g, float alpha, float t) {
      float size = 0.155;
      bool pair = fract(g.z * 13.7) > 0.5;
      float2 u = turn(d, 0.35 * sin(t * (1.0 + g.x) + 6.2832 * g.y)) / size + (pair ? float2(0.36, 0.48) : float2(0.14, 0.4));
      float edge = (length(turn(u, 0.4) / float2(0.3, 0.21)) - 1.0) * 0.21;
      edge = min(edge, segment(u, float2(0.27, 0.06), float2(0.27, 1.0)) - 0.045);
      if (pair) {
        float2 v = u - float2(0.72, 0.16);
        edge = min(edge, (length(turn(v, 0.4) / float2(0.3, 0.21)) - 1.0) * 0.21);
        edge = min(edge, segment(v, float2(0.27, 0.06), float2(0.27, 1.0)) - 0.045);
        edge = min(edge, segment(u, float2(0.27, 0.93), float2(0.99, 1.09)) - 0.075);
      } else {
        edge = min(edge, segment(u, float2(0.27, 1.0), float2(0.55, 0.62)) - 0.05);
        edge = min(edge, segment(u, float2(0.55, 0.62), float2(0.5, 0.42)) - 0.045);
      }
      edge *= size;
      float fill = 1.0 - smoothstep(-0.012, 0.012, edge);
      float ink = 1.0 - smoothstep(0.0, 0.03, edge);
      float3 tint = 0.82 + 0.18 * cos(6.2832 * (fract(g.z * 7.31) + float3(0.0, 0.33, 0.67)));
      color = mix(color, color * 0.35, alpha * 0.6 * max(ink - fill, 0.0));
      return mix(color, tint, alpha * fill);
    }

    // A spinning five-pointed star, gold or now and then silver, lighter towards
    // its middle and glinting.
    static float3 starParticle(float3 color, float2 d, float3 h, float3 g, float alpha, float t) {
      float r = 0.1 + 0.04 * g.z;
      float edge = star(turn(d, 6.2832 * g.z + t * (0.6 + 0.8 * g.x) * sign(h.x - 0.5)), r, 0.45);
      float inner = clamp(-edge / (0.35 * r), 0.0, 1.0);
      float glint = 0.5 + 0.5 * sin(t * (2.0 + 2.0 * g.y) + 6.2832 * h.y);
      float3 tone = mix(float3(0.93, 0.6, 0.1), float3(1.0, 0.95, 0.6), inner);
      tone = mix(tone, float3(0.72, 0.76, 0.84) + 0.24 * inner, step(0.75, fract(g.z * 7.31)));
      tone = min(tone * (0.85 + 0.25 * glint), float3(1.0));
      return mix(color, tone, alpha * 0.95 * (1.0 - smoothstep(-0.012, 0.012, edge)));
    }

    // A firefly: a small yellow-green light wandering about, glowing up and
    // fading away again.
    static float3 firefly(float3 color, float2 d, float3 g, float alpha, float t) {
      d.y -= 0.06 * sin(t * (0.5 + 0.5 * g.z) + 6.2832 * g.x);
      float blink = smoothstep(0.25, 0.9, 0.5 + 0.5 * sin(t * (0.9 + 0.9 * g.x) + 6.2832 * g.y));
      float r2 = dot(d, d);
      float core = exp(-r2 / 0.0008);
      float3 tint = mix(float3(0.75, 1.0, 0.3), float3(1.0, 1.0, 0.85), core);
      return glow(color, tint * (blink * alpha * (core + 0.55 * exp(-r2 / 0.006))));
    }

    // An ember: a flickering spark streaked by its rise, dimming the higher it
    // gets, height being 0 at the bottom of the picture and 1 at its top.
    static float3 ember(float3 color, float2 d, float3 g, float alpha, float t, float height) {
      d.x -= 0.03 * sin(t * (3.0 + 2.0 * g.z) + 6.2832 * g.x);
      float flicker = 0.6 + 0.4 * sin(t * (6.0 + 6.0 * g.x) + 6.2832 * g.y);
      float2 e = d * float2(1.0, 0.45);
      float core = exp(-dot(e, e) / 0.0006);
      float3 tint = mix(mix(float3(1.0, 0.32, 0.06), float3(1.0, 0.72, 0.25), fract(g.z * 7.31)), float3(1.0, 0.92, 0.7), 0.6 * core);
      return glow(color, tint * (alpha * flicker * (1.0 - 0.7 * height) * (1.3 * core + 0.5 * exp(-dot(d, d) / 0.0036))));
    }

    // A banknote, spinning and turning over as it falls: green paper with a dark
    // frame and an oval in the middle.
    static float3 banknote(float3 color, float2 d, float3 h, float3 g, float alpha, float t) {
      float tumble = cos(t * (2.0 + 2.0 * g.y) + 6.2832 * h.y);
      float2 u = turn(d, 6.2832 * g.z + t * (0.6 + 1.0 * g.x) * sign(h.x - 0.5));
      float breadth = 0.062 * abs(tumble) + 0.004;
      float edge = box(u, float2(0.12, breadth));
      float frame = box(u, float2(0.106, breadth - 0.014 * abs(tumble)));
      float oval = length(float2(u.x / 0.12 / 0.3, u.y / breadth / 0.62));
      float3 dark = float3(0.18, 0.42, 0.24);
      float3 tone = mix(float3(0.6, 0.8, 0.55), dark, smoothstep(-0.003, 0.003, frame));
      tone = mix(tone, float3(0.78, 0.9, 0.72), 0.6 * (1.0 - smoothstep(0.8, 0.9, oval)));
      tone = mix(tone, dark, 0.85 * (1.0 - smoothstep(0.08, 0.16, abs(oval - 1.0))));
      tone *= 0.6 + 0.4 * abs(tumble);
      return mix(color, tone, alpha * (1.0 - smoothstep(-0.012, 0.012, edge)));
    }

    // A shiny balloon swinging on its string as it rises.
    static float3 balloon(float3 color, float2 d, float3 g, float alpha, float t) {
      float size = 0.16;
      float2 u = turn(d, 0.12 * sin(t * (0.6 + 0.6 * g.x) + 6.2832 * g.y)) / size;
      float2 q = u - float2(0.0, 0.38);
      float2 n = float2(q.x * (1.0 - 0.15 * clamp(q.y / 0.72, -1.0, 1.0)) / 0.6, q.y / 0.72);
      float body = (length(n) - 1.0) * 0.6;
      float knot = length(u - float2(0.0, -0.41)) - 0.08;
      float line = abs(u.x - 0.06 * sin(6.0 * u.y + 2.0 * t + 6.2832 * g.y)) - 0.02;
      line = max(line, max(-1.12 - u.y, u.y + 0.45));
      float3 hue = clamp(abs(fract(fract(g.z * 7.31) + float3(0.0, 0.6667, 0.3333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
      float3 tone = mix(float3(1.0), hue, 0.8) * 0.92;
      float2 shine = q - float2(-0.25, 0.3);
      float3 skin = tone * (1.0 - 0.35 * smoothstep(0.3, 1.0, length(n)));
      skin = mix(skin, float3(1.0), 0.7 * exp(-dot(shine, shine) / 0.02));
      color = mix(color, float3(0.9), alpha * 0.7 * (1.0 - smoothstep(0.0, 0.06, line)));
      color = mix(color, tone * 0.7, alpha * (1.0 - smoothstep(-0.075, 0.075, knot)));
      return mix(color, skin, alpha * 0.95 * (1.0 - smoothstep(-0.075, 0.075, body)));
    }

    kernel void divineParticles(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float intensity = u[3].x;
      int style = int(u[3].z + 0.5);
      float2 p = pixelOf(u, gid, target.get_height());
      float s = min(f.size.x, f.size.y);
      float t = u[3].y;
      float3 color = tap(frame, f, p);
      float4 look = lookOf(style);
      // How fast the cells move sideways, for the rain and petals the wind slants.
      float drift = style == 4 ? 0.22 : (style == 6 ? 0.08 : 0.0);
      float2 fall = normalize(float2(drift, look.y));
      for (int k = 0; k < 3; k++) {
        float depth = 0.55 + 0.225 * float(k);
        float2 q = (p - float2(drift * depth * t * s, look.y * depth * t * s)) / (s * look.x * depth) + float2(0.37 * float(k), 0.0);
        float2 id = floor(q) + float2(131.0, 71.0) * float(k);
        float3 h = hash3(id);
        if (h.z >= look.w * intensity) continue;
        float3 g = hash3(id + 17.0);
        float2 d = fract(q) - (0.25 + 0.5 * h.xy);
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
          color = ember(color, d, g, alpha, t, p.y / f.size.y);
        } else if (style == 13) {
          color = banknote(color, d, h, g, alpha, t);
        } else if (style == 14) {
          color = balloon(color, d, g, alpha, t);
        } else {
          color = snowflake(color, d, g, alpha);
        }
      }
      target.write(float4(color, 1.0), gid);
    }
    """
}
