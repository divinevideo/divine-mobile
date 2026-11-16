import Foundation
import divine_video_player
import pro_video_editor

/// Stained glass: the picture as panes of coloured glass, each filled with the
/// colour under its middle, held by dark lead.
///
/// The panes are the cells of a Voronoi diagram: a grid with one point placed
/// at random in each square, every pixel belonging to the nearest point. The
/// lead runs where two cells meet, found as the distance to the nearest border
/// with Inigo Quilez's two passes over the squares around. The panes are
/// brighter and more colourful than the picture, a little lighter in the
/// middle, and each slightly lighter or darker than its neighbours. The panes
/// stay in place while the picture moves under them.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// far the picture turns into glass).
final class StainedGlassVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.stainedGlass"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in StainedGlassVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in StainedGlassVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] : nil
  }

  static let function = "divineStainedGlass"

  /// `s` is the frame's shorter side, `g` a grid square's side and
  /// `lead` half the lead's width, in pixels. The hash is Dave Hoskins'
  /// "hash without sine" with 3.33 in place of its 33.33, as the
  /// particles use it.
  static let source = """
    static float luma(float3 c) {
      return dot(c, float3(0.299, 0.587, 0.114));
    }

    static float2 hash2(float2 q) {
      float3 r = fract(float3(q.xyx) * float3(0.1031, 0.1030, 0.0973));
      r += dot(r, r.yzx + 3.33);
      return fract((r.xx + r.yz) * r.zy);
    }

    kernel void divineStainedGlass(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float intensity = u[3].x;
      float2 p = pixelOf(u, gid, target.get_height());
      float s = min(f.size.x, f.size.y);
      float g = max(8.0, s / 16.0);
      float2 q = p / g;
      float2 cell = floor(q);
      float2 inSquare = q - cell;
      float2 best = float2(0.0);
      float2 toBest = float2(0.0);
      float nearest = 8.0;
      for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
          float2 o = float2(float(i), float(j));
          float2 r = o + 0.1 + 0.8 * hash2(cell + o) - inSquare;
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
          float2 o = best + float2(float(i), float(j));
          float2 r = o + 0.1 + 0.8 * hash2(cell + o) - inSquare;
          float2 between = r - toBest;
          if (dot(between, between) > 0.00001) {
            border = min(border, dot(0.5 * (toBest + r), normalize(between)));
          }
        }
      }
      float3 color = tap(frame, f, p);
      float3 pane = tap(frame, f, p + toBest * g);
      float tint = 0.9 + 0.2 * hash2(cell + best + 17.0).x;
      float shine = 1.15 - 0.35 * sqrt(nearest);
      float3 glass = clamp(mix(float3(luma(pane)), pane, 1.4) * tint * shine, 0.0, 1.0);
      float lead = max(1.0, s / 400.0);
      float edge = 1.0 - smoothstep(lead - 0.75, lead + 0.75, border * g);
      float3 window = mix(glass, float3(0.06, 0.06, 0.07), edge);
      target.write(float4(mix(color, window, intensity), 1.0), gid);
    }
    """
}
