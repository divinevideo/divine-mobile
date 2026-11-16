import Foundation
import divine_video_player
import pro_video_editor

/// The picture painted in one of its ``Style``s: in watercolour or in oil.
///
/// Both are a Kuwahara filter, which paints each pixel with the mean colour of
/// the evenest of the four quadrants around it, so the picture turns into
/// flat patches with the edges kept. The quadrants are mixed by how even each
/// is. Watercolour mixes them softly, lightens the washes unevenly, lets the
/// paint pool a little darker where they meet and shows the paper's grain;
/// oil paint keeps only the evenest, for hard edges, deepens the colours and
/// lights the patches' edges from the top left like thick paint, with fine
/// bristle marks.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// far the picture turns into paint).
final class PaintVideoEffect: ShaderVideoEffect {
  /// How the picture is painted; the raw value is what the shader mixes by.
  enum Style: Double, CaseIterable {
    case watercolor = 0
    case oil = 1

    /// The id the Dart `CustomVideoEffect` names.
    var id: String {
      switch self {
      case .watercolor: return "divine.watercolor"
      case .oil: return "divine.oilPaint"
      }
    }
  }

  private let style: Style
  private let intensity: Double

  init(style: Style, params: [String: Any]) {
    self.style = style
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers every style, each under its own id, for exports and for the
  /// editor preview, and compiles the shader ahead of the first frame.
  static func register() {
    for style in Style.allCases {
      CustomVideoEffects.register(style.id) { params in
        PaintVideoEffect(style: style, params: params)
      }
      VideoFrameEffects.register(style.id) { params in
        PaintVideoEffect(style: style, params: params)
      }
    }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity, style.rawValue] : nil
  }

  static let function = "divinePaint"

  /// `s` is the frame's shorter side, `e` the step between the filter's
  /// 7 by 7 taps, so the patches stay about the same share of the frame
  /// at every resolution. The hash is Dave Hoskins' "hash without sine"
  /// with 3.33 in place of its 33.33, as the particles use it.
  static let source = """
    static float luma(float3 c) {
      return dot(c, float3(0.299, 0.587, 0.114));
    }

    static float hash(float2 q) {
      float3 r = fract(float3(q.xyx) * 0.1031);
      r += dot(r, r.yzx + 3.33);
      return fract((r.x + r.y) * r.z);
    }

    static float noise(float2 q) {
      float2 i = floor(q);
      float2 f = q - i;
      f = f * f * (3.0 - 2.0 * f);
      float bottom = mix(hash(i), hash(i + float2(1.0, 0.0)), f.x);
      float top = mix(hash(i + float2(0.0, 1.0)), hash(i + float2(1.0, 1.0)), f.x);
      return mix(bottom, top, f.y);
    }

    kernel void divinePaint(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float intensity = u[3].x;
      float style = u[3].y;
      float2 p = pixelOf(u, gid, target.get_height());
      float s = min(f.size.x, f.size.y);
      float e = max(1.0, s / 360.0);
      float3 m0 = float3(0.0);
      float3 m1 = float3(0.0);
      float3 m2 = float3(0.0);
      float3 m3 = float3(0.0);
      float4 sum = float4(0.0);
      float4 squares = float4(0.0);
      for (int j = -3; j <= 3; j++) {
        for (int i = -3; i <= 3; i++) {
          float3 c = tap(frame, f, p + float2(float(i), float(j)) * e);
          float l = luma(c);
          float left = step(float(i), 0.0);
          float right = step(0.0, float(i));
          float below = step(float(j), 0.0);
          float above = step(0.0, float(j));
          float4 w = float4(left * below, right * below, left * above, right * above);
          m0 += c * w.x;
          m1 += c * w.y;
          m2 += c * w.z;
          m3 += c * w.w;
          sum += w * l;
          squares += w * l * l;
        }
      }
      float4 mean = sum / 16.0;
      float4 deviation = sqrt(max(squares / 16.0 - mean * mean, 0.0));
      float4 k = 1.0 / (1.0 + pow(deviation * 40.0, float4(mix(3.0, 8.0, style))));
      float3 painted = (m0 * k.x + m1 * k.y + m2 * k.z + m3 * k.w) / (16.0 * dot(k, float4(1.0)));
      float lo = min(min(mean.x, mean.y), min(mean.z, mean.w));
      float hi = max(max(mean.x, mean.y), max(mean.z, mean.w));
      float pool = smoothstep(0.06, 0.25, hi - lo);
      float blot = noise(p / (0.12 * s));
      float paper = 0.93 + 0.07 * noise(p / e);
      float3 pigment = clamp(mix(float3(luma(painted)), painted, 1.15), 0.0, 1.0);
      float3 wash = (1.0 - (1.0 - pigment) * (0.8 + 0.15 * blot)) * (1.0 - 0.12 * pool) * paper;
      float2 slope = float2(mean.y + mean.w - mean.x - mean.z, mean.z + mean.w - mean.x - mean.y);
      float relief = 1.0 + 0.8 * dot(slope, float2(-0.70710678, 0.70710678));
      float bristle = noise(float2(dot(p, float2(0.8, 0.6)) / e, dot(p, float2(-0.6, 0.8)) / (6.0 * e)));
      float light = clamp(relief * (0.96 + 0.08 * bristle), 0.85, 1.15);
      float3 oil = clamp(mix(float3(luma(painted)), painted, 1.3) * light, 0.0, 1.0);
      float3 art = mix(wash, oil, style);
      target.write(float4(mix(tap(frame, f, p), art, intensity), 1.0), gid);
    }
    """
}
