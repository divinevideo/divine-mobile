package com.divinevideo.divine_video_player

import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Timeline
import androidx.media3.common.util.ExperimentalApi
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.drm.DrmSessionManagerProvider
import androidx.media3.exoplayer.source.ClippingMediaPeriod
import androidx.media3.exoplayer.source.ForwardingTimeline
import androidx.media3.exoplayer.source.MediaPeriod
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.WrappingMediaSource
import androidx.media3.exoplayer.upstream.Allocator
import androidx.media3.exoplayer.upstream.CmcdConfiguration
import androidx.media3.exoplayer.upstream.LoadErrorHandlingPolicy
import androidx.media3.exoplayer.util.ReleasableExecutor
import androidx.media3.extractor.text.SubtitleParser
import com.google.common.base.Supplier

/**
 * Asks for a clip to end where the shorter of its video and audio tracks does,
 * and to begin where its picture does.
 *
 * Carried as the media item's tag; [CommonTrackEndMediaSourceFactory] turns
 * it into a [CommonTrackEndMediaSource]. [requestedEndUs] is the caller's own
 * end, or [C.TIME_END_OF_SOURCE] for none — the track end may only shorten it.
 */
internal data class CommonTrackEndClip(val requestedEndUs: Long)

/**
 * Where a clip whose tracks end at [videoEndUs] and [audioEndUs] should stop,
 * or `null` when it should play to [requestedEndUs] (or its own end) as it is.
 *
 * The container's duration is the *longer* track, so playing to it leaves a
 * stretch where the shorter one has already run out — a frozen last frame or
 * silence, and on a looping player that stretch is the seam. Encoders and
 * muxers leave a frame or two of it; anything past [MAX_COMMON_TRACK_END_TRIM_US],
 * or past [MAX_COMMON_TRACK_END_TRIM_RATIO] of what plays, is taken to be the
 * creator's own and left. Clamping only ever shortens: an earlier requested
 * end still wins.
 */
internal fun commonTrackEndUs(
    requestedEndUs: Long,
    videoEndUs: Long,
    audioEndUs: Long,
    startUs: Long = 0L,
): Long? {
    if (videoEndUs <= 0 || audioEndUs <= 0) return null
    val containerEndUs = maxOf(videoEndUs, audioEndUs)
    val playbackEndUs =
        if (requestedEndUs == C.TIME_END_OF_SOURCE || requestedEndUs == C.TIME_UNSET) {
            containerEndUs
        } else {
            minOf(requestedEndUs, containerEndUs)
        }
    val commonEndUs = minOf(videoEndUs, audioEndUs)
    val trimUs = playbackEndUs - commonEndUs
    val playableUs = playbackEndUs - startUs
    if (commonEndUs <= startUs || trimUs <= 0 || playableUs <= 0) return null
    val limitUs = minOf(
        MAX_COMMON_TRACK_END_TRIM_US,
        (playableUs * MAX_COMMON_TRACK_END_TRIM_RATIO).toLong(),
    )
    return commonEndUs.takeIf { trimUs <= limitUs }
}

/**
 * Longest tail treated as an encoder/muxer track-end mismatch.
 *
 * Mirrored independently by `maxCommonTrackEndTrimMs` in the Apple
 * implementation (`DivineVideoPlayerInstance.swift`) — there is no shared
 * constant between the two platforms, so a retune here needs the same
 * change there. `loop_seam_trim_contract_test.dart` asserts the two stay
 * equal.
 */
internal const val MAX_COMMON_TRACK_END_TRIM_US = 500_000L

/**
 * Largest share of a clip the track-end clamp may take.
 *
 * Mirrored independently by `maxCommonTrackEndTrimRatio` in the Apple
 * implementation; see [MAX_COMMON_TRACK_END_TRIM_US].
 */
internal const val MAX_COMMON_TRACK_END_TRIM_RATIO = 0.10

/**
 * Where a clip whose first frame is shown at [videoStartUs] should begin, or
 * zero when it should begin at the top of the container.
 *
 * An initial empty edit on the video track shows nothing new until
 * [videoStartUs]. Played once, that is a moment of black or of the poster;
 * looped, it is the previous lap's last frame held that much longer at every
 * restart. Every Divine derivative carries 21–23 ms of it — the AAC encoder's
 * priming, which the transcoder's muxer offsets the picture by — so on a
 * 30 fps clip the restart frame stayed up for ~56 ms instead of 33. Starting
 * the clip at the first frame also drops the sound under that gap, which on
 * those files is priming, not content.
 *
 * Bounded like the end: only a lead of at most [MAX_LEADING_VIDEO_GAP_US], and
 * at most [MAX_COMMON_TRACK_END_TRIM_RATIO] of what plays, is taken to be the
 * muxer's rather than the creator's.
 */
internal fun leadingVideoGapUs(videoStartUs: Long, endUs: Long): Long {
    if (videoStartUs <= 0 || endUs <= videoStartUs) return 0L
    val limitUs = minOf(
        MAX_LEADING_VIDEO_GAP_US,
        (endUs * MAX_COMMON_TRACK_END_TRIM_RATIO).toLong(),
    )
    return if (videoStartUs <= limitUs) videoStartUs else 0L
}

/** Longest lead before the first frame treated as a muxer's empty edit. */
internal const val MAX_LEADING_VIDEO_GAP_US = 100_000L

/**
 * Hands every item tagged with a [CommonTrackEndClip] to a
 * [CommonTrackEndMediaSource]; everything else passes straight through.
 *
 * [trackEndsFor] looks up the `[videoEndUs, audioEndUs, videoStartUs]` the
 * player's own extractor recorded for a URI (see
 * [TrackEndCapturingExtractorsFactory]).
 */
@UnstableApi
internal class CommonTrackEndMediaSourceFactory(
    private val delegate: MediaSource.Factory,
    private val trackEndsFor: (uri: String) -> LongArray?,
) : MediaSource.Factory {

    override fun createMediaSource(mediaItem: MediaItem): MediaSource {
        val source = delegate.createMediaSource(mediaItem)
        val localConfiguration = mediaItem.localConfiguration ?: return source
        val clip = localConfiguration.tag as? CommonTrackEndClip ?: return source
        val uri = localConfiguration.uri.toString()
        return CommonTrackEndMediaSource(source, clip.requestedEndUs) { trackEndsFor(uri) }
    }

    override fun getSupportedTypes(): IntArray = delegate.supportedTypes

    override fun setDrmSessionManagerProvider(
        drmSessionManagerProvider: DrmSessionManagerProvider,
    ): MediaSource.Factory = apply {
        delegate.setDrmSessionManagerProvider(drmSessionManagerProvider)
    }

    override fun setLoadErrorHandlingPolicy(
        loadErrorHandlingPolicy: LoadErrorHandlingPolicy,
    ): MediaSource.Factory = apply {
        delegate.setLoadErrorHandlingPolicy(loadErrorHandlingPolicy)
    }

    override fun setCmcdConfigurationFactory(
        cmcdConfigurationFactory: CmcdConfiguration.Factory,
    ): MediaSource.Factory = apply {
        delegate.setCmcdConfigurationFactory(cmcdConfigurationFactory)
    }

    @Deprecated("Forwarded to the wrapped factory, which is where it is deprecated.")
    @ExperimentalApi
    override fun experimentalParseSubtitlesDuringExtraction(
        parseSubtitlesDuringExtraction: Boolean,
    ): MediaSource.Factory = apply {
        @Suppress("DEPRECATION")
        delegate.experimentalParseSubtitlesDuringExtraction(parseSubtitlesDuringExtraction)
    }

    override fun setSubtitleParserFactory(
        subtitleParserFactory: SubtitleParser.Factory,
    ): MediaSource.Factory = apply {
        delegate.setSubtitleParserFactory(subtitleParserFactory)
    }

    @ExperimentalApi
    override fun experimentalSetCodecsToParseWithinGopSampleDependencies(
        codecsToParseWithinGopSampleDependencies: Int,
    ): MediaSource.Factory = apply {
        delegate.experimentalSetCodecsToParseWithinGopSampleDependencies(
            codecsToParseWithinGopSampleDependencies,
        )
    }

    override fun setDownloadExecutor(
        downloadExecutor: Supplier<ReleasableExecutor>,
    ): MediaSource.Factory = apply {
        delegate.setDownloadExecutor(downloadExecutor)
    }
}

/**
 * Clips a source to its common track end, and to its first frame, the moment
 * those are known.
 *
 * `ClippingMediaSource` takes its end from the media item, so an end learned
 * after the item was handed over can only be applied by replacing the item —
 * which re-prepares the source, and on a playing video froze the first loop
 * restart for ~300 ms. Here the end is set when the child publishes the
 * timeline that carries the real duration. For a progressive source that
 * happens as the `moov` box is parsed, after [TrackEndCapturingExtractorsFactory]
 * has recorded the track lengths and before the period reports itself
 * prepared, so the renderers never read a sample past it and the first lap is
 * already the right length.
 *
 * Periods are clipped in place through [ClippingMediaPeriod.updateClipping],
 * the same call `ClippingMediaSource` makes when a live window moves. A start
 * learned that way arrives with the source's first real timeline, which
 * replaces a placeholder, so the player moves the period it has not prepared
 * yet to the new start rather than playing the gap; every repeat is created
 * there.
 */
@UnstableApi
internal class CommonTrackEndMediaSource(
    mediaSource: MediaSource,
    private val requestedEndUs: Long,
    private val trackEnds: () -> LongArray?,
) : WrappingMediaSource(mediaSource) {

    private val mediaPeriods = ArrayList<ClippingMediaPeriod>()
    private val window = Timeline.Window()
    private var periodStartUs = 0L
    private var periodEndUs = requestedEndUs

    override fun canUpdateMediaItem(mediaItem: MediaItem): Boolean =
        mediaItem.localConfiguration?.tag == getMediaItem().localConfiguration?.tag &&
            super.canUpdateMediaItem(mediaItem)

    override fun createPeriod(
        id: MediaSource.MediaPeriodId,
        allocator: Allocator,
        startPositionUs: Long,
    ): MediaPeriod {
        // A clip that starts at zero starts on a key frame, so there is no
        // initial discontinuity to report.
        val mediaPeriod = ClippingMediaPeriod(
            mediaSource.createPeriod(id, allocator, startPositionUs),
            /* enableInitialDiscontinuity= */ false,
            periodStartUs,
            periodEndUs,
        )
        mediaPeriods.add(mediaPeriod)
        return mediaPeriod
    }

    override fun releasePeriod(mediaPeriod: MediaPeriod) {
        check(mediaPeriods.remove(mediaPeriod)) {
            "releasePeriod called for a period this source did not create: $mediaPeriod"
        }
        mediaSource.releasePeriod((mediaPeriod as ClippingMediaPeriod).mediaPeriod)
    }

    override fun onChildSourceInfoRefreshed(newTimeline: Timeline) {
        refreshSourceInfo(clip(newTimeline))
    }

    /**
     * Clips every live period to the start and end [newTimeline] and the
     * recorded track bounds call for, and returns the timeline to publish in
     * its place.
     */
    internal fun clip(newTimeline: Timeline): Timeline {
        if (newTimeline.windowCount != 1 || newTimeline.periodCount != 1) return newTimeline
        newTimeline.getWindow(/* windowIndex= */ 0, window)
        val ends = trackEnds()?.takeIf { it.size >= 2 }
        val clipEndUs = clipEndUs(ends)
        val clipStartUs = clipStartUs(ends, clipEndUs)
        periodStartUs = window.positionInFirstPeriodUs + clipStartUs
        periodEndUs = if (clipEndUs == C.TIME_END_OF_SOURCE) {
            C.TIME_END_OF_SOURCE
        } else {
            window.positionInFirstPeriodUs + clipEndUs
        }
        mediaPeriods.forEach { it.updateClipping(periodStartUs, periodEndUs) }
        return if (clipStartUs == 0L && clipEndUs == C.TIME_END_OF_SOURCE) {
            newTimeline
        } else {
            TrackBoundsTimeline(newTimeline, clipStartUs, clipEndUs)
        }
    }

    /** The end the clip plays to: the caller's, tightened to the tracks'. */
    private fun clipEndUs(ends: LongArray?): Long {
        val commonEndUs = ends?.let {
            commonTrackEndUs(requestedEndUs, videoEndUs = it[0], audioEndUs = it[1])
        }
        return when {
            commonEndUs != null -> commonEndUs
            requestedEndUs == C.TIME_UNSET -> C.TIME_END_OF_SOURCE
            else -> requestedEndUs
        }
    }

    /** Where the clip starts: its first frame, when that trails zero a little. */
    private fun clipStartUs(ends: LongArray?, clipEndUs: Long): Long {
        if (ends == null || ends.size < 3) return 0L
        val endUs = if (clipEndUs == C.TIME_END_OF_SOURCE) ends[0] else clipEndUs
        return leadingVideoGapUs(videoStartUs = ends[2], endUs = endUs)
    }
}

/**
 * A single-window, single-period timeline played from [startUs] to [endUs] of
 * its window — `ClippingMediaSource`'s own timeline, for a clip whose bounds
 * arrive with the source's timeline instead of with the media item.
 * [endUs] may be [C.TIME_END_OF_SOURCE] for none.
 */
@UnstableApi
internal class TrackBoundsTimeline(
    timeline: Timeline,
    private val startUs: Long,
    endUs: Long,
) : ForwardingTimeline(timeline) {

    private val endUs: Long
    private val durationUs: Long
    private val isDynamic: Boolean

    init {
        val window = timeline.getWindow(/* windowIndex= */ 0, Timeline.Window())
        var resolvedEndUs = if (endUs == C.TIME_END_OF_SOURCE) window.durationUs else endUs
        if (window.durationUs != C.TIME_UNSET && resolvedEndUs > window.durationUs) {
            resolvedEndUs = window.durationUs
        }
        this.endUs = resolvedEndUs
        durationUs = if (resolvedEndUs == C.TIME_UNSET) {
            C.TIME_UNSET
        } else {
            (resolvedEndUs - startUs).coerceAtLeast(0L)
        }
        isDynamic = window.isDynamic &&
            (resolvedEndUs == C.TIME_UNSET ||
                (window.durationUs != C.TIME_UNSET && resolvedEndUs == window.durationUs))
    }

    override fun getWindow(
        windowIndex: Int,
        window: Window,
        defaultPositionProjectionUs: Long,
    ): Window {
        timeline.getWindow(/* windowIndex= */ 0, window, /* defaultPositionProjectionUs= */ 0)
        window.positionInFirstPeriodUs += startUs
        window.durationUs = durationUs
        window.isDynamic = isDynamic
        if (window.defaultPositionUs != C.TIME_UNSET) {
            var defaultUs = maxOf(window.defaultPositionUs, startUs)
            if (endUs != C.TIME_UNSET) defaultUs = minOf(defaultUs, endUs)
            window.defaultPositionUs = defaultUs - startUs
        }
        return window
    }

    override fun getPeriod(periodIndex: Int, period: Period, setIds: Boolean): Period {
        timeline.getPeriod(/* periodIndex= */ 0, period, setIds)
        val isPlaceholder = period.isPlaceholder
        val positionInWindowUs = period.positionInWindowUs - startUs
        val periodDurationUs = if (durationUs == C.TIME_UNSET) {
            C.TIME_UNSET
        } else {
            durationUs - positionInWindowUs
        }
        period.set(
            period.id,
            period.uid,
            /* windowIndex= */ 0,
            periodDurationUs,
            positionInWindowUs,
        )
        period.isPlaceholder = isPlaceholder
        return period
    }
}
