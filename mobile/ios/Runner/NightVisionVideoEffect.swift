import Foundation
import divine_video_player
import pro_video_editor

/// Night vision: the picture as night vision goggles show it, brightened into
/// green phosphor, with fine noise, faint scanlines and darker corners.
///
/// The brightness is lifted, more in the shadows, and turned into the
/// phosphor's green, which pales towards white where it is brightest. The
/// noise changes 24 times a second, stepping through ``noisePatterns`` patterns,
/// so it stays fine grain rather than a flicker; its mean is zero, so the
/// picture keeps its brightness. It moves with the time since the effect
/// started, so it is the same in the preview and in the export.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
/// the picture turns into night vision), `grain` (0–3: how much grain the tube
/// adds, as a share of the default) and `color` (the phosphor's colour, as an
/// ARGB integer: green by default).
final class NightVisionVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.nightVision"

  /// The phosphor's colour unless the user picks another, as an ARGB integer.
  private static let defaultColor: Int64 = 0xFF1A_FF26

  /// How far the default phosphor lifts towards white as it glows.
  private static let defaultLift: [Double] = [0.5, 0, 0.4]

  /// How many noise patterns the effect steps through, 24 a second.
  static let noisePatterns: Int64 = 64

  private let intensity: Double
  private let grain: Double
  private let base: [Double]
  private let lift: [Double]

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    grain = Self.readNumber(params, "grain", fallback: 1, in: 0...3)
    let base = Self.readColor(params, "color", fallback: Self.defaultColor)
    let defaultBase = Self.readColor([:], "color", fallback: Self.defaultColor)
    self.base = base
    // How far the phosphor lifts towards white as it glows, kept off the
    // default colour as far as the colour is.
    lift = (0..<3).map { Self.defaultLift[$0] + 0.5 * (defaultBase[$0] - base[$0]) }
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in NightVisionVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in NightVisionVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  /// Which noise pattern shows `effectTimeUs` after the effect started.
  static func noiseFrame(effectTimeUs: Int64) -> Double {
    Double(max(effectTimeUs, 0) * 24 / 1_000_000 % noisePatterns)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0
      ? [intensity, Self.noiseFrame(effectTimeUs: effectTimeUs), grain] + base + lift : nil
  }

  static let function = "divineNightVision"

  /// `s` is the frame's shorter side, `e` a grain cell and half a
  /// scanline, in pixels. The noise is interleaved gradient noise, its
  /// cells shifted by the pattern's number. The brightness is clamped
  /// before its power, which GLSL and Metal leave undefined for a negative
  /// base.
  static let source = """
    static float luma(float3 c) {
      return dot(c, float3(0.299, 0.587, 0.114));
    }

    static float grain(float2 q) {
      return fract(52.9829189 * fract(dot(q, float2(0.06711056, 0.00583715))));
    }

    kernel void divineNightVision(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float2 uSize = f.size;
      float uIntensity = u[3].x;
      float uNoiseFrame = u[3].y;
      float uGrain = u[3].z;
      float3 uBase = float3(u[3].w, u[4].x, u[4].y);
      float3 uLift = float3(u[4].z, u[4].w, u[5].x);
      float2 p = pixelOf(u, gid, target.get_height());
      float s = min(uSize.x, uSize.y);
      float e = max(1.0, s / 540.0);
      float3 color = tap(frame, f, p);
      float level = clamp(1.1 * pow(max(luma(color), 0.0), 0.75), 0.0, 1.0);
      float noise = grain(floor(p / e) + uNoiseFrame * float2(37.0, 17.0)) - 0.5;
      float scan = 0.94 + 0.06 * step(0.5, fract(p.y / (2.0 * e)));
      float corner = length(p / uSize - 0.5);
      float tube = 1.0 - 0.65 * smoothstep(0.35, 0.75, corner);
      float glow = clamp((level + 0.12 * uGrain * noise) * scan * tube, 0.0, 1.0);
      float3 phosphor = (uBase + uLift * glow) * glow + float3(0.0, 0.03, 0.01);
      target.write(float4(mix(color, clamp(phosphor, 0.0, 1.0), uIntensity), 1.0), gid);
    }
    """
}
