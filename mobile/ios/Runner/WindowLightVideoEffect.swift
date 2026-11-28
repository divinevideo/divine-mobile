import Foundation
import divine_video_player
import pro_video_editor

/// Window light: slanted stripes of warm afternoon light, as through a
/// venetian blind, slide slowly across the picture.
///
/// The stripes fall on a soft, wide window patch a little right of and above
/// the middle, and fade out towards the frame's edges. In a stripe the
/// picture is lit warm; between the stripes, and outside the patch, it is a
/// little darker. The stripes take about nine seconds to move on by one, and
/// as many slide in as slide out, so the picture never pulses brighter and
/// darker.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
/// strong the light and the shade are), `angle` (-60–60: how far the slats lean
/// from level, in degrees; about 24 by default), `width` (0.5–2: how far apart
/// the slats are, as a share of the default), `color` (the colour of the light
/// falling through, as an ARGB integer) and `speed` (0–3: how fast the slats
/// drift, as a share of the default; 0 holds them still). The stripes move with
/// the time since the effect started, so they are in the same place in the
/// preview and in the export.
final class WindowLightVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.windowLight"

  /// How far the slats lean from level by default, in degrees.
  private static let angle = 24.227745

  /// How long the slats' direction is: one slat every 12% of the shorter side
  /// along it.
  private static let slantLength = 1.0965856

  private let intensity: Double
  private let slant: [Double]
  private let slat: Double
  private let color: [Double]
  private let speed: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    let angle = Self.readNumber(params, "angle", fallback: Self.angle, in: -60...60)
    let turn = Self.turn(degrees: angle)
    // The slats run across this direction; its length sets their spacing.
    slant = [Self.slantLength * turn[1], Self.slantLength * turn[0]]
    slat = Self.readNumber(params, "width", fallback: 1, in: 0.5...2)
    color = Self.readColor(params, "color", fallback: 0xFFFF_B650)
    speed = Self.readNumber(params, "speed", fallback: 1, in: 0...3)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in WindowLightVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in WindowLightVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0
      ? [intensity, Double(effectTimeUs) / 1_000_000] + slant + [slat] + color + [speed] : nil
  }

  static let function = "divineWindowLight"

  /// `s` is the frame's shorter side; one stripe and the gap after it take
  /// 12% of it.
  static let source = """
    kernel void divineWindowLight(
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
      float2 uSlant = u[3].zw;
      float uSlat = u[4].x;
      float3 uColor = u[4].yzw;
      float uSpeed = u[5].x;
      float2 p = pixelOf(u, gid, target.get_height());
      float s = min(uSize.x, uSize.y);
      float slats = fract(dot(p, uSlant) / (0.12 * uSlat * s) - 0.11 * uTime * uSpeed);
      float slat = smoothstep(0.0, 0.12, slats) * (1.0 - smoothstep(0.42, 0.56, slats));
      float2 d = (p / uSize - float2(0.58, 0.6)) * float2(1.3, 1.0);
      float window = 1.0 - smoothstep(0.25, 0.75, length(d));
      float3 shade = float3(1.0 - 0.35 * uIntensity);
      float3 warm = 1.0 + uIntensity * 0.7 * uColor;
      float3 base = tap(frame, f, p);
      target.write(float4(clamp(base * mix(shade, warm, slat * window), 0.0, 1.0), 1.0), gid);
    }
    """
}
