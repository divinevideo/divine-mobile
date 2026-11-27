import Foundation
import divine_video_player
import pro_video_editor

/// 8-bit: the picture as early console pixel art, in chunky pixels and 8-bit
/// colour.
///
/// The shorter side is cut into 100 pixels, each the average of four taps
/// inside it. Its colour is cut down to 256: eight levels of red and of green
/// and four of blue, three bits, three and two. A 4 × 4 ordered dither mixes
/// neighbouring levels, so gradients turn into the regular dot patterns such
/// games showed. Where the shorter side is a multiple of four, as in every
/// common video size, no pixel centre lands right on a cell's edge, so no
/// cell depends on how the GPU rounds there.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
/// the picture turns into pixel art), `size` (0.5–4: how large the pixels are,
/// as a share of the default) and `levels` (2–15: how many shades red and green
/// each take; blue takes three sevenths as many).
final class EightBitVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.eightBit"

  private let intensity: Double
  private let pixel: Double
  private let levels: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    pixel = Self.readNumber(params, "size", fallback: 1, in: 0.5...4)
    levels = Self.readNumber(params, "levels", fallback: 7, in: 2...15).rounded()
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in EightBitVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in EightBitVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] + [pixel, levels] : nil
  }

  static let function = "divineEightBit"

  /// `s` is the frame's shorter side, `cell` one game pixel's size in frame
  /// pixels. `bayer` is one step of the ordered dither, 0, 0.5, 0.75 or 0.25
  /// by where a cell sits in its 2 × 2 square; two steps make the 4 × 4
  /// threshold.
  static let source = """
    static float bayer(float2 a) {
      a = floor(a);
      return fract(a.x * 0.5 + a.y * a.y * 0.75);
    }

    kernel void divineEightBit(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float2 uSize = f.size;
      float uIntensity = u[3].x;
      float uPixel = u[3].y;
      float uLevels = u[3].z;
      float2 p = pixelOf(u, gid, target.get_height());
      float s = min(uSize.x, uSize.y);
      float cell = max(1.0, s / 100.0 * uPixel);
      float2 index = floor(p / cell);
      float2 centre = (index + 0.5) * cell;
      float q = 0.25 * cell;
      float3 color = tap(frame, f, p);
      float3 block = 0.25 * (tap(frame, f, centre + float2(-q, -q)) + tap(frame, f, centre + float2(q, -q)) +
        tap(frame, f, centre + float2(-q, q)) + tap(frame, f, centre + float2(q, q)));
      float threshold = 0.25 * bayer(0.5 * index) + bayer(index);
      float3 levels = float3(uLevels, uLevels, max(1.0, floor(uLevels * 3.0 / 7.0 + 0.5)));
      float3 shade = clamp(floor(block * levels + threshold), float3(0.0), levels) / levels;
      target.write(float4(mix(color, shade, uIntensity), 1.0), gid);
    }
    """
}
