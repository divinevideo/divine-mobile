package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Night vision: the picture as night vision goggles show it, brightened into
 * green phosphor, with fine noise, faint scanlines and darker corners.
 *
 * The brightness is lifted, more in the shadows, and turned into the
 * phosphor's green, which pales towards white where it is brightest. The
 * noise changes 24 times a second, stepping through [NOISE_PATTERNS] patterns,
 * so it stays fine grain rather than a flicker; its mean is zero, so the
 * picture keeps its brightness. It moves with the time since the effect
 * started, so it is the same in the preview and in the export.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * far the picture turns into night vision).
 */
class NightVisionVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uNoiseFrame", noiseFrameOf(effectTimeUs))
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.nightVision"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> NightVisionVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> NightVisionVideoEffect(params) }
        }

        /** How many noise patterns the effect steps through, 24 a second. */
        const val NOISE_PATTERNS = 64L

        /** Which noise pattern shows [effectTimeUs] after the effect started. */
        fun noiseFrameOf(effectTimeUs: Long): Float =
            (effectTimeUs.coerceAtLeast(0L) * 24L / 1_000_000L % NOISE_PATTERNS).toFloat()

        // `s` is the frame's shorter side, `e` a grain cell and half a
        // scanline, in pixels. The noise is interleaved gradient noise, its
        // cells shifted by the pattern's number. The brightness is clamped
        // before its power, which GLSL and Metal leave undefined for a
        // negative base.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uNoiseFrame;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

float grain(vec2 q) {
  return fract(52.9829189 * fract(dot(q, vec2(0.06711056, 0.00583715))));
}

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  float e = max(1.0, s / 540.0);
  vec3 color = tap(p);
  float level = clamp(1.1 * pow(max(luma(color), 0.0), 0.75), 0.0, 1.0);
  float noise = grain(floor(p / e) + uNoiseFrame * vec2(37.0, 17.0)) - 0.5;
  float scan = 0.94 + 0.06 * step(0.5, fract(p.y / (2.0 * e)));
  float corner = length(p / uSize - 0.5);
  float tube = 1.0 - 0.65 * smoothstep(0.35, 0.75, corner);
  float glow = clamp((level + 0.12 * noise) * scan * tube, 0.0, 1.0);
  vec3 phosphor = vec3(0.1 + 0.5 * glow, 1.0, 0.15 + 0.4 * glow) * glow + vec3(0.0, 0.03, 0.01);
  gl_FragColor = vec4(mix(color, clamp(phosphor, 0.0, 1.0), uIntensity), 1.0);
}
"""
    }
}
