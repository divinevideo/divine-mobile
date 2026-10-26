import Foundation
import divine_video_player
import pro_video_editor

/// Particles over the picture in one of four ``Style``s: snow falling,
/// confetti tumbling down, hearts floating up, or sparkles twinkling in place.
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

    /// The id the Dart `CustomVideoEffect` names.
    var id: String {
      switch self {
      case .snow: return "divine.snow"
      case .confetti: return "divine.confetti"
      case .hearts: return "divine.hearts"
      case .sparkles: return "divine.sparkles"
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
  /// within a thousandth of the exact result.
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

    static float2 turn(float2 d, float angle) {
      float c = cos(angle);
      float n = sin(angle);
      return float2(c * d.x + n * d.y, c * d.y - n * d.x);
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
      float style = u[3].z;
      float2 p = pixelOf(u, gid, target.get_height());
      float s = min(f.size.x, f.size.y);
      float t = u[3].y;
      float3 color = tap(frame, f, p);
      // Snow, the default: per style the cell size, how fast and which way the
      // cells move, how far a particle sways and how many cells hold one.
      float cell = 0.14;
      float speed = -0.22;
      float sway = 0.1;
      float density = 0.75;
      if (style > 2.5) {
        cell = 0.15;
        speed = 0.03;
        sway = 0.0;
        density = 0.45;
      } else if (style > 1.5) {
        cell = 0.17;
        speed = 0.12;
        sway = 0.1;
        density = 0.35;
      } else if (style > 0.5) {
        cell = 0.13;
        speed = -0.32;
        sway = 0.08;
        density = 0.6;
      }
      for (int k = 0; k < 3; k++) {
        float depth = 0.55 + 0.225 * float(k);
        float2 q = (p - float2(0.0, speed * depth * t * s)) / (s * cell * depth) + float2(0.37 * float(k), 0.0);
        float2 id = floor(q) + float2(131.0, 71.0) * float(k);
        float3 h = hash3(id);
        if (h.z >= density * intensity) continue;
        float3 g = hash3(id + 17.0);
        float2 d = fract(q) - (0.25 + 0.5 * h.xy);
        d.x -= sway * sin(t * (0.6 + 0.6 * g.x) + 6.2832 * g.y);
        float alpha = 0.55 + 0.45 * depth;
        if (style > 2.5) {
          float twinkle = 0.5 + 0.5 * sin(t * (1.6 + 1.6 * g.x) + 6.2832 * g.y);
          float reach = (0.1 + 0.1 * g.z) * (0.3 + 0.7 * twinkle);
          float2 m = abs(d);
          float rays = exp(-m.x / 0.016) * max(1.0 - m.y / reach, 0.0) + exp(-m.y / 0.016) * max(1.0 - m.x / reach, 0.0);
          float core = exp(-dot(d, d) / (reach * reach * 0.05));
          color = mix(color, float3(1.0, 0.93, 0.75), alpha * twinkle * min(rays + core, 1.0));
        } else if (style > 1.5) {
          float size = 0.13 + 0.04 * g.z;
          float edge = heart(turn(d, 0.3 * sin(t * (1.0 + g.x) + 6.2832 * g.y)) / size + float2(0.0, 0.5)) * size;
          float3 pink = mix(float3(0.93, 0.13, 0.3), float3(1.0, 0.45, 0.65), fract(g.z * 7.31));
          color = mix(color, pink, alpha * 0.92 * (1.0 - smoothstep(-0.012, 0.012, edge)));
        } else if (style > 0.5) {
          float tumble = cos(t * (3.0 + 3.0 * g.y) + 6.2832 * h.y);
          float2 b = abs(turn(d, 6.2832 * g.z + t * (1.5 + 2.5 * g.x) * sign(h.x - 0.5))) - float2(0.11 * abs(tumble) + 0.01, 0.05);
          float edge = length(max(b, float2(0.0))) + min(max(b.x, b.y), 0.0);
          float3 paper = (0.55 + 0.45 * cos(6.2832 * (fract(g.z * 7.31) + float3(0.0, 0.33, 0.67)))) * (0.65 + 0.35 * abs(tumble));
          color = mix(color, paper, alpha * (1.0 - smoothstep(-0.012, 0.012, edge)));
        } else {
          float r = 0.07 + 0.05 * g.z;
          color = mix(color, float3(0.97, 0.98, 1.0), alpha * (1.0 - smoothstep(r * 0.3, r, length(d))));
        }
      }
      target.write(float4(color, 1.0), gid);
    }
    """
}
