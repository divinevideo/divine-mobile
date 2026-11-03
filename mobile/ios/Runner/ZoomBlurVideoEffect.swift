import Foundation
import divine_video_player
import pro_video_editor

/// Zoom blur: the picture streaks outward from its centre, as if the camera
/// zoomed in during the exposure.
///
/// Each pixel averages 32 taps along the line from it towards the centre,
/// reaching up to 22% of the way there. The taps start at a different point
/// from pixel to pixel, by interleaved gradient noise, so they leave a fine
/// grain rather than rings. A frame without streaks, such as one between two
/// hits on the beat, is left as it is.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
/// long the streaks are) and, for an effect on the beat, `beatsUs`: the beats,
/// in microseconds after the effect's start. On the beat the streaks only show
/// on each hit and fade out over half a second; see ``BlurHits``.
final class ZoomBlurVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.zoomBlur"

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
    CustomVideoEffects.register(id) { params in ZoomBlurVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in ZoomBlurVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    let strength = BlurHits.strength(
      intensity: intensity, beatsUs: beatsUs, effectTimeUs: effectTimeUs)
    return strength > 0 ? [strength] : nil
  }

  static let function = "divineZoomBlur"

  static let source = """
    kernel void divineZoomBlur(
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
      float jitter = fract(52.9829189 * fract(dot(p, float2(0.06711056, 0.00583715))));
      float3 color = float3(0.0);
      for (int i = 0; i < 32; i++) {
        float share = (float(i) + jitter) / 32.0;
        color += tap(frame, f, c + (p - c) * (1.0 - 0.22 * strength * share));
      }
      target.write(float4(color / 32.0, 1.0), gid);
    }
    """
}

/// How strongly the zoom blur, or the spin blur, streaks at a moment. Mirrors
/// the Android `BlurHits`.
///
/// All the time it streaks at its intensity. On the beat each beat starts a
/// hit at the intensity that fades out over ``hitUs`` as `(1 - u)²`, `u` the
/// share of the hit gone, as the built-in zoom pulse eases out; a later beat
/// starts the next hit. Before the first beat it does not streak at all.
enum BlurHits {
  /// How long one hit lasts.
  static let hitUs: Int64 = 500_000

  /// The beats in `params`, in order, or `nil` for an effect that plays all
  /// through.
  static func beats(_ params: [String: Any]) -> [Int64]? {
    (params["beatsUs"] as? [Any])?.compactMap { ($0 as? NSNumber)?.int64Value }.sorted()
  }

  /// The strength `effectTimeUs` after the effect started, from 0 to
  /// `intensity`.
  static func strength(intensity: Double, beatsUs: [Int64]?, effectTimeUs: Int64) -> Double {
    guard let beatsUs else { return intensity }
    guard let last = beatsUs.last(where: { $0 <= effectTimeUs }) else { return 0 }
    let u = Double(effectTimeUs - last) / Double(hitUs)
    guard u < 1 else { return 0 }
    return intensity * (1 - u) * (1 - u)
  }
}
