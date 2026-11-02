package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Ripple: rings spread out from the centre, as on water after a stone drops
 * in.
 *
 * The rings are a tenth of the frame's shorter side apart and travel
 * three-quarters of that a second. Each pixel is pushed towards or away from
 * the centre by up to 1.2% of the shorter side, and one side of every crest
 * is lit while the other darkens, by up to 12%. Both calm down towards the
 * centre, where the rings start. The picture is zoomed in by up to 2.5%, so
 * the pushed edges stay in view. The phase is kept within one turn, where
 * the GPU's sine and cosine stay exact over the whole frame.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * far the rings push the picture). The rings move with the time since the
 * effect started, so they are in the same place in the preview and in the
 * export.
 */
class RippleVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uTime", (effectTimeUs / 1_000_000.0).toFloat())
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.ripple"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> RippleVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> RippleVideoEffect(params) }
        }

        // `s` is the frame's shorter side.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uTime;

void main() {
  vec2 p = vTexCoord * uSize;
  vec2 c = uSize * 0.5;
  vec2 d = p - c;
  float r = length(d);
  float s = min(uSize.x, uSize.y);
  float phase = 6.2832 * fract(r / (0.1 * s) - fract(uTime * 0.75));
  float fade = smoothstep(0.0, 0.2 * s, r);
  float push = 0.012 * s * uIntensity * fade * sin(phase);
  vec2 q = c + d * (1.0 - 0.025 * uIntensity) + d / max(r, 0.001) * push;
  vec3 color = tap(q) * (1.0 + 0.12 * uIntensity * fade * cos(phase));
  gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
"""
    }
}
