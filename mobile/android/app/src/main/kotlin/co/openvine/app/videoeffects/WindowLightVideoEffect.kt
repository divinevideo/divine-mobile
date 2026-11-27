package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Window light: slanted stripes of warm afternoon light, as through a
 * venetian blind, slide slowly across the picture.
 *
 * The stripes fall on a soft, wide window patch a little right of and above
 * the middle, and fade out towards the frame's edges. In a stripe the
 * picture is lit warm; between the stripes, and outside the patch, it is a
 * little darker. The stripes take about nine seconds to move on by one, and
 * as many slide in as slide out, so the picture never pulses brighter and
 * darker.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
 * strong the light and the shade are), `angle` (-60–60: how far the slats lean
 * from level, in degrees; about 24 by default), `width` (0.5–2: how far apart
 * the slats are, as a share of the default), `color` (the colour of the light
 * falling through, as an ARGB integer) and `speed` (0–3: how fast the slats
 * drift, as a share of the default; 0 holds them still). The stripes move with
 * the time since the effect started, so they are in the same place in the
 * preview and in the export.
 */
class WindowLightVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val slant = turnOf(numberOf(params, "angle", ANGLE, -60f, 60f)).let {
        // The slats run across this direction; its length sets their spacing.
        floatArrayOf(SLANT_LENGTH * it[1], SLANT_LENGTH * it[0])
    }

    private val slat = numberOf(params, "width", 1f, 0.5f, 2f)

    private val color = colorOf(params, "color", 0xFFFFB650)

    private val speed = numberOf(params, "speed", 1f, 0f, 3f)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uTime", (effectTimeUs / 1_000_000.0).toFloat())
        shader.setFloats("uSlant", slant)
        shader.setFloat("uSlat", slat)
        shader.setFloats("uColor", color)
        shader.setFloat("uSpeed", speed)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.windowLight"

        /** How far the slats lean from level by default, in degrees. */
        private const val ANGLE = 24.227745f

        /** How long the slats' direction is: one slat every 12% of the shorter side along it. */
        private const val SLANT_LENGTH = 1.0965856f

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> WindowLightVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> WindowLightVideoEffect(params) }
        }

        // `s` is the frame's shorter side; one stripe and the gap after it
        // take 12% of it.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uTime;
uniform vec2 uSlant;
uniform float uSlat;
uniform vec3 uColor;
uniform float uSpeed;

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  float slats = fract(dot(p, uSlant) / (0.12 * uSlat * s) - 0.11 * uTime * uSpeed);
  float slat = smoothstep(0.0, 0.12, slats) * (1.0 - smoothstep(0.42, 0.56, slats));
  vec2 d = (p / uSize - vec2(0.58, 0.6)) * vec2(1.3, 1.0);
  float window = 1.0 - smoothstep(0.25, 0.75, length(d));
  vec3 shade = vec3(1.0 - 0.35 * uIntensity);
  vec3 warm = 1.0 + uIntensity * 0.7 * uColor;
  vec3 base = tap(p);
  gl_FragColor = vec4(clamp(base * mix(shade, warm, slat * window), 0.0, 1.0), 1.0);
}
"""
    }
}
