import Foundation
import divine_video_player
import pro_video_editor

/// Thermal camera: the picture as a thermal camera shows it, from cold black
/// and purple through red and orange to hot yellow and white.
///
/// A camera cannot see heat, so the warmth is mostly how much redder than
/// green and blue the picture is, plus some of its brightness: skin, lips and
/// warm lights run hot, pale walls lukewarm, and blue, green and dark things
/// cold. A thermal camera's picture is soft, so the warmth is averaged over
/// five taps first, then stretched and run through an ironbow palette.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// far the picture turns into the thermal view).
final class ThermalVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.thermal"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in ThermalVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in ThermalVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] : nil
  }

  static let function = "divineThermal"

  /// `s` is the frame's shorter side, `e` the taps' distance in pixels.
  /// The ironbow palette runs through six colours, one stretch of it
  /// after another.
  static let source = """
    static float warmth(float3 c) {
      return 0.3 * dot(c, float3(0.299, 0.587, 0.114)) + 1.6 * max(c.r - 0.5 * (c.g + c.b), 0.0);
    }

    static float3 ironbow(float t) {
      float3 c = mix(float3(0.0, 0.0, 0.12), float3(0.35, 0.0, 0.55), clamp(t / 0.25, 0.0, 1.0));
      c = mix(c, float3(0.85, 0.1, 0.25), clamp((t - 0.25) / 0.25, 0.0, 1.0));
      c = mix(c, float3(1.0, 0.5, 0.0), clamp((t - 0.5) / 0.2, 0.0, 1.0));
      c = mix(c, float3(1.0, 0.85, 0.1), clamp((t - 0.7) / 0.15, 0.0, 1.0));
      return mix(c, float3(1.0, 1.0, 0.9), clamp((t - 0.85) / 0.15, 0.0, 1.0));
    }

    kernel void divineThermal(
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
      float e = max(1.0, s / 270.0);
      float3 color = tap(frame, f, p);
      float heat = (2.0 * warmth(color) + warmth(tap(frame, f, p + float2(e, 0.0))) +
        warmth(tap(frame, f, p - float2(e, 0.0))) + warmth(tap(frame, f, p + float2(0.0, e))) +
        warmth(tap(frame, f, p - float2(0.0, e)))) / 6.0;
      float3 thermal = ironbow(smoothstep(0.1, 0.75, heat));
      target.write(float4(mix(color, thermal, intensity), 1.0), gid);
    }
    """
}
