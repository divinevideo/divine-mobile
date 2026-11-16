import Foundation
import divine_video_player
import pro_video_editor

/// Bricks: the picture built from square toy bricks seen from above, each with
/// a round stud.
///
/// Each brick takes the mean colour of four taps inside it, a little more
/// colourful and cut to five levels a channel, as a box of bricks holds a
/// limited set of colours. Light comes from the top left: it catches the
/// bricks' top and left edges and the studs' rims, the studs cast a short
/// shadow to the bottom right, and dark seams run between the bricks. A
/// little of the light is added rather than multiplied, so black bricks show
/// their studs too.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// far the picture turns into bricks).
final class BricksVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.bricks"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in BricksVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in BricksVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity] : nil
  }

  static let function = "divineBricks"

  /// `s` is the frame's shorter side, `c` a brick's side in pixels, `d`
  /// the place within a brick from its middle, in bricks, and `aa` one
  /// pixel in bricks, which softens every edge.
  static let source = """
    static float luma(float3 c) {
      return dot(c, float3(0.299, 0.587, 0.114));
    }

    kernel void divineBricks(
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
      float c = max(6.0, s / 28.0);
      float2 cell = floor(p / c);
      float2 middle = (cell + 0.5) * c;
      float3 ink = 0.25 * (tap(frame, f, middle + float2(-0.25, -0.25) * c) + tap(frame, f, middle + float2(0.25, -0.25) * c) +
        tap(frame, f, middle + float2(-0.25, 0.25) * c) + tap(frame, f, middle + float2(0.25, 0.25) * c));
      float3 brick = floor(clamp(mix(float3(luma(ink)), ink, 1.2), 0.0, 1.0) * 4.0 + 0.5) / 4.0;
      float2 d = p / c - cell - 0.5;
      float aa = 1.0 / c;
      float2 toLight = float2(-0.70710678, 0.70710678);
      float edge = 0.5 - max(abs(d.x), abs(d.y));
      float seam = smoothstep(0.0, 1.5 * aa, edge);
      float2 outward = abs(d.x) > abs(d.y) ? float2(sign(d.x), 0.0) : float2(0.0, sign(d.y));
      float bevel = 1.0 + 0.3 * (1.0 - clamp(edge / 0.08, 0.0, 1.0)) * dot(outward, toLight);
      float r = length(d);
      float stud = 1.0 - smoothstep(0.3 - aa, 0.3 + aa, r);
      float shadow = 1.0 - smoothstep(0.3 - aa, 0.3 + aa, length(d - float2(0.05, -0.05)));
      float2 normal = d / max(r, 0.0001);
      float rim = 1.08 + 0.35 * smoothstep(0.22, 0.3, r) * dot(normal, toLight);
      float shade = mix(bevel * (1.0 - 0.25 * shadow), rim, stud);
      float3 bricks = clamp((brick * shade + 0.12 * max(shade - 1.0, 0.0)) * (0.35 + 0.65 * seam), 0.0, 1.0);
      target.write(float4(mix(tap(frame, f, p), bricks, intensity), 1.0), gid);
    }
    """
}
