package co.openvine.app.videoeffects

import ch.waio.pro_video_editor.effects.CustomVideoEffectFrame
import ch.waio.pro_video_editor.effects.CustomVideoEffectRenderer
import ch.waio.pro_video_editor.effects.CustomVideoEffectShader
import ch.waio.pro_video_editor.effects.CustomVideoEffects
import com.divinevideo.divine_video_player.VideoFrameEffect
import com.divinevideo.divine_video_player.VideoFrameEffects
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * The Time effects besides the echo trail: each builds the picture from
 * earlier source frames of the same clip as well as the current one, so it
 * only shows where something moves. Mirrors the Swift `TimeVideoEffects`.
 *
 * The earlier frames come as [EchoVideoEffect]'s do: pro_video_editor hands
 * them to the export, and divine_video_player to the editor preview. They lie
 * whole frames back, [frameOffsetUs], so effects that ask for the same moment
 * share it, and the iOS export decodes each moment once.
 */
object TimeVideoEffects {
    /** Registers every Time effect for exports and for the editor preview. */
    fun register() {
        register(TimeSplitVideoEffect.ID) { TimeSplitVideoEffect(it) }
        register(LongExposureVideoEffect.ID) { LongExposureVideoEffect(it) }
        register(MotionOnlyVideoEffect.ID) { MotionOnlyVideoEffect(it) }
        register(StutterVideoEffect.ID) { StutterVideoEffect(it) }
        register(TimeWarpVideoEffect.ID) { TimeWarpVideoEffect(it) }
    }

    private fun <T> register(id: String, factory: (Map<String, Any?>) -> T)
        where T : CustomVideoEffectRenderer, T : VideoFrameEffect {
        CustomVideoEffects.register(id) { params -> factory(params) }
        VideoFrameEffects.register(id) { params -> factory(params) }
    }

    /**
     * How far back the frame [frames] frames before the current one lies, at
     * the 30 fps Divine records and exports at: rounded down to the
     * microsecond, so a frame that starts a fraction of a microsecond later
     * still counts. Mirrors the Swift `TimeVideoEffects.frameOffsetUs`.
     */
    fun frameOffsetUs(frames: Int): Long = frames * 100_000L / 3

    /** How long one frame lasts at 30 fps. */
    const val FRAME_US = 1_000_000.0 / 30
}

/**
 * An effect drawn with one fragment shader over the current frame and
 * [historyOffsetsUs] earlier ones, in the export (pro_video_editor) and in
 * the editor preview (divine_video_player) alike.
 *
 * The shader gets the frame as `uFrame`, its size in pixels as `uSize` and
 * the earlier frames as `uEarlier0`, `uEarlier1`, ..., newest first. An
 * earlier frame the clip has not played far enough back for yet is the
 * current frame, so a clip starts out as if nothing moved. [setUniforms]
 * sets the rest for each frame.
 *
 * Each subclass's shader is the Swift effect's Metal kernel of the same
 * name, line for line.
 */
abstract class EarlierFramesShaderEffect(
    fragmentShader: String,
    final override val historyOffsetsUs: LongArray,
    final override val historyScale: Float,
) : CustomVideoEffectRenderer(), VideoFrameEffect {

    private val shader = CustomVideoEffectShader(fragmentShader)

    /**
     * Sets the shader's uniforms beyond the textures and `uSize`, for a
     * frame [effectTimeUs] after the effect started.
     */
    protected abstract fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long)

    override fun render(frame: CustomVideoEffectFrame) {
        draw(frame.textureId, frame.width, frame.height, frame.history.map { it?.textureId }, frame.effectTimeUs)
    }

    override fun render(
        frameTextureId: Int,
        width: Int,
        height: Int,
        history: List<Int?>,
        timeUs: Long,
        effectTimeUs: Long,
    ) {
        draw(frameTextureId, width, height, history, effectTimeUs)
    }

    // The player calls the timed render; this draws the effect as it starts.
    override fun render(frameTextureId: Int, width: Int, height: Int, history: List<Int?>) {
        draw(frameTextureId, width, height, history, 0L)
    }

    private fun draw(frameTexture: Int, width: Int, height: Int, history: List<Int?>, effectTimeUs: Long) {
        shader.use()
        shader.setTexture("uFrame", frameTexture, 0)
        historyOffsetsUs.indices.forEach { k ->
            // A sampler must be bound even when the clip has not played that
            // far yet; the current frame stands in.
            shader.setTexture("uEarlier$k", history.getOrNull(k) ?: frameTexture, k + 1)
        }
        shader.setFloats("uSize", floatArrayOf(width.toFloat(), height.toFloat()))
        setUniforms(shader, effectTimeUs)
        shader.draw()
    }

    override fun release() {
        shader.release()
    }

    companion object {
        /**
         * [ShaderVideoEffect.PRELUDE] and a sampler per earlier frame,
         * `uEarlier0` the newest.
         */
        fun prelude(earlier: Int): String = buildString {
            append(ShaderVideoEffect.PRELUDE)
            for (k in 0 until earlier) append("uniform sampler2D uEarlier$k;\n")
        }
    }
}

/**
 * Time split: red shows the current frame, green the frame 100 ms earlier
 * and blue the one 200 ms earlier, so still parts keep their colours and
 * moving parts get rainbow ghosts.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
 * far the colours split, from the plain picture to the full split) and, for
 * an effect on the beat, `beatsUs`: the beats, in microseconds after the
 * effect's start. On the beat the colours only split on each hit and come
 * back together over half a second, as the zoom blur's streaks fade; see
 * [BlurHits].
 *
 * The earlier frames are kept whole: green and blue carry every still part of
 * the picture too, and a smaller copy would blur them.
 */
class TimeSplitVideoEffect(params: Map<String, Any?>) :
    EarlierFramesShaderEffect(
        FRAGMENT_SHADER,
        longArrayOf(TimeVideoEffects.frameOffsetUs(3), TimeVideoEffects.frameOffsetUs(6)),
        historyScale = 1f,
    ) {

    private val intensity = ShaderVideoEffect.intensityOf(params)

    private val beatsUs = BlurHits.beatsOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uStrength", BlurHits.strength(intensity, beatsUs, effectTimeUs))
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.timeSplit"

        private val FRAGMENT_SHADER = EarlierFramesShaderEffect.prelude(2) + """
uniform float uStrength;

void main() {
  vec3 now = tap(vTexCoord * uSize);
  vec3 split = vec3(
      now.r, texture2D(uEarlier0, vTexCoord).g, texture2D(uEarlier1, vTexCoord).b);
  gl_FragColor = vec4(mix(now, split, uStrength), 1.0);
}
"""
    }
}

/**
 * Long exposure: bright parts leave trails, so a torch or a sparkler can
 * paint light in a dark room.
 *
 * Each pixel takes the brightest of itself and of up to six earlier frames,
 * two frames apart, each counted only as far as it is bright and fading the
 * further back it lies. A still part looks the same in every frame and stays
 * as it is.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1):
 * longer trails, fading slower, and of less bright parts. The trails are
 * soft anyway, so the earlier frames are kept at half size.
 */
class LongExposureVideoEffect private constructor(private val intensity: Float, copies: Int) :
    EarlierFramesShaderEffect(
        fragmentShader(copies),
        LongArray(copies) { TimeVideoEffects.frameOffsetUs(2 * (it + 1)) },
        historyScale = 0.5f,
    ) {

    constructor(params: Map<String, Any?>) : this(
        ShaderVideoEffect.intensityOf(params),
        copiesOf(ShaderVideoEffect.intensityOf(params)),
    )

    /** How much of each earlier frame counts, newest first. */
    private val weights = FloatArray(copies) { k -> (0.7f + 0.25f * intensity).pow(k + 1) }

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        // A part starts to count from this brightness, fully 0.25 above it.
        shader.setFloat("uThreshold", 0.7f - 0.25f * intensity)
        weights.forEachIndexed { k, weight -> shader.setFloat("uWeight$k", weight) }
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.longExposure"

        /** How many earlier frames an effect at [intensity] reads: 2 to 6. */
        fun copiesOf(intensity: Float): Int = (2 + 4 * intensity).roundToInt().coerceIn(2, 6)

        private fun fragmentShader(copies: Int): String = buildString {
            append(EarlierFramesShaderEffect.prelude(copies))
            for (k in 0 until copies) append("uniform float uWeight$k;\n")
            append("uniform float uThreshold;\n")
            append("\n")
            append("vec3 trail(vec3 c, float weight) {\n")
            append("  float bright = smoothstep(uThreshold, uThreshold + 0.25, dot(c, vec3(0.299, 0.587, 0.114)));\n")
            append("  return c * (bright * weight);\n")
            append("}\n")
            append("\n")
            append("void main() {\n")
            append("  vec3 color = tap(vTexCoord * uSize);\n")
            for (k in 0 until copies) {
                append("  color = max(color, trail(texture2D(uEarlier$k, vTexCoord).rgb, uWeight$k));\n")
            }
            append("  gl_FragColor = vec4(color, 1.0);\n")
            append("}\n")
        }
    }
}

/**
 * Motion only: still parts go dark and moving parts glow, from the
 * difference to the frame before. Where a part moves, its edges differ the
 * most, so they light up as outlines.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1):
 * how dark the still parts go, down to black, and how much the moving parts
 * glow. The frame before is kept whole, so fine still detail does not count
 * as movement.
 */
class MotionOnlyVideoEffect(params: Map<String, Any?>) :
    EarlierFramesShaderEffect(
        FRAGMENT_SHADER,
        longArrayOf(TimeVideoEffects.frameOffsetUs(1)),
        historyScale = 1f,
    ) {

    private val intensity = ShaderVideoEffect.intensityOf(params)

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uIntensity", intensity)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.motionOnly"

        // A difference below 0.05 is the sensor's noise, not movement.
        private val FRAGMENT_SHADER = EarlierFramesShaderEffect.prelude(1) + """
uniform float uIntensity;

void main() {
  vec3 now = tap(vTexCoord * uSize);
  vec3 before = texture2D(uEarlier0, vTexCoord).rgb;
  float moved = smoothstep(0.05, 0.15, length(now - before));
  vec3 glow = min(now * (1.0 + 0.5 * uIntensity) + 0.1 * uIntensity, vec3(1.0));
  gl_FragColor = vec4(mix(now * (1.0 - uIntensity), glow, moved), 1.0);
}
"""
    }
}

/**
 * Stutter: the picture holds frames, so it plays at 6 to 12 frames a second
 * instead of the clip's 30.
 *
 * Each held frame is the first of its hold, at most four frames back, so the
 * effect draws one of the earlier frames whole; see [StutterHolds]. A frame
 * the clip has not played far enough back for yet is drawn as it is.
 *
 * Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: from
 * 12 frames a second down to 6) and, for an effect on the beat, `beatsUs`:
 * the beats, in microseconds after the effect's start. On the beat it only
 * stutters for half a second after each beat, its holds starting on the beat.
 */
class StutterVideoEffect(params: Map<String, Any?>) : CustomVideoEffectRenderer(), VideoFrameEffect {

    private val intensity = ShaderVideoEffect.intensityOf(params)

    private val beatsUs = BlurHits.beatsOf(params)

    override val historyOffsetsUs = LongArray(StutterHolds.MAX_BACK) { TimeVideoEffects.frameOffsetUs(it + 1) }

    // The held frame is the picture, so it is kept whole.
    override val historyScale = 1f

    private val shader = CustomVideoEffectShader(FRAGMENT_SHADER)

    override fun render(frame: CustomVideoEffectFrame) {
        draw(frame.textureId, frame.history.map { it?.textureId }, frame.effectTimeUs)
    }

    override fun render(
        frameTextureId: Int,
        width: Int,
        height: Int,
        history: List<Int?>,
        timeUs: Long,
        effectTimeUs: Long,
    ) {
        draw(frameTextureId, history, effectTimeUs)
    }

    override fun render(frameTextureId: Int, width: Int, height: Int, history: List<Int?>) {
        draw(frameTextureId, history, 0L)
    }

    private fun draw(frameTexture: Int, history: List<Int?>, effectTimeUs: Long) {
        val back = StutterHolds.framesBack(intensity, beatsUs, effectTimeUs)
        val held = if (back == 0) frameTexture else history.getOrNull(back - 1) ?: frameTexture
        shader.use()
        shader.setTexture("uFrame", held, 0)
        shader.draw()
    }

    override fun release() {
        shader.release()
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.stutter"

        private const val FRAGMENT_SHADER = """
precision mediump float;
uniform sampler2D uFrame;
varying vec2 vTexCoord;

void main() {
  gl_FragColor = vec4(texture2D(uFrame, vTexCoord).rgb, 1.0);
}
"""
    }
}

/**
 * Which earlier frame the stutter shows at a moment. Mirrors the Swift
 * `StutterHolds`.
 *
 * The picture holds a frame for a period of `1 / (12 - 6 × intensity)`
 * seconds, from the start of the effect's window or, on the beat, from each
 * beat for [BlurHits.HIT_US]. Within a hold it shows the hold's first frame,
 * as many frames back as have gone by since, rounded down with a millisecond
 * to spare.
 */
object StutterHolds {
    /** The furthest back a hold reaches: at 6 frames a second, five frames are held. */
    const val MAX_BACK = 4

    /**
     * How many frames back the frame shown [effectTimeUs] after the effect
     * started lies: 0 for the current frame, up to [MAX_BACK].
     */
    fun framesBack(intensity: Float, beatsUs: LongArray?, effectTimeUs: Long): Int {
        val sinceUs = if (beatsUs == null) {
            effectTimeUs
        } else {
            val last = beatsUs.lastOrNull { it <= effectTimeUs } ?: return 0
            (effectTimeUs - last).takeIf { it < BlurHits.HIT_US } ?: return 0
        }
        val periodUs = 1_000_000.0 / (12.0 - 6.0 * intensity)
        // Frame times are rounded down to the microsecond, so a frame can
        // start a hair before the hold it opens.
        val since = sinceUs + 1_000.0
        val intoHoldUs = since - floor(since / periodUs) * periodUs
        return floor(intoHoldUs / TimeVideoEffects.FRAME_US).toInt().coerceIn(0, MAX_BACK)
    }
}

/**
 * Time warp: each band of the picture comes from a different moment, the
 * top from now and each band below it from two frames further back, so
 * moving people bend and stretch, as in a slit-scan photograph.
 *
 * Neighbouring bands blend over the middle 30% of the way from one band's
 * middle to the next, so a moving edge steps rather than tears. Up to seven
 * earlier frames are read, as many as the intensity reaches down to; with the
 * current frame they take the eight texture units OpenGL ES 2.0 guarantees.
 *
 * Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1):
 * how far back the bottom of the picture reaches, up to 7 bands of two frames
 * each, 467 ms. The earlier frames are kept at half size, which keeps seven
 * of them, and the frames between them the preview keeps, to a quarter of the
 * memory.
 */
class TimeWarpVideoEffect private constructor(private val depth: Float, copies: Int) :
    EarlierFramesShaderEffect(
        fragmentShader(copies),
        LongArray(copies) { TimeVideoEffects.frameOffsetUs(2 * (it + 1)) },
        historyScale = 0.5f,
    ) {

    constructor(params: Map<String, Any?>) : this(
        depthOf(ShaderVideoEffect.intensityOf(params)),
        copiesOf(ShaderVideoEffect.intensityOf(params)),
    )

    override fun setUniforms(shader: CustomVideoEffectShader, effectTimeUs: Long) {
        shader.setFloat("uDepth", depth)
    }

    companion object {
        /** The id the Dart `CustomVideoEffect` names. */
        const val ID = "divine.timeWarp"

        private const val MAX_BANDS_BACK = 7

        /** How many bands back the bottom of the picture lies at [intensity]. */
        fun depthOf(intensity: Float): Float = MAX_BANDS_BACK * intensity

        /** How many earlier frames an effect at [intensity] reads: 1 to 7. */
        fun copiesOf(intensity: Float): Int = ceil(depthOf(intensity)).toInt().coerceIn(1, MAX_BANDS_BACK)

        private fun fragmentShader(copies: Int): String = buildString {
            append(EarlierFramesShaderEffect.prelude(copies))
            append("uniform float uDepth;\n")
            append("\n")
            append("// How much of band k a pixel t bands down shows: all of it near the band's\n")
            append("// middle, none from a whole band away, and in between the weights of two\n")
            append("// neighbouring bands add up to 1.\n")
            append("float band(float t, float k) {\n")
            append("  return 1.0 - smoothstep(0.35, 0.65, abs(t - k));\n")
            append("}\n")
            append("\n")
            append("void main() {\n")
            append("  float t = (1.0 - vTexCoord.y) * uDepth;\n")
            append("  vec3 color = tap(vTexCoord * uSize) * band(t, 0.0);\n")
            for (k in 0 until copies) {
                append("  color += texture2D(uEarlier$k, vTexCoord).rgb * band(t, ${k + 1}.0);\n")
            }
            append("  gl_FragColor = vec4(color, 1.0);\n")
            append("}\n")
        }
    }
}
