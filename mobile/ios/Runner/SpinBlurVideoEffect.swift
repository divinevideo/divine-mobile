import Foundation
import divine_video_player
import pro_video_editor

/// Spin blur: the picture streaks around its centre, as if the camera turned
/// during the exposure.
///
/// Each pixel averages 32 taps along the arc through it around the centre,
/// reaching up to 0.11 radians either way, so the picture stays where it is
/// while its edges smear the most. The taps start at a different point from
/// pixel to pixel, by interleaved gradient noise, so they leave a fine grain
/// rather than rings. A frame without streaks, such as one between two hits
/// on the beat, is left as it is.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
/// long the streaks are) and, for an effect on the beat, `beatsUs`: the beats,
/// in microseconds after the effect's start. On the beat the streaks only show
/// on each hit and fade out over half a second; see ``BlurHits``.
final class SpinBlurVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.spinBlur"

  private let intensity: Double
  private let beatsUs: [Int64]?

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    beatsUs = BlurHits.beats(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in SpinBlurVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in SpinBlurVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    let strength = BlurHits.strength(
      intensity: intensity, beatsUs: beatsUs, effectTimeUs: effectTimeUs)
    return strength > 0 ? [strength] : nil
  }

  static let function = "divineSpinBlur"

  static let source = """
    kernel void divineSpinBlur(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float strength = u[3].x;
      float2 p = pixelOf(u, gid, target.get_height());
      if (strength <= 0.0) {
        target.write(float4(tap(frame, f, p), 1.0), gid);
        return;
      }
      float2 c = f.size * 0.5;
      float2 d = p - c;
      float jitter = fract(52.9829189 * fract(dot(p, float2(0.06711056, 0.00583715))));
      float3 color = float3(0.0);
      for (int i = 0; i < 32; i++) {
        float a = 0.22 * strength * ((float(i) + jitter) / 32.0 - 0.5);
        float s = sin(a);
        float k = cos(a);
        color += tap(frame, f, c + float2(d.x * k - d.y * s, d.x * s + d.y * k));
      }
      target.write(float4(color / 32.0, 1.0), gid);
    }
    """
}
