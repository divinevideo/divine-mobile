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
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * bright the light and how dark the shade are). The stripes move with the
 * time since the effect started, so they are in the same place in the
 * preview and in the export.
 */
class WindowLightVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uTime", (effectTimeUs / 1_000_000.0).toFloat())
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.windowLight"

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

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  float slats = fract((p.y + 0.45 * p.x) / (0.12 * s) - 0.11 * uTime);
  float slat = smoothstep(0.0, 0.12, slats) * (1.0 - smoothstep(0.42, 0.56, slats));
  vec2 d = (p / uSize - vec2(0.58, 0.6)) * vec2(1.3, 1.0);
  float window = 1.0 - smoothstep(0.25, 0.75, length(d));
  vec3 shade = vec3(1.0 - 0.35 * uIntensity);
  vec3 warm = 1.0 + uIntensity * vec3(0.7, 0.5, 0.22);
  vec3 base = tap(p);
  gl_FragColor = vec4(clamp(base * mix(shade, warm, slat * window), 0.0, 1.0), 1.0);
}
"""
    }
}
