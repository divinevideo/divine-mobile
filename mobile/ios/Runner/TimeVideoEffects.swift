import CoreImage
import Foundation
import divine_video_player
import pro_video_editor

/// The Time effects besides the echo trail: each builds the picture from
/// earlier source frames of the same clip as well as the current one, so it
/// only shows where something moves. Mirrors the Android `TimeVideoEffects`.
///
/// The earlier frames come as ``EchoVideoEffect``'s do: pro_video_editor hands
/// them to the export, and divine_video_player to the editor preview. They lie
/// whole frames back, ``frameOffsetUs(_:)``, so effects that ask for the same
/// moment share it, and the export decodes each moment once.
enum TimeVideoEffects {
  /// Registers every Time effect for exports and for the editor preview, and
  /// compiles the shaders of new effects ahead of their first frame.
  static func register() {
    register(TimeSplitVideoEffect.id) { TimeSplitVideoEffect(params: $0) }
    register(LongExposureVideoEffect.id) { LongExposureVideoEffect(params: $0) }
    register(MotionOnlyVideoEffect.id) { MotionOnlyVideoEffect(params: $0) }
    register(StutterVideoEffect.id) { StutterVideoEffect(params: $0) }
    register(TimeWarpVideoEffect.id) { TimeWarpVideoEffect(params: $0) }
    let intensity = ShaderVideoEffect.defaultIntensity
    let kernels: [(function: String, source: String)] = [
      (TimeSplitVideoEffect.function, TimeSplitVideoEffect.source),
      (MotionOnlyVideoEffect.function, MotionOnlyVideoEffect.source),
      LongExposureVideoEffect.kernel(copies: LongExposureVideoEffect.copies(intensity)),
      TimeWarpVideoEffect.kernel(copies: TimeWarpVideoEffect.copies(intensity)),
    ]
    for kernel in kernels {
      ShaderVideoEffectKernel.prepare(function: kernel.function, source: kernel.source)
    }
  }

  private static func register<T: CustomVideoEffectRenderer & VideoFrameEffect>(
    _ id: String, _ factory: @escaping ([String: Any]) -> T
  ) {
    CustomVideoEffects.register(id) { params in factory(params) }
    VideoFrameEffects.register(id) { params in factory(params) }
  }

  /// How far back the frame `frames` frames before the current one lies, at
  /// the 30 fps Divine records and exports at: rounded down to the
  /// microsecond, so a frame that starts a fraction of a microsecond later
  /// still counts. Mirrors the Android `TimeVideoEffects.frameOffsetUs`.
  static func frameOffsetUs(_ frames: Int) -> Int64 {
    Int64(frames) * 100_000 / 3
  }

  /// How long one frame lasts at 30 fps.
  static let frameUs = 1_000_000.0 / 30
}

/// Time split: red shows the current frame, green the frame 100 ms earlier
/// and blue the one 200 ms earlier, or as many times that as the delay set, so
/// still parts keep their colours and moving parts get rainbow ghosts. Mirrors
/// the Android `TimeSplitVideoEffect`.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
/// far the colours split, from the plain picture to the full split), `delay`
/// (0.34–3: how far back green and blue lag, as a share of the default; see
/// ``frames(_:)``) and, for an effect on the beat, `beatsUs`: the beats, in
/// microseconds after the effect's start. On the beat the colours only split on each hit and come
/// back together over half a second, as the zoom blur's streaks fade; see
/// ``BlurHits``.
///
/// The earlier frames are kept whole: green and blue carry every still part of
/// the picture too, and a smaller copy would blur them.
final class TimeSplitVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.timeSplit"

  private let intensity: Double
  private let beatsUs: [Int64]?
  private let offsets: [Int64]

  override var historyOffsetsUs: [Int64] { offsets }

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    beatsUs = BlurHits.beats(params)
    let (green, blue) = Self.frames(params)
    offsets = [TimeVideoEffects.frameOffsetUs(green), TimeVideoEffects.frameOffsetUs(blue)]
    super.init(function: Self.function, source: Self.source)
  }

  /// How many frames back green and blue lag: three and six times the
  /// `delay` in `params`, at least one and one more. Mirrors the Android
  /// `TimeSplitVideoEffect.framesOf`.
  static func frames(_ params: [String: Any]) -> (green: Int, blue: Int) {
    let delay = readNumber(params, "delay", fallback: 1, in: 0.34...3)
    let green = max(1, Int((3 * delay).rounded()))
    return (green, max(green + 1, Int((6 * delay).rounded())))
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    let strength = BlurHits.strength(
      intensity: intensity, beatsUs: beatsUs, effectTimeUs: effectTimeUs)
    return strength > 0 ? [strength] : nil
  }

  static let function = "divineTimeSplit"

  static let source = """
    kernel void divineTimeSplit(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      texture2d<float, access::sample> earlier0 [[texture(2)]],
      texture2d<float, access::sample> earlier1 [[texture(3)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float strength = u[3].x;
      float2 p = pixelOf(u, gid, target.get_height());
      float3 now = tap(frame, f, p);
      float3 split = float3(
          now.r, earlierAt(earlier0, f, p).g, earlierAt(earlier1, f, p).b);
      target.write(float4(mix(now, split, strength), 1.0), gid);
    }
    """
}

/// Long exposure: bright parts leave trails, so a torch or a sparkler can
/// paint light in a dark room. Mirrors the Android `LongExposureVideoEffect`.
///
/// Each pixel takes the brightest of itself and of up to six earlier frames,
/// two frames apart, each counted only as far as it is bright and fading the
/// further back it lies. A still part looks the same in every frame and stays
/// as it is.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1:
/// longer trails, fading slower, and of less bright parts), `length` (0.5–3:
/// how far apart the earlier frames lie, as a share of the default two frames,
/// so how far back the trails reach) and `sensitivity` (0–1: how bright a part
/// must be to leave a trail; 0.5 by default, higher leaves trails sooner). The
/// trails are soft anyway, so the earlier frames are kept at half size.
final class LongExposureVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.longExposure"

  private let intensity: Double
  private let sensitivity: Double
  private let offsets: [Int64]

  override var historyOffsetsUs: [Int64] { offsets }

  override var historyScale: Double { 0.5 }

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    sensitivity = Self.readNumber(params, "sensitivity", fallback: 0.5, in: 0...1)
    let copies = Self.copies(intensity)
    let length = Self.readNumber(params, "length", fallback: 1, in: 0.5...3)
    offsets = (0..<copies).map {
      TimeVideoEffects.frameOffsetUs(Self.framesBack($0, length: length))
    }
    let (function, source) = Self.kernel(copies: copies)
    super.init(function: function, source: source)
  }

  /// How many earlier frames an effect at `intensity` reads: 2 to 6.
  static func copies(_ intensity: Double) -> Int {
    min(6, max(2, Int((2 + 4 * intensity).rounded())))
  }

  /// How many frames back earlier frame `k` lies, newest first: two frames
  /// apart, times `length`, and at least one further back than the one
  /// before.
  static func framesBack(_ k: Int, length: Double) -> Int {
    max(k + 1, Int((Double(2 * (k + 1)) * length).rounded()))
  }

  /// A part starts to count from the first value, fully 0.25 above it; then
  /// how much of each earlier frame counts, newest first.
  override func values(effectTimeUs: Int64) -> [Double]? {
    [0.7 - 0.25 * intensity - 0.4 * (sensitivity - 0.5)]
      + offsets.indices.map { k in pow(0.7 + 0.25 * intensity, Double(k + 1)) }
  }

  /// The kernel for `copies` earlier frames, by name and source.
  static func kernel(copies: Int) -> (function: String, source: String) {
    let function = "divineLongExposure\(copies)"
    let textures = (0..<copies).map {
      "  texture2d<float, access::sample> earlier\($0) [[texture(\($0 + 2))]],\n"
    }.joined()
    let trails = (0..<copies).map {
      "  color = max(color, trail(earlierAt(earlier\($0), f, p), threshold, v[\($0 + 1)]));\n"
    }.joined()
    let source = """
      static float3 trail(float3 c, float threshold, float weight) {
        float bright = smoothstep(threshold, threshold + 0.25, dot(c, float3(0.299, 0.587, 0.114)));
        return c * (bright * weight);
      }

      kernel void \(function)(
        texture2d<float, access::sample> frame [[texture(0)]],
        texture2d<float, access::write> target [[texture(1)]],
      \(textures)  constant float4 *u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
      ) {
        if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
        Frame f = frameOf(u);
        constant float *v = (constant float *)(u + 3);
        float threshold = v[0];
        float2 p = pixelOf(u, gid, target.get_height());
        float3 color = tap(frame, f, p);
      \(trails)  target.write(float4(color, 1.0), gid);
      }
      """
    return (function, source)
  }
}

/// Motion only: still parts go dark and moving parts glow, from the
/// difference to the frame before. Where a part moves, its edges differ the
/// most, so they light up as outlines. Mirrors the Android
/// `MotionOnlyVideoEffect`.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
/// dark the still parts go, down to black, and how much the moving parts glow)
/// and `sensitivity` (0–1: how small a change counts as movement; 0.5 by
/// default, higher counts smaller ones). The frame before is kept whole, so
/// fine still detail does not count as movement.
final class MotionOnlyVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.motionOnly"

  private let intensity: Double
  private let spread: Double

  override var historyOffsetsUs: [Int64] { [TimeVideoEffects.frameOffsetUs(1)] }

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    spread = Self.spread(Self.readNumber(params, "sensitivity", fallback: 0.5, in: 0...1))
    super.init(function: Self.function, source: Self.source)
  }

  /// How far the change that counts as movement is scaled at `sensitivity`:
  /// 1 at the default 0.5, smaller as it rises. Mirrors the Android
  /// `MotionOnlyVideoEffect.spreadOf`.
  static func spread(_ sensitivity: Double) -> Double {
    max(0.2, 2 - 2 * sensitivity)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 ? [intensity, spread] : nil
  }

  static let function = "divineMotionOnly"

  // A difference below 0.05 is the sensor's noise, not movement.
  static let source = """
    kernel void divineMotionOnly(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      texture2d<float, access::sample> earlier0 [[texture(2)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float intensity = u[3].x;
      float spread = u[3].y;
      float2 p = pixelOf(u, gid, target.get_height());
      float3 now = tap(frame, f, p);
      float3 before = earlierAt(earlier0, f, p);
      float moved = smoothstep(0.05 * spread, 0.15 * spread, length(now - before));
      float3 glow = min(now * (1.0 + 0.5 * intensity) + 0.1 * intensity, float3(1.0));
      target.write(float4(mix(now * (1.0 - intensity), glow, moved), 1.0), gid);
    }
    """
}

/// Stutter: the picture holds frames, so it plays at 6 to 12 frames a second
/// instead of the clip's 30. Mirrors the Android `StutterVideoEffect`.
///
/// Each held frame is the first of its hold, at most four frames back, so the
/// effect shows one of the earlier frames whole; see ``StutterHolds``. A frame
/// the clip has not played far enough back for yet is shown as it is.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: from
/// 12 frames a second down to 6) and, for an effect on the beat, `beatsUs`:
/// the beats, in microseconds after the effect's start. On the beat it only
/// stutters for half a second after each beat, its holds starting on the beat.
final class StutterVideoEffect: CustomVideoEffectRenderer, VideoFrameEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.stutter"

  private let intensity: Double
  private let beatsUs: [Int64]?

  let historyOffsetsUs: [Int64] = (1...StutterHolds.maxBack).map {
    TimeVideoEffects.frameOffsetUs($0)
  }

  // The held frame is the picture, so it is kept whole.
  let historyScale = 1.0

  init(params: [String: Any]) {
    intensity = ShaderVideoEffect.readIntensity(params)
    beatsUs = BlurHits.beats(params)
  }

  func render(_ frame: CustomVideoEffectFrame) -> CIImage {
    held(frame.image, frame.history, effectTimeUs: frame.effectTimeUs)
  }

  func render(_ image: CIImage, history: [CIImage?], timeUs: Int64, effectTimeUs: Int64)
    -> CIImage
  {
    held(image, history, effectTimeUs: effectTimeUs)
  }

  private func held(_ image: CIImage, _ history: [CIImage?], effectTimeUs: Int64) -> CIImage {
    let back = StutterHolds.framesBack(
      intensity: intensity, beatsUs: beatsUs, effectTimeUs: effectTimeUs)
    guard back > 0, back <= history.count, let earlier = history[back - 1] else { return image }
    return earlier
  }
}

/// Which earlier frame the stutter shows at a moment. Mirrors the Android
/// `StutterHolds`.
///
/// The picture holds a frame for a period of `1 / (12 - 6 × intensity)`
/// seconds, from the start of the effect's window or, on the beat, from each
/// beat for ``BlurHits/hitUs``. Within a hold it shows the hold's first frame,
/// as many frames back as have gone by since, rounded down with a millisecond
/// to spare.
enum StutterHolds {
  /// The furthest back a hold reaches: at 6 frames a second, five frames are
  /// held.
  static let maxBack = 4

  /// How many frames back the frame shown `effectTimeUs` after the effect
  /// started lies: 0 for the current frame, up to ``maxBack``.
  static func framesBack(intensity: Double, beatsUs: [Int64]?, effectTimeUs: Int64) -> Int {
    let sinceUs: Int64
    if let beatsUs {
      guard let last = beatsUs.last(where: { $0 <= effectTimeUs }),
        effectTimeUs - last < BlurHits.hitUs
      else { return 0 }
      sinceUs = effectTimeUs - last
    } else {
      sinceUs = effectTimeUs
    }
    let periodUs = 1_000_000.0 / (12.0 - 6.0 * intensity)
    // Frame times are rounded down to the microsecond, so a frame can start a
    // hair before the hold it opens.
    let since = Double(sinceUs) + 1_000
    let intoHoldUs = since - (since / periodUs).rounded(.down) * periodUs
    let back = Int((intoHoldUs / TimeVideoEffects.frameUs).rounded(.down))
    return min(maxBack, max(0, back))
  }
}

/// Time warp: each band of the picture comes from a different moment, the
/// top from now and each band below it from two frames further back, or the
/// same from whichever edge the user picks, so moving people bend and
/// stretch, as in a slit-scan photograph. Mirrors the Android
/// `TimeWarpVideoEffect`.
///
/// Neighbouring bands blend over the middle 30% of the way from one band's
/// middle to the next, so a moving edge steps rather than tears. Up to seven
/// earlier frames are read, as many as the intensity reaches down to, as on
/// Android, where the current frame and seven earlier ones take the eight
/// texture units OpenGL ES 2.0 guarantees.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
/// far back the far edge of the picture reaches, up to 7 bands of two frames
/// each, 467 ms) and `direction` (which way across the picture leads further
/// back: 0 down, 1 up, 2 right, 3 left; see ``axis(_:)``). The earlier frames
/// are kept at half size, as on Android.
final class TimeWarpVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.timeWarp"

  private static let maxBandsBack = 7

  private let depth: Double
  private let offsets: [Int64]
  private let axis: [Double]

  override var historyOffsetsUs: [Int64] { offsets }

  override var historyScale: Double { 0.5 }

  init(params: [String: Any]) {
    let intensity = Self.readIntensity(params)
    depth = Double(Self.maxBandsBack) * intensity
    axis = Self.axis((params["direction"] as? NSNumber)?.intValue ?? 0)
    let copies = Self.copies(intensity)
    offsets = (1...copies).map { TimeVideoEffects.frameOffsetUs(2 * $0) }
    let (function, source) = Self.kernel(copies: copies)
    super.init(function: function, source: source)
  }

  /// How many earlier frames an effect at `intensity` reads: 1 to 7.
  static func copies(_ intensity: Double) -> Int {
    min(maxBandsBack, max(1, Int((Double(maxBandsBack) * intensity).rounded(.up))))
  }

  /// How far a point lies towards the past edge, from 0 at the present edge
  /// to 1, as `dot(uv, axis.xy) + axis.z` for a point uv in shares of the
  /// frame with y up: for `direction` 0 the top is now and the bottom furthest
  /// back, 1 the other way round, 2 the left now and the right furthest back,
  /// 3 the other way round. Mirrors the Android `TimeWarpVideoEffect.axisOf`.
  static func axis(_ direction: Int) -> [Double] {
    switch direction {
    case 1: return [0, 1, 0]
    case 2: return [1, 0, 0]
    case 3: return [-1, 0, 1]
    default: return [0, -1, 1]
    }
  }

  /// How many bands back the far edge of the picture lies, then which edge
  /// that is (see ``axis(_:)``).
  override func values(effectTimeUs: Int64) -> [Double]? {
    [depth] + axis
  }

  /// The kernel for `copies` earlier frames, by name and source.
  static func kernel(copies: Int) -> (function: String, source: String) {
    let function = "divineTimeWarp\(copies)"
    let textures = (0..<copies).map {
      "  texture2d<float, access::sample> earlier\($0) [[texture(\($0 + 2))]],\n"
    }.joined()
    let bands = (0..<copies).map {
      "  color += earlierAt(earlier\($0), f, p) * band(t, \($0 + 1).0);\n"
    }.joined()
    let source = """
      // How much of band k a pixel t bands down shows: all of it near the band's
      // middle, none from a whole band away, and in between the weights of two
      // neighbouring bands add up to 1.
      static float band(float t, float k) {
        return 1.0 - smoothstep(0.35, 0.65, abs(t - k));
      }

      kernel void \(function)(
        texture2d<float, access::sample> frame [[texture(0)]],
        texture2d<float, access::write> target [[texture(1)]],
      \(textures)  constant float4 *u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
      ) {
        if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
        Frame f = frameOf(u);
        float depth = u[3].x;
        float3 axis = u[3].yzw;
        float2 p = pixelOf(u, gid, target.get_height());
        float t = (dot(p / f.size, axis.xy) + axis.z) * depth;
        float3 color = tap(frame, f, p) * band(t, 0.0);
      \(bands)  target.write(float4(color, 1.0), gid);
      }
      """
    return (function, source)
  }
}
