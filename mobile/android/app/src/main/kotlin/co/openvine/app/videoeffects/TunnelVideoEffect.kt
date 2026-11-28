package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects
import kotlin.math.ln
import kotlin.math.min
import kotlin.math.roundToLong

/**
 * Tunnel: the picture holds a smaller copy of itself in its middle, which
 * holds another, and so on, and the picture zooms into them without end.
 *
 * The copy is 15% to 55% of the frame as the intensity rises. Each step zooms
 * one copy up to the size of the one around it. The plain tunnel nests whole
 * frames, each with a thin shadow along its edge; the spiral tunnel nests
 * rings within half the shorter side and twists them, so one turn around the
 * middle leads one copy deeper.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
 * large the copy is), `speed` (0.25–3: how fast it zooms, as a share of the
 * natural pace, when nothing else times it), `direction` (-1 to zoom out of the
 * copies instead of into them), `periodUs` (how long a step takes; the Dart
 * side fits a whole number of steps into the effect's window, so a video that
 * loops zooms on seamlessly) and, for an effect on the beat, `beatsUs`: the
 * beats, in microseconds after the effect's start, each taking one step; see
 * TUNNEL_STEPS.
 */
class TunnelVideoEffect(
    private val spiral: Boolean,
    params: Map<String, Any?>,
) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val periodUs =
        (params["periodUs"] as? Number)?.toLong()?.takeIf { it > 0 }
            ?: (TunnelSteps.naturalPeriodUs(intensity) /
                numberOf(params, "speed", 1f, 0.25f, 3f)).roundToLong()

    private val beatsUs = BlurHits.beatsOf(params)

    private val direction = directionOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        // Zooming out runs the phase backwards; the shader wraps it into a turn.
        shader.setFloat(
            "uPhase",
            direction * TunnelSteps.phase(periodUs, beatsUs, effectTimeUs),
        )
        shader.setFloat("uSpiral", if (spiral) 1f else 0f)
    }

    companion object {
        /** The ids the Dart `CustomVideoEffect` names. */
        const val ID = "divine.tunnel"
        const val SPIRAL_ID = "divine.spiralTunnel"

        /** Registers both tunnels for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> TunnelVideoEffect(false, params) }
            VideoFrameEffects.register(ID) { params -> TunnelVideoEffect(false, params) }
            CustomVideoEffects.register(SPIRAL_ID) { params -> TunnelVideoEffect(true, params) }
            VideoFrameEffects.register(SPIRAL_ID) { params -> TunnelVideoEffect(true, params) }
        }

        // `level` is how many times e the picture grows from one copy to the
        // next, `f` how far a pixel lies into its copy (0 at its edge, 1 at the
        // next copy's edge), and `edge` how many pixels the point it reads lies
        // inside its copy's edge. `s` is the frame's shorter side.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uPhase;
uniform float uSpiral;

void main() {
  vec2 p = vTexCoord * uSize;
  if (uIntensity <= 0.0) {
    gl_FragColor = vec4(tap(p), 1.0);
    return;
  }
  vec2 c = uSize * 0.5;
  vec2 d = p - c;
  float s = min(uSize.x, uSize.y);
  float level = -log(0.15 + 0.4 * uIntensity);
  vec2 q;
  float edge;
  if (uSpiral > 0.5) {
    float big = 0.5 * s;
    float lr = log(max(length(d), 0.001) / big);
    float a = atan(d.y, d.x);
    float twist = level / 6.2832;
    float f = fract(-(lr + a * twist) / level + uPhase);
    float r = big * exp(-level * f);
    float b = a - lr * twist;
    q = c + r * vec2(cos(b), sin(b));
    edge = big - r;
  } else {
    float m = max(max(abs(d.x) / c.x, abs(d.y) / c.y), 0.0001);
    float f = fract(-log(m) / level + uPhase);
    q = c + d * (exp(-level * f) / m);
    vec2 e = c - abs(q - c);
    edge = min(e.x, e.y);
  }
  float shade = 1.0 - 0.35 * (1.0 - smoothstep(0.0, 0.012 * s, edge));
  gl_FragColor = vec4(tap(q) * shade, 1.0);
}
"""
    }
}

/**
 * How far the tunnel has zoomed into its current copy at a moment, from 0 to
 * 1. Mirrors the Swift `TunnelSteps` and the Dart `tunnelStepDuration`.
 *
 * All the time it zooms on steadily, one step per period. On the beat each
 * beat zooms one step, easing out over [STEP_US] or until the next beat,
 * whichever comes first; before the first beat it holds still.
 */
object TunnelSteps {
    /** The longest one step on the beat takes. */
    const val STEP_US = 350_000L

    /** How long the picture takes to double in size, whatever the copy's size. */
    private const val DOUBLING_US = 1_200_000.0

    /** How long a step takes at [intensity] in a window it need not fit. */
    fun naturalPeriodUs(intensity: Float): Long =
        (-ln(0.15 + 0.4 * intensity) / ln(2.0) * DOUBLING_US).roundToLong()

    /** The phase [effectTimeUs] after the effect started. */
    fun phase(periodUs: Long, beatsUs: LongArray?, effectTimeUs: Long): Float {
        if (beatsUs == null) {
            return (Math.floorMod(effectTimeUs, periodUs).toDouble() / periodUs).toFloat()
        }
        val index = beatsUs.indexOfLast { it <= effectTimeUs }
        if (index < 0) return 0f
        val beat = beatsUs[index]
        val next = beatsUs.getOrNull(index + 1)
        val span = maxOf(1L, if (next == null) STEP_US else min(STEP_US, next - beat))
        val x = min(1.0, (effectTimeUs - beat).toDouble() / span)
        if (x >= 1.0) return 0f
        val rest = 1.0 - x
        return (1.0 - rest * rest * rest).toFloat()
    }
}
