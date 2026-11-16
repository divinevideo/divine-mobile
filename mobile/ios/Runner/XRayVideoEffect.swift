import Foundation
import divine_video_player
import pro_video_editor

/// X-ray: the picture as an X-ray film, its brightness turned around into
/// cold blue-white on near black, with the outlines standing out like bone.
///
/// What was dark turns bright and what was bright fades out. The outlines,
/// found where the brightness changes sharply with a Sobel filter, are
/// lightened on top, so shapes keep their edges.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// far the picture turns into the X-ray).
final class XRayVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.xray"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in XRayVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in XRayVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] : nil
  }

  static let function = "divineXRay"

  /// `s` is the frame's shorter side, `e` the Sobel filter's step in
  /// pixels. The darkness is clamped before its power, which GLSL and Metal
  /// leave undefined for a negative base.
  static let source = """
    static float luma(float3 c) {
      return dot(c, float3(0.299, 0.587, 0.114));
    }

    kernel void divineXRay(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float intensity = u[3].x;
      float2 p = pixelOf(u, gid, target.get_height());
      float s = min(f.size.x, f.size.y);
      float e = max(1.0, s / 540.0);
      float3 color = tap(frame, f, p);
      float tl = luma(tap(frame, f, p + float2(-e, e)));
      float tc = luma(tap(frame, f, p + float2(0.0, e)));
      float tr = luma(tap(frame, f, p + float2(e, e)));
      float ml = luma(tap(frame, f, p + float2(-e, 0.0)));
      float mr = luma(tap(frame, f, p + float2(e, 0.0)));
      float bl = luma(tap(frame, f, p + float2(-e, -e)));
      float bc = luma(tap(frame, f, p + float2(0.0, -e)));
      float br = luma(tap(frame, f, p + float2(e, -e)));
      float gx = tr + 2.0 * mr + br - tl - 2.0 * ml - bl;
      float gy = tl + 2.0 * tc + tr - bl - 2.0 * bc - br;
      float bone = smoothstep(0.1, 0.6, length(float2(gx, gy)));
      float density = clamp(1.1 * pow(max(1.0 - luma(color), 0.0), 1.6) + 0.5 * bone, 0.0, 1.0);
      float3 film = mix(float3(0.0, 0.02, 0.06), float3(0.78, 0.9, 1.0), density);
      target.write(float4(mix(color, film, intensity), 1.0), gid);
    }
    """
}
