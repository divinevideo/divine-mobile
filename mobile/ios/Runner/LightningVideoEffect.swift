import Foundation
import divine_video_player
import pro_video_editor

/// Lightning: the picture flashes blue-white with a short bolt, then fades
/// back.
///
/// The bolt runs from just above the top edge down through eight zigzag
/// steps, with a thinner branch forking off its third corner on most strikes:
/// a thin bright core with a soft blue glow, dimming over the last two steps
/// of each, which shows for a moment and fades. The flash lights the picture up in a cool tint and fades out more
/// slowly; see ``LightningStrikes``. Each strike flashes once.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
/// bright the flash is), `strikesUs`, when it strikes, in microseconds after
/// the effect's start, and `bolts`, the shape of each strike's bolt (14 values
/// each, as the Dart `lightningBolt` describes). The Dart side times the
/// strikes, on the beat or at irregular intervals, within three flashes a
/// second together with the video's other flashes, so this draws them as they
/// come.
final class LightningVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.lightning"

  private let intensity: Double
  private let strikesUs: [Int64]
  private let bolts: [Double]

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    strikesUs = LightningStrikes.strikes(params)
    bolts = LightningStrikes.bolts(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in LightningVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in LightningVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    guard let index = LightningStrikes.index(strikesUs: strikesUs, effectTimeUs: effectTimeUs)
    else { return nil }
    let start = index * LightningStrikes.boltValues
    guard start + LightningStrikes.boltValues <= bolts.count else { return nil }
    let since = effectTimeUs - strikesUs[index]
    let flash = LightningStrikes.flash(intensity: intensity, sinceUs: since)
    let bolt = LightningStrikes.bolt(intensity: intensity, sinceUs: since)
    guard flash > 0 || bolt > 0 else { return nil }
    return [flash, bolt] + bolts[start..<(start + LightningStrikes.boltValues)]
  }

  static let function = "divineLightning"

  /// `l` is the frame's longer side. The bolt's corners are `c0` at the top
  /// to `c8` where it ends, each `rise` lower than the one before, and its
  /// branch forks off `c3` through `b1` to `b3`, level with `c6`.
  static let source = """
    static float segment(float2 p, float2 a, float2 b) {
      float2 pa = p - a;
      float2 ba = b - a;
      float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
      return length(pa - ba * h);
    }

    kernel void divineLightning(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float4 strike = u[3];
      float4 pathA = u[4];
      float4 pathB = u[5];
      float4 branch = u[6];
      float2 p = pixelOf(u, gid, target.get_height());
      float3 base = tap(frame, f, p);
      float flash = strike.x;
      float bolt = strike.y;
      if (flash <= 0.0 && bolt <= 0.0) {
        target.write(float4(base, 1.0), gid);
        return;
      }
      float l = max(f.size.x, f.size.y);
      float top = f.size.y + 0.02 * l;
      float rise = (top - strike.w * f.size.y) / 8.0;
      float2 c0 = float2(strike.z * f.size.x, top);
      float2 c1 = float2(pathA.x * f.size.x, top - rise);
      float2 c2 = float2(pathA.y * f.size.x, top - 2.0 * rise);
      float2 c3 = float2(pathA.z * f.size.x, top - 3.0 * rise);
      float2 c4 = float2(pathA.w * f.size.x, top - 4.0 * rise);
      float2 c5 = float2(pathB.x * f.size.x, top - 5.0 * rise);
      float2 c6 = float2(pathB.y * f.size.x, top - 6.0 * rise);
      float2 c7 = float2(pathB.z * f.size.x, top - 7.0 * rise);
      float2 c8 = float2(pathB.w * f.size.x, top - 8.0 * rise);
      float2 b1 = float2(branch.x * f.size.x, top - 4.0 * rise);
      float2 b2 = float2(branch.y * f.size.x, top - 5.0 * rise);
      float2 b3 = float2(branch.z * f.size.x, top - 6.0 * rise);
      float upper = min(min(segment(p, c0, c1), segment(p, c1, c2)), min(segment(p, c2, c3), segment(p, c3, c4)));
      float lower = min(min(segment(p, c4, c5), segment(p, c5, c6)), min(segment(p, c6, c7), segment(p, c7, c8)));
      float trunk = min(upper, lower);
      float side = min(min(segment(p, c3, b1), segment(p, b1, b2)), segment(p, b2, b3));
      float w = 0.003 * l;
      float trunkEnd = clamp((p.y - c8.y) / (2.0 * rise), 0.0, 1.0);
      float sideEnd = clamp((p.y - b3.y) / (2.0 * rise), 0.0, 1.0);
      float core = (0.3 + 0.7 * trunkEnd) * exp(-trunk * trunk / (w * w)) + 0.7 * branch.w * sideEnd * exp(-side * side / (0.36 * w * w));
      float glow = (0.3 + 0.7 * trunkEnd) * exp(-trunk / (0.035 * l)) + 0.5 * branch.w * sideEnd * exp(-side / (0.025 * l));
      float3 tint = float3(0.78, 0.86, 1.0);
      float3 lit = base * (1.0 + 0.9 * flash * tint) + 0.22 * flash * tint;
      lit += bolt * (min(core, 1.0) * float3(0.95, 0.97, 1.0) + 0.6 * glow * float3(0.55, 0.65, 1.0));
      target.write(float4(clamp(lit, 0.0, 1.0), 1.0), gid);
    }
    """
}

/// How bright lightning's flash and bolt are at a moment. Mirrors the Android
/// `LightningStrikes`.
///
/// Each strike flashes once: the flash starts at the intensity and fades out
/// over ``flashUs``, `e^(-t / 160 ms) · (1 - t / flashUs)`, and the bolt shows
/// fully for ``boltHoldUs``, then fades out over ``boltFadeUs``. A later
/// strike starts over. Before the first strike nothing shows.
enum LightningStrikes {
  /// How long a flash takes to fade out.
  static let flashUs: Int64 = 700_000

  /// How long the bolt shows fully, and then takes to fade out.
  static let boltHoldUs: Int64 = 60_000
  static let boltFadeUs: Int64 = 150_000

  /// How many values describe one bolt, as the Dart `lightningBoltValueCount`.
  static let boltValues = 14

  /// When the effect strikes, from `params`, in the order given.
  static func strikes(_ params: [String: Any]) -> [Int64] {
    (params["strikesUs"] as? [Any])?.compactMap { ($0 as? NSNumber)?.int64Value } ?? []
  }

  /// The shape of each strike's bolt, from `params`.
  static func bolts(_ params: [String: Any]) -> [Double] {
    (params["bolts"] as? [Any])?.compactMap { ($0 as? NSNumber)?.doubleValue } ?? []
  }

  /// The number of the last strike at or before `effectTimeUs`, or `nil`
  /// before the first.
  static func index(strikesUs: [Int64], effectTimeUs: Int64) -> Int? {
    strikesUs.lastIndex(where: { $0 <= effectTimeUs })
  }

  /// How bright the flash is `sinceUs` after a strike, from 0 to `intensity`.
  static func flash(intensity: Double, sinceUs: Int64) -> Double {
    guard sinceUs >= 0, sinceUs < flashUs else { return 0 }
    let fade = exp(-Double(sinceUs) / 160_000) * (1 - Double(sinceUs) / Double(flashUs))
    return intensity * fade
  }

  /// How bright the bolt is `sinceUs` after a strike, from 0 to 1.
  static func bolt(intensity: Double, sinceUs: Int64) -> Double {
    guard intensity > 0, sinceUs >= 0 else { return 0 }
    let shown =
      sinceUs < boltHoldUs ? 1 : 1 - Double(sinceUs - boltHoldUs) / Double(boltFadeUs)
    return (0.35 + 0.65 * intensity) * max(0, shown)
  }
}
