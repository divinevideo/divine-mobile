import Foundation
import divine_video_player
import pro_video_editor

/// An intro or an outro in one of its ``Style``s: an intro reveals the
/// picture over the effect's window, an outro covers it, always all the way.
/// The fade goes to a colour from black to white, the circle closes on the
/// middle with a hard to soft edge, black bars close over one to eight bands,
/// red stage curtains with three to twelve folds draw in from the sides, and
/// the focus blurs the picture slightly to heavily.
///
/// Each style has an intro and an outro id. The kernel knows how far the
/// picture is covered and how far a moving curtain's bottom trails behind its
/// top, which ``IntroOutroProgress`` works out from the time since the effect
/// started, and the structure of the look.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: the
/// structure of the look, which the editor's slider sets) and `durationUs`
/// (how long the window lasts, so the intro is open and the outro closed
/// right where it ends).
final class IntroOutroVideoEffect: ShaderVideoEffect {
  /// The looks; the raw value is what the kernel branches on.
  enum Style: Double, CaseIterable {
    case fade = 0
    case circle = 1
    case cinema = 2
    case curtain = 3
    case focus = 4

    /// The id the Dart `CustomVideoEffect` names for the intro.
    var introId: String {
      switch self {
      case .fade: return "divine.introFade"
      case .circle: return "divine.introCircle"
      case .cinema: return "divine.introCinema"
      case .curtain: return "divine.introCurtain"
      case .focus: return "divine.introFocus"
      }
    }

    /// The id the Dart `CustomVideoEffect` names for the outro.
    var outroId: String {
      switch self {
      case .fade: return "divine.outroFade"
      case .circle: return "divine.outroCircle"
      case .cinema: return "divine.outroCinema"
      case .curtain: return "divine.outroCurtain"
      case .focus: return "divine.outroFocus"
      }
    }
  }

  private let style: Style
  private let ending: Bool
  private let shape: Double
  private let durationUs: Int64

  init(style: Style, ending: Bool, params: [String: Any]) {
    self.style = style
    self.ending = ending
    shape = Self.readIntensity(params)
    let duration = (params["durationUs"] as? NSNumber)?.int64Value ?? 0
    durationUs = duration > 0 ? duration : IntroOutroProgress.defaultDurationUs
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the intro and the outro of every style for exports and for the
  /// editor preview, and compiles the shader ahead of the first frame.
  static func register() {
    for style in Style.allCases {
      for (id, ending) in [(style.introId, false), (style.outroId, true)] {
        CustomVideoEffects.register(id) { params in
          IntroOutroVideoEffect(style: style, ending: ending, params: params)
        }
        VideoFrameEffects.register(id) { params in
          IntroOutroVideoEffect(style: style, ending: ending, params: params)
        }
      }
    }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  override func values(effectTimeUs: Int64) -> [Double]? {
    let amount = IntroOutroProgress.amount(
      ending: ending, durationUs: durationUs, effectTimeUs: effectTimeUs)
    guard amount > 0 else { return nil }
    let swing = IntroOutroProgress.swing(
      ending: ending, durationUs: durationUs, effectTimeUs: effectTimeUs)
    return [amount, shape, style.rawValue, swing]
  }

  static let function = "divineIntroOutro"

  /// `s` is the frame's shorter side. A curtain hangs from a rail at the top,
  /// and its bottom trails behind while it moves, by `swing`, so `reach`, how
  /// far it covers its half of the frame, is worked out per row. Its cloth is
  /// as wide as its half: the cloth by its edge hangs in folds of their
  /// natural `width`, and what is left over is pushed together towards the
  /// side, `squeeze` times tighter and darker there. `inset` is how far a
  /// pixel lies inside the curtain from its edge, `fold` how many folds of
  /// cloth lie between them, fanning out a little towards the bottom and
  /// spaced unevenly. Each fold is lit from the middle of the stage, with a
  /// velvet sheen and fine nap on the side facing it, and the tops lie in the
  /// shadow of the stage opening. The blur's taps lie on a golden-angle
  /// spiral, each turned from the one before by the golden angle, whose cosine
  /// and sine are the constants.
  static let source = """
    kernel void divineIntroOutro(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float k = u[3].x;
      float shape = u[3].y;
      float style = u[3].z;
      float swing = u[3].w;
      float2 p = pixelOf(u, gid, target.get_height());
      if (k <= 0.0) {
        target.write(float4(tap(frame, f, p), 1.0), gid);
        return;
      }
      float2 c = 0.5 * f.size;
      float s = min(f.size.x, f.size.y);
      float3 color;
      if (style < 0.5) {
        color = mix(tap(frame, f, p), float3(shape), k);
      } else if (style < 1.5) {
        float soft = 1.0 + 0.3 * s * shape;
        float reach = length(c) + soft;
        float r = reach - (reach + soft) * k;
        color = tap(frame, f, p) * smoothstep(-0.5 * soft, 0.5 * soft, r - length(p - c));
      } else if (style < 2.5) {
        float band = f.size.y / (1.0 + floor(7.0 * shape + 0.5));
        float y = p.y - band * floor(p.y / band);
        float bar = (0.5 * band + 1.0) * k;
        color = tap(frame, f, p) * clamp(min(y, band - y) - bar + 0.5, 0.0, 1.0);
      } else if (style < 3.5) {
        float yN = p.y / f.size.y;
        float full = c.x + 1.0;
        float reach = max(full * k - swing * 0.18 * c.x * (1.0 - yN) * (1.0 - yN), 0.0);
        float inset = reach - min(p.x, f.size.x - p.x);
        float cloth = clamp(inset + 0.5, 0.0, 1.0);
        float along = clamp(inset, 0.0, reach) / max(reach, 0.001);
        float excess = max(full - reach, 0.0);
        float squeeze = 1.0 + 3.0 * excess * along * along / max(reach, 0.001);
        float folds = 3.0 + 9.0 * shape;
        float width = full / folds;
        float fold = (clamp(inset, 0.0, reach) + excess * along * along * along) / width * (0.92 + 0.08 * yN);
        fold += 0.12 * sin(2.3 * fold + 0.4);
        float a = 6.2831853 * fract(fold);
        float relief = clamp(width / squeeze / (0.012 * s) - 0.5, 0.0, 1.0) * (0.7 + 0.3 * sin(1.7 * fold + 0.6));
        float ridge = 0.5 + 0.5 * relief * (sin(a) + 0.3 * sin(2.0 * a + 1.3)) / 1.3;
        float facing = relief * (cos(a) + 0.6 * cos(2.0 * a + 1.3)) / 1.6;
        float nap = 1.0 + 0.05 * relief * sin(43.982297 * fold + 1.0);
        float stack = 1.0 - 0.35 * clamp((squeeze - 1.0) / 6.0, 0.0, 1.0);
        float diffuse = (0.12 + 0.6 * ridge + 0.4 * (0.5 + 0.5 * facing)) * nap * stack;
        float sheen = facing * facing * (0.5 + 0.5 * facing);
        float light = (0.62 + 0.48 * yN) * (1.0 - 0.45 * exp((yN - 1.0) / 0.06)) * (1.0 - 0.45 * exp(-max(inset, 0.0) / (0.006 * s)));
        float3 velvet = (float3(0.52, 0.03, 0.06) * diffuse + float3(0.4, 0.09, 0.1) * sheen) * light;
        float shade = 1.0 - 0.55 * min(reach / (0.04 * s), 1.0) * exp(min(inset, 0.0) / (0.04 * s));
        color = mix(tap(frame, f, p) * shade * (1.0 - 0.2 * k), velvet, cloth);
      } else {
        float radius = (0.01 + 0.05 * shape) * s * k;
        float3 sum = float3(0.0);
        float2 dir = float2(1.0, 0.0);
        for (int i = 0; i < 48; i++) {
          float r = radius * sqrt((float(i) + 0.5) / 48.0);
          sum += tap(frame, f, p + r * dir);
          dir = float2(dir.x * -0.73736888 - dir.y * 0.67549029, dir.x * 0.67549029 + dir.y * -0.73736888);
        }
        color = sum / 48.0;
      }
      target.write(float4(color, 1.0), gid);
    }
    """
}

/// How an intro or outro moves at a moment. Mirrors the Kotlin
/// `IntroOutroProgress` and the Dart `introOutroCoverage` and
/// `introOutroSwing`.
enum IntroOutroProgress {
  /// How long the window lasts when the params do not say: a new one's length.
  static let defaultDurationUs: Int64 = 1_000_000

  /// How far the picture is covered `effectTimeUs` after the effect started:
  /// from covered (1) to open (0) for an intro and the other way round for an
  /// outro, easing in and out with no jolt at either end (smootherstep).
  static func amount(ending: Bool, durationUs: Int64, effectTimeUs: Int64) -> Double {
    let p = progress(durationUs: durationUs, effectTimeUs: effectTimeUs)
    let eased: Double = p * p * p * (p * (6 * p - 15) + 10)
    return ending ? eased : 1 - eased
  }

  /// How far a moving curtain's bottom trails behind its top `effectTimeUs`
  /// after the effect started, 0 at both ends: for an outro it rises to about
  /// 0.8 while the curtain closes, then turns negative about three quarters
  /// of the way through and dips to about -0.2 as the cloth swings past; an
  /// intro is the mirror image. It trails most while the curtain speeds up
  /// and swings a little past as it stops.
  static func swing(ending: Bool, durationUs: Int64, effectTimeUs: Int64) -> Double {
    let p = progress(durationUs: durationUs, effectTimeUs: effectTimeUs)
    let speed: Double = 30 * p * p * (1 - p) * (1 - p) / 1.875
    let pull: Double = 60 * p * (1 - p) * (1 - 2 * p) / 5.7735027
    let trail: Double = 0.6 * speed + 0.4 * pull
    return ending ? trail : -trail
  }

  private static func progress(durationUs: Int64, effectTimeUs: Int64) -> Double {
    min(1, max(0, Double(effectTimeUs) / Double(durationUs)))
  }
}
