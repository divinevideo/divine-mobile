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
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
/// dark the picture gets outside the lights), `size` (0.5–2: how large the
/// lights are, as a share of the default) and `speed` (0–3: how fast they
/// wander, as a share of the default; 0 holds them still). The lights move with
/// the time since the effect started, so they follow the same path in the
/// preview and in the export.
final class SpotlightVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.spotlight"

  private let intensity: Double
  private let spread: Double
  private let speed: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    spread = Self.readNumber(params, "size", fallback: 1, in: 0.5...2)
    speed = Self.readNumber(params, "speed", fallback: 1, in: 0...3)
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
    intensity > 0 ? [intensity, Double(effectTimeUs) / 1_000_000] + [spread, speed] : nil
  }

  static let function = "divineSpotlight"

  /// `l` is the frame's longer side; each light's reach is a share of it.
  static let source = """
    // A round light with a flat top and a short, soft edge.
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
      float2 uSize = f.size;
      float uIntensity = u[3].x;
      float uTime = u[3].y;
      float uSpread = u[3].z;
      float uSpeed = u[3].w;
      float2 p = pixelOf(u, gid, target.get_height());
      float l = max(uSize.x, uSize.y);
      float t = uTime * uSpeed;
      float2 warmCentre = uSize * float2(0.5 + 0.28 * sin(0.41 * t + 0.3), 0.56 + 0.2 * sin(0.53 * t + 1.7));
      float2 coolCentre = uSize * float2(0.5 + 0.3 * sin(0.33 * t + 3.4), 0.44 + 0.22 * sin(0.47 * t + 0.6));
      float3 light = max(
        float3(1.12, 1.04, 0.9) * spot(p, warmCentre, 0.2 * l * uSpread),
        float3(0.92, 0.98, 1.12) * spot(p, coolCentre, 0.17 * l * uSpread));
      float dark = 0.8 * uIntensity;
      float3 base = tap(frame, f, p);
      target.write(float4(clamp(base * (1.0 - dark + dark * light), 0.0, 1.0), 1.0), gid);
    }
    """
}
