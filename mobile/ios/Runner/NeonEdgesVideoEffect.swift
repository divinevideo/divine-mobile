import Foundation
import divine_video_player
import pro_video_editor

/// Neon edges: the picture's outlines glow on black.
///
/// An outline is where the brightness changes sharply, found from taps on
/// either side at three distances: the nearest draws a thin, white-hot core,
/// the further ones a glow fading out around it. Each outline glows in the
/// picture's own colour there; where the picture has little colour, in a
/// colour that turns with the outline's direction, so a grey picture glows in
/// every colour.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// far the picture turns into neon).
final class NeonEdgesVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.neonEdges"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in NeonEdgesVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in NeonEdgesVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] : nil
  }

  static let function = "divineNeonEdges"

  /// `s` is the frame's shorter side, `e` the nearest taps' distance in
  /// pixels. Where the brightness does not change at all the direction has
  /// no angle, so the kernel falls back to one rather than read
  /// `atan2(0, 0)`, which the Android shader's `atan` leaves undefined.
  static let source = """
    static float luma(float3 c) {
      return dot(c, float3(0.299, 0.587, 0.114));
    }

    static float2 slope(texture2d<float, access::sample> frame, Frame f, float2 p, float d) {
      return float2(
        luma(tap(frame, f, p + float2(d, 0.0))) - luma(tap(frame, f, p - float2(d, 0.0))),
        luma(tap(frame, f, p + float2(0.0, d))) - luma(tap(frame, f, p - float2(0.0, d))));
    }

    kernel void divineNeonEdges(
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
      float2 near = slope(frame, f, p, e);
      float2 mid = slope(frame, f, p, 3.0 * e);
      float2 far = slope(frame, f, p, 7.0 * e);
      float core = smoothstep(0.08, 0.35, length(near));
      float glow = 0.9 * core + 0.4 * smoothstep(0.08, 0.45, length(mid)) +
        0.2 * smoothstep(0.08, 0.55, length(far));
      float2 direction = near + mid + far;
      float size = length(direction);
      float2 axis = size > 0.0001 ? direction / size : float2(1.0, 0.0);
      float hue = atan2(axis.y, axis.x) / 6.2831853 + 0.5;
      float3 turning = clamp(abs(fract(hue + float3(0.0, 0.6666667, 0.3333333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
      float lo = min(min(color.r, color.g), color.b);
      float hi = max(max(color.r, color.g), color.b);
      float3 own = (color - lo) / max(hi - lo, 0.001);
      float3 tint = mix(turning, own, smoothstep(0.08, 0.25, hi - lo));
      float3 neon = clamp(tint * glow + 0.6 * core * core, 0.0, 1.0);
      target.write(float4(mix(color, neon, intensity), 1.0), gid);
    }
    """
}
