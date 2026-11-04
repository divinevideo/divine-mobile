import Foundation
import divine_video_player
import pro_video_editor

/// 3D glasses: the picture as a red-cyan anaglyph, the way 3D films and comics
/// were printed for cardboard glasses.
///
/// The red channel shows the picture moved to the right and the green and blue
/// channels show it moved to the left, each mostly grey with a little of its
/// own colour kept. The red copy lying right of the cyan one makes the picture
/// seem to stand in front of the screen through the glasses; without them,
/// each shape gets a red fringe on one side and a cyan one on the other.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// far apart the copies are and how far the colours turn red and cyan).
final class AnaglyphVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.anaglyph"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in AnaglyphVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in AnaglyphVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] : nil
  }

  static let function = "divineAnaglyph"

  /// `s` is the frame's shorter side; each copy moves a share of it.
  static let source = """
    static float luma(float3 c) {
      return dot(c, float3(0.299, 0.587, 0.114));
    }

    kernel void divineAnaglyph(
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
      float2 shift = float2(0.014 * s * intensity, 0.0);
      float3 color = tap(frame, f, p);
      float3 left = tap(frame, f, p - shift);
      float3 right = tap(frame, f, p + shift);
      float3 stereo = float3(mix(luma(left), left.r, 0.3), mix(float2(luma(right)), right.gb, 0.3));
      target.write(float4(mix(color, stereo, intensity), 1.0), gid);
    }
    """
}
