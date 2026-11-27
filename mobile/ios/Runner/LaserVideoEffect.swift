import Foundation
import divine_video_player
import pro_video_editor

/// Laser: thin coloured beams fan out from the top of the picture and sweep
/// across it, changing colour, over a slightly dimmed picture.
///
/// Seven beams start just above the middle of the top edge, the angle between
/// them opening and closing slowly while the whole fan swings from side to
/// side, `0.5 · sin(0.8 · phase)` radians from straight down. Each beam is a
/// thin bright core with a soft glow around it, fading with the distance from
/// the source, and the beams take two colours in turn, half the hue circle
/// apart, which change together; see ``PartyLights``.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how dim
/// the picture gets and how bright the beams are), `count` (1–9: how many beams
/// the fan has), `speed` (0–3: how fast the fan swings, as a share of the
/// default; 0 holds it still) and, for an effect on the beat, `beatsUs`: the
/// beats, in microseconds after the effect's start. On the beat the colours
/// change and the fan swings the other way on each beat; otherwise the colours
/// change every one and a half seconds and it swings on steadily.
final class LaserVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.laser"

  private let intensity: Double
  private let beatsUs: [Int64]?
  private let beams: Double
  private let speed: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    beatsUs = BlurHits.beats(params)
    beams = Self.readNumber(params, "count", fallback: 7, in: 1...9).rounded()
    speed = Self.readNumber(params, "speed", fallback: 1, in: 0...3)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in LaserVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in LaserVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    guard intensity > 0 else { return nil }
    let lights = PartyLights.at(beatsUs: beatsUs, effectTimeUs: effectTimeUs)
    return [intensity, lights.phase * speed, lights.step, lights.mix, beams]
  }

  static let function = "divineLaser"

  /// `l` is the frame's longer side. `across` is how far the pixel lies
  /// beside a beam, in pixels.
  static let source = PartyLights.color + """
    kernel void divineLaser(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float2 uSize = f.size;
      float uIntensity = u[3].x;
      float uPhase = u[3].y;
      float uStep = u[3].z;
      float uMix = u[3].w;
      float uBeams = u[4].x;
      float2 p = pixelOf(u, gid, target.get_height());
      float l = max(uSize.x, uSize.y);
      float2 d = p - float2(0.5 * uSize.x, uSize.y + 0.02 * l);
      float dist = length(d);
      float angle = atan2(d.x, -d.y);
      float aim = 0.5 * sin(0.8 * uPhase);
      float spread = 0.14 + 0.05 * sin(0.45 * uPhase + 1.3);
      float3 first = mix(partyColor(uStep - 1.0, 0.0), partyColor(uStep, 0.0), uMix);
      float3 second = mix(partyColor(uStep - 1.0, 1.5), partyColor(uStep, 1.5), uMix);
      float core = 0.0022 * l;
      float glow = 0.012 * l;
      float3 light = float3(0.0);
      for (int i = 0; i < 9; i++) {
        if (float(i) >= uBeams) break;
        float across = dist * abs(sin(angle - aim - (float(i) - 0.5 * (uBeams - 1.0)) * spread));
        float beam = exp(-across * across / (core * core)) + 0.35 * exp(-across / glow);
        light += beam * mix(first, second, float(i) - 2.0 * floor(float(i) / 2.0));
      }
      float fade = 1.0 / (1.0 + dist / (0.8 * l));
      float3 base = tap(frame, f, p);
      float3 lit = base * (1.0 - 0.35 * uIntensity) + uIntensity * fade * light;
      target.write(float4(clamp(lit, 0.0, 1.0), 1.0), gid);
    }
    """
}
