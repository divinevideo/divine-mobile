import Foundation
import divine_video_player
import pro_video_editor

/// Comic: the picture as a printed comic, with flat poster colours, halftone
/// dots in the darker tones and ink outlines.
///
/// The colours are saturated and their brightness cut into four bands, each
/// colour keeping its hue. The dots sit on a grid turned 45 degrees and grow
/// where the picture is darker. The ink follows where the brightness changes
/// sharply, found with a Sobel filter whose taps stay about the same share of
/// the frame at every resolution.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// far the picture turns into the comic).
final class ComicVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.comic"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in ComicVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in ComicVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] : nil
  }

  static let function = "divineComic"

  /// `s` is the frame's shorter side, `e` the Sobel filter's step in pixels.
  static let source = """
    static float luma(float3 c) {
      return dot(c, float3(0.299, 0.587, 0.114));
    }

    kernel void divineComic(
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
      float ink = smoothstep(0.3, 0.8, length(float2(gx, gy)));
      float l = luma(color);
      float3 vivid = mix(float3(l), color, 1.4);
      float band = 0.2 + 0.27 * min(floor(l * 4.0), 3.0);
      float3 poster = clamp(vivid * band / max(l, 0.04), 0.0, 1.0);
      float cell = 0.018 * s;
      float2 grid = float2(p.x + p.y, p.y - p.x) * 0.70710678 / cell;
      float2 d = (fract(grid) - 0.5) * cell;
      float radius = 0.6 * cell * sqrt(max(0.7 - l, 0.0));
      float spot = clamp(radius - length(d), 0.0, 1.0);
      float3 comic = poster * (1.0 - 0.35 * spot) * (1.0 - 0.85 * ink);
      target.write(float4(mix(color, comic, intensity), 1.0), gid);
    }
    """
}
