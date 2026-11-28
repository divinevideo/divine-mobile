package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Disco: coloured spots from a mirror ball sweep over the picture, which is
 * slightly dimmed around them.
 *
 * The ball hangs above the middle of the top edge. Its spots lie on rings
 * around it, each ring a share of the frame's longer side further out than
 * the one before, at even steps along each ring and half a step apart from
 * ring to ring. All of them turn around the ball together, so they sweep
 * sideways across the picture. Each spot has a flat top and a soft edge,
 * `exp(-r⁴)` of the distance from its centre in shares of its size, and one
 * of three colours that change together, blended over a moment; see
 * [PartyLights].
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how dim
 * the picture gets and how bright the spots are), `size` (0.5–2: how large the
 * spots are, as a share of the default), `speed` (0–3: how fast the ball turns,
 * as a share of the default; 0 holds it still) and, for an effect on the beat,
 * `beatsUs`: the beats, in microseconds after the effect's start. On the beat
 * the colours change and the ball turns the other way on each beat; otherwise
 * the colours change every one and a half seconds and it keeps turning one way.
 */
class DiscoVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val beatsUs = BlurHits.beatsOf(params)

    private val spotSize = numberOf(params, "size", 1f, 0.5f, 2f)

    private val speed = numberOf(params, "speed", 1f, 0f, 3f)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        val lights = PartyLights.at(beatsUs, effectTimeUs)
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uPhase", lights.phase * speed)
        shader.setFloat("uStep", lights.step)
        shader.setFloat("uMix", lights.mix)
        shader.setFloat("uSpotSize", spotSize)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.disco"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> DiscoVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> DiscoVideoEffect(params) }
        }

        // `l` is the frame's longer side. `turn` is the angle around the ball
        // from straight down, turned with the ball, and `cell` the angle from
        // one spot to the next on the pixel's ring.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + PartyLights.COLOR + """
uniform float uIntensity;
uniform float uPhase;
uniform float uStep;
uniform float uMix;
uniform float uSpotSize;

void main() {
  vec2 p = vTexCoord * uSize;
  float l = max(uSize.x, uSize.y);
  vec2 ball = vec2(0.5 * uSize.x, uSize.y + 0.35 * l);
  vec2 d = p - ball;
  float spacing = 0.085 * l;
  float ring = floor(length(d) / spacing);
  float odd = ring - 2.0 * floor(ring / 2.0);
  float cell = 1.1 / (ring + 0.5);
  float spin = 0.25 * uPhase;
  float turn = atan(d.x, -d.y) + spin;
  float index = floor(turn / cell + 0.5 * odd);
  float centreTurn = (index + 0.5 - 0.5 * odd) * cell - spin;
  vec2 centre = ball + (ring + 0.5) * spacing * vec2(sin(centreTurn), -cos(centreTurn));
  float size = 0.018 * l * uSpotSize * (0.75 + 0.5 * fract(index * 0.618034 + ring * 0.371));
  vec2 q = (p - centre) / size;
  float r2 = dot(q, q);
  float spot = exp(-r2 * r2 * r2);
  float group = index + ring - 3.0 * floor((index + ring) / 3.0);
  vec3 color = mix(partyColor(uStep - 1.0, group), partyColor(uStep, group), uMix);
  vec3 base = tap(p);
  vec3 lit = base * (1.0 - 0.4 * uIntensity) + uIntensity * spot * color * (0.25 + 0.75 * base);
  gl_FragColor = vec4(clamp(lit, 0.0, 1.0), 1.0);
}
"""
    }
}

/**
 * Where the disco and laser lights stand at a moment: which colours they show,
 * how far they have blended into them, and how far they have moved. Mirrors
 * the Swift `PartyLights`.
 *
 * All the time the colours change every [STEP_US] and the lights move on one
 * way at one unit a second. On the beat each beat changes the colours and
 * turns the movement round, so the lights swing back and forth with the music;
 * before the first beat they move on with the first colours. A change blends
 * over [FADE_US], or until the next beat, whichever comes first, eased in and
 * out, so the colours never jump.
 */
object PartyLights {
    /** How long the colours stay when the lights play all through. */
    const val STEP_US = 1_500_000L

    /** How long a change of colour blends over. */
    const val FADE_US = 200_000L

    /**
     * The lights at a moment: the colours of [step], blended [mix] (0–1) of the
     * way from those of the step before, moved [phase] units.
     */
    data class State(val step: Float, val mix: Float, val phase: Float)

    /**
     * The party colours: three groups of lights, a third of the hue circle
     * apart, turning round the hue circle by the golden angle each step, and
     * a fifth white so they light the picture rather than tint it.
     */
    const val COLOR = """
vec3 partyColor(float stage, float group) {
  vec3 hue = fract(0.08 + stage * 0.381966 + group / 3.0 + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0));
  return mix(vec3(1.0), clamp(abs(hue * 6.0 - 3.0) - 1.0, 0.0, 1.0), 0.8);
}
"""

    /** The lights [effectTimeUs] after the effect started, on [beatsUs] or all through. */
    fun at(beatsUs: LongArray?, effectTimeUs: Long): State {
        val time = maxOf(0L, effectTimeUs)
        if (beatsUs == null) {
            val step = time / STEP_US
            val mix = if (step == 0L) 1f else ease((time - step * STEP_US).toFloat() / FADE_US)
            return State(step.toFloat(), mix, (time / 1e6).toFloat())
        }
        val index = beatsUs.indexOfLast { it <= time }
        if (index < 0) return State(0f, 1f, (time / 1e6).toFloat())
        var phaseUs = beatsUs[0]
        var direction = -1L
        for (k in 0 until index) {
            phaseUs += direction * (beatsUs[k + 1] - beatsUs[k])
            direction = -direction
        }
        val beat = beatsUs[index]
        phaseUs += direction * (time - beat)
        val next = beatsUs.getOrNull(index + 1)
        val fade = if (next == null) FADE_US else maxOf(1L, minOf(FADE_US, next - beat))
        return State((index + 1).toFloat(), ease((time - beat).toFloat() / fade), (phaseUs / 1e6).toFloat())
    }

    private fun ease(x: Float): Float {
        val c = x.coerceIn(0f, 1f)
        return c * c * (3f - 2f * c)
    }
}
