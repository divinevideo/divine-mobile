package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects
import kotlin.math.roundToInt

/**
 * Laser: thin coloured beams fan out from the top of the picture and sweep
 * across it, changing colour, over a slightly dimmed picture.
 *
 * Seven beams start just above the middle of the top edge, the angle between
 * them opening and closing slowly while the whole fan swings from side to
 * side, `0.5 · sin(0.8 · phase)` radians from straight down. Each beam is a
 * thin bright core with a soft glow around it, fading with the distance from
 * the source, and the beams take two colours in turn, half the hue circle
 * apart, which change together; see [PartyLights].
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how dim
 * the picture gets and how bright the beams are), `count` (1–9: how many beams
 * the fan has), `speed` (0–3: how fast the fan swings, as a share of the
 * default; 0 holds it still) and, for an effect on the beat, `beatsUs`: the
 * beats, in microseconds after the effect's start. On the beat the colours
 * change and the fan swings the other way on each beat; otherwise the colours
 * change every one and a half seconds and it swings on steadily.
 */
class LaserVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val beatsUs = BlurHits.beatsOf(params)

    private val beams = numberOf(params, "count", 7f, 1f, 9f).roundToInt().toFloat()

    private val speed = numberOf(params, "speed", 1f, 0f, 3f)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        val lights = PartyLights.at(beatsUs, effectTimeUs)
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uPhase", lights.phase * speed)
        shader.setFloat("uStep", lights.step)
        shader.setFloat("uMix", lights.mix)
        shader.setFloat("uBeams", beams)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.laser"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> LaserVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> LaserVideoEffect(params) }
        }

        // `l` is the frame's longer side. `across` is how far the pixel lies
        // beside a beam, in pixels.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + PartyLights.COLOR + """
uniform float uIntensity;
uniform float uPhase;
uniform float uStep;
uniform float uMix;
uniform float uBeams;

void main() {
  vec2 p = vTexCoord * uSize;
  float l = max(uSize.x, uSize.y);
  vec2 d = p - vec2(0.5 * uSize.x, uSize.y + 0.02 * l);
  float dist = length(d);
  float angle = atan(d.x, -d.y);
  float aim = 0.5 * sin(0.8 * uPhase);
  float spread = 0.14 + 0.05 * sin(0.45 * uPhase + 1.3);
  vec3 first = mix(partyColor(uStep - 1.0, 0.0), partyColor(uStep, 0.0), uMix);
  vec3 second = mix(partyColor(uStep - 1.0, 1.5), partyColor(uStep, 1.5), uMix);
  float core = 0.0022 * l;
  float glow = 0.012 * l;
  vec3 light = vec3(0.0);
  for (int i = 0; i < 9; i++) {
    if (float(i) >= uBeams) break;
    float across = dist * abs(sin(angle - aim - (float(i) - 0.5 * (uBeams - 1.0)) * spread));
    float beam = exp(-across * across / (core * core)) + 0.35 * exp(-across / glow);
    light += beam * mix(first, second, float(i) - 2.0 * floor(float(i) / 2.0));
  }
  float fade = 1.0 / (1.0 + dist / (0.8 * l));
  vec3 base = tap(p);
  vec3 lit = base * (1.0 - 0.35 * uIntensity) + uIntensity * fade * light;
  gl_FragColor = vec4(clamp(lit, 0.0, 1.0), 1.0);
}
"""
    }
}
