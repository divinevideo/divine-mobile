import Foundation
import divine_video_player
import pro_video_editor

/// Ripple: rings spread out from the centre, as on water after a stone drops
/// in.
///
/// The rings are a tenth of the frame's shorter side apart and travel
/// three-quarters of that a second. Each pixel is pushed towards or away from
/// the centre by up to 1.2% of the shorter side, and one side of every crest
/// is lit while the other darkens, by up to 12%. Both calm down towards the
/// centre, where the rings start. The picture is zoomed in by up to 2.5%, so
/// the pushed edges stay in view. The phase is kept within one turn, where
/// the GPU's sine and cosine stay exact over the whole frame.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// far the rings push the picture). The rings move with the time since the
/// effect started, so they are in the same place in the preview and in the
/// export.
final class RippleVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.ripple"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in RippleVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in RippleVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity, Double(effectTimeUs) / 1_000_000] : nil
  }

  static let function = "divineRipple"

  /// `s` is the frame's shorter side.
  static let source = """
    kernel void divineRipple(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float intensity = u[3].x;
      float time = u[3].y;
      float2 p = pixelOf(u, gid, target.get_height());
      float2 c = f.size * 0.5;
      float2 d = p - c;
      float r = length(d);
      float s = min(f.size.x, f.size.y);
      float phase = 6.2832 * fract(r / (0.1 * s) - fract(time * 0.75));
      float fade = smoothstep(0.0, 0.2 * s, r);
      float push = 0.012 * s * intensity * fade * sin(phase);
      float2 q = c + d * (1.0 - 0.025 * intensity) + d / max(r, 0.001) * push;
      float3 color = tap(frame, f, q) * (1.0 + 0.12 * intensity * fade * cos(phase));
      target.write(float4(clamp(color, 0.0, 1.0), 1.0), gid);
    }
    """
}
