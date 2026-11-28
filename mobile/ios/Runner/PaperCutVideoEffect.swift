import Foundation
import divine_video_player
import pro_video_editor

/// Paper cut: the picture as layers of cut coloured paper stacked on each
/// other, the lighter ones on top.
///
/// The picture is softened over a ring of taps, so the sheets get smooth,
/// rounded edges instead of following every grain and speck, and its
/// brightness is cut into four layers. Each sheet has its layer's one
/// brightness and keeps the picture's hue there, a little paler, so grey
/// stays grey and skin stays skin. Light comes from the top left: a higher
/// sheet casts a soft shadow on the ones below, and a sheet's edge facing the
/// light catches it. The paper has a faint grain.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
/// the picture turns into paper), `layers` (2–8: how many sheets the picture is
/// cut into) and `shadow` (0.3–2.5: how far the sheets stand apart, which sets
/// how long their shadows are, as a share of the default).
final class PaperCutVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.paperCut"

  private let intensity: Double
  private let layers: Double
  private let depth: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    layers = Self.readNumber(params, "layers", fallback: 4, in: 2...8).rounded()
    depth = Self.readNumber(params, "shadow", fallback: 1, in: 0.3...2.5)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in PaperCutVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in PaperCutVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] + [layers, depth] : nil
  }

  static let function = "divinePaperCut"

  /// `s` is the frame's shorter side, `e` the softening's radius and the
  /// shadow's step in pixels. Each of the three places the shadow looks
  /// at is softened over nine taps, so the effect reads 28 taps a pixel.
  static let source = """
    static float luma(float3 c) {
      return dot(c, float3(0.299, 0.587, 0.114));
    }

    static float grain(float2 q) {
      return fract(52.9829189 * fract(dot(q, float2(0.06711056, 0.00583715))));
    }

    // The picture at `q`, softened over its centre and eight taps on a ring `e`
    // around it.
    static float3 soft(texture2d<float, access::sample> frame, Frame f, float2 q, float e) {
      float d = 0.70710678 * e;
      float3 ring = tap(frame, f, q + float2(e, 0.0)) + tap(frame, f, q - float2(e, 0.0)) + tap(frame, f, q + float2(0.0, e)) +
        tap(frame, f, q - float2(0.0, e)) + tap(frame, f, q + float2(d, d)) + tap(frame, f, q - float2(d, d)) +
        tap(frame, f, q + float2(d, -d)) + tap(frame, f, q - float2(d, -d));
      return (tap(frame, f, q) + ring) / 9.0;
    }

    // Which of the n layers a colour lies on, 0 the lowest.
    static float layer(float3 c, float n) {
      return min(floor(clamp(luma(c), 0.0, 1.0) * n), n - 1.0);
    }

    kernel void divinePaperCut(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float2 uSize = f.size;
      float uIntensity = u[3].x;
      float uLayers = u[3].y;
      float uDepth = u[3].z;
      float2 p = pixelOf(u, gid, target.get_height());
      float s = min(uSize.x, uSize.y);
      float e = max(1.5, s / 180.0);
      float2 toLight = float2(-0.70710678, 0.70710678) * e * uDepth;
      float3 here = soft(frame, f, p, e);
      float h = layer(here, uLayers);
      float near = layer(soft(frame, f, p + toLight, e), uLayers);
      float far = layer(soft(frame, f, p + 2.0 * toLight, e), uLayers);
      float shadow = max(step(h + 0.5, near) * 0.7, step(h + 0.5, far) * 0.35);
      float lit = step(near + 0.5, h);
      float l = luma(here);
      float3 hue = (here - l) * 0.8;
      float sheetLuma = 0.16 + 0.72 * h / (uLayers - 1.0);
      float3 sheet = clamp(sheetLuma + hue * min(sheetLuma / max(l, 0.05), 1.5), 0.0, 1.0);
      float fibre = 0.97 + 0.03 * grain(floor(p / max(1.0, s / 540.0)));
      float3 paper = clamp(sheet * (1.0 - 0.4 * shadow) * (1.0 + 0.12 * lit) * fibre, 0.0, 1.0);
      target.write(float4(mix(tap(frame, f, p), paper, uIntensity), 1.0), gid);
    }
    """
}
