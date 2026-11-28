import Foundation
import divine_video_player
import pro_video_editor

/// Ripple: rings spread out from a centre, the middle unless the user moves it,
/// as on water after a stone drops in.
///
/// The rings are a tenth of the frame's shorter side apart and travel
/// three-quarters of that a second, both scaled by the settings. Each pixel is
/// pushed towards or away from the centre by up to 1.2% of the shorter side,
/// and one side of every crest is lit while the other darkens, by up to 12%.
/// Both calm down towards the centre, where the rings start. The picture is
/// zoomed in by up to 2.5%, so the pushed edges stay in view. The phase is kept
/// within one turn, where the GPU's sine and cosine stay exact over the whole
/// frame.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
/// the rings push the picture), `centerX` and `centerY` (0–1: where its centre
/// sits, as shares of the width from the left and of the height from the top;
/// the middle by default), `spacing` (0.4–3: how far apart the rings are, as a
/// share of the default) and `speed` (0–2: how fast they travel, as a share of
/// the default; 0 holds them still). The rings move with the time since the
/// effect started, so they are in the same place in the preview and in the
/// export.
final class RippleVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.ripple"

  private let intensity: Double
  private let center: [Double]
  private let spacing: Double
  private let speed: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    center = Self.readCenter(params)
    spacing = Self.readNumber(params, "spacing", fallback: 1, in: 0.4...3)
    speed = Self.readNumber(params, "speed", fallback: 1, in: 0...2)
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
    intensity > 0
      ? [intensity, Double(effectTimeUs) / 1_000_000] + center + [spacing, speed] : nil
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
      float2 uSize = f.size;
      float uIntensity = u[3].x;
      float uTime = u[3].y;
      float2 uCenter = u[3].zw;
      float uSpacing = u[4].x;
      float uSpeed = u[4].y;
      float2 p = pixelOf(u, gid, target.get_height());
      float2 c = float2(uCenter.x, 1.0 - uCenter.y) * uSize;
      float2 d = p - c;
      float r = length(d);
      float s = min(uSize.x, uSize.y);
      float phase = 6.2832 * fract(r / (0.1 * uSpacing * s) - fract(uTime * 0.75 * uSpeed));
      float fade = smoothstep(0.0, 0.2 * s, r);
      float push = 0.012 * s * uIntensity * fade * sin(phase);
      float2 q = c + d * (1.0 - 0.025 * uIntensity) + d / max(r, 0.001) * push;
      float3 color = tap(frame, f, q) * (1.0 + 0.12 * uIntensity * fade * cos(phase));
      target.write(float4(clamp(color, 0.0, 1.0), 1.0), gid);
    }
    """
}
