package com.divinevideo.divine_video_player

import android.content.Context
import android.graphics.Bitmap
import android.opengl.GLES20
import android.opengl.GLUtils
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram
import java.util.concurrent.ConcurrentHashMap
import java.util.IdentityHashMap
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.abs
import kotlin.math.roundToLong

/**
 * An effect the app draws on the player's frames, registered by id with
 * [VideoFrameEffects] and switched on from Dart with `setFrameEffects`.
 *
 * It receives earlier frames of the same clip, as many as [historyOffsetsUs]
 * asks for, so an effect such as an echo trail can be previewed. While
 * playing they come from what the player showed; after a seek the missing
 * ones are decoded from the clip's file.
 *
 * Every method runs on the player's GL thread with its context current.
 */
interface VideoFrameEffect {
    /** How far before the current frame each earlier frame lies, in µs of playback. */
    val historyOffsetsUs: LongArray

    /** The size earlier frames are kept at, relative to the video, 0.05..1. */
    val historyScale: Float get() = 1f

    /**
     * Draws the frame in [frameTextureId], a `GL_TEXTURE_2D` with its origin
     * at the bottom left, with the effect into the bound framebuffer.
     * [history] has one texture per offset, or null when the player has not
     * shown that far back in this clip.
     */
    fun render(frameTextureId: Int, width: Int, height: Int, history: List<Int?>)

    /** Releases the effect's GL objects. */
    fun release() {}
}

/** The frame effects the app registered, by id. */
object VideoFrameEffects {
    private val factories = ConcurrentHashMap<String, (Map<String, Any?>) -> VideoFrameEffect>()

    /**
     * Registers [factory] under [id]. The player calls it on its GL thread
     * with the params Dart sends, so the effect may compile shaders there.
     */
    @JvmStatic
    fun register(id: String, factory: (Map<String, Any?>) -> VideoFrameEffect) {
        factories[id] = factory
    }

    internal fun factory(id: String): ((Map<String, Any?>) -> VideoFrameEffect)? = factories[id]
}

/**
 * What the player's main thread tells the frame-effect stage on the GL
 * thread: which effects, which of them are in their window now, the clip's
 * speed, where the last seek went, and earlier frames decoded after it.
 */
internal class FrameEffectsState {
    /** An effect and its window on the player's timeline, either end open. */
    data class Config(val id: String, val params: Map<String, Any?>, val startUs: Long?, val endUs: Long?)

    /** A seek to [sourceUs] of clip [clipIndex]'s file. */
    class Seek(val generation: Int, val clipIndex: Int, val sourceUs: Long)

    /** A frame decoded from a clip's file: wanted for [targetUs], shown from [frameUs]. */
    class DecodedFrame(val targetUs: Long, val frameUs: Long, val bitmap: Bitmap)

    /** Earlier frames decoded from clip [clipIndex]'s file; they replace the previous ones. */
    class Fill(val clipIndex: Int, val frames: List<DecodedFrame>)

    @Volatile var configs: List<Config> = emptyList()
        private set
    @Volatile var configVersion = 0
        private set

    /** Per config, whether the playhead is inside its window. */
    @Volatile var enabled: BooleanArray = BooleanArray(0)

    /** The current clip's speed, which turns playback offsets into media time. */
    @Volatile var speed = 1f

    /** The offsets the effects ask for, published by the GL thread once it built them. */
    @Volatile var historyOffsetsUs: LongArray = LongArray(0)
    @Volatile var historyScale = 1f

    /** The [configVersion] [historyOffsetsUs] and [historyScale] belong to. */
    @Volatile var publishedConfigVersion = -1

    /** Called on the GL thread once it published the offsets of new effects. */
    @Volatile var onConfigPublished: (() -> Unit)? = null

    /** The last seek, which the first frame the player shows after it belongs to. */
    @Volatile var seek = Seek(0, NO_CLIP, 0L)
        private set

    /** Decoded frames the GL thread has not taken yet. */
    val pendingFill = AtomicReference<Fill?>()

    /**
     * A move of the player to [timelineUs] on its timeline, which the first
     * frame after the next flush shows; null when that place is not known.
     */
    class Reposition(val generation: Int, val timelineUs: Long?)

    /**
     * The player's timeline as its frames step through it: its [clips] one
     * after the other, starting over at the end when [looping].
     *
     * Frames step through each clip's media time, which a clip at a speed
     * of its own plays faster or slower than the timeline.
     */
    class Timeline(val clips: List<Clip>, val looping: Boolean) {
        /** A clip [mediaUs] of media long, played at [speed]. */
        data class Clip(val mediaUs: Long, val speed: Float) {
            /** How long the clip lasts on the timeline. */
            val timelineUs: Long = (mediaUs / speed.toDouble()).roundToLong()
        }

        /** How long the timeline lasts. */
        val lengthUs: Long = clips.sumOf { it.timelineUs }

        /** How much media the frames of one pass through the timeline span. */
        val mediaLengthUs: Long = clips.sumOf { it.mediaUs }

        /** How far into the media of all clips [timelineUs] lies. */
        fun mediaUsAt(timelineUs: Long): Long {
            var timelineStartUs = 0L
            var mediaStartUs = 0L
            for ((index, clip) in clips.withIndex()) {
                if (timelineUs < timelineStartUs + clip.timelineUs || index == clips.lastIndex) {
                    return mediaStartUs + ((timelineUs - timelineStartUs) * clip.speed.toDouble()).roundToLong()
                }
                timelineStartUs += clip.timelineUs
                mediaStartUs += clip.mediaUs
            }
            return timelineUs
        }

        /** Where on the timeline [mediaUs] into the media of all clips lies. */
        fun timelineUsAt(mediaUs: Long): Long {
            var timelineStartUs = 0L
            var mediaStartUs = 0L
            for ((index, clip) in clips.withIndex()) {
                if (mediaUs < mediaStartUs + clip.mediaUs || index == clips.lastIndex) {
                    return timelineStartUs + ((mediaUs - mediaStartUs) / clip.speed.toDouble()).roundToLong()
                }
                timelineStartUs += clip.timelineUs
                mediaStartUs += clip.mediaUs
            }
            return mediaUs
        }
    }

    /** The last move of the player, see [repositionTo]. */
    @Volatile var reposition = Reposition(0, null)
        private set

    /** The timeline frames step through, or null while it is not known. */
    @Volatile var timeline: Timeline? = null

    /** Where the main thread last saw the playhead, in µs on the timeline. */
    @Volatile var playheadUs = 0L

    fun setConfigs(configs: List<Config>) {
        this.configs = configs
        enabled = BooleanArray(configs.size) { true }
        configVersion++
    }

    /** Records a seek to [sourceUs] of clip [clipIndex]'s file. Call before the player seeks. */
    @Synchronized
    fun seekTo(clipIndex: Int, sourceUs: Long) {
        seek = Seek(seek.generation + 1, clipIndex, sourceUs)
    }

    /**
     * Records that the player moves to [timelineUs] on its timeline. Call
     * before every seek or prepare, so the frame-effect stage can tell where
     * each frame lies.
     */
    @Synchronized
    fun repositionTo(timelineUs: Long?) {
        reposition = Reposition(reposition.generation + 1, timelineUs)
    }

    companion object {
        const val NO_CLIP = -1
    }
}

/**
 * The player's frame-effect stage: draws the active [VideoFrameEffect]s on
 * every frame and keeps the earlier frames they ask for.
 */
@UnstableApi
internal class FrameEffectsGlEffect(private val state: FrameEffectsState) : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram {
        if (useHdr) throw VideoFrameProcessingException("Frame effects do not support HDR")
        return Program(state)
    }

    override fun isNoOp(inputWidth: Int, inputHeight: Int): Boolean = false

    /**
     * Earlier frames come from two places. While playing, the frames the
     * player showed are kept, by their presentation time. After a seek, the
     * frames decoded from the clip's file stand in for the ones not shown
     * yet; they are matched by time in the file, which the first frame shown
     * after the seek ties to the presentation times.
     */
    @UnstableApi
    private class Program(private val state: FrameEffectsState) :
        BaseGlShaderProgram(/* useHighPrecisionColorComponents= */ false, /* texturePoolCapacity= */ 1) {

        private data class Entry(val timeUs: Long, val slot: Int)

        private class Decoded(val targetUs: Long, val frameUs: Long, val texture: Int)

        private val copy = GlProgram(VERTEX_SHADER, COPY_SHADER)
        private var effects: List<VideoFrameEffect?> = emptyList()
        private var version = -1
        private var maxOffsetUs = 0L

        /** The seek [anchorUs] belongs to, and the last seek a flush followed. */
        private var seek: FrameEffectsState.Seek? = null
        private var anchorUs: Long? = null
        private var flushedGeneration = -1

        /**
         * The move the next frame shows, taken at a flush and at the first
         * frame; and the frame that showed the last move, by its presentation
         * time and its place on the timeline.
         */
        private var pendingReposition: FrameEffectsState.Reposition? = null
        private var timelineAnchor: Pair<Long, Long>? = null
        private var lastPresentationUs: Long? = null

        private var width = 0
        private var height = 0
        private var historyWidth = 0
        private var historyHeight = 0
        private val history = ArrayList<Entry>()
        private val slotTextures = ArrayList<Int>()
        private val slotFbos = ArrayList<Int>()
        private val freeSlots = ArrayDeque<Int>()
        private var decodedClip = FrameEffectsState.NO_CLIP
        private val decoded = ArrayList<Decoded>()
        private val tempTextures = intArrayOf(NONE, NONE)
        private val tempFbos = intArrayOf(NONE, NONE)

        override fun configure(inputWidth: Int, inputHeight: Int): Size {
            if (inputWidth != width || inputHeight != height) {
                width = inputWidth
                height = inputHeight
                deleteTextures()
                updateHistorySize()
            }
            return Size(inputWidth, inputHeight)
        }

        override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
            try {
                val outputFbo = currentFramebuffer()
                syncEffects()
                anchor(presentationTimeUs)
                anchorTimeline(presentationTimeUs)
                applyFill()

                val speed = state.speed.coerceAtLeast(0.01f)
                val sourceUs = frameSourceUs(presentationTimeUs)
                val enabled = frameWindows(presentationTimeUs) ?: state.enabled
                val active = effects.indices.filter { i ->
                    effects[i] != null && enabled.getOrElse(i) { true }
                }
                if (active.isEmpty()) {
                    drawCopy(inputTexId)
                } else {
                    var source = inputTexId
                    active.forEachIndexed { n, i ->
                        val effect = effects[i]!!
                        val last = n == active.lastIndex
                        if (last) {
                            GlUtil.focusFramebufferUsingCurrentContext(outputFbo, width, height)
                        } else {
                            focusTemp(n % 2)
                        }
                        val earlier = effect.historyOffsetsUs.map { offset ->
                            val backUs = (offset * speed).toLong()
                            val limit = presentationTimeUs - backUs + TOLERANCE_US
                            history.lastOrNull { it.timeUs <= limit }?.let { slotTextures[it.slot] }
                                ?: sourceUs?.let { decodedTexture(it - backUs) }
                        }
                        effect.render(source, width, height, earlier)
                        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
                        if (!last) source = tempTextures[n % 2]
                    }
                }

                // One frame per [KEEP_INTERVAL_US] of playback is plenty for
                // a trail and bounds the history: a fast clip at a high frame
                // rate would otherwise keep a hundred frames and more.
                val keepIntervalUs = (KEEP_INTERVAL_US * speed).toLong()
                if (maxOffsetUs > 0 && history.none { abs(it.timeUs - presentationTimeUs) < keepIntervalUs }) {
                    keep(inputTexId, presentationTimeUs, speed)
                }
                GlUtil.focusFramebufferUsingCurrentContext(outputFbo, width, height)
                GlUtil.checkGlError()
            } catch (e: Exception) {
                throw VideoFrameProcessingException(e, presentationTimeUs)
            }
        }

        /**
         * Ties the first frame after a seek's flush to that seek. Frames of
         * the previous position can still arrive after the main thread
         * recorded a seek, and only the flush tells them apart. The player's
         * own seeks, such as a loop's, record none and tie nothing.
         */
        private fun anchor(presentationTimeUs: Long) {
            val current = state.seek
            if (flushedGeneration == current.generation && seek?.generation != current.generation) {
                seek = current
                anchorUs = presentationTimeUs
                clearHistory()
            } else if (history.isNotEmpty() &&
                presentationTimeUs < history.last().timeUs - REDRAW_SLACK_US
            ) {
                // A new clip or loop starts its stream over, and the time in
                // the file no longer follows from the anchor.
                clearHistory()
                anchorUs = null
            }
        }

        /** Where the frame at [presentationTimeUs] lies in the decoded clip's file, if that is known. */
        private fun frameSourceUs(presentationTimeUs: Long): Long? {
            val anchor = anchorUs ?: return null
            val seek = seek ?: return null
            if (seek.clipIndex != decodedClip) return null
            return seek.sourceUs + (presentationTimeUs - anchor)
        }

        /**
         * Ties the first frame after a flush, and the very first frame, to
         * the player's last move. From there frames step through the
         * timeline in step with their presentation times, across clip
         * changes and loops; a stream that starts over unasked unties them.
         */
        private fun anchorTimeline(presentationTimeUs: Long) {
            val last = lastPresentationUs
            if (last == null) pendingReposition = state.reposition
            val pending = pendingReposition
            if (pending != null) {
                timelineAnchor = pending.timelineUs?.let { presentationTimeUs to it }
                pendingReposition = null
            } else if (last != null && presentationTimeUs < last - REDRAW_SLACK_US) {
                timelineAnchor = null
            }
            lastPresentationUs = presentationTimeUs
        }

        /**
         * Which effects are in their window at the frame itself, or null
         * when its place on the timeline is not known; the playhead the main
         * thread last saw stands in then. The pipeline runs a few frames
         * ahead of the playhead, so only the frame's own time puts a window
         * on the frames it covers.
         */
        private fun frameWindows(presentationTimeUs: Long): BooleanArray? {
            val (anchorPresentationUs, anchorTimelineUs) = timelineAnchor ?: return null
            val timeline = state.timeline ?: return null
            val timelineUs = frameTimelineUs(
                presentationTimeUs, anchorPresentationUs, anchorTimelineUs, timeline,
            )
            if (!isNearPlayhead(timelineUs, state.playheadUs, timeline)) return null
            return effectWindowsAt(state.configs, timelineUs)
        }

        /**
         * The decoded frame for [sourceUs]: the one decoded for the nearest
         * time, if that lies close enough. While scrubbing, the frames
         * decoded for where the playhead just was serve the next positions.
         */
        private fun decodedTexture(sourceUs: Long): Int? =
            nearestDecodedFrame(decoded.map { it.targetUs to it.frameUs }, sourceUs)
                ?.let { decoded[it].texture }

        /** Builds the effects again when Dart switched to others. */
        private fun syncEffects() {
            val current = state.configVersion
            if (current == version) return
            version = current
            effects.forEach { it?.release() }
            effects = state.configs.map { config ->
                val effect = VideoFrameEffects.factory(config.id)?.invoke(config.params)
                if (effect == null) {
                    DivineVideoPlayerLog.warning(
                        "No frame effect is registered under ${config.id}",
                        name = "DivineVideoPlayer.Effects",
                    )
                }
                effect
            }
            val offsets = effects.filterNotNull().flatMap { it.historyOffsetsUs.toList() }
            maxOffsetUs = offsets.maxOrNull() ?: 0L
            state.historyOffsetsUs = offsets.distinct().sorted().toLongArray()
            val scale = effects.filterNotNull().minOfOrNull { it.historyScale } ?: 1f
            state.historyScale = scale.coerceIn(0.05f, 1f)
            // The frames kept so far stay useful: the history is keyed by time.
            updateHistorySize()
            state.publishedConfigVersion = current
            state.onConfigPublished?.invoke()
        }

        private fun updateHistorySize() {
            val scale = state.historyScale
            val w = maxOf(1, Math.round(width * scale))
            val h = maxOf(1, Math.round(height * scale))
            if (w != historyWidth || h != historyHeight) {
                deleteSlots()
                historyWidth = w
                historyHeight = h
            }
        }

        private fun clearHistory() {
            for (entry in history) freeSlots += entry.slot
            history.clear()
        }

        /** Swaps in the frames decoded last, each bitmap uploaded once. */
        private fun applyFill() {
            val fill = state.pendingFill.getAndSet(null) ?: return
            deleteDecoded()
            decodedClip = fill.clipIndex
            val textures = IdentityHashMap<Bitmap, Int>()
            for (frame in fill.frames) {
                val texture = textures.getOrPut(frame.bitmap) { upload(frame.bitmap) }
                decoded += Decoded(frame.targetUs, frame.frameUs, texture)
            }
            textures.keys.forEach { it.recycle() }
        }

        private fun upload(bitmap: Bitmap): Int {
            val ids = IntArray(1)
            GLES20.glGenTextures(1, ids, 0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, ids[0])
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
            return ids[0]
        }

        /** Copies the frame into a history slot and drops what no later frame needs. */
        private fun keep(inputTexId: Int, timeUs: Long, speed: Float) {
            val slot = freeSlots.removeFirstOrNull() ?: newSlot()
            GlUtil.focusFramebufferUsingCurrentContext(slotFbos[slot], historyWidth, historyHeight)
            drawCopy(inputTexId)
            val index = history.indexOfFirst { it.timeUs > timeUs }.let { if (it < 0) history.size else it }
            history.add(index, Entry(timeUs, slot))
            val limit = timeUs - (maxOffsetUs * speed).toLong() + TOLERANCE_US
            val oldestNeeded = history.indexOfLast { it.timeUs <= limit }
            repeat(maxOf(0, oldestNeeded)) { freeSlots += history.removeAt(0).slot }
            while (history.size > MAX_FRAMES) freeSlots += history.removeAt(0).slot
        }

        private fun drawCopy(textureId: Int) {
            copy.use()
            copy.setSamplerTexIdUniform("uTexSampler", textureId, 0)
            val vertices = GlUtil.getNormalizedCoordinateBounds()
            copy.setBufferAttribute("aFramePosition", vertices, if (vertices.size == 8) 2 else 4)
            copy.bindAttributesAndUniforms()
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        }

        private fun focusTemp(index: Int) {
            if (tempTextures[index] == NONE) {
                tempTextures[index] = GlUtil.createTexture(width, height, false)
                tempFbos[index] = GlUtil.createFboForTexture(tempTextures[index])
            }
            GlUtil.focusFramebufferUsingCurrentContext(tempFbos[index], width, height)
        }

        private fun newSlot(): Int {
            val texture = GlUtil.createTexture(historyWidth, historyHeight, false)
            slotTextures += texture
            slotFbos += GlUtil.createFboForTexture(texture)
            return slotTextures.size - 1
        }

        private fun deleteSlots() {
            for (fbo in slotFbos) GlUtil.deleteFbo(fbo)
            for (texture in slotTextures) GlUtil.deleteTexture(texture)
            slotFbos.clear()
            slotTextures.clear()
            freeSlots.clear()
            history.clear()
        }

        private fun deleteDecoded() {
            decoded.map { it.texture }.distinct().forEach { GlUtil.deleteTexture(it) }
            decoded.clear()
            decodedClip = FrameEffectsState.NO_CLIP
        }

        private fun deleteTextures() {
            deleteSlots()
            deleteDecoded()
            for (i in 0..1) {
                if (tempFbos[i] != NONE) GlUtil.deleteFbo(tempFbos[i])
                if (tempTextures[i] != NONE) GlUtil.deleteTexture(tempTextures[i])
                tempFbos[i] = NONE
                tempTextures[i] = NONE
            }
        }

        // A seek flushes the stage; the first frame after it is the one the
        // seek asked for, which [anchor] ties to the seek. The history stays
        // until then, so a flush of a paused redraw does not lose it.
        override fun flush() {
            super.flush()
            flushedGeneration = state.seek.generation
            pendingReposition = state.reposition
            timelineAnchor = null
        }

        override fun release() {
            super.release()
            try {
                effects.forEach { it?.release() }
                deleteTextures()
                copy.delete()
            } catch (e: Exception) {
                throw VideoFrameProcessingException(e)
            }
        }

        private fun currentFramebuffer(): Int {
            val binding = IntArray(1)
            GLES20.glGetIntegerv(GLES20.GL_FRAMEBUFFER_BINDING, binding, 0)
            return binding[0]
        }

        companion object {
            private const val NONE = -1
            private const val TOLERANCE_US = 1_000L
            private const val REDRAW_SLACK_US = 100_000L

            private const val KEEP_INTERVAL_US = 30_000L
            private const val MAX_FRAMES = 64

            private const val VERTEX_SHADER =
                "attribute vec4 aFramePosition;\n" +
                "varying vec2 vTexCoord;\n" +
                "void main() {\n" +
                "  gl_Position = aFramePosition;\n" +
                "  vTexCoord = aFramePosition.xy * 0.5 + 0.5;\n" +
                "}"

            private const val COPY_SHADER =
                "#ifdef GL_FRAGMENT_PRECISION_HIGH\n" +
                "precision highp float;\n" +
                "#else\n" +
                "precision mediump float;\n" +
                "#endif\n" +
                "uniform sampler2D uTexSampler;\n" +
                "varying vec2 vTexCoord;\n" +
                "void main() {\n" +
                "  gl_FragColor = texture2D(uTexSampler, vTexCoord);\n" +
                "}"
        }
    }
}

/** How far from the time it was decoded for a decoded frame may stand in. */
internal const val MAX_DECODED_DRIFT_US = 150_000L

/**
 * The index of the decoded frame to show for [sourceUs], from frames given
 * as `(targetUs, frameUs)`: the one decoded for the nearest target, if that
 * lies within [MAX_DECODED_DRIFT_US], and never one shown after [sourceUs].
 * While scrubbing, the frames decoded for where the playhead just was serve
 * the next positions.
 */
internal fun nearestDecodedFrame(frames: List<Pair<Long, Long>>, sourceUs: Long): Int? =
    frames.indices
        .filter { i ->
            val (targetUs, frameUs) = frames[i]
            abs(targetUs - sourceUs) <= MAX_DECODED_DRIFT_US && frameUs <= sourceUs + 1_000L
        }
        .minByOrNull { abs(frames[it].first - sourceUs) }

/**
 * Where a frame lies on the player's timeline: as far into the clips' media
 * past [anchorTimelineUs], where the anchoring frame lies, as the frame's
 * presentation time is past that frame's, wrapped at the end of a looping
 * [timeline].
 */
internal fun frameTimelineUs(
    presentationTimeUs: Long,
    anchorPresentationUs: Long,
    anchorTimelineUs: Long,
    timeline: FrameEffectsState.Timeline,
): Long {
    val mediaUs = timeline.mediaUsAt(anchorTimelineUs) + (presentationTimeUs - anchorPresentationUs)
    val wrappedUs = if (timeline.looping && timeline.mediaLengthUs > 0) {
        Math.floorMod(mediaUs, timeline.mediaLengthUs)
    } else {
        mediaUs
    }
    return timeline.timelineUsAt(wrappedUs)
}

/**
 * Whether [timelineUs] lies close enough to [playheadUs] for its anchor to
 * be trusted. Frames run a few frames ahead of a playhead the main thread
 * reads every 200 ms; one farther off was anchored to a move it does not
 * belong to.
 */
internal fun isNearPlayhead(timelineUs: Long, playheadUs: Long, timeline: FrameEffectsState.Timeline): Boolean {
    var distanceUs = abs(timelineUs - playheadUs)
    if (timeline.looping && timeline.lengthUs > 0) {
        distanceUs = minOf(distanceUs, timeline.lengthUs - distanceUs.coerceAtMost(timeline.lengthUs))
    }
    return distanceUs <= MAX_PLAYHEAD_DISTANCE_US
}

/** How far a frame may lie from the playhead the main thread last saw. */
internal const val MAX_PLAYHEAD_DISTANCE_US = 600_000L

/** Per config, whether [timelineUs] lies in its window. */
internal fun effectWindowsAt(configs: List<FrameEffectsState.Config>, timelineUs: Long): BooleanArray =
    BooleanArray(configs.size) { i ->
        val config = configs[i]
        (config.startUs == null || timelineUs >= config.startUs) &&
            (config.endUs == null || timelineUs < config.endUs)
    }
