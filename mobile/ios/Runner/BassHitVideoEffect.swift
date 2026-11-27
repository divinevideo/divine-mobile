import Foundation
import divine_video_player
import pro_video_editor

/// A hit of heavy bass in one of its ``Style``s: a shockwave or a subwoofer.
///
/// The shockwave sends a ring of pressure from where it hits past the farthest
/// corner, slowing as it goes, and leaves the frame well before its time is up.
/// The ring bends the picture like a lens, splits its colours along the way out
/// and lights it by up to 6%, and fades as it travels; within 8% of the shorter
/// side from the frame's edge it eases off, so it never reads past the edge.
/// The picture punches in by up to 8%.
///
/// The subwoofer bulges the picture out like a speaker cone where it hits, at
/// most 45% at its middle and not at all from half the shorter side out, then
/// pulls it in and lets it spring back twice within 0.4 s.
///
/// Either way the picture rattles for 0.4 s, by up to 1.5% (shockwave) or 0.7%
/// (subwoofer) of the shorter side along two sines of unrelated frequencies,
/// and is zoomed in by a little more than twice that, so its edges never come
/// into view. The look the user set scales these.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
/// hard the hit lands), `strikesUs`, when it hits, in microseconds after the
/// effect's start, `hitUs`, how long one hit lasts, and the look the user set
/// (see ``HitLook``): where it hits, how far the ring travels or how large the
/// cone is, how hard the picture rattles and punches in, and how far the ring
/// splits the colours. The Dart side times the hits, on the beat, once or again
/// and again; see ``BassHits`` for how they play out.
final class BassHitVideoEffect: ShaderVideoEffect {
  /// How the hit lands; the raw value is what the shader mixes by.
  enum Style: Double, CaseIterable {
    case shockwave = 0
    case subwoofer = 1

    /// The id the Dart `CustomVideoEffect` names.
    var id: String {
      switch self {
      case .shockwave: return "divine.shockwave"
      case .subwoofer: return "divine.subwoofer"
      }
    }
  }

  private let style: Style
  private let intensity: Double
  private let look: HitLook
  private let hitsUs: [Int64]
  private let hitUs: Int64

  init(style: Style, params: [String: Any]) {
    self.style = style
    intensity = Self.readIntensity(params)
    look = HitLook(params, defaultColor: 0)
    hitsUs = LightningStrikes.strikes(params)
    hitUs = BassHits.hit(params, fallbackUs: BassHits.hitUs)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers every style, each under its own id, for exports and for the
  /// editor preview, and compiles the shader ahead of the first frame.
  static func register() {
    for style in Style.allCases {
      CustomVideoEffects.register(style.id) { params in
        BassHitVideoEffect(style: style, params: params)
      }
      VideoFrameEffects.register(style.id) { params in
        BassHitVideoEffect(style: style, params: params)
      }
    }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    guard intensity > 0,
      let age = BassHits.age(
        hitsUs: hitsUs, hitUs: hitUs, animationUs: BassHits.hitUs, effectTimeUs: effectTimeUs)
    else { return nil }
    return [
      intensity, age, style.rawValue, look.reach, look.centerX, look.centerY, look.shake,
      look.punch, look.fringe,
    ]
  }

  static let function = "divineBassHit"

  /// `s` is the frame's shorter side. `wave` is 1 for the shockwave and 0 for
  /// the subwoofer, whose terms the other one multiplies away.
  static let source = """
    kernel void divineBassHit(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float2 uSize = f.size;
      float uIntensity = u[3].x;
      float uAge = u[3].y;
      float uStyle = u[3].z;
      float uReach = u[3].w;
      float2 uCenter = u[4].xy;
      float uShake = u[4].z;
      float uPunch = u[4].w;
      float uFringe = u[5].x;
      float2 p = pixelOf(u, gid, target.get_height());
      float2 c = float2(uCenter.x, 1.0 - uCenter.y) * uSize;
      float2 m = uSize * 0.5;
      float s = min(uSize.x, uSize.y);
      float2 d = p - c;
      float r = length(d);
      float2 dir = d / max(r, 0.001);
      float wave = 1.0 - step(0.5, uStyle);
      float edge = min(min(p.x, uSize.x - p.x), min(p.y, uSize.y - p.y));
      float keep = smoothstep(0.0, 0.08 * s, edge);

      float t = min(uAge / 0.5, 1.0);
      float spread = 1.0 - (1.0 - t) * (1.0 - t);
      float w = s * (0.07 + 0.1 * spread);
      float x = (r - 1.6 * uReach * length(max(c, uSize - c)) * spread) / w;
      float band = max(1.0 - x * x, 0.0);
      band = band * band;
      float ring = uIntensity * (1.0 - t) * wave * keep;
      float2 q = p - dir * (0.9 * w * ring * x * band);

      float v = min(uAge / 0.4, 1.0);
      float spring = (1.0 - v) * (1.0 - v) * cos(12.566 * v);
      float nr = r / (0.5 * s * uReach);
      float cone = max(1.0 - nr * nr, 0.0);
      q = c + (q - c) * (1.0 - 0.45 * uIntensity * (1.0 - wave) * spring * cone * cone * keep);

      float rattle = max(1.0 - uAge / 0.4, 0.0);
      rattle = rattle * rattle * rattle;
      float punch = max(1.0 - uAge / 0.3, 0.0);
      punch = punch * punch;
      float jolt = mix(0.007, 0.015, wave) * uIntensity * uShake * rattle;
      float zoom = 1.0 + 2.2 * jolt + 0.08 * uIntensity * uPunch * wave * punch;
      float2 shake = jolt * s * float2(sin(81.681 * uAge + 0.6), sin(106.814 * uAge + 2.1));
      q = m + (q - m) / zoom + shake;
      float2 fringe = dir * (0.02 * s * uFringe * ring * band) / zoom;

      float3 color = float3(tap(frame, f, q + fringe).r, tap(frame, f, q).g, tap(frame, f, q - fringe).b);
      target.write(float4(clamp(color * (1.0 + 0.06 * ring * band), 0.0, 1.0), 1.0), gid);
    }
    """
}

/// How the hits of the bass hits and the blasts play out. Mirrors the Android
/// `BassHits`.
///
/// Each hit lasts `hitUs`, and its animation, drawn over a fixed length of its
/// own, is stretched or squeezed to fill it; a later hit starts the next one.
/// Before the first hit, and once one is over, they leave the picture alone.
enum BassHits {
  /// How long a bass hit's own animation lasts: the ring reaches past the
  /// corners by then.
  static let hitUs: Int64 = 500_000

  /// How long one hit lasts, from `params`, or `fallbackUs` without one.
  static func hit(_ params: [String: Any], fallbackUs: Int64) -> Int64 {
    max(1, (params["hitUs"] as? NSNumber)?.int64Value ?? fallbackUs)
  }

  /// Seconds into an animation of `animationUs` that the last of `hitsUs` at
  /// or before `effectTimeUs` has reached, with each hit lasting `hitUs`;
  /// `nil` before the first hit and once that one is over.
  static func age(hitsUs: [Int64], hitUs: Int64, animationUs: Int64, effectTimeUs: Int64)
    -> Double?
  {
    guard let index = LightningStrikes.index(strikesUs: hitsUs, effectTimeUs: effectTimeUs)
    else { return nil }
    let sinceUs = effectTimeUs - hitsUs[index]
    guard sinceUs < hitUs else { return nil }
    return Double(sinceUs) / Double(hitUs) * Double(animationUs) / 1_000_000
  }
}

/// How a bass hit or a blast looks beyond its intensity, from its params, as
/// the Dart effect settings catalog stores them. Mirrors the Android `HitLook`.
///
/// `centerX` and `centerY` are where it hits, in shares of the frame from its
/// top left; `reach` how far it spreads, 0.2 to 1; `shake`, `punch` and
/// `fringe` scale the rattle, the punch in and the colour fringes, 0 to 2;
/// `color` is the colour of a blast's glow, liquid or smoke, red, green and
/// blue from 0 to 1, read from an ARGB integer and `defaultColor` without
/// one.
struct HitLook {
  let centerX: Double
  let centerY: Double
  let reach: Double
  let shake: Double
  let punch: Double
  let fringe: Double
  let color: [Double]

  init(_ params: [String: Any], defaultColor: Int64) {
    func number(_ key: String, _ fallback: Double, _ low: Double, _ high: Double) -> Double {
      min(high, max(low, (params[key] as? NSNumber)?.doubleValue ?? fallback))
    }
    centerX = number("centerX", 0.5, 0, 1)
    centerY = number("centerY", 0.5, 0, 1)
    reach = number("reach", 1, 0.2, 1)
    shake = number("shake", 1, 0, 2)
    punch = number("punch", 1, 0, 2)
    fringe = number("fringe", 1, 0, 2)
    let argb = (params["color"] as? NSNumber)?.int64Value ?? defaultColor
    color = [16, 8, 0].map { Double((argb >> Int64($0)) & 0xFF) / 255 }
  }
}
