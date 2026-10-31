import Foundation
import divine_video_player
import pro_video_editor

/// Swirl: the picture twists around its centre, most in the middle and not at
/// all from half its shorter side out.
///
/// Each pixel samples the picture turned around the centre by
/// `3 · intensity · w²` radians, where `w` falls from 1 at the centre to 0 at
/// half the shorter side. A pixel only turns within that circle, so it samples
/// as far from the centre as it is and never outside the frame.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// far the middle turns).
final class SwirlVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.swirl"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in SwirlVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in SwirlVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] : nil
  }

  static let function = "divineSwirl"

  static let source = """
    kernel void divineSwirl(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float intensity = u[3].x;
      float2 p = pixelOf(u, gid, target.get_height());
      float2 c = f.size * 0.5;
      float2 d = p - c;
      float w = max(1.0 - length(d) / (0.5 * min(f.size.x, f.size.y)), 0.0);
      float angle = 3.0 * intensity * w * w;
      float co = cos(angle);
      float si = sin(angle);
      float3 color = tap(frame, f, c + float2(co * d.x - si * d.y, si * d.x + co * d.y));
      target.write(float4(color, 1.0), gid);
    }
    """
}
