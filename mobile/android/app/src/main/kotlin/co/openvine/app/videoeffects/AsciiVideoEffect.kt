package co.openvine.app.videoeffects

import android.content.res.AssetManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.opengl.GLES20
import android.opengl.GLUtils
import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffects
import io.flutter.FlutterInjector

/**
 * ASCII: the picture redrawn in characters on black, in a grid of square
 * cells.
 *
 * Each cell shows the glyph whose ink matches the cell's brightness, from the
 * glyph atlas in the Flutter assets, which `tools/generate_ascii_glyphs.dart`
 * writes: ten glyphs of 24×24 side by side, emptiest first. It is uploaded as
 * a second texture and read with bilinear filtering, as the Swift
 * `AsciiVideoEffect` and the picker tile's `shaders/ascii.frag` read it. The
 * glyph is drawn in the cell's colour brightened to full strength, so the
 * glyphs carry the brightness and the colour stays clear.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * far the picture turns into characters).
 */
class AsciiVideoEffect(glyphs: Bitmap, params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val glyphTexture = upload(glyphs)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setTexture("uGlyphs", glyphTexture, 1)
        shader.setFloat("uIntensity", intensity)
    }

    override fun release() {
        super.release()
        GLES20.glDeleteTextures(1, intArrayOf(glyphTexture), 0)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.ascii"

        /** The atlas, decoded once on first use. */
        @Volatile
        private var glyphs: Bitmap? = null

        /**
         * Registers the effect for exports and for the editor preview.
         * [assets] are the app's, which hold the Flutter assets.
         */
        fun register(assets: AssetManager) {
            CustomVideoEffects.register(ID) { params -> AsciiVideoEffect(glyphsOf(assets), params) }
            VideoFrameEffects.register(ID) { params -> AsciiVideoEffect(glyphsOf(assets), params) }
        }

        /**
         * The glyph atlas, read on first use. The PNG carries no colour
         * profile, so it decodes to exactly the values it holds.
         */
        @Synchronized
        private fun glyphsOf(assets: AssetManager): Bitmap = glyphs ?: run {
            val key = FlutterInjector.instance().flutterLoader()
                .getLookupKeyForAsset("assets/effects/ascii_glyphs.png")
            val options = BitmapFactory.Options().apply {
                inPreferredConfig = Bitmap.Config.ARGB_8888
                inScaled = false
            }
            assets.open(key).use { stream ->
                checkNotNull(BitmapFactory.decodeStream(stream, null, options)) {
                    "Could not decode the ASCII glyphs"
                }
            }.also { glyphs = it }
        }

        /** Uploads [atlas] as a texture, filtered bilinearly and clamped. */
        private fun upload(atlas: Bitmap): Int {
            val ids = IntArray(1)
            GLES20.glGenTextures(1, ids, 0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, ids[0])
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, atlas, 0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
            return ids[0]
        }

        // `s` is the frame's shorter side and `c` a cell's side, in pixels.
        // The atlas's first row, the glyphs' top, is at t = 0, as GLUtils
        // uploads a bitmap top row first. The cell's colour is the mean of
        // four taps inside it, which steadies the glyphs against noise.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform float uIntensity;
uniform sampler2D uGlyphs;

const float kGlyphs = 10.0;
const float kGlyphSize = 24.0;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  float c = max(8.0, s / 60.0);
  vec2 cell = floor(p / c);
  vec2 middle = (cell + 0.5) * c;
  vec3 ink = 0.25 * (tap(middle + vec2(-0.25, -0.25) * c) + tap(middle + vec2(0.25, -0.25) * c) +
    tap(middle + vec2(-0.25, 0.25) * c) + tap(middle + vec2(0.25, 0.25) * c));
  float level = min(floor(luma(ink) * kGlyphs), kGlyphs - 1.0);
  vec2 inCell = p / c - cell;
  vec2 texel = clamp(vec2(inCell.x, 1.0 - inCell.y) * kGlyphSize, 0.5, kGlyphSize - 0.5);
  vec2 atlas = vec2(kGlyphs * kGlyphSize, kGlyphSize);
  float glyph = texture2D(uGlyphs, vec2(level * kGlyphSize + texel.x, texel.y) / atlas).r;
  float hi = max(max(ink.r, ink.g), ink.b);
  vec3 ascii = clamp(ink / max(hi, 0.25), 0.0, 1.0) * glyph;
  gl_FragColor = vec4(mix(tap(p), ascii, uIntensity), 1.0);
}
"""
    }
}
