package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * The picture painted in one of its [Style]s: in watercolour or in oil.
 *
 * Both are a soft Kuwahara filter, which paints each pixel with the mean
 * colours of the four quadrants around it, weighted towards the evenest, so the
 * picture turns into flat patches with the edges kept. Watercolour mixes them
 * softly, lightens the washes unevenly, lets the paint pool a little darker
 * where they meet and shows the paper's grain; oil paint keeps only the
 * evenest, for hard edges, deepens the colours and lights the patches' edges
 * from the top left like thick paint, with fine bristle marks.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how far
 * the picture turns into paint), `size` (0.5–3: how large the brush strokes
 * are, as a share of the default).
 */
class PaintVideoEffect(private val style: Style, params: Map<String, Any?>) :
    ShaderVideoEffect(FRAGMENT_SHADER) {

    /** How the picture is painted; [shaderValue] is what the shader mixes by. */
    enum class Style(val id: String, val shaderValue: Float) {
        WATERCOLOR("divine.watercolor", 0f),
        OIL("divine.oilPaint", 1f),
    }

    private val intensity = intensityOf(params)

    private val brush = numberOf(params, "size", 1f, 0.5f, 3f)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uStyle", style.shaderValue)
        shader.setFloat("uBrush", brush)
    }

    companion object {
        /** Registers every style, each under its own id, for exports and for the editor preview. */
        fun register() {
            for (style in Style.values()) {
                CustomVideoEffects.register(style.id) { params -> PaintVideoEffect(style, params) }
                VideoFrameEffects.register(style.id) { params -> PaintVideoEffect(style, params) }
            }
        }

        // `s` is the frame's shorter side, `e` the step between the filter's
        // 7 by 7 taps, so the patches stay about the same share of the frame
        // at every resolution. The hash is Dave Hoskins' "hash without sine"
        // with 3.33 in place of its 33.33, as the particles use it.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform float uStyle;
uniform float uBrush;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 q) {
  vec3 r = fract(vec3(q.xyx) * 0.1031);
  r += dot(r, r.yzx + 3.33);
  return fract((r.x + r.y) * r.z);
}

// Value noise: the hash on a grid, blended smoothly between its points.
float noise(vec2 q) {
  vec2 i = floor(q);
  vec2 f = q - i;
  f = f * f * (3.0 - 2.0 * f);
  float bottom = mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x);
  float top = mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x);
  return mix(bottom, top, f.y);
}

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  float e = max(1.0, s / 360.0 * uBrush);
  vec3 m0 = vec3(0.0);
  vec3 m1 = vec3(0.0);
  vec3 m2 = vec3(0.0);
  vec3 m3 = vec3(0.0);
  vec4 sum = vec4(0.0);
  vec4 squares = vec4(0.0);
  for (int j = -3; j <= 3; j++) {
    for (int i = -3; i <= 3; i++) {
      vec3 c = tap(p + vec2(float(i), float(j)) * e);
      float l = luma(c);
      float left = step(float(i), 0.0);
      float right = step(0.0, float(i));
      float below = step(float(j), 0.0);
      float above = step(0.0, float(j));
      vec4 w = vec4(left * below, right * below, left * above, right * above);
      m0 += c * w.x;
      m1 += c * w.y;
      m2 += c * w.z;
      m3 += c * w.w;
      sum += w * l;
      squares += w * l * l;
    }
  }
  vec4 mean = sum / 16.0;
  vec4 deviation = sqrt(max(squares / 16.0 - mean * mean, 0.0));
  vec4 k = 1.0 / (1.0 + pow(deviation * 40.0, vec4(mix(3.0, 8.0, uStyle))));
  vec3 painted = (m0 * k.x + m1 * k.y + m2 * k.z + m3 * k.w) / (16.0 * dot(k, vec4(1.0)));
  float lo = min(min(mean.x, mean.y), min(mean.z, mean.w));
  float hi = max(max(mean.x, mean.y), max(mean.z, mean.w));
  float pool = smoothstep(0.06, 0.25, hi - lo);
  float blot = noise(p / (0.12 * s));
  float paper = 0.93 + 0.07 * noise(p / e);
  vec3 pigment = clamp(mix(vec3(luma(painted)), painted, 1.15), 0.0, 1.0);
  vec3 wash = (1.0 - (1.0 - pigment) * (0.8 + 0.15 * blot)) * (1.0 - 0.12 * pool) * paper;
  vec2 slope = vec2(mean.y + mean.w - mean.x - mean.z, mean.z + mean.w - mean.x - mean.y);
  float relief = 1.0 + 0.8 * dot(slope, vec2(-0.70710678, 0.70710678));
  float bristle = noise(vec2(dot(p, vec2(0.8, 0.6)) / e, dot(p, vec2(-0.6, 0.8)) / (6.0 * e)));
  float light = clamp(relief * (0.96 + 0.08 * bristle), 0.85, 1.15);
  vec3 oil = clamp(mix(vec3(luma(painted)), painted, 1.3) * light, 0.0, 1.0);
  vec3 art = mix(wash, oil, uStyle);
  gl_FragColor = vec4(mix(tap(p), art, uIntensity), 1.0);
}
"""
    }
}
