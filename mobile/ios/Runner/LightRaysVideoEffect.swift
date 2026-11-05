import Foundation
import divine_video_player
import pro_video_editor

/// Light rays: shafts of warm light fall from a sun just above the top edge,
/// through the gaps between trees, windows or hair.
///
/// Each pixel reads 32 taps on the way from it halfway to the sun. A tap only
/// counts as far as it is a highlight, and nearer taps count more, so the
/// bright parts of the picture streak away from the sun and the dark parts
/// between them leave shadows. The taps start at a different point from pixel
/// to pixel, by interleaved gradient noise, as the zoom blur's do. A soft glow
/// around the sun lights the top of the picture even where nothing is bright,
/// and everything is added warm with a screen blend.
///
/// The sun drifts slowly along the top edge, at the same strength all the
/// time, so the picture never pulses brighter and darker.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// strong the light is). The sun moves with the time since the effect started,
/// so it follows the same path in the preview and in the export.
final class LightRaysVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.lightRays"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in LightRaysVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in LightRaysVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity, Double(effectTimeUs) / 1_000_000] : nil
  }

  static let function = "divineLightRays"

  /// `l` is the frame's longer side; the sun's glow reaches a share of it.
  static let source = """
    static float luma(float3 c) {
      return dot(c, float3(0.299, 0.587, 0.114));
    }

    kernel void divineLightRays(
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
      float2 sun = f.size * float2(0.3 + 0.25 * sin(0.23 * t + 0.8), 1.06);
      float2 toSun = sun - p;
      float jitter = fract(52.9829189 * fract(dot(p, float2(0.06711056, 0.00583715))));
      float3 rays = float3(0.0);
      for (int i = 0; i < 32; i++) {
        float share = (float(i) + jitter) / 32.0;
        float3 c = tap(frame, f, p + toSun * (0.5 * share));
        rays += c * (smoothstep(0.7, 1.0, luma(c)) * (1.0 - share));
      }
      float2 d = toSun / l;
      float sunGlow = exp(-5.0 * dot(d, d));
      float3 glow = float3(1.0, 0.86, 0.62) * (rays * (2.0 / 16.0) + 0.35 * sunGlow);
      float3 lit = clamp(glow * intensity, 0.0, 1.0);
      float3 base = tap(frame, f, p);
      target.write(float4(1.0 - (1.0 - base) * (1.0 - lit), 1.0), gid);
    }
    """
}
