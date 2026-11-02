import Foundation
import divine_video_player
import pro_video_editor

/// Fluted glass: the picture is seen through ribbed glass, each rib showing a
/// squeezed slice of it.
///
/// Upright ribs, each 8% of the frame's shorter side wide and one centred on
/// the frame, show a slice of the picture up to two and a half ribs wide, so
/// neighbouring ribs repeat parts of it. A slice reaching past the left or
/// right edge of the frame is mirrored back, rather than smearing the edge
/// pixels. Each rib darkens towards its edges, by up to 15%, and carries a
/// soft highlight left of its middle, so it reads as rounded glass.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// much the ribs squeeze and shade the picture).
final class FlutedGlassVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.flutedGlass"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in FlutedGlassVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in FlutedGlassVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] : nil
  }

  static let function = "divineFlutedGlass"

  /// `across` runs from -0.5 to 0.5 across a rib, 0 at its middle.
  static let source = """
    kernel void divineFlutedGlass(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float intensity = u[3].x;
      float2 p = pixelOf(u, gid, target.get_height());
      float rib = 0.08 * min(f.size.x, f.size.y);
      float across = fract((p.x - 0.5 * f.size.x) / rib + 0.5) - 0.5;
      float x = abs(p.x + 1.5 * intensity * across * rib);
      float3 color = tap(frame, f, float2(f.size.x - abs(f.size.x - x), p.y));
      color *= 1.0 - 0.6 * intensity * across * across;
      color += 0.1 * intensity * (1.0 - smoothstep(0.0, 0.15, abs(across + 0.22)));
      target.write(float4(clamp(color, 0.0, 1.0), 1.0), gid);
    }
    """
}
