import Foundation
import divine_video_player
import pro_video_editor

/// Tilt-shift: the picture blurs on both sides of a sharp band, across the
/// middle unless the user moves or turns it, and the colours turn a little
/// brighter and punchier, so the scene looks like a miniature.
///
/// The blur grows from nothing at a tenth of the height from the band's middle
/// to its full radius at 42%, both scaled by the band's width. Each pixel
/// averages 32 taps spread over a disc, on a golden-angle spiral that is turned
/// by interleaved gradient noise from pixel to pixel, so the taps leave a fine
/// grain rather than ghost copies.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
/// strongly the edges blur and the colours lift), `focus` (0–1: where the band
/// lies, as a share of the height from the top, or of the width from the left
/// for an upright band), `width` (0.2–3: how wide the band and the ramp are, 1
/// by default) and `orientation` (1 for an upright band, 0 for one across).
final class TiltShiftVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.tiltShift"

  private let intensity: Double
  private let focus: Double
  private let band: Double
  private let vertical: Bool

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    focus = Self.readNumber(params, "focus", fallback: 0.5, in: 0...1)
    band = Self.readNumber(params, "width", fallback: 1, in: 0.2...3)
    vertical = (params["orientation"] as? NSNumber)?.intValue == 1
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in TiltShiftVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in TiltShiftVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity, focus, band, vertical ? 1 : 0] : nil
  }

  static let function = "divineTiltShift"

  /// `s` is the frame's shorter side.
  static let source = """
    kernel void divineTiltShift(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float2 uSize = f.size;
      float uIntensity = u[3].x;
      float uFocus = u[3].y;
      float uBand = u[3].z;
      float uVertical = u[3].w;
      float2 p = pixelOf(u, gid, target.get_height());
      float s = min(uSize.x, uSize.y);
      float along = uVertical > 0.5 ? p.x / uSize.x : 1.0 - p.y / uSize.y;
      float away = abs(along - uFocus);
      float r = 0.03 * s * uIntensity * smoothstep(0.1 * uBand, 0.1 * uBand + 0.32, away);
      float3 color = tap(frame, f, p);
      if (r > 0.5) {
        float spin = 6.2832 * fract(52.9829189 * fract(dot(p, float2(0.06711056, 0.00583715))));
        for (int i = 0; i < 32; i++) {
          float n = float(i);
          float angle = n * 2.399963 + spin;
          color += tap(frame, f, p + r * sqrt((n + 0.5) / 32.0) * float2(cos(angle), sin(angle)));
        }
        color /= 33.0;
      }
      float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
      color = mix(float3(luma), color, 1.0 + 0.4 * uIntensity);
      color = (color - 0.5) * (1.0 + 0.12 * uIntensity) + 0.5;
      target.write(float4(clamp(color, 0.0, 1.0), 1.0), gid);
    }
    """
}
