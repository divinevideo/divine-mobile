import Foundation
import divine_video_player
import pro_video_editor

/// Disco: coloured spots from a mirror ball sweep over the picture, which is
/// slightly dimmed around them.
///
/// The ball hangs above the middle of the top edge. Its spots lie on rings
/// around it, each ring a share of the frame's longer side further out than
/// the one before, at even steps along each ring and half a step apart from
/// ring to ring. All of them turn around the ball together, so they sweep
/// sideways across the picture. Each spot has a flat top and a soft edge,
/// `exp(-r⁴)` of the distance from its centre in shares of its size, and one
/// of three colours that change together, blended over a moment; see
/// ``PartyLights``.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how dim
/// the picture gets and how bright the spots are), `size` (0.5–2: how large the
/// spots are, as a share of the default), `speed` (0–3: how fast the ball
/// turns, as a share of the default; 0 holds it still) and, for an effect on
/// the beat, `beatsUs`: the beats, in microseconds after the effect's start. On
/// the beat the colours change and the ball turns the other way on each beat;
/// otherwise the colours change every one and a half seconds and it keeps
/// turning one way.
final class DiscoVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.disco"

  private let intensity: Double
  private let beatsUs: [Int64]?
  private let spotSize: Double
  private let speed: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    beatsUs = BlurHits.beats(params)
    spotSize = Self.readNumber(params, "size", fallback: 1, in: 0.5...2)
    speed = Self.readNumber(params, "speed", fallback: 1, in: 0...3)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in DiscoVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in DiscoVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    guard intensity > 0 else { return nil }
    let lights = PartyLights.at(beatsUs: beatsUs, effectTimeUs: effectTimeUs)
    return [intensity, lights.phase * speed, lights.step, lights.mix, spotSize]
  }

  static let function = "divineDisco"

  /// `l` is the frame's longer side. `turn` is the angle around the ball from
  /// straight down, turned with the ball, and `cell` the angle from one spot
  /// to the next on the pixel's ring.
  static let source = PartyLights.color + """
    kernel void divineDisco(
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
      float uSpotSize = u[4].x;
      float2 p = pixelOf(u, gid, target.get_height());
      float l = max(uSize.x, uSize.y);
      float2 ball = float2(0.5 * uSize.x, uSize.y + 0.35 * l);
      float2 d = p - ball;
      float spacing = 0.085 * l;
      float ring = floor(length(d) / spacing);
      float odd = ring - 2.0 * floor(ring / 2.0);
      float cell = 1.1 / (ring + 0.5);
      float spin = 0.25 * uPhase;
      float turn = atan2(d.x, -d.y) + spin;
      float index = floor(turn / cell + 0.5 * odd);
      float centreTurn = (index + 0.5 - 0.5 * odd) * cell - spin;
      float2 centre = ball + (ring + 0.5) * spacing * float2(sin(centreTurn), -cos(centreTurn));
      float size = 0.018 * l * uSpotSize * (0.75 + 0.5 * fract(index * 0.618034 + ring * 0.371));
      float2 q = (p - centre) / size;
      float r2 = dot(q, q);
      float spot = exp(-r2 * r2 * r2);
      float group = index + ring - 3.0 * floor((index + ring) / 3.0);
      float3 color = mix(partyColor(uStep - 1.0, group), partyColor(uStep, group), uMix);
      float3 base = tap(frame, f, p);
      float3 lit = base * (1.0 - 0.4 * uIntensity) + uIntensity * spot * color * (0.25 + 0.75 * base);
      target.write(float4(clamp(lit, 0.0, 1.0), 1.0), gid);
    }
    """
}

/// Where the disco and laser lights stand at a moment: which colours they
/// show, how far they have blended into them, and how far they have moved.
/// Mirrors the Android `PartyLights`.
///
/// All the time the colours change every ``stepUs`` and the lights move on one
/// way at one unit a second. On the beat each beat changes the colours and
/// turns the movement round, so the lights swing back and forth with the
/// music; before the first beat they move on with the first colours. A change
/// blends over ``fadeUs``, or until the next beat, whichever comes first,
/// eased in and out, so the colours never jump.
enum PartyLights {
  /// How long the colours stay when the lights play all through.
  static let stepUs: Int64 = 1_500_000

  /// How long a change of colour blends over.
  static let fadeUs: Int64 = 200_000

  /// The party colours: three groups of lights, a third of the hue circle
  /// apart, turning round the hue circle by the golden angle each step, and a
  /// fifth white so they light the picture rather than tint it.
  static let color = """
    static float3 partyColor(float stage, float group) {
      float3 hue = fract(0.08 + stage * 0.381966 + group / 3.0 + float3(0.0, 2.0 / 3.0, 1.0 / 3.0));
      return mix(float3(1.0), clamp(abs(hue * 6.0 - 3.0) - 1.0, 0.0, 1.0), 0.8);
    }

    """

  /// The lights `effectTimeUs` after the effect started, on `beatsUs` or all
  /// through: the colours of `step`, blended `mix` (0–1) of the way from
  /// those of the step before, moved `phase` units.
  static func at(beatsUs: [Int64]?, effectTimeUs: Int64)
    -> (step: Double, mix: Double, phase: Double)
  {
    let time = max(0, effectTimeUs)
    guard let beatsUs else {
      let step = time / stepUs
      let mix = step == 0 ? 1 : ease(Double(time - step * stepUs) / Double(fadeUs))
      return (Double(step), mix, Double(time) / 1_000_000)
    }
    guard let index = beatsUs.lastIndex(where: { $0 <= time }) else {
      return (0, 1, Double(time) / 1_000_000)
    }
    var phaseUs = beatsUs[0]
    var direction: Int64 = -1
    for k in 0..<index {
      phaseUs += direction * (beatsUs[k + 1] - beatsUs[k])
      direction = -direction
    }
    let beat = beatsUs[index]
    phaseUs += direction * (time - beat)
    let fade =
      index + 1 < beatsUs.count ? max(1, min(fadeUs, beatsUs[index + 1] - beat)) : fadeUs
    return (
      Double(index + 1), ease(Double(time - beat) / Double(fade)), Double(phaseUs) / 1_000_000
    )
  }

  private static func ease(_ x: Double) -> Double {
    let c = min(1, max(0, x))
    return c * c * (3 - 2 * c)
  }
}
