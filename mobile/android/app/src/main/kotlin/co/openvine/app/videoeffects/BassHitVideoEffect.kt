package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * A hit of heavy bass in one of its [Style]s: a shockwave or a subwoofer.
 *
 * The shockwave sends a ring of pressure from where it hits past the farthest
 * corner, slowing as it goes, and leaves the frame well before its time is up.
 * The ring bends the picture like a lens, splits its colours along the way out
 * and lights it by up to 6%, and fades as it travels; within 8% of the shorter
 * side from the frame's edge it eases off, so it never reads past the edge. The
 * picture punches in by up to 8%.
 *
 * The subwoofer bulges the picture out like a speaker cone where it hits, at
 * most 45% at its middle and not at all from half the shorter side out, then
 * pulls it in and lets it spring back twice within 0.4 s.
 *
 * Either way the picture rattles for 0.4 s, by up to 1.5% (shockwave) or 0.7%
 * (subwoofer) of the shorter side along two sines of unrelated frequencies, and
 * is zoomed in by a little more than twice that, so its edges never come into
 * view. The look the user set scales these.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how hard
 * the hit lands), `strikesUs`, when it hits, in microseconds after the effect's
 * start, `hitUs`, how long one hit lasts, and the look the user set (see
 * [HitLook]): where it hits, how far the ring travels or how large the cone is,
 * how hard the picture rattles and punches in, and how far the ring splits the
 * colours. The Dart side times the hits, on the beat, once or again and again;
 * see [BassHits] for how they play out.
 */
class BassHitVideoEffect(private val style: Style, params: Map<String, Any?>) :
    ShaderVideoEffect(FRAGMENT_SHADER) {

    /** How the hit lands; [shaderValue] is what the shader mixes by. */
    enum class Style(val id: String, val shaderValue: Float) {
        SHOCKWAVE("divine.shockwave", 0f),
        SUBWOOFER("divine.subwoofer", 1f),
    }

    private val intensity = intensityOf(params)

    private val look = HitLook(params, defaultColor = 0L)

    private val hitsUs = LightningStrikes.strikesOf(params)

    private val hitUs = BassHits.hitOf(params, BassHits.HIT_US)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        val age = BassHits.ageOf(hitsUs, hitUs, BassHits.HIT_US, effectTimeUs)
        shader.setFloat("uIntensity", if (age == null) 0f else intensity)
        shader.setFloat("uAge", age ?: 0f)
        shader.setFloat("uStyle", style.shaderValue)
        shader.setFloat("uReach", look.reach)
        shader.setFloats("uCenter", look.center)
        shader.setFloat("uShake", look.shake)
        shader.setFloat("uPunch", look.punch)
        shader.setFloat("uFringe", look.fringe)
    }

    companion object {
        /** Registers every style, each under its own id, for exports and for the editor preview. */
        fun register() {
            for (style in Style.values()) {
                CustomVideoEffects.register(style.id) { params -> BassHitVideoEffect(style, params) }
                VideoFrameEffects.register(style.id) { params -> BassHitVideoEffect(style, params) }
            }
        }

        // `s` is the frame's shorter side. `wave` is 1 for the shockwave and
        // 0 for the subwoofer, whose terms the other one multiplies away. At
        // no intensity every term is zero and each pixel is read as it is.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uAge;
uniform float uStyle;
uniform float uReach;
uniform vec2 uCenter;
uniform float uShake;
uniform float uPunch;
uniform float uFringe;

void main() {
  vec2 p = vTexCoord * uSize;
  vec2 c = vec2(uCenter.x, 1.0 - uCenter.y) * uSize;
  vec2 m = uSize * 0.5;
  float s = min(uSize.x, uSize.y);
  vec2 d = p - c;
  float r = length(d);
  vec2 dir = d / max(r, 0.001);
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
  vec2 q = p - dir * (0.9 * w * ring * x * band);

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
  vec2 shake = jolt * s * vec2(sin(81.681 * uAge + 0.6), sin(106.814 * uAge + 2.1));
  q = m + (q - m) / zoom + shake;
  vec2 fringe = dir * (0.02 * s * uFringe * ring * band) / zoom;

  vec3 color = vec3(tap(q + fringe).r, tap(q).g, tap(q - fringe).b);
  gl_FragColor = vec4(clamp(color * (1.0 + 0.06 * ring * band), 0.0, 1.0), 1.0);
}
"""
    }
}

/**
 * How the hits of the bass hits and the blasts play out. Mirrors the Swift
 * `BassHits`.
 *
 * Each hit lasts `hitUs`, and its animation, drawn over a fixed length of its
 * own, is stretched or squeezed to fill it; a later hit starts the next one.
 * Before the first hit, and once one is over, they leave the picture alone.
 */
object BassHits {
    /** How long a bass hit's own animation lasts: the ring reaches past the corners by then. */
    const val HIT_US = 500_000L

    /** How long one hit lasts, from [params], or [fallbackUs] without one. */
    fun hitOf(params: Map<String, Any?>, fallbackUs: Long): Long =
        ((params["hitUs"] as? Number)?.toLong() ?: fallbackUs).coerceAtLeast(1L)

    /**
     * Seconds into an animation of [animationUs] that the last of [hitsUs]
     * at or before [effectTimeUs] has reached, with each hit lasting [hitUs];
     * `null` before the first hit and once that one is over.
     */
    fun ageOf(hitsUs: LongArray, hitUs: Long, animationUs: Long, effectTimeUs: Long): Float? {
        val index = LightningStrikes.indexAt(hitsUs, effectTimeUs)
        if (index < 0) return null
        val sinceUs = effectTimeUs - hitsUs[index]
        if (sinceUs >= hitUs) return null
        return (sinceUs.toDouble() / hitUs * animationUs / 1_000_000.0).toFloat()
    }
}

/**
 * How a bass hit or a blast looks beyond its intensity, from its params, as
 * the Dart `HitLookSettings` stores them. Mirrors the Swift `HitLook`.
 *
 * [center] is where it hits, in shares of the frame from its top left;
 * [reach] how far it spreads, 0.2 to 1; [shake], [punch] and [fringe] scale
 * the rattle, the punch in and the colour fringes, 0 to 2; [color] is the
 * colour of a blast's glow, liquid or smoke, red, green and blue from 0 to 1,
 * read from an ARGB integer and [defaultColor] without one.
 */
class HitLook(params: Map<String, Any?>, defaultColor: Long) {
    val center = floatArrayOf(
        number(params, "centerX", 0.5f, 0f, 1f),
        number(params, "centerY", 0.5f, 0f, 1f),
    )
    val reach = number(params, "reach", 1f, 0.2f, 1f)
    val shake = number(params, "shake", 1f, 0f, 2f)
    val punch = number(params, "punch", 1f, 0f, 2f)
    val fringe = number(params, "fringe", 1f, 0f, 2f)
    val color: FloatArray = ((params["color"] as? Number)?.toLong() ?: defaultColor).let { argb ->
        floatArrayOf(
            ((argb shr 16) and 0xFF) / 255f,
            ((argb shr 8) and 0xFF) / 255f,
            (argb and 0xFF) / 255f,
        )
    }

    private companion object {
        fun number(params: Map<String, Any?>, key: String, fallback: Float, min: Float, max: Float): Float =
            ((params[key] as? Number)?.toFloat() ?: fallback).coerceIn(min, max)
    }
}
