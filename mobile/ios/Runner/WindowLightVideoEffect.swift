import Foundation
import divine_video_player
import pro_video_editor

/// Window light: slanted stripes of warm afternoon light, as through a
/// venetian blind, slide slowly across the picture.
///
/// The stripes fall on a soft, wide window patch a little right of and above
/// the middle, and fade out towards the frame's edges. In a stripe the
/// picture is lit warm; between the stripes, and outside the patch, it is a
/// little darker. The stripes take about nine seconds to move on by one, and
/// as many slide in as slide out, so the picture never pulses brighter and
/// darker.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// bright the light and how dark the shade are). The stripes move with the
/// time since the effect started, so they are in the same place in the
/// preview and in the export.
final class WindowLightVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.windowLight"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in WindowLightVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in WindowLightVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity, Double(effectTimeUs) / 1_000_000] : nil
  }

  static let function = "divineWindowLight"

  /// `s` is the frame's shorter side; one stripe and the gap after it take
  /// 12% of it.
  static let source = """
    kernel void divineWindowLight(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float intensity = u[3].x;
      float t = u[3].y;
      float2 p = pixelOf(u, gid, target.get_height());
      float s = min(f.size.x, f.size.y);
      float slats = fract((p.y + 0.45 * p.x) / (0.12 * s) - 0.11 * t);
      float slat = smoothstep(0.0, 0.12, slats) * (1.0 - smoothstep(0.42, 0.56, slats));
      float2 d = (p / f.size - float2(0.58, 0.6)) * float2(1.3, 1.0);
      float window = 1.0 - smoothstep(0.25, 0.75, length(d));
      float3 shade = float3(1.0 - 0.35 * intensity);
      float3 warm = 1.0 + intensity * float3(0.7, 0.5, 0.22);
      float3 base = tap(frame, f, p);
      target.write(float4(clamp(base * mix(shade, warm, slat * window), 0.0, 1.0), 1.0), gid);
    }
    """
}
