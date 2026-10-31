package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Zoom blur: the picture streaks outward from its centre, as if the camera
 * zoomed in during the exposure.
 *
 * Each pixel averages 32 taps along the line from it towards the centre,
 * reaching up to 22% of the way there. The taps start at a different point
 * from pixel to pixel, by interleaved gradient noise, so they leave a fine
 * grain rather than rings. A frame without streaks, such as one between two
 * hits on the beat, reads each pixel once.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
 * long the streaks are) and, for an effect on the beat, `beatsUs`: the beats,
 * in microseconds after the effect's start. On the beat the streaks only show
 * on each hit and fade out over half a second; see [BlurHits].
 */
class ZoomBlurVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val beatsUs = BlurHits.beatsOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uStrength", BlurHits.strength(intensity, beatsUs, effectTimeUs))
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.zoomBlur"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> ZoomBlurVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> ZoomBlurVideoEffect(params) }
        }

        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uStrength;

void main() {
  vec2 p = vTexCoord * uSize;
  if (uStrength <= 0.0) {
    gl_FragColor = vec4(tap(p), 1.0);
    return;
  }
  vec2 c = uSize * 0.5;
  float jitter = fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
  vec3 color = vec3(0.0);
  for (int i = 0; i < 32; i++) {
    float share = (float(i) + jitter) / 32.0;
    color += tap(c + (p - c) * (1.0 - 0.22 * uStrength * share));
  }
  gl_FragColor = vec4(color / 32.0, 1.0);
}
"""
    }
}

/**
 * How strongly the zoom blur, or the spin blur, streaks at a moment. Mirrors
 * the Swift `BlurHits`.
 *
 * All the time it streaks at its intensity. On the beat each beat starts a hit
 * at the intensity that fades out over [HIT_US] as `(1 - u)²`, `u` the share
 * of the hit gone, as the built-in zoom pulse eases out; a later beat starts
 * the next hit. Before the first beat it does not streak at all.
 */
object BlurHits {
    /** How long one hit lasts. */
    const val HIT_US = 500_000L

    /** The beats in [params], in order, or `null` for an effect that plays all through. */
    fun beatsOf(params: Map<String, Any?>): LongArray? =
        (params["beatsUs"] as? List<*>)
            ?.mapNotNull { (it as? Number)?.toLong() }
            ?.sorted()
            ?.toLongArray()

    /** The strength [effectTimeUs] after the effect started, from 0 to [intensity]. */
    fun strength(intensity: Float, beatsUs: LongArray?, effectTimeUs: Long): Float {
        if (beatsUs == null) return intensity
        val last = beatsUs.lastOrNull { it <= effectTimeUs } ?: return 0f
        val u = (effectTimeUs - last).toFloat() / HIT_US
        if (u >= 1f) return 0f
        return intensity * (1f - u) * (1f - u)
    }
}
