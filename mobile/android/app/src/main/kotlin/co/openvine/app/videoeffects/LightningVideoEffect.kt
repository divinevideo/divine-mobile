package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Lightning: the picture flashes blue-white with a short bolt, then fades
 * back.
 *
 * The bolt runs from just above the top edge down through eight zigzag
 * steps, with a thinner branch forking off its third corner on most strikes:
 * a thin bright core with a soft blue glow, dimming over the last two steps
 * of each, which shows for a moment and fades. The flash lights the picture up in a cool tint and fades out more
 * slowly; see [LightningStrikes]. Each strike flashes once.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
 * bright the flash is), `strikesUs`, when it strikes, in microseconds after
 * the effect's start, and `bolts`, the shape of each strike's bolt (14 values
 * each, as the Dart `lightningBolt` describes). The Dart side times the
 * strikes, on the beat or at irregular intervals, within three flashes a
 * second together with the video's other flashes, so this draws them as they
 * come.
 */
class LightningVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val strikesUs = LightningStrikes.strikesOf(params)

    private val bolts = LightningStrikes.boltsOf(params)

    private val strike = FloatArray(4)
    private val pathA = FloatArray(4)
    private val pathB = FloatArray(4)
    private val branch = FloatArray(4)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        val index = LightningStrikes.indexAt(strikesUs, effectTimeUs)
        val bolt = index * LightningStrikes.BOLT_VALUES
        val hasBolt = index >= 0 && bolt + LightningStrikes.BOLT_VALUES <= bolts.size
        val sinceUs = if (index >= 0) effectTimeUs - strikesUs[index] else -1L
        strike[0] = if (hasBolt) LightningStrikes.flash(intensity, sinceUs) else 0f
        strike[1] = if (hasBolt) LightningStrikes.bolt(intensity, sinceUs) else 0f
        if (hasBolt) {
            strike[2] = bolts[bolt]
            strike[3] = bolts[bolt + 1]
            for (i in 0 until 4) {
                pathA[i] = bolts[bolt + 2 + i]
                pathB[i] = bolts[bolt + 6 + i]
                branch[i] = bolts[bolt + 10 + i]
            }
        } else {
            strike[2] = 0f
            strike[3] = 0f
            pathA.fill(0f)
            pathB.fill(0f)
            branch.fill(0f)
        }
        shader.setFloats("uStrike", strike)
        shader.setFloats("uPathA", pathA)
        shader.setFloats("uPathB", pathB)
        shader.setFloats("uBranch", branch)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.lightning"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> LightningVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> LightningVideoEffect(params) }
        }

        // `l` is the frame's longer side. The bolt's corners are `c0` at the
        // top to `c8` where it ends, each `rise` lower than the one before, and
        // its branch forks off `c3` through `b1` to `b3`, level with `c6`.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform vec4 uStrike;
uniform vec4 uPathA;
uniform vec4 uPathB;
uniform vec4 uBranch;

float segment(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h);
}

void main() {
  vec2 p = vTexCoord * uSize;
  vec3 base = tap(p);
  float flash = uStrike.x;
  float bolt = uStrike.y;
  if (flash <= 0.0 && bolt <= 0.0) {
    gl_FragColor = vec4(base, 1.0);
    return;
  }
  float l = max(uSize.x, uSize.y);
  float top = uSize.y + 0.02 * l;
  float rise = (top - uStrike.w * uSize.y) / 8.0;
  vec2 c0 = vec2(uStrike.z * uSize.x, top);
  vec2 c1 = vec2(uPathA.x * uSize.x, top - rise);
  vec2 c2 = vec2(uPathA.y * uSize.x, top - 2.0 * rise);
  vec2 c3 = vec2(uPathA.z * uSize.x, top - 3.0 * rise);
  vec2 c4 = vec2(uPathA.w * uSize.x, top - 4.0 * rise);
  vec2 c5 = vec2(uPathB.x * uSize.x, top - 5.0 * rise);
  vec2 c6 = vec2(uPathB.y * uSize.x, top - 6.0 * rise);
  vec2 c7 = vec2(uPathB.z * uSize.x, top - 7.0 * rise);
  vec2 c8 = vec2(uPathB.w * uSize.x, top - 8.0 * rise);
  vec2 b1 = vec2(uBranch.x * uSize.x, top - 4.0 * rise);
  vec2 b2 = vec2(uBranch.y * uSize.x, top - 5.0 * rise);
  vec2 b3 = vec2(uBranch.z * uSize.x, top - 6.0 * rise);
  float upper = min(min(segment(p, c0, c1), segment(p, c1, c2)), min(segment(p, c2, c3), segment(p, c3, c4)));
  float lower = min(min(segment(p, c4, c5), segment(p, c5, c6)), min(segment(p, c6, c7), segment(p, c7, c8)));
  float trunk = min(upper, lower);
  float side = min(min(segment(p, c3, b1), segment(p, b1, b2)), segment(p, b2, b3));
  float w = 0.003 * l;
  float trunkEnd = clamp((p.y - c8.y) / (2.0 * rise), 0.0, 1.0);
  float sideEnd = clamp((p.y - b3.y) / (2.0 * rise), 0.0, 1.0);
  float core = (0.3 + 0.7 * trunkEnd) * exp(-trunk * trunk / (w * w)) + 0.7 * uBranch.w * sideEnd * exp(-side * side / (0.36 * w * w));
  float glow = (0.3 + 0.7 * trunkEnd) * exp(-trunk / (0.035 * l)) + 0.5 * uBranch.w * sideEnd * exp(-side / (0.025 * l));
  vec3 tint = vec3(0.78, 0.86, 1.0);
  vec3 lit = base * (1.0 + 0.9 * flash * tint) + 0.22 * flash * tint;
  lit += bolt * (min(core, 1.0) * vec3(0.95, 0.97, 1.0) + 0.6 * glow * vec3(0.55, 0.65, 1.0));
  gl_FragColor = vec4(clamp(lit, 0.0, 1.0), 1.0);
}
"""
    }
}

/**
 * How bright lightning's flash and bolt are at a moment. Mirrors the Swift
 * `LightningStrikes`.
 *
 * Each strike flashes once: the flash starts at the intensity and fades out
 * over [FLASH_US], `e^(-t / 160 ms) · (1 - t / FLASH_US)`, and the bolt shows
 * fully for [BOLT_HOLD_US], then fades out over [BOLT_FADE_US]. A later strike
 * starts over. Before the first strike nothing shows.
 */
object LightningStrikes {
    /** How long a flash takes to fade out. */
    const val FLASH_US = 700_000L

    /** How long the bolt shows fully, and then takes to fade out. */
    const val BOLT_HOLD_US = 60_000L
    const val BOLT_FADE_US = 150_000L

    /** How many values describe one bolt, as the Dart `lightningBoltValueCount`. */
    const val BOLT_VALUES = 14

    /** When the effect strikes, from [params], in the order given. */
    fun strikesOf(params: Map<String, Any?>): LongArray =
        (params["strikesUs"] as? List<*>)
            ?.mapNotNull { (it as? Number)?.toLong() }
            ?.toLongArray()
            ?: LongArray(0)

    /** The shape of each strike's bolt, from [params]. */
    fun boltsOf(params: Map<String, Any?>): FloatArray =
        (params["bolts"] as? List<*>)
            ?.mapNotNull { (it as? Number)?.toFloat() }
            ?.toFloatArray()
            ?: FloatArray(0)

    /** The number of the last strike at or before [effectTimeUs], or -1 before the first. */
    fun indexAt(strikesUs: LongArray, effectTimeUs: Long): Int =
        strikesUs.indexOfLast { it <= effectTimeUs }

    /** How bright the flash is [sinceUs] after a strike, from 0 to [intensity]. */
    fun flash(intensity: Float, sinceUs: Long): Float {
        if (sinceUs < 0 || sinceUs >= FLASH_US) return 0f
        val fade = Math.exp(-sinceUs / 160_000.0) * (1.0 - sinceUs.toDouble() / FLASH_US)
        return (intensity * fade).toFloat()
    }

    /** How bright the bolt is [sinceUs] after a strike, from 0 to 1. */
    fun bolt(intensity: Float, sinceUs: Long): Float {
        if (intensity <= 0f || sinceUs < 0) return 0f
        val shown = if (sinceUs < BOLT_HOLD_US) {
            1f
        } else {
            1f - (sinceUs - BOLT_HOLD_US).toFloat() / BOLT_FADE_US
        }
        return (0.35f + 0.65f * intensity) * shown.coerceAtLeast(0f)
    }
}
