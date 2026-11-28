import Foundation
import divine_video_player
import pro_video_editor

/// Cross-stitch: the picture embroidered in cross stitches on off-white cloth.
///
/// Each cell of the cloth holds one stitch, two strands of thread crossing
/// from corner to corner, in the mean colour of four taps inside the cell, a
/// little more colourful and cut to seven levels a channel, as a set of
/// threads holds a limited choice of colours. Each strand is rounded and
/// twisted, the top one runs from the top left to the bottom right, and both
/// shade the cloth beside them. The cloth shows between the stitches, with a
/// hole at every corner where the needle went through.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
/// the picture turns into embroidery), `size` (0.5–3: how large the stitches
/// are, as a share of the default) and `color` (the cloth's colour, as an ARGB
/// integer).
final class CrossStitchVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.crossStitch"

  private let intensity: Double
  private let stitch: Double
  private let cloth: [Double]

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    stitch = Self.readNumber(params, "size", fallback: 1, in: 0.5...3)
    cloth = Self.readColor(params, "color", fallback: 0xFFF0_EBDB)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in CrossStitchVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in CrossStitchVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] + [stitch] + cloth : nil
  }

  static let function = "divineCrossStitch"

  /// `s` is the frame's shorter side and `c` a cell's side in pixels;
  /// `inCell` is the place within a cell, `w` half a strand's width and
  /// `aa` one pixel, all in cells. Each twist keeps its phase within one
  /// turn, where the GPU's sine stays exact.
  static let source = """
    static float luma(float3 c) {
      return dot(c, float3(0.299, 0.587, 0.114));
    }

    kernel void divineCrossStitch(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float2 uSize = f.size;
      float uIntensity = u[3].x;
      float uStitch = u[3].y;
      float3 uCloth = float3(u[3].z, u[3].w, u[4].x);
      float2 p = pixelOf(u, gid, target.get_height());
      float s = min(uSize.x, uSize.y);
      float c = max(6.0, s / 36.0 * uStitch);
      float2 cell = floor(p / c);
      float2 middle = (cell + 0.5) * c;
      float3 ink = 0.25 * (tap(frame, f, middle + float2(-0.25, -0.25) * c) + tap(frame, f, middle + float2(0.25, -0.25) * c) +
        tap(frame, f, middle + float2(-0.25, 0.25) * c) + tap(frame, f, middle + float2(0.25, 0.25) * c));
      float3 floss = floor(clamp(mix(float3(luma(ink)), ink, 1.15), 0.0, 1.0) * 6.0 + 0.5) / 6.0;
      float2 inCell = p / c - cell;
      float aa = 1.0 / c;
      float w = 0.2;
      float under = abs(inCell.x - inCell.y) * 0.70710678;
      float over = abs(inCell.x + inCell.y - 1.0) * 0.70710678;
      float ends = max(abs(inCell.x - 0.5), abs(inCell.y - 0.5));
      float inside = 1.0 - smoothstep(0.47 - aa, 0.47 + aa, ends);
      float underMask = (1.0 - smoothstep(w - aa, w + aa, under)) * inside;
      float overMask = (1.0 - smoothstep(w - aa, w + aa, over)) * inside;
      float underTwist = 0.9 + 0.1 * sin(6.2831853 * fract((inCell.x + inCell.y) * 2.5));
      float overTwist = 0.9 + 0.1 * sin(6.2831853 * fract((inCell.x - inCell.y) * 2.5));
      float underRound = 1.0 - 0.25 * min(under / w, 1.0) * min(under / w, 1.0);
      float overRound = 1.0 - 0.25 * min(over / w, 1.0) * min(over / w, 1.0);
      float beside = max(1.0 - smoothstep(w, w + 0.08, under), 1.0 - smoothstep(w, w + 0.08, over));
      float2 hole = inCell - floor(inCell + 0.5);
      float holes = smoothstep(0.04, 0.09, length(hole));
      float3 cloth = uCloth * (0.7 + 0.3 * holes) * (1.0 - 0.25 * beside * inside);
      float3 stitch = mix(cloth, floss * underTwist * underRound, underMask);
      stitch = mix(stitch, floss * overTwist * overRound * 1.05, overMask);
      target.write(float4(mix(tap(frame, f, p), clamp(stitch, 0.0, 1.0), uIntensity), 1.0), gid);
    }
    """
}
