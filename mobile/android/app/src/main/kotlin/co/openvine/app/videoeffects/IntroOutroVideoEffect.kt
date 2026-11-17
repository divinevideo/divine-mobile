package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * An intro or an outro in one of its [Style]s: an intro reveals the picture
 * over the effect's window, an outro covers it, always all the way. The fade
 * goes to a colour from black to white, the circle closes on the middle with
 * a hard to soft edge, black bars close over one to eight bands, red stage
 * curtains with three to twelve folds draw in from the sides, and the focus
 * blurs the picture slightly to heavily.
 *
 * Each style has an intro and an outro id. The shader knows how far the
 * picture is covered, `uAmount`, and how far a moving curtain's bottom trails
 * behind its top, `uSwing`, which [IntroOutroProgress] works out from the time
 * since the effect started, and the structure of the look, `uShape`.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: the
 * structure of the look, which the editor's slider sets) and `durationUs`
 * (how long the window lasts, so the intro is open and the outro closed
 * right where it ends).
 */
class IntroOutroVideoEffect(
    private val style: Style,
    private val ending: Boolean,
    params: Map<String, Any?>,
) : ShaderVideoEffect(FRAGMENT_SHADER) {

    /** The looks; [shaderValue] is what the shader branches on. */
    enum class Style(val introId: String, val outroId: String, val shaderValue: Float) {
        FADE("divine.introFade", "divine.outroFade", 0f),
        CIRCLE("divine.introCircle", "divine.outroCircle", 1f),
        CINEMA("divine.introCinema", "divine.outroCinema", 2f),
        CURTAIN("divine.introCurtain", "divine.outroCurtain", 3f),
        FOCUS("divine.introFocus", "divine.outroFocus", 4f),
    }

    private val shape = intensityOf(params)

    private val durationUs =
        (params["durationUs"] as? Number)?.toLong()?.takeIf { it > 0 }
            ?: IntroOutroProgress.DEFAULT_DURATION_US

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uAmount", IntroOutroProgress.amount(ending, durationUs, effectTimeUs))
        shader.setFloat("uShape", shape)
        shader.setFloat("uStyle", style.shaderValue)
        shader.setFloat("uSwing", IntroOutroProgress.swing(ending, durationUs, effectTimeUs))
    }

    companion object {
        /** Registers the intro and the outro of every style for exports and for the editor preview. */
        fun register() {
            for (style in Style.values()) {
                for ((id, ending) in listOf(style.introId to false, style.outroId to true)) {
                    CustomVideoEffects.register(id) { params -> IntroOutroVideoEffect(style, ending, params) }
                    VideoFrameEffects.register(id) { params -> IntroOutroVideoEffect(style, ending, params) }
                }
            }
        }

        // `s` is the frame's shorter side. A curtain hangs from a rail at the
        // top, and its bottom trails behind while it moves, by `uSwing`, so
        // `reach`, how far it covers its half of the frame, is worked out per
        // row. Its cloth is as wide as its half: the cloth by its edge hangs in
        // folds of their natural `width`, and what is left over is pushed
        // together towards the side, `squeeze` times tighter and darker there.
        // `inset` is how far a pixel lies inside the curtain from its edge,
        // `fold` how many folds of cloth lie between them, fanning out a little
        // towards the bottom and spaced unevenly. Each fold is lit from the
        // middle of the stage, with a velvet sheen and fine nap on the side
        // facing it, and the tops lie in the shadow of the stage opening. The
        // blur's taps lie on a golden-angle spiral, each turned from the one
        // before by the golden angle, whose cosine and sine are the constants.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uAmount;
uniform float uShape;
uniform float uStyle;
uniform float uSwing;

void main() {
  vec2 p = vTexCoord * uSize;
  float k = uAmount;
  if (k <= 0.0) {
    gl_FragColor = vec4(tap(p), 1.0);
    return;
  }
  vec2 c = 0.5 * uSize;
  float s = min(uSize.x, uSize.y);
  vec3 color;
  if (uStyle < 0.5) {
    color = mix(tap(p), vec3(uShape), k);
  } else if (uStyle < 1.5) {
    float soft = 1.0 + 0.3 * s * uShape;
    float reach = length(c) + soft;
    float r = reach - (reach + soft) * k;
    color = tap(p) * smoothstep(-0.5 * soft, 0.5 * soft, r - length(p - c));
  } else if (uStyle < 2.5) {
    float band = uSize.y / (1.0 + floor(7.0 * uShape + 0.5));
    float y = p.y - band * floor(p.y / band);
    float bar = (0.5 * band + 1.0) * k;
    color = tap(p) * clamp(min(y, band - y) - bar + 0.5, 0.0, 1.0);
  } else if (uStyle < 3.5) {
    float yN = p.y / uSize.y;
    float full = c.x + 1.0;
    float reach = max(full * k - uSwing * 0.18 * c.x * (1.0 - yN) * (1.0 - yN), 0.0);
    float inset = reach - min(p.x, uSize.x - p.x);
    float cloth = clamp(inset + 0.5, 0.0, 1.0);
    float along = clamp(inset, 0.0, reach) / max(reach, 0.001);
    float excess = max(full - reach, 0.0);
    float squeeze = 1.0 + 3.0 * excess * along * along / max(reach, 0.001);
    float folds = 3.0 + 9.0 * uShape;
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
    vec3 velvet = (vec3(0.52, 0.03, 0.06) * diffuse + vec3(0.4, 0.09, 0.1) * sheen) * light;
    float shade = 1.0 - 0.55 * min(reach / (0.04 * s), 1.0) * exp(min(inset, 0.0) / (0.04 * s));
    color = mix(tap(p) * shade * (1.0 - 0.2 * k), velvet, cloth);
  } else {
    float radius = (0.01 + 0.05 * uShape) * s * k;
    vec3 sum = vec3(0.0);
    vec2 dir = vec2(1.0, 0.0);
    for (int i = 0; i < 48; i++) {
      float r = radius * sqrt((float(i) + 0.5) / 48.0);
      sum += tap(p + r * dir);
      dir = vec2(dir.x * -0.73736888 - dir.y * 0.67549029, dir.x * 0.67549029 + dir.y * -0.73736888);
    }
    color = sum / 48.0;
  }
  gl_FragColor = vec4(color, 1.0);
}
"""
    }
}

/**
 * How an intro or outro moves at a moment. Mirrors the Swift
 * `IntroOutroProgress` and the Dart `introOutroCoverage` and
 * `introOutroSwing`.
 */
object IntroOutroProgress {
    /** How long the window lasts when the params do not say: a new one's length. */
    const val DEFAULT_DURATION_US = 1_000_000L

    /**
     * How far the picture is covered [effectTimeUs] after the effect started:
     * from covered (1) to open (0) for an intro and the other way round for
     * an outro, easing in and out with no jolt at either end (smootherstep).
     */
    fun amount(ending: Boolean, durationUs: Long, effectTimeUs: Long): Float {
        val p = progress(durationUs, effectTimeUs)
        val eased = p * p * p * (p * (6 * p - 15) + 10)
        return (if (ending) eased else 1 - eased).toFloat()
    }

    /**
     * How far a moving curtain's bottom trails behind its top [effectTimeUs]
     * after the effect started, about -1 to 1: positive while an outro closes,
     * negative while an intro opens, 0 at both ends. It drags behind while the
     * curtain moves, and swings back as it speeds up and slows down.
     */
    fun swing(ending: Boolean, durationUs: Long, effectTimeUs: Long): Float {
        val p = progress(durationUs, effectTimeUs)
        val speed = 30 * p * p * (1 - p) * (1 - p) / 1.875
        val pull = 60 * p * (1 - p) * (1 - 2 * p) / 5.7735027
        val trail = 0.6 * speed + 0.4 * pull
        return (if (ending) trail else -trail).toFloat()
    }

    private fun progress(durationUs: Long, effectTimeUs: Long): Double =
        (effectTimeUs.toDouble() / durationUs).coerceIn(0.0, 1.0)
}
