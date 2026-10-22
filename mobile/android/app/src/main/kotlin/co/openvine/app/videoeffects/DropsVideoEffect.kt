package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectFrame
import ch.waio.pro_video_editor.effects.CustomVideoEffectRenderer
import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffect
import com.divinevideo.divine_video_player.VideoFrameEffects
import kotlin.math.sin

/**
 * Drops: clear glass drops drift over the picture and flow into each other
 * where they meet. Each drop bends the picture at its rim, with colour
 * fringes, frosts it, catches a highlight on its top left edge and casts a
 * soft shadow below.
 *
 * The shader is the Swift `DropsVideoEffect`'s Metal kernel, line for line,
 * and so is `shaders/drops.frag`, which draws the effects picker's tile.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
 * strongly the glass bends, lights and shades the picture) and the
 * [DropsSettings]. The drops move with the time since the effect started, so
 * they follow the same path in the preview and in the export.
 */
class DropsVideoEffect(params: Map<String, Any?>) : CustomVideoEffectRenderer(), VideoFrameEffect {

    private val intensity = (params["intensity"] as? Number)?.toFloat()?.coerceIn(0f, 1f)
        ?: DEFAULT_INTENSITY

    private val settings = DropsSettings.fromParams(params)

    override val historyOffsetsUs = LongArray(0)

    override val historyScale = 1f

    private val shader = CustomVideoEffectShader(FRAGMENT_SHADER)

    override fun render(frame: CustomVideoEffectFrame) {
        draw(frame.textureId, frame.width, frame.height, frame.effectTimeUs)
    }

    override fun render(
        frameTextureId: Int,
        width: Int,
        height: Int,
        history: List<Int?>,
        timeUs: Long,
        effectTimeUs: Long,
    ) {
        draw(frameTextureId, width, height, effectTimeUs)
    }

    // The player calls the timed render; this draws the drops where they start.
    override fun render(frameTextureId: Int, width: Int, height: Int, history: List<Int?>) {
        draw(frameTextureId, width, height, 0L)
    }

    private fun draw(frameTexture: Int, width: Int, height: Int, effectTimeUs: Long) {
        shader.use()
        shader.setTexture("uFrame", frameTexture, 0)
        shader.setFloats("uSize", floatArrayOf(width.toFloat(), height.toFloat()))
        shader.setFloat("uIntensity", intensity)
        shader.setFloat("uScale", DropsLayout.scale(settings).toFloat())
        shader.setFloat("uFrost", settings.frost.toFloat())
        shader.setFloat("uFringes", settings.fringes.toFloat())
        DropsLayout.drops(settings, effectTimeUs / 1_000_000.0).forEachIndexed { i, drop ->
            shader.setFloats(
                "uDrop$i",
                floatArrayOf(drop.x.toFloat(), drop.y.toFloat(), drop.radius.toFloat()),
            )
        }
        shader.draw()
    }

    override fun release() {
        shader.release()
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.drops"

        private const val DEFAULT_INTENSITY = 0.7f

        /** Registers the effect for exports and for the editor preview. */
        fun register() {
            CustomVideoEffects.register(ID) { params -> DropsVideoEffect(params) }
            VideoFrameEffects.register(ID) { params -> DropsVideoEffect(params) }
        }

        // Distances are in pixels with y up, from the frame's bottom left; `s`
        // is the frame's shorter side, and `z` scales everything around the
        // drops' rims with their size. Pixel coordinates need highp: mediump
        // cannot address a 1080p frame to the pixel.
        private const val FRAGMENT_SHADER = """
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
uniform sampler2D uFrame;
uniform vec2 uSize;
uniform float uIntensity;
uniform float uScale;
uniform float uFrost;
uniform float uFringes;
uniform vec3 uDrop0;
uniform vec3 uDrop1;
uniform vec3 uDrop2;
uniform vec3 uDrop3;
uniform vec3 uDrop4;
varying vec2 vTexCoord;

vec3 drops[5];

float smin(float a, float b, float k) {
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

// Signed distance to the glass, negative inside.
float glass(vec2 p, float k) {
  float d = 1e5;
  for (int i = 0; i < 5; i++) {
    d = smin(d, length(p - drops[i].xy) - drops[i].z, k);
  }
  return d;
}

vec3 tap(vec2 q) {
  return texture2D(uFrame, clamp(q, vec2(0.5), uSize - 0.5) / uSize).rgb;
}

vec3 frosted(vec2 q, float r) {
  vec3 sum = tap(q);
  for (int i = 0; i < 8; i++) {
    float n = float(i);
    float angle = n * 2.399963;
    sum += tap(q + r * sqrt((n + 0.5) / 8.0) * vec2(cos(angle), sin(angle)));
  }
  return sum / 9.0;
}

void main() {
  float intensity = uIntensity;
  float z = uScale;
  float frost = uFrost;
  float fringes = uFringes;
  vec2 p = vTexCoord * uSize;
  float s = min(uSize.x, uSize.y);
  drops[0] = vec3(uDrop0.xy * uSize, uDrop0.z * s);
  drops[1] = vec3(uDrop1.xy * uSize, uDrop1.z * s);
  drops[2] = vec3(uDrop2.xy * uSize, uDrop2.z * s);
  drops[3] = vec3(uDrop3.xy * uSize, uDrop3.z * s);
  drops[4] = vec3(uDrop4.xy * uSize, uDrop4.z * s);
  float k = 0.13 * s * z;

  vec3 base = tap(p);
  float d = glass(p, k);
  float shadow = 1.0 - smoothstep(0.0, 0.07 * s * z, glass(p + vec2(0.0, 0.018 * s * z), k));
  vec3 background = base * (1.0 - shadow * 0.3 * intensity);
  if (d > 1.0) {
    gl_FragColor = vec4(background, 1.0);
    return;
  }

  vec2 g = vec2(
    glass(p + vec2(1.0, 0.0), k) - glass(p - vec2(1.0, 0.0), k),
    glass(p + vec2(0.0, 1.0), k) - glass(p - vec2(0.0, 1.0), k));
  vec2 n = g / max(length(g), 1e-4);
  float w = 0.11 * s * z;
  float e = 1.0 - clamp(-d / w, 0.0, 1.0);
  float slope = e * e * e * pow(max(1.0 - e * e * e * e, 1e-4), -0.75);
  float bend = slope / sqrt(1.0 + slope * slope);
  vec2 shift = -n * bend * 0.95 * intensity * w;
  float r = 0.028 * s * frost * intensity;
  float spread = 0.28 * fringes;
  vec3 color = vec3(
    frosted(p + shift * (1.0 - spread), r).r,
    frosted(p + shift, r).g,
    frosted(p + shift * (1.0 + spread), r).b);
  color = mix(color, vec3(1.0), (0.05 + 0.12 * frost) * intensity);
  float rim = 1.0 - smoothstep(0.0, 0.014 * s * z, -d);
  float light = dot(n, vec2(-0.5524, 0.8336));
  float lit = max(light, 0.0);
  float back = max(-light, 0.0);
  color += intensity * rim * (0.85 * (lit * lit * lit + 0.45 * back * back * back) + 0.08);
  color = clamp(color, 0.0, 1.0);
  gl_FragColor = vec4(mix(background, color, clamp(0.5 - d, 0.0, 1.0)), 1.0);
}
"""
    }
}

/**
 * The drops' settings beyond the intensity, each from 0 to 1 except [count]
 * and [seed]. The Dart `DropsEffectSettings` writes them.
 */
data class DropsSettings(
    /** How many drops show, 1 to [DropsLayout.MAX_DROPS]. */
    val count: Int = 3,
    /** How large the drops are; 0.5 is the default size. */
    val size: Double = 0.5,
    /** How fast they drift; 0 holds them still, 0.5 is the default pace. */
    val speed: Double = 0.5,
    /** How frosted the glass is. */
    val frost: Double = 0.5,
    /** How strongly red and blue part at the rims. */
    val fringes: Double = 0.5,
    /** Which arrangement and paths the drops take; 0 is the default one. */
    val seed: Int = 0,
) {
    companion object {
        fun fromParams(params: Map<String, Any?>): DropsSettings {
            val defaults = DropsSettings()
            fun unit(key: String, fallback: Double) =
                (params[key] as? Number)?.toDouble()?.coerceIn(0.0, 1.0) ?: fallback
            return DropsSettings(
                count = (params["count"] as? Number)?.toInt()?.coerceIn(1, DropsLayout.MAX_DROPS)
                    ?: defaults.count,
                size = unit("size", defaults.size),
                speed = unit("speed", defaults.speed),
                frost = unit("frost", defaults.frost),
                fringes = unit("fringes", defaults.fringes),
                seed = (params["seed"] as? Number)?.toInt() ?: defaults.seed,
            )
        }
    }
}

/**
 * Where the drops are. Mirrors the Swift `DropsLayout` and the Dart
 * `dropsLayout`.
 *
 * Each drop follows a path of its own, `0.5 + a · sin(f · t + phase)` along
 * each axis, where `t` is the time since the effect started times twice the
 * speed. The seed shifts every phase, which rearranges the drops and when
 * they meet without changing how they move.
 */
object DropsLayout {
    /** The most drops the effect draws. */
    const val MAX_DROPS = 5

    /**
     * A drop: its centre as fractions of the frame's width and height, up
     * from the bottom left, and its radius as a fraction of the shorter side.
     */
    data class Drop(val x: Double, val y: Double, val radius: Double)

    /**
     * Per drop: frequency, phase and amplitude across, the same up, and the
     * radius at the default size.
     */
    private val paths = arrayOf(
        doubleArrayOf(0.53, 0.0, 0.24, 0.41, 1.570796, 0.17, 0.17),
        doubleArrayOf(0.37, 2.1, 0.26, 0.29, 0.7, 0.21, 0.13),
        doubleArrayOf(0.45, 5.570796, 0.20, 0.51, 3.3, 0.19, 0.15),
        doubleArrayOf(0.31, 5.2, 0.22, 0.47, 1.9, 0.23, 0.11),
        doubleArrayOf(0.59, 0.4, 0.18, 0.33, 4.6, 0.16, 0.14),
    )

    /** Where a drop that is not shown sits: far outside the frame. */
    private val hidden = Drop(-100.0, -100.0, 0.0)

    /**
     * How much larger than at the default size the drops, and everything
     * around their rims, are drawn.
     */
    fun scale(settings: DropsSettings): Double = 0.5 + settings.size

    /** All [MAX_DROPS] drops [seconds] into the effect; those past the count are hidden. */
    fun drops(settings: DropsSettings, seconds: Double): List<Drop> {
        val t = seconds * 2 * settings.speed
        val seed = settings.seed.toDouble()
        return paths.mapIndexed { i, path ->
            if (i >= settings.count) return@mapIndexed hidden
            val n = (i + 1).toDouble()
            Drop(
                x = 0.5 + path[2] * sin(path[0] * t + path[1] + seed * 2.399963 * n),
                y = 0.5 + path[5] * sin(path[3] * t + path[4] + seed * 1.618034 * n),
                radius = path[6] * scale(settings),
            )
        }
    }
}
