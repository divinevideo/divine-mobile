import Foundation
import divine_video_player
import pro_video_editor

/// Pop art: the picture four times in a 2×2 grid, each copy screen-printed in
/// three flat tones of its own bold colour scheme.
///
/// Each copy is the whole picture at half size. Its brightness is cut into a
/// dark, a middle and a light tone, with a narrow blend between them that
/// keeps the edges from crawling as the picture moves, and each tone takes
/// that copy's colour.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// far the copies turn into the print). The grid shows at any intensity
/// above zero, so at zero the picture is left as it is.
final class PopArtVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.popArt"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in PopArtVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in PopArtVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] : nil
  }

  static let function = "divinePopArt"

  /// Copy 0 is at the bottom left, 1 at the bottom right, 2 at the top
  /// left and 3 at the top right; `pick` chooses among four colours by
  /// the copy's number without an array, as the Android shader must:
  /// GLSL ES 1.00 cannot initialise one.
  static let source = """
    static float luma(float3 c) {
      return dot(c, float3(0.299, 0.587, 0.114));
    }

    static float3 pick(float i, float3 a, float3 b, float3 c, float3 d) {
      return mix(mix(a, b, step(0.5, i)), mix(c, d, step(2.5, i)), step(1.5, i));
    }

    kernel void divinePopArt(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float intensity = u[3].x;
      float2 p = pixelOf(u, gid, target.get_height());
      float2 halfSize = 0.5 * f.size;
      float2 quadrant = step(halfSize, p);
      float2 local = mix(p, (p - halfSize * quadrant) * 2.0, step(0.0001, intensity));
      float3 copy = tap(frame, f, local);
      float l = luma(copy);
      float level = smoothstep(0.28, 0.32, l) + smoothstep(0.58, 0.62, l);
      float i = quadrant.x + 2.0 * quadrant.y;
      float3 dark = pick(i, float3(0.1, 0.1, 0.35), float3(0.3, 0.05, 0.4), float3(0.55, 0.0, 0.1),
        float3(0.0, 0.25, 0.3));
      float3 mid = pick(i, float3(1.0, 0.2, 0.6), float3(1.0, 0.5, 0.1), float3(0.45, 0.85, 0.2),
        float3(1.0, 0.85, 0.0));
      float3 light = pick(i, float3(1.0, 0.9, 0.2), float3(0.3, 0.9, 1.0), float3(1.0, 0.75, 0.85),
        float3(0.8, 0.7, 1.0));
      float3 print = mix(mix(dark, mid, clamp(level, 0.0, 1.0)), light, clamp(level - 1.0, 0.0, 1.0));
      target.write(float4(mix(copy, print, intensity), 1.0), gid);
    }
    """
}
