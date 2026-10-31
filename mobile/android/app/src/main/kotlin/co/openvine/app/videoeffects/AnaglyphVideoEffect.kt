package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * 3D glasses: the picture as a red-cyan anaglyph, the way 3D films and comics
 * were printed for cardboard glasses.
 *
 * The red channel shows the picture moved to the right and the green and blue
 * channels show it moved to the left, each mostly grey with a little of its
 * own colour kept. The red copy lying right of the cyan one makes the picture
 * seem to stand in front of the screen through the glasses; without them,
 * each shape gets a red fringe on one side and a cyan one on the other.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * far apart the copies are and how far the colours turn red and cyan).
 */
class AnaglyphVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.anaglyph"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> AnaglyphVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> AnaglyphVideoEffect(params) }
        }

        // `s` is the frame's shorter side; each copy moves a share of it.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  vec2 shift = vec2(0.014 * s * uIntensity, 0.0);
  vec3 color = tap(p);
  vec3 left = tap(p - shift);
  vec3 right = tap(p + shift);
  vec3 stereo = vec3(mix(luma(left), left.r, 0.3), mix(vec2(luma(right)), right.gb, 0.3));
  gl_FragColor = vec4(mix(color, stereo, uIntensity), 1.0);
}
"""
    }
}
