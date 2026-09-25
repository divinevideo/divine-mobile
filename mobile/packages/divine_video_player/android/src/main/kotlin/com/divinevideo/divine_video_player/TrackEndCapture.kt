package com.divinevideo.divine_video_player

import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.DataReader
import androidx.media3.common.Format
import androidx.media3.common.util.ExperimentalApi
import androidx.media3.common.util.ParsableByteArray
import androidx.media3.common.util.UnstableApi
import androidx.media3.extractor.Extractor
import androidx.media3.extractor.ExtractorInput
import androidx.media3.extractor.ExtractorOutput
import androidx.media3.extractor.ExtractorsFactory
import androidx.media3.extractor.PositionHolder
import androidx.media3.extractor.SeekMap
import androidx.media3.extractor.SniffFailure
import androidx.media3.extractor.TrackOutput
import androidx.media3.extractor.text.SubtitleParser

/**
 * Reports each source's video and audio track lengths as the player's own
 * extractor reads them from the container.
 *
 * Where a clip's tracks end decides where it has to loop, and the player
 * learns that from the `moov` box before it has decoded a single frame. Reading
 * it a second time with a `MediaExtractor` meant either holding the load back
 * for a round trip or letting the video start before the answer — and a clamp
 * that lands on a playing video can only be installed by swapping its item,
 * which froze the first loop restart for ~300 ms. Taken from here, the answer
 * arrives before the player publishes the source's timeline, so the clip end
 * is set before anything is shown.
 *
 * It also reports where the picture begins. A transcoder that pads the video
 * with an initial empty edit — every Divine derivative carries one of 21–23 ms,
 * the AAC encoder's priming — has the first frame appear that far into the
 * clip, so a loop from zero holds the previous lap's last frame for that long
 * at every restart.
 *
 * [onTrackEnds] runs on the loading thread, once per parse of a container that
 * carries both a video and an audio track, when the extractor publishes its
 * seek map — which the MP4 extractor does straight after its track list, and
 * the player waits for before it prepares. The lengths are the tracks'
 * presentation ends — edit list included — which is what the player's own
 * timeline is made of; the start is the presentation time of the first video
 * frame the seek map would start from.
 */
@UnstableApi
internal class TrackEndCapturingExtractorsFactory(
    private val delegate: ExtractorsFactory,
    private val onTrackEnds: (
        uri: Uri,
        videoEndUs: Long,
        audioEndUs: Long,
        videoStartUs: Long,
    ) -> Unit,
) : ExtractorsFactory {

    override fun createExtractors(): Array<Extractor> = delegate.createExtractors()

    override fun createExtractors(
        uri: Uri,
        responseHeaders: Map<String, List<String>>,
    ): Array<Extractor> =
        delegate.createExtractors(uri, responseHeaders)
            .map { extractor ->
                TrackEndCapturingExtractor(extractor) { videoEndUs, audioEndUs, videoStartUs ->
                    onTrackEnds(uri, videoEndUs, audioEndUs, videoStartUs)
                }
            }
            .toTypedArray()

    @Deprecated("Forwarded to the wrapped factory, which is where it is deprecated.")
    @ExperimentalApi
    override fun experimentalSetTextTrackTranscodingEnabled(
        textTrackTranscodingEnabled: Boolean,
    ): ExtractorsFactory {
        @Suppress("DEPRECATION")
        delegate.experimentalSetTextTrackTranscodingEnabled(textTrackTranscodingEnabled)
        return this
    }

    override fun setSubtitleParserFactory(
        subtitleParserFactory: SubtitleParser.Factory,
    ): ExtractorsFactory {
        delegate.setSubtitleParserFactory(subtitleParserFactory)
        return this
    }

    @ExperimentalApi
    override fun experimentalSetCodecsToParseWithinGopSampleDependencies(
        codecsToParseWithinGopSampleDependencies: Int,
    ): ExtractorsFactory {
        delegate.experimentalSetCodecsToParseWithinGopSampleDependencies(
            codecsToParseWithinGopSampleDependencies,
        )
        return this
    }
}

/** Passes everything through, and hands the track bounds out with the seek map. */
@UnstableApi
private class TrackEndCapturingExtractor(
    private val delegate: Extractor,
    private val onTrackEnds: (videoEndUs: Long, audioEndUs: Long, videoStartUs: Long) -> Unit,
) : Extractor {

    override fun sniff(input: ExtractorInput): Boolean = delegate.sniff(input)

    override fun getSniffFailureDetails(): List<SniffFailure> = delegate.sniffFailureDetails

    override fun init(output: ExtractorOutput) {
        delegate.init(TrackEndCapturingOutput(output, onTrackEnds))
    }

    override fun read(input: ExtractorInput, seekPosition: PositionHolder): Int =
        delegate.read(input, seekPosition)

    override fun seek(position: Long, timeUs: Long) = delegate.seek(position, timeUs)

    override fun release() = delegate.release()

    // The progressive loader asks what it is really talking to (an MP3
    // extractor gets its seeking disabled on ICY streams); it must still see
    // the real extractor through the wrapper.
    override fun getUnderlyingImplementation(): Extractor = delegate.underlyingImplementation
}

@UnstableApi
private class TrackEndCapturingOutput(
    private val delegate: ExtractorOutput,
    private val onTrackEnds: (videoEndUs: Long, audioEndUs: Long, videoStartUs: Long) -> Unit,
) : ExtractorOutput {

    private var videoEndUs = C.TIME_UNSET
    private var audioEndUs = C.TIME_UNSET

    override fun track(id: Int, type: Int): TrackOutput {
        val output = delegate.track(id, type)
        return when (type) {
            C.TRACK_TYPE_VIDEO, C.TRACK_TYPE_AUDIO ->
                DurationCapturingTrackOutput(output) { durationUs -> record(type, durationUs) }
            else -> output
        }
    }

    /** The first track of each type is the one the player plays. */
    private fun record(type: Int, durationUs: Long) {
        if (durationUs <= 0 || durationUs == C.TIME_UNSET) return
        if (type == C.TRACK_TYPE_VIDEO && videoEndUs == C.TIME_UNSET) videoEndUs = durationUs
        if (type == C.TRACK_TYPE_AUDIO && audioEndUs == C.TIME_UNSET) audioEndUs = durationUs
    }

    override fun endTracks() = delegate.endTracks()

    /**
     * The MP4 seek map starts from the first video sync sample, so asking it
     * for time zero answers with the time the first frame is shown — past
     * zero when an empty edit delays the picture.
     */
    override fun seekMap(seekMap: SeekMap) {
        if (videoEndUs != C.TIME_UNSET && audioEndUs != C.TIME_UNSET) {
            val videoStartUs = if (seekMap.isSeekable) {
                seekMap.getSeekPoints(0L).first.timeUs.coerceAtLeast(0L)
            } else {
                0L
            }
            onTrackEnds(videoEndUs, audioEndUs, videoStartUs)
        }
        delegate.seekMap(seekMap)
    }
}

@UnstableApi
private class DurationCapturingTrackOutput(
    private val delegate: TrackOutput,
    private val onDuration: (Long) -> Unit,
) : TrackOutput {

    override fun durationUs(durationUs: Long) {
        onDuration(durationUs)
        delegate.durationUs(durationUs)
    }

    override fun format(format: Format) = delegate.format(format)

    override fun sampleData(input: DataReader, length: Int, allowEndOfInput: Boolean): Int =
        delegate.sampleData(input, length, allowEndOfInput)

    override fun sampleData(data: ParsableByteArray, length: Int) =
        delegate.sampleData(data, length)

    override fun sampleData(
        input: DataReader,
        length: Int,
        allowEndOfInput: Boolean,
        sampleDataPart: Int,
    ): Int = delegate.sampleData(input, length, allowEndOfInput, sampleDataPart)

    override fun sampleData(data: ParsableByteArray, length: Int, sampleDataPart: Int) =
        delegate.sampleData(data, length, sampleDataPart)

    override fun sampleMetadata(
        timeUs: Long,
        flags: Int,
        size: Int,
        offset: Int,
        cryptoData: TrackOutput.CryptoData?,
    ) = delegate.sampleMetadata(timeUs, flags, size, offset, cryptoData)
}
