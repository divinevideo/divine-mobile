import Foundation
import divine_video_player
import pro_video_editor

/// Light leak: warm light washes in from the left and top edges and drifts
/// across the picture, the way stray light fogs a strip of film.
///
/// Three soft lights, orange, red and gold, each follow a slow path of their
/// own, `a + b · sin(f · t + phase)` along each axis, and brighten the picture
/// with a screen blend. Each light keeps its strength while it moves, so the
/// picture never pulses brighter and darker: a flashing effect would need the
/// flashing lights warning.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
/// strong the light is), `hue` (0–360: how far the light's colours turn around
/// the colour wheel, in degrees), `size` (0.5–2: how large the patches of light
/// are, as a share of the default) and `speed` (0–3: how fast they drift, as a
/// share of the default; 0 holds them still). The lights move with the time
/// since the effect started, so they follow the same path in the preview and in
/// the export.
final class LightLeakVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.lightLeak"

  private let intensity: Double
  private let hue: [Double]
  private let spread: Double
  private let speed: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    hue = Self.turn(degrees: Self.readNumber(params, "hue", fallback: 0, in: 0...360))
    spread = Self.readNumber(params, "size", fallback: 1, in: 0.5...2)
    speed = Self.readNumber(params, "speed", fallback: 1, in: 0...3)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in LightLeakVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in LightLeakVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity, Double(effectTimeUs) / 1_000_000] + hue + [spread, speed] : nil
  }

  static let function = "divineLightLeak"

  /// `l` is the frame's longer side; each light's reach is a share of it
  /// across and up.
  static let source = """
    // c turned around the grey axis of the colour cube by the angle whose cosine
    // and sine hue holds.
    static float3 turnHue(float3 c, float2 hue) {
      float3 k = float3(0.57735);
      return c * hue.x + cross(k, c) * hue.y + k * dot(k, c) * (1.0 - hue.x);
    }

    static float3 light(float2 p, float2 centre, float2 reach, float3 color) {
      float2 d = (p - centre) / reach;
      return color * exp(-dot(d, d));
    }

    kernel void divineLightLeak(
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
      float2 uHue = u[3].zw;
      float uSpread = u[4].x;
      float uSpeed = u[4].y;
      float2 p = pixelOf(u, gid, target.get_height());
      float l = max(uSize.x, uSize.y);
      float t = uTime * uSpeed;
      float reach = l * uSpread;
      float3 base = tap(frame, f, p);
      float3 glow =
        light(p, uSize * float2(-0.06 + 0.16 * sin(0.37 * t + 0.4), 0.62 + 0.3 * sin(0.21 * t + 1.1)),
          reach * float2(0.32, 0.6), float3(0.95, 0.49, 0.17)) +
        light(p, uSize * float2(0.45 + 0.4 * sin(0.18 * t + 2.2), 1.04 + 0.08 * sin(0.31 * t + 0.3)),
          reach * float2(0.55, 0.26), float3(0.75, 0.21, 0.24)) +
        light(p, uSize * float2(0.18 + 0.42 * sin(0.27 * t + 4.0), 0.8 + 0.18 * sin(0.47 * t + 2.6)),
          reach * float2(0.24, 0.24), float3(0.55, 0.45, 0.28));
      float3 leak = clamp(turnHue(glow, uHue) * uIntensity, 0.0, 1.0);
      target.write(float4(1.0 - (1.0 - base) * (1.0 - leak), 1.0), gid);
    }
    """
}
