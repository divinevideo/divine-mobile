package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectFrame
import ch.waio.pro_video_editor.effects.CustomVideoEffectRenderer
import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffect
import com.divinevideo.divine_video_player.VideoFrameEffects

/**
 * The Adjust controls a colour matrix cannot draw (#10392): highlights,
 * shadows, vibrance, sharpening, the Color section's per-colour hue,
 * saturation and lightness, and the tone curve (#10871).
 *
 * A matrix changes every pixel the same way, but these depend on each pixel's
 * own brightness, hue or saturation, or on its neighbours. Sharpening adds
 * back the difference between a pixel's brightness and a small blur of it,
 * but never past the brightest or darkest pixel it sampled, so hard edges get
 * no halo. Shadows and highlights move the brightness along a curve that
 * leaves black and white in place, scaling red, green and blue alike so the
 * colour stays. The tone curve maps each channel through a smooth curve
 * through five points that never overshoots them, first the master curve,
 * then the channel's own. Vibrance saturates dull colours more than strong
 * ones and mostly spares skin tones. The Color section turns, mutes or
 * strengthens, and darkens or lightens each of eight colour bands, which
 * blend into each other so no hue edge shows.
 *
 * The shader is the Swift `AdjustVideoEffect`'s Metal kernel, line for line,
 * so both platforms draw the same picture. Only the Metal copy runs in a test
 * (`AdjustVideoEffectTests` in `RunnerTests`), so a change here has to be made
 * there as well.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `highlights`, `shadows`
 * and `vibrance` (-1 to 1), `sharpen` (0 to 1), a hue, saturation and
 * lightness per colour band, like `redHue` (-1 to 1), and a value per tone
 * curve point, like `curveRgbShadows` (how far the point's output sits above
 * its input level); a missing one is 0.
 */
class AdjustVideoEffect(params: Map<String, Any?>) : CustomVideoEffectRenderer(), VideoFrameEffect {

    private val values = floatArrayOf(
        params.unit("highlights", -1f),
        params.unit("shadows", -1f),
        params.unit("vibrance", -1f),
        params.unit("sharpen", 0f),
    )

    /** Per colour band, in [BANDS] order, the band's hue, then saturation, then lightness. */
    private val colors = COLOR_PROPERTIES.map { property ->
        FloatArray(BANDS.size) { band -> params.unit(BANDS[band] + property, -1f) }
    }

    /**
     * The curves' points below white, curve after curve in [CURVES] order,
     * as the `mat4` takes its columns, and then the curves' white points.
     */
    private val curves = FloatArray(CURVES.size * (CURVE_POINTS.size - 1)) { i ->
        params.curvePoint(CURVES[i / 4], i % 4)
    }

    private val curveWhites = FloatArray(CURVES.size) { curve ->
        params.curvePoint(CURVES[curve], CURVE_POINTS.size - 1)
    }

    override val historyOffsetsUs = LongArray(0)

    override val historyScale = 1f

    private val shader = CustomVideoEffectShader(FRAGMENT_SHADER)

    override fun render(frame: CustomVideoEffectFrame) {
        draw(frame.textureId, frame.width, frame.height)
    }

    override fun render(frameTextureId: Int, width: Int, height: Int, history: List<Int?>) {
        draw(frameTextureId, width, height)
    }

    private fun draw(frameTexture: Int, width: Int, height: Int) {
        shader.use()
        shader.setTexture("uFrame", frameTexture, 0)
        shader.setFloats("uSize", floatArrayOf(width.toFloat(), height.toFloat()))
        shader.setFloats("uAdjust", values)
        shader.setFloats("uHueA", colors[0].copyOfRange(0, 4))
        shader.setFloats("uHueB", colors[0].copyOfRange(4, 8))
        shader.setFloats("uSaturationA", colors[1].copyOfRange(0, 4))
        shader.setFloats("uSaturationB", colors[1].copyOfRange(4, 8))
        shader.setFloats("uLightnessA", colors[2].copyOfRange(0, 4))
        shader.setFloats("uLightnessB", colors[2].copyOfRange(4, 8))
        shader.setFloats("uCurves", curves)
        shader.setFloats("uCurveWhites", curveWhites)
        shader.draw()
    }

    override fun release() {
        shader.release()
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.adjust"

        /** The colour bands, in hue order, as the Dart `AdjustColorBand` names them. */
        private val BANDS = listOf("red", "orange", "yellow", "green", "aqua", "blue", "purple", "magenta")

        /** What follows a band in a Color param. */
        private val COLOR_PROPERTIES = listOf("Hue", "Saturation", "Lightness")

        /** The tone curves, as their params name them after `curve`. */
        private val CURVES = listOf("Rgb", "Red", "Green", "Blue")

        /** A curve's points from black to white, as their params name them last. */
        private val CURVE_POINTS = listOf("Blacks", "Shadows", "Midtones", "Highlights", "Whites")

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> AdjustVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> AdjustVideoEffect(params) }
        }

        private fun Map<String, Any?>.unit(key: String, min: Float): Float =
            (this[key] as? Number)?.toFloat()?.coerceIn(min, 1f) ?: 0f

        /**
         * How far point [point] of [curve] sits above its input level, kept
         * between black and white.
         */
        private fun Map<String, Any?>.curvePoint(curve: String, point: Int): Float {
            val x = point / (CURVE_POINTS.size - 1f)
            val value = this["curve$curve${CURVE_POINTS[point]}"] as? Number
            return value?.toFloat()?.coerceIn(-x, 1f - x) ?: 0f
        }

        // `p` is in pixels from the bottom left. The sharpening blur samples
        // a ring that grows with the frame, 1.5 px on a 1080p one, so a
        // video looks as sharp after it at any resolution. Pixel coordinates
        // need highp: mediump cannot address a 1080p frame to the pixel.
        // Hues are in degrees. Media3 binds no uniform arrays, so the bands
        // come in vec4s, four at a time, and the curves below white as the
        // columns of a mat4.
        private const val FRAGMENT_SHADER = """
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
uniform sampler2D uFrame;
uniform vec2 uSize;
uniform vec4 uAdjust;
uniform vec4 uHueA;
uniform vec4 uHueB;
uniform vec4 uSaturationA;
uniform vec4 uSaturationB;
uniform vec4 uLightnessA;
uniform vec4 uLightnessB;
uniform mat4 uCurves;
uniform vec4 uCurveWhites;
varying vec2 vTexCoord;
const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);
vec3 tap(vec2 q) {
  return texture2D(uFrame, clamp(q, vec2(0.5), uSize - 0.5) / uSize).rgb;
}
float luma(vec2 q) {
  return dot(tap(q), kLuma);
}
float slope(float before, float after) {
  return (sign(before) + sign(after)) * min(min(abs(before), abs(after)), 0.25 * abs(before + after));
}
float curve(float x, vec4 points, float whites) {
  if (points == vec4(0.0) && whites == 0.0) return x;
  float y0 = clamp(points.x, 0.0, 1.0);
  float y1 = clamp(0.25 + points.y, 0.0, 1.0);
  float y2 = clamp(0.5 + points.z, 0.0, 1.0);
  float y3 = clamp(0.75 + points.w, 0.0, 1.0);
  float y4 = clamp(1.0 + whites, 0.0, 1.0);
  float d0 = 4.0 * (y1 - y0);
  float d1 = 4.0 * (y2 - y1);
  float d2 = 4.0 * (y3 - y2);
  float d3 = 4.0 * (y4 - y3);
  float s = clamp(x, 0.0, 1.0) * 4.0;
  float k = min(floor(s), 3.0);
  float t = s - k;
  float ya = y3;
  float yb = y4;
  float ma = slope(d2, d3);
  float mb = d3;
  if (k < 0.5) {
    ya = y0; yb = y1; ma = d0; mb = slope(d0, d1);
  } else if (k < 1.5) {
    ya = y1; yb = y2; ma = slope(d0, d1); mb = slope(d1, d2);
  } else if (k < 2.5) {
    ya = y2; yb = y3; ma = slope(d1, d2); mb = slope(d2, d3);
  }
  float t2 = t * t;
  float t3 = t2 * t;
  float y = (2.0 * t3 - 3.0 * t2 + 1.0) * ya + (t3 - 2.0 * t2 + t) * 0.25 * ma
    + (3.0 * t2 - 2.0 * t3) * yb + (t3 - t2) * 0.25 * mb;
  return clamp(y, 0.0, 1.0);
}
float band(float hue, float before, float centre, float after) {
  if (hue < before || hue > after) return 0.0;
  float t = hue < centre ? (hue - before) / (centre - before) : (after - hue) / (after - centre);
  return t * t * (3.0 - 2.0 * t);
}
vec3 fromHsl(float hue, float saturation, float lightness) {
  vec3 k = vec3(0.0, 8.0, 4.0) + hue / 30.0;
  k = k - 12.0 * floor(k / 12.0);
  float a = saturation * min(lightness, 1.0 - lightness);
  return lightness - a * clamp(min(k - 3.0, 9.0 - k), -1.0, 1.0);
}
vec3 mixColors(vec3 color) {
  float hi = max(color.r, max(color.g, color.b));
  float lo = min(color.r, min(color.g, color.b));
  float chroma = hi - lo;
  if (chroma < 0.00001) return color;
  float lightness = (hi + lo) * 0.5;
  float saturation = min(chroma / (1.0 - abs(2.0 * lightness - 1.0)), 1.0);
  float hue = hi == color.r ? (color.g - color.b) / chroma
    : hi == color.g ? (color.b - color.r) / chroma + 2.0
    : (color.r - color.g) / chroma + 4.0;
  hue *= 60.0;
  if (hue < 0.0) hue += 360.0;
  float redHue = hue > 180.0 ? hue - 360.0 : hue;
  vec4 a = vec4(
    band(redHue, -60.0, 0.0, 30.0),
    band(hue, 0.0, 30.0, 60.0),
    band(hue, 30.0, 60.0, 120.0),
    band(hue, 60.0, 120.0, 180.0));
  vec4 b = vec4(
    band(hue, 120.0, 180.0, 240.0),
    band(hue, 180.0, 240.0, 270.0),
    band(hue, 240.0, 270.0, 300.0),
    band(hue, 270.0, 300.0, 360.0));
  float turn = dot(a, uHueA) + dot(b, uHueB);
  float strength = dot(a, uSaturationA) + dot(b, uSaturationB);
  float light = (dot(a, uLightnessA) + dot(b, uLightnessB)) * smoothstep(0.0, 0.2, chroma);
  hue += 30.0 * turn;
  if (hue < 0.0) hue += 360.0;
  if (hue >= 360.0) hue -= 360.0;
  saturation = clamp(saturation * (1.0 + strength), 0.0, 1.0);
  lightness = light > 0.0 ? lightness + (1.0 - lightness) * light * 0.5 : lightness * (1.0 + light * 0.5);
  return clamp(fromHsl(hue, saturation, lightness), 0.0, 1.0);
}
void main() {
  vec2 p = vTexCoord * uSize;
  float highlights = uAdjust.x;
  float shadows = uAdjust.y;
  float vibrance = uAdjust.z;
  float sharpen = uAdjust.w;
  vec3 color = tap(p);
  if (sharpen > 0.0) {
    float r = max(1.0, 1.5 * min(uSize.x, uSize.y) / 1080.0);
    float y = dot(color, kLuma);
    float e0 = luma(p + vec2(r, 0.0));
    float e1 = luma(p - vec2(r, 0.0));
    float e2 = luma(p + vec2(0.0, r));
    float e3 = luma(p - vec2(0.0, r));
    float c0 = luma(p + vec2(r, r));
    float c1 = luma(p + vec2(-r, r));
    float c2 = luma(p + vec2(r, -r));
    float c3 = luma(p - vec2(r, r));
    float blur = (4.0 * y + 2.0 * (e0 + e1 + e2 + e3) + c0 + c1 + c2 + c3) / 16.0;
    float lo = min(y, min(min(min(e0, e1), min(e2, e3)), min(min(c0, c1), min(c2, c3))));
    float hi = max(y, max(max(max(e0, e1), max(e2, e3)), max(max(c0, c1), max(c2, c3))));
    float sharp = clamp(y + 3.0 * sharpen * (y - blur), lo, hi);
    color = clamp(color + (sharp - y), 0.0, 1.0);
  }
  float l = dot(color, kLuma);
  float dark = 1.0 - l;
  float lows = l * dark * dark * dark * dark * 12.20703125;
  float highs = l * l * l * l * dark * 12.20703125;
  float toned = l
    + shadows * (shadows > 0.0 ? 0.2 : 0.065) * lows
    + highlights * (highlights < 0.0 ? 0.2 : 0.065) * highs;
  color = clamp(l > 0.0001 ? color * (toned / l) : color + (toned - l), 0.0, 1.0);
  color = vec3(
    curve(curve(color.r, uCurves[0], uCurveWhites.x), uCurves[1], uCurveWhites.y),
    curve(curve(color.g, uCurves[0], uCurveWhites.x), uCurves[2], uCurveWhites.z),
    curve(curve(color.b, uCurves[0], uCurveWhites.x), uCurves[3], uCurveWhites.w));
  if (vibrance != 0.0) {
    float chroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
    float skin = 0.0;
    if (color.r >= color.g && color.g >= color.b && chroma > 0.0001) {
      float hue = (color.g - color.b) / chroma;
      skin = smoothstep(0.05, 0.25, hue) * (1.0 - smoothstep(0.6, 0.85, hue))
        * smoothstep(0.02, 0.08, chroma) * (1.0 - smoothstep(0.5, 0.75, chroma));
    }
    float keep = 1.0 - 0.85 * skin;
    float amount = vibrance > 0.0
      ? vibrance * 1.25 * (1.0 - chroma) * (1.0 - chroma) * keep
      : vibrance * (0.4 + 0.6 * chroma) * keep;
    float grey = dot(color, kLuma);
    color = clamp(grey + (color - grey) * (1.0 + amount), 0.0, 1.0);
  }
  if (uHueA != vec4(0.0) || uHueB != vec4(0.0) || uSaturationA != vec4(0.0)
      || uSaturationB != vec4(0.0) || uLightnessA != vec4(0.0) || uLightnessB != vec4(0.0)) {
    color = mixColors(color);
  }
  gl_FragColor = vec4(color, 1.0);
}
"""
    }
}
