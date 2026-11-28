import Foundation
import divine_video_player
import pro_video_editor

/// Swirl: the picture twists around a centre, the middle unless the user moves
/// it, most there and not at all from the radius out.
///
/// Each pixel samples the picture turned around the centre by `3 · intensity ·
/// w²` radians, clockwise unless the user turns it the other way, where `w`
/// falls from 1 at the centre to 0 at the radius: half the shorter side at the
/// default size.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
/// the middle turns), `centerX` and `centerY` (0–1: where its centre sits, as
/// shares of the width from the left and of the height from the top; the middle
/// by default), `size` (0.3–2: the radius, as a share of half the shorter side)
/// and `direction` (-1 to turn it anticlockwise).
final class SwirlVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.swirl"

  private let intensity: Double
  private let center: [Double]
  private let radius: Double
  private let direction: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    center = Self.readCenter(params)
    radius = Self.readNumber(params, "size", fallback: 1, in: 0.3...2)
    direction = Self.readDirection(params)
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
    intensity > 0 ? [intensity] + center + [radius, direction] : nil
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
      float2 uSize = f.size;
      float uIntensity = u[3].x;
      float2 uCenter = u[3].yz;
      float uRadius = u[3].w;
      float uDirection = u[4].x;
      float2 p = pixelOf(u, gid, target.get_height());
      float2 c = float2(uCenter.x, 1.0 - uCenter.y) * uSize;
      float2 d = p - c;
      float w = max(1.0 - length(d) / (0.5 * uRadius * min(uSize.x, uSize.y)), 0.0);
      float angle = 3.0 * uIntensity * uDirection * w * w;
      float co = cos(angle);
      float si = sin(angle);
      float3 color = tap(frame, f, c + float2(co * d.x - si * d.y, si * d.x + co * d.y));
      target.write(float4(color, 1.0), gid);
    }
    """
}
