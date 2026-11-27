import Foundation
import divine_video_player
import pro_video_editor

/// Anamorphic: lamps, headlights and the sun throw long, thin blue streaks to
/// both sides, as through an anamorphic cinema lens.
///
/// Each pixel reads 48 taps along its row, up to a quarter of the frame's
/// width to each side. A tap counts by the square of how far its brightness is
/// above a threshold near white, so only real highlights streak, not a bright
/// sky or a white wall, and by the square of how near it is. The taps start at
/// a different point from pixel to pixel, by interleaved gradient noise, as
/// the zoom blur's do. The streak is tinted blue and added with a screen blend.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
/// long and bright the streaks are), `color` (the streaks' colour, as an ARGB
/// integer), `length` (0.3–2: how long they are, as a share of the default) and
/// `sensitivity` (0–1: how dim a light may be and still streak; 0.5 by
/// default). The streaks follow the picture, so they need no time.
final class AnamorphicVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.anamorphic"

  private let intensity: Double
  private let color: [Double]
  private let length: Double
  private let sensitivity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    color = Self.readColor(params, "color", fallback: 0xFF4D_9EFF)
    length = Self.readNumber(params, "length", fallback: 1, in: 0.3...2)
    sensitivity = Self.readNumber(params, "sensitivity", fallback: 0.5, in: 0...1)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in AnamorphicVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in AnamorphicVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] + color + [length, sensitivity] : nil
  }

  static let function = "divineAnamorphic"

  static let source = """
    static float luma(float3 c) {
      return dot(c, float3(0.299, 0.587, 0.114));
    }

    kernel void divineAnamorphic(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float2 uSize = f.size;
      float uIntensity = u[3].x;
      float3 uColor = u[3].yzw;
      float uLength = u[4].x;
      float uSensitivity = u[4].y;
      float2 p = pixelOf(u, gid, target.get_height());
      float reach = (0.08 + 0.17 * uIntensity) * uSize.x * uLength;
      float threshold = min(0.85 - 0.1 * uIntensity - 0.3 * (uSensitivity - 0.5), 0.95);
      float jitter = fract(52.9829189 * fract(dot(p, float2(0.06711056, 0.00583715))));
      float streak = 0.0;
      for (int i = 0; i < 48; i++) {
        float x = 2.0 * (float(i) + jitter) / 48.0 - 1.0;
        float w = 1.0 - abs(x);
        float h = max(luma(tap(frame, f, p + float2(x * reach, 0.0))) - threshold, 0.0) / (1.0 - threshold);
        streak += h * h * w * w;
      }
      streak *= 3.0 / 48.0;
      float3 lit = clamp(uColor * (5.0 * streak * uIntensity), 0.0, 1.0);
      float3 base = tap(frame, f, p);
      target.write(float4(1.0 - (1.0 - base) * (1.0 - lit), 1.0), gid);
    }
    """
}
