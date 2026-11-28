import Foundation
import divine_video_player
import pro_video_editor

/// Fluted glass: the picture is seen through ribbed glass, each rib showing a
/// squeezed slice of it.
///
/// Upright ribs, each 8% of the frame's shorter side wide and one centred on
/// the frame, unless the user widens or turns them, show a slice of the picture
/// up to two and a half ribs wide, so neighbouring ribs repeat parts of it. A
/// slice reaching past an edge of the frame is mirrored back, rather than
/// smearing the edge pixels. Each rib darkens towards its edges, by up to 15%,
/// and carries a soft highlight beside its middle, so it reads as rounded
/// glass.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
/// much the ribs squeeze and shade the picture), `width` (0.3–3: how wide the
/// ribs are, as a share of the default) and `angle` (0–180: how far the ribs
/// are turned from upright, in degrees, anticlockwise).
final class FlutedGlassVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.flutedGlass"

  private let intensity: Double
  private let rib: Double
  /// The direction across the ribs, with y up.
  private let axis: [Double]

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    rib = Self.readNumber(params, "width", fallback: 1, in: 0.3...3)
    let angle = Self.readNumber(params, "angle", fallback: 0, in: 0...180) * .pi / 180
    axis = [cos(angle), sin(angle)]
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
    intensity > 0 ? [intensity, rib] + axis : nil
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
      float2 uSize = f.size;
      float uIntensity = u[3].x;
      float uRib = u[3].y;
      float2 uAxis = u[3].zw;
      float2 p = pixelOf(u, gid, target.get_height());
      float rib = 0.08 * uRib * min(uSize.x, uSize.y);
      float across = fract(dot(p - 0.5 * uSize, uAxis) / rib + 0.5) - 0.5;
      float2 q = abs(p + 1.5 * uIntensity * across * rib * uAxis);
      float3 color = tap(frame, f, uSize - abs(uSize - q));
      color *= 1.0 - 0.6 * uIntensity * across * across;
      color += 0.1 * uIntensity * (1.0 - smoothstep(0.0, 0.15, abs(across + 0.22)));
      target.write(float4(clamp(color, 0.0, 1.0), 1.0), gid);
    }
    """
}
