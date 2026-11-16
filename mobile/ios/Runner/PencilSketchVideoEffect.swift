import Foundation
import divine_video_player
import pro_video_editor

/// Pencil sketch: the picture drawn in graphite on off-white paper, with
/// outlines and cross-hatching.
///
/// The outlines follow where the brightness changes sharply, found with a
/// Sobel filter whose taps stay about the same share of the frame at every
/// resolution. The hatching comes in three layers of slightly wavy lines at
/// different angles, each drawn where the picture is darker than its
/// threshold, so the shadows get the most lines.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// far the picture turns into the sketch).
final class PencilSketchVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.pencilSketch"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in PencilSketchVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in PencilSketchVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] : nil
  }

  static let function = "divinePencilSketch"

  /// `s` is the frame's shorter side, `e` the Sobel filter's step, `g`
  /// the gap between hatching lines and `w` their width, all in pixels.
  /// The tone is the mean brightness of the nine taps, which steadies
  /// the hatching against noise. Each line's wave keeps its phase within
  /// one turn, where the GPU's sine stays exact.
  static let source = """
    static float luma(float3 c) {
      return dot(c, float3(0.299, 0.587, 0.114));
    }

    static float grain(float2 q) {
      return fract(52.9829189 * fract(dot(q, float2(0.06711056, 0.00583715))));
    }

    static float hatch(float2 p, float2 n, float g, float w) {
      float along = dot(p, float2(-n.y, n.x)) / g;
      float across = dot(p, n) / g + 0.12 * sin(6.2831853 * fract(along * 0.07));
      float d = abs(fract(across) - 0.5) * g;
      return clamp(0.5 * w - d + 0.5, 0.0, 1.0);
    }

    kernel void divinePencilSketch(
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
      float e = max(1.0, s / 540.0);
      float3 color = tap(frame, f, p);
      float tl = luma(tap(frame, f, p + float2(-e, e)));
      float tc = luma(tap(frame, f, p + float2(0.0, e)));
      float tr = luma(tap(frame, f, p + float2(e, e)));
      float ml = luma(tap(frame, f, p + float2(-e, 0.0)));
      float mr = luma(tap(frame, f, p + float2(e, 0.0)));
      float bl = luma(tap(frame, f, p + float2(-e, -e)));
      float bc = luma(tap(frame, f, p + float2(0.0, -e)));
      float br = luma(tap(frame, f, p + float2(e, -e)));
      float gx = tr + 2.0 * mr + br - tl - 2.0 * ml - bl;
      float gy = tl + 2.0 * tc + tr - bl - 2.0 * bc - br;
      float outline = smoothstep(0.2, 0.7, length(float2(gx, gy)));
      float l = (luma(color) + tl + tc + tr + ml + mr + bl + bc + br) / 9.0;
      float g = max(3.0, s / 160.0);
      float w = max(1.0, s / 900.0);
      float a = hatch(p, float2(0.70710678, 0.70710678), g, w) * (1.0 - smoothstep(0.62, 0.82, l));
      float b = hatch(p, float2(0.70710678, -0.70710678), g, w) * (1.0 - smoothstep(0.35, 0.55, l));
      float c = hatch(p, float2(0.25881905, 0.96592583), g, w) * (1.0 - smoothstep(0.12, 0.3, l));
      float shade = 1.0 - (1.0 - a) * (1.0 - b) * (1.0 - c);
      float tooth = grain(floor(p / e));
      float mark = 1.0 - (1.0 - 0.7 * shade * (0.8 + 0.2 * tooth)) * (1.0 - 0.85 * outline);
      float3 paper = float3(0.97, 0.95, 0.91) * (0.97 + 0.03 * tooth);
      float3 sketch = mix(paper, float3(0.2, 0.2, 0.22), mark);
      target.write(float4(mix(color, sketch, intensity), 1.0), gid);
    }
    """
}
