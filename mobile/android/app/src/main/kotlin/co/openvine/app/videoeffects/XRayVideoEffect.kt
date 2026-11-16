package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * X-ray: the picture as an X-ray film, its brightness turned around into
 * cold blue-white on near black, with the outlines standing out like bone.
 *
 * What was dark turns bright and what was bright fades out. The outlines,
 * found where the brightness changes sharply with a Sobel filter, are
 * lightened on top, so shapes keep their edges.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * far the picture turns into the X-ray).
 */
class XRayVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.xray"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> XRayVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> XRayVideoEffect(params) }
        }

        // `s` is the frame's shorter side, `e` the Sobel filter's step in
        // pixels. The darkness is clamped before its power, which GLSL and Metal
        // leave undefined for a negative base.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  float e = max(1.0, s / 540.0);
  vec3 color = tap(p);
  float tl = luma(tap(p + vec2(-e, e)));
  float tc = luma(tap(p + vec2(0.0, e)));
  float tr = luma(tap(p + vec2(e, e)));
  float ml = luma(tap(p + vec2(-e, 0.0)));
  float mr = luma(tap(p + vec2(e, 0.0)));
  float bl = luma(tap(p + vec2(-e, -e)));
  float bc = luma(tap(p + vec2(0.0, -e)));
  float br = luma(tap(p + vec2(e, -e)));
  float gx = tr + 2.0 * mr + br - tl - 2.0 * ml - bl;
  float gy = tl + 2.0 * tc + tr - bl - 2.0 * bc - br;
  float bone = smoothstep(0.1, 0.6, length(vec2(gx, gy)));
  float density = clamp(1.1 * pow(max(1.0 - luma(color), 0.0), 1.6) + 0.5 * bone, 0.0, 1.0);
  vec3 film = mix(vec3(0.0, 0.02, 0.06), vec3(0.78, 0.9, 1.0), density);
  gl_FragColor = vec4(mix(color, film, uIntensity), 1.0);
}
"""
    }
}
