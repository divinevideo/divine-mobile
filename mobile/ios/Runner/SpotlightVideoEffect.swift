import Foundation
import divine_video_player
import pro_video_editor

/// Spotlight: the picture is dimmed, and two round stage lights, one warm and
/// one cool, wander slowly over it and light it back up.
///
/// Each light has a flat top and a short, soft edge, `exp(-r⁶)` of the
/// distance from its centre in shares of its reach. Where both fall, the
/// brighter one wins, so the picture never gets brighter than in one light.
/// The lights follow slow paths of their own, `a + b · sin(f · t + phase)`
/// along each axis, through the middle of the frame, so about as much of the
/// picture is lit all the time and it never pulses brighter and darker.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// dark the picture is outside the lights). The lights move with the time
/// since the effect started, so they follow the same path in the preview and
/// in the export.
final class SpotlightVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.spotlight"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in SpotlightVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in SpotlightVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity, Double(effectTimeUs) / 1_000_000] : nil
  }

  static let function = "divineSpotlight"

  /// `l` is the frame's longer side; each light's reach is a share of it.
  static let source = """
    static float spot(float2 p, float2 centre, float reach) {
      float2 d = (p - centre) / reach;
      float r2 = dot(d, d);
      return exp(-r2 * r2 * r2);
    }

    kernel void divineSpotlight(
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
      float l = max(f.size.x, f.size.y);
      float2 warmCentre =
        f.size * float2(0.5 + 0.28 * sin(0.41 * t + 0.3), 0.56 + 0.2 * sin(0.53 * t + 1.7));
      float2 coolCentre =
        f.size * float2(0.5 + 0.3 * sin(0.33 * t + 3.4), 0.44 + 0.22 * sin(0.47 * t + 0.6));
      float3 light = max(
        float3(1.12, 1.04, 0.9) * spot(p, warmCentre, 0.2 * l),
        float3(0.92, 0.98, 1.12) * spot(p, coolCentre, 0.17 * l));
      float dark = 0.8 * intensity;
      float3 base = tap(frame, f, p);
      target.write(float4(clamp(base * (1.0 - dark + dark * light), 0.0, 1.0), 1.0), gid);
    }
    """
}
