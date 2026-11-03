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
import java.util.concurrent.ConcurrentHashMap

/**
 * A colour-graded look: every colour of the picture is mapped through the
 * look's 33×33×33 lookup table, as a film stock or a colourist's grade would
 * map it.
 *
 * The table is the look's PNG in the Flutter assets, which
 * `tools/generate_looks.dart` writes: 33 slices of 33×33 side by side, one per
 * blue level, with red growing to the right and green downwards. It is
 * uploaded as a second texture; red and green interpolate within a slice
 * through the texture's bilinear filtering, and blue between the two nearest
 * slices. That is the trilinear interpolation Core Image's `CIColorCube` does
 * in the Swift `LookVideoEffect`, and both run on the sRGB-encoded values the
 * frames carry, so the preview and the export look the same on every
 * platform. The picker tile's `shaders/look.frag` is the same lookup.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
 * much of the look is mixed over the picture).
 */
class LookVideoEffect(table: Bitmap, params: Map<String, Any?>) : ShaderVideoEffect(FRAGMENT_SHADER) {

    private val intensity = intensityOf(params)

    private val tableTexture = upload(table)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setTexture("uTable", tableTexture, 1)
        shader.setFloat("uIntensity", intensity)
    }

    override fun release() {
        super.release()
        GLES20.glDeleteTextures(1, intArrayOf(tableTexture), 0)
    }

    /** Each look, under the id the Dart `CustomVideoEffect` names. */
    enum class Look(val id: String, val asset: String) {
        TEAL_ORANGE("divine.look.tealOrange", "teal_orange"),
        WARM_FILM("divine.look.warmFilm", "warm_film"),
        SLIDE_FILM("divine.look.slideFilm", "slide_film"),
        COOL_FILM("divine.look.coolFilm", "cool_film"),
        MATTE("divine.look.matte", "matte"),
        BLEACH_BYPASS("divine.look.bleachBypass", "bleach_bypass"),
        CROSS_PROCESS("divine.look.crossProcess", "cross_process"),
        GOLDEN_HOUR("divine.look.goldenHour", "golden_hour"),
        MOONLIGHT("divine.look.moonlight", "moonlight"),
        SILVER("divine.look.silver", "silver"),
    }

    companion object {
        /** Decoded tables, kept once read: 10 of them take about 1.4 MB. */
        private val tables = ConcurrentHashMap<Look, Bitmap>()

        /**
         * Registers every look, each under its own id, for exports and for
         * the editor preview. [assets] are the app's, which hold the Flutter
         * assets.
         */
        fun register(assets: AssetManager) {
            for (look in Look.values()) {
                CustomVideoEffects.register(look.id) { params -> LookVideoEffect(tableOf(assets, look), params) }
                VideoFrameEffects.register(look.id) { params -> LookVideoEffect(tableOf(assets, look), params) }
            }
        }

        /**
         * The table of [look], read on first use. The PNG carries no colour
         * profile, so it decodes to exactly the values it holds.
         */
        private fun tableOf(assets: AssetManager, look: Look): Bitmap = tables.getOrPut(look) {
            val key = FlutterInjector.instance().flutterLoader()
                .getLookupKeyForAsset("assets/looks/${look.asset}.png")
            val options = BitmapFactory.Options().apply {
                inPreferredConfig = Bitmap.Config.ARGB_8888
                inScaled = false
            }
            assets.open(key).use { stream ->
                checkNotNull(BitmapFactory.decodeStream(stream, null, options)) {
                    "Could not decode the table of $look"
                }
            }
        }

        /** Uploads [table] as a texture, filtered bilinearly and clamped. */
        private fun upload(table: Bitmap): Int {
            val ids = IntArray(1)
            GLES20.glGenTextures(1, ids, 0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, ids[0])
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, table, 0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
            return ids[0]
        }

        // The lookup is `shaders/look.frag`'s line for line. The table's
        // first row, green 0, is at t = 0, as GLUtils uploads a bitmap top
        // row first. The frame is read through `tap`, which keeps `uSize`
        // in use: ShaderVideoEffect sets it, and Media3 throws when a set
        // uniform was compiled out.
        private const val FRAGMENT_SHADER = ShaderVideoEffect.PRELUDE + """
uniform sampler2D uTable;
uniform float uIntensity;

const float kPoints = 33.0;

vec3 lookUp(vec3 color) {
  vec3 p = clamp(color, 0.0, 1.0) * (kPoints - 1.0);
  float lower = floor(p.b);
  float upper = min(lower + 1.0, kPoints - 1.0);
  vec2 texel = p.rg + 0.5;
  vec2 tableSize = vec2(kPoints * kPoints, kPoints);
  vec3 a = texture2D(uTable, vec2(lower * kPoints + texel.x, texel.y) / tableSize).rgb;
  vec3 b = texture2D(uTable, vec2(upper * kPoints + texel.x, texel.y) / tableSize).rgb;
  return mix(a, b, p.b - lower);
}

void main() {
  vec3 color = tap(vTexCoord * uSize);
  gl_FragColor = vec4(mix(color, lookUp(color), uIntensity), 1.0);
}
"""
    }
}
