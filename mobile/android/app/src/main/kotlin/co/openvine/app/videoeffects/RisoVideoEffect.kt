package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * Riso print: the picture printed in fluorescent pink and blue ink on
 * off-white paper, grainy and slightly out of register, as a risograph
 * prints.
 *
 * The pink ink takes the green out of the paper and the blue ink the red, so
 * each lays down as much as the picture lacks of that channel; where both
 * land they make a deep navy. Each ink covers its grain cells against
 * interleaved gradient noise of its own, with a soft edge, and the blue one
 * is read a little off to the side.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
 * the picture turns into the print), `color` and `color2` (the two inks, as
 * ARGB integers: pink and blue by default) and `offset` (0–3: how far the
 * second ink slips from the first, as a share of the default).
 */
class RisoVideoEffect(params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val inkA = colorOf(params, "color", 0xFFFF47B0)

    private val inkB = colorOf(params, "color2", 0xFF0078BF)

    private val slip = numberOf(params, "offset", 1f, 0f, 3f)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloats("uInkA", inkA)
        shader.setFloats("uInkB", inkB)
        shader.setFloat("uSlip", slip)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.riso"

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> RisoVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> RisoVideoEffect(params) }
        }

        // `s` is the frame's shorter side and `g` the grain cell, about three
        // pixels of a 1080p frame. `cover` maps the noise into 0.15–0.85 and
        // softens the edge over 0.3, so no ink lands on white and full ink
        // covers everything.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform vec3 uInkA;
uniform vec3 uInkB;
uniform float uSlip;

float grain(vec2 q) {
  return fract(52.9829189 * fract(dot(q, vec2(0.06711056, 0.00583715))));
}

float cover(float density, float threshold) {
  return clamp((density - 0.15 - 0.7 * threshold) / 0.3 + 0.5, 0.0, 1.0);
}

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  vec2 g = floor(p / max(1.0, s / 360.0));
  vec3 color = tap(p);
  vec3 slipped = tap(p + vec2(0.006, -0.004) * s * uSlip);
  float pink = cover(1.0 - color.g, grain(g));
  float blue = cover(1.0 - slipped.r, grain(g + vec2(19.0, 7.0)));
  vec3 riso = vec3(0.96, 0.94, 0.9) * mix(vec3(1.0), uInkA, pink) *
    mix(vec3(1.0), uInkB, blue);
  gl_FragColor = vec4(mix(color, riso, uIntensity), 1.0);
}
"""
    }
}
