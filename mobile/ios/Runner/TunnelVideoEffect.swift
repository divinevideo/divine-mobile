import Foundation
import divine_video_player
import pro_video_editor

/// Tunnel: the picture holds a smaller copy of itself in its middle, which
/// holds another, and so on, and the picture zooms into them without end.
///
/// The copy is 15% to 55% of the frame as the intensity rises. Each step zooms
/// one copy up to the size of the one around it. The plain tunnel nests whole
/// frames, each with a thin shadow along its edge; the spiral tunnel nests
/// rings within half the shorter side and twists them, so one turn around the
/// middle leads one copy deeper.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
/// large the copy is), `periodUs` (how long a step takes; the Dart side fits a
/// whole number of steps into the effect's window, so a video that loops
/// zooms on seamlessly) and, for an effect on the beat, `beatsUs`: the beats,
/// in microseconds after the effect's start, each taking one step; see
/// ``TunnelSteps``.
final class TunnelVideoEffect: ShaderVideoEffect {
  /// The ids the Dart `CustomVideoEffect` names.
  static let id = "divine.tunnel"
  static let spiralId = "divine.spiralTunnel"

  private let spiral: Bool
  private let intensity: Double
  private let periodUs: Int64
  private let beatsUs: [Int64]?

  init(spiral: Bool, params: [String: Any]) {
    self.spiral = spiral
    intensity = Self.readIntensity(params)
    let period = (params["periodUs"] as? NSNumber)?.int64Value ?? 0
    periodUs = period > 0 ? period : TunnelSteps.naturalPeriodUs(intensity: intensity)
    beatsUs = BlurHits.beats(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers both tunnels for exports and for the editor preview, and
  /// compiles their shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in TunnelVideoEffect(spiral: false, params: params) }
    VideoFrameEffects.register(id) { params in TunnelVideoEffect(spiral: false, params: params) }
    CustomVideoEffects.register(spiralId) { params in
      TunnelVideoEffect(spiral: true, params: params)
    }
    VideoFrameEffects.register(spiralId) { params in
      TunnelVideoEffect(spiral: true, params: params)
    }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    guard intensity > 0 else { return nil }
    let phase = TunnelSteps.phase(periodUs: periodUs, beatsUs: beatsUs, effectTimeUs: effectTimeUs)
    return [intensity, phase, spiral ? 1 : 0]
  }

  static let function = "divineTunnel"

  /// `level` is how many times e the picture grows from one copy to the
  /// next, `f` how far a pixel lies into its copy (0 at its edge, 1 at the
  /// next copy's edge), and `edge` how many pixels the point it reads lies
  /// inside its copy's edge. `s` is the frame's shorter side.
  static let source = """
    kernel void divineTunnel(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f0 = frameOf(u);
      float intensity = u[3].x;
      float phase = u[3].y;
      float spiral = u[3].z;
      float2 p = pixelOf(u, gid, target.get_height());
      if (intensity <= 0.0) {
        target.write(float4(tap(frame, f0, p), 1.0), gid);
        return;
      }
      float2 c = f0.size * 0.5;
      float2 d = p - c;
      float s = min(f0.size.x, f0.size.y);
      float level = -log(0.15 + 0.4 * intensity);
      float2 q;
      float edge;
      if (spiral > 0.5) {
        float big = 0.5 * s;
        float lr = log(max(length(d), 0.001) / big);
        float a = atan2(d.y, d.x);
        float twist = level / 6.2832;
        float f = fract(-(lr + a * twist) / level + phase);
        float r = big * exp(-level * f);
        float b = a - lr * twist;
        q = c + r * float2(cos(b), sin(b));
        edge = big - r;
      } else {
        float m = max(max(abs(d.x) / c.x, abs(d.y) / c.y), 0.0001);
        float f = fract(-log(m) / level + phase);
        q = c + d * (exp(-level * f) / m);
        float2 e = c - abs(q - c);
        edge = min(e.x, e.y);
      }
      float shade = 1.0 - 0.35 * (1.0 - smoothstep(0.0, 0.012 * s, edge));
      target.write(float4(tap(frame, f0, q) * shade, 1.0), gid);
    }
    """
}

/// How far the tunnel has zoomed into its current copy at a moment, from 0 to
/// 1. Mirrors the Kotlin `TunnelSteps` and the Dart `tunnelStepDuration`.
///
/// All the time it zooms on steadily, one step per period. On the beat each
/// beat zooms one step, easing out over ``stepUs`` or until the next beat,
/// whichever comes first; before the first beat it holds still.
enum TunnelSteps {
  /// The longest one step on the beat takes.
  static let stepUs: Int64 = 350_000

  /// How long the picture takes to double in size, whatever the copy's size.
  private static let doublingUs = 1_200_000.0

  /// How long a step takes at `intensity` in a window it need not fit.
  static func naturalPeriodUs(intensity: Double) -> Int64 {
    Int64((-log(0.15 + 0.4 * intensity) / log(2.0) * doublingUs).rounded())
  }

  /// The phase `effectTimeUs` after the effect started.
  static func phase(periodUs: Int64, beatsUs: [Int64]?, effectTimeUs: Int64) -> Double {
    guard let beatsUs else {
      let into = ((effectTimeUs % periodUs) + periodUs) % periodUs
      return Double(into) / Double(periodUs)
    }
    guard let index = beatsUs.lastIndex(where: { $0 <= effectTimeUs }) else { return 0 }
    let beat = beatsUs[index]
    let next = index + 1 < beatsUs.count ? beatsUs[index + 1] : nil
    let span = max(1, next.map { min(stepUs, $0 - beat) } ?? stepUs)
    let x = min(1, Double(effectTimeUs - beat) / Double(span))
    guard x < 1 else { return 0 }
    let rest = 1 - x
    return 1 - rest * rest * rest
  }
}
