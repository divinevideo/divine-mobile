import Foundation
import divine_video_player
import pro_video_editor

/// Prism: a rainbow falls across the top-right corner, as when a prism or a
/// crystal is held in front of the lens.
///
/// The band runs diagonally, from the top edge to the right edge. Across it
/// the colour runs from red to violet, at full strength in its middle and
/// fading out at both sides. Under the band the picture splits into red and
/// blue edges across it, the further the stronger the band, and the rainbow
/// is added with a screen blend. The band drifts and breathes slowly, at the
/// same strength all the time, so the picture never pulses brighter and
/// darker.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// strong the rainbow and the split are). The band moves with the time since
/// the effect started, so it follows the same path in the preview and in the
/// export.
final class PrismVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.prism"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in PrismVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in PrismVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity, Double(effectTimeUs) / 1_000_000] : nil
  }

  static let function = "divinePrism"

  /// `across` runs from 0 at the bottom-left corner to 1 at the top-right one;
  /// the band's centre and width are on it. `hue` 0 is red, 0.75 violet. `l`
  /// is the frame's longer side.
  static let source = """
    kernel void divinePrism(
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
      float2 uv = p / f.size;
      float across = 0.45 * uv.x + 0.55 * uv.y;
      float centre = 0.72 + 0.06 * sin(0.31 * t + 1.3);
      float width = 0.14 + 0.02 * sin(0.23 * t + 0.4);
      float b = (across - centre) / width;
      float band = 1.0 - smoothstep(0.55, 1.0, abs(b));
      float hue = 0.375 * (b + 1.0);
      float3 rainbow = clamp(
        abs(fract(hue + float3(1.0, 0.6667, 0.3333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
      float2 shift = normalize(float2(0.45 / f.size.x, 0.55 / f.size.y))
        * (0.008 * l * intensity * band);
      float3 base = float3(
        tap(frame, f, p + shift).r, tap(frame, f, p).g, tap(frame, f, p - shift).b);
      float3 lit = clamp(rainbow * (0.75 * band * intensity), 0.0, 1.0);
      target.write(float4(1.0 - (1.0 - base) * (1.0 - lit), 1.0), gid);
    }
    """
}
