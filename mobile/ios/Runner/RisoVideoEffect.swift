import Foundation
import divine_video_player
import pro_video_editor

/// Riso print: the picture printed in fluorescent pink and blue ink on
/// off-white paper, grainy and slightly out of register, as a risograph
/// prints.
///
/// The pink ink takes the green out of the paper and the blue ink the red, so
/// each lays down as much as the picture lacks of that channel; where both
/// land they make a deep navy. Each ink covers its grain cells against
/// interleaved gradient noise of its own, with a soft edge, and the blue one
/// is read a little off to the side.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
/// the picture turns into the print), `color` and `color2` (the two inks, as
/// ARGB integers: pink and blue by default) and `offset` (0–3: how far the
/// second ink slips from the first, as a share of the default).
final class RisoVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.riso"

  private let intensity: Double
  private let inkA: [Double]
  private let inkB: [Double]
  private let slip: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    inkA = Self.readColor(params, "color", fallback: 0xFFFF_47B0)
    inkB = Self.readColor(params, "color2", fallback: 0xFF00_78BF)
    slip = Self.readNumber(params, "offset", fallback: 1, in: 0...3)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in RisoVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in RisoVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] + inkA + inkB + [slip] : nil
  }

  static let function = "divineRiso"

  /// `s` is the frame's shorter side and `g` the grain cell, about three
  /// pixels of a 1080p frame. `cover` maps the noise into 0.15–0.85 and
  /// softens the edge over 0.3, so no ink lands on white and full ink covers
  /// everything.
  static let source = """
    static float grain(float2 q) {
      return fract(52.9829189 * fract(dot(q, float2(0.06711056, 0.00583715))));
    }

    static float cover(float density, float threshold) {
      return clamp((density - 0.15 - 0.7 * threshold) / 0.3 + 0.5, 0.0, 1.0);
    }

    kernel void divineRiso(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float2 uSize = f.size;
      float uIntensity = u[3].x;
      float3 uInkA = u[3].yzw;
      float3 uInkB = u[4].xyz;
      float uSlip = u[4].w;
      float2 p = pixelOf(u, gid, target.get_height());
      float s = min(uSize.x, uSize.y);
      float2 g = floor(p / max(1.0, s / 360.0));
      float3 color = tap(frame, f, p);
      float3 slipped = tap(frame, f, p + float2(0.006, -0.004) * s * uSlip);
      float pink = cover(1.0 - color.g, grain(g));
      float blue = cover(1.0 - slipped.r, grain(g + float2(19.0, 7.0)));
      float3 riso = float3(0.96, 0.94, 0.9) * mix(float3(1.0), uInkA, pink) *
        mix(float3(1.0), uInkB, blue);
      target.write(float4(mix(color, riso, uIntensity), 1.0), gid);
    }
    """
}
