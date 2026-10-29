// ABOUTME: Generates caption cues for the editor timeline from clip, voice-over
// ABOUTME: and extracted sound. Server path merges once; on-device runs each.

import 'dart:async';
import 'dart:math' as math;

import 'package:caption_generator/caption_generator.dart';
import 'package:collection/collection.dart' show mergeSort;
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_generation_outcome.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/video_editor/caption_remote_transcriber.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

export 'package:openvine/models/video_editor/caption_generation_outcome.dart';

/// Generates caption cues from the editor's timeline.
///
/// Speech comes from the clips' own sound, from voice-over takes and from
/// sound extracted from a clip. Music and other sounds are not transcribed.
///
/// Two transcription paths, matched to what each backend handles well:
///
/// * **Server** (when a [CaptionRemoteTranscriber] is present): the audible
///   sources' trimmed audio is merged into a single continuous WAV and
///   transcribed in one pass, then mapped back onto the composition timeline
///   via the merge's per-segment offset map. One continuous stream gives cloud
///   ASR more context than isolated short clips.
/// * **On-device** (no remote, or the server path failed): each source's audio
///   is transcribed separately. The OS recognizer is built for short
///   utterances and stalls on a long merged file, so the fallback must stay
///   per-source.
///
/// A track with a voice effect always takes the on-device path, next to the
/// server's result for the rest, so its recording without the effect never
/// leaves the phone.
///
/// Both paths carry a timeout so a stalled recognizer or network never hangs
/// the editor. Muted clips and tracks, clips without a local file, and empty
/// trim windows are excluded; their timeline span is still counted so later
/// cues stay aligned.
class CaptionGenerationService {
  /// Creates the service.
  CaptionGenerationService({
    required AudioExtractionService audioExtractionService,
    required CaptionGenerator captionGenerator,
    CaptionRemoteTranscriber? remoteTranscriber,
    Duration remoteTimeout = _defaultRemoteTimeout,
    Duration onDeviceClipTimeout = _defaultOnDeviceClipTimeout,
  }) : _audioExtractionService = audioExtractionService,
       _captionGenerator = captionGenerator,
       _remoteTranscriber = remoteTranscriber,
       _remoteTimeout = remoteTimeout,
       _onDeviceClipTimeout = onDeviceClipTimeout;

  /// Creates the service with its production dependencies.
  ///
  /// Pass [remoteTranscriber] to prefer server-side transcription (falling
  /// back to on-device on failure); omit it for on-device only.
  factory CaptionGenerationService.production({
    CaptionRemoteTranscriber? remoteTranscriber,
  }) => CaptionGenerationService(
    audioExtractionService: AudioExtractionService(),
    captionGenerator: CaptionGenerator(),
    remoteTranscriber: remoteTranscriber,
  );

  final AudioExtractionService _audioExtractionService;
  final CaptionGenerator _captionGenerator;

  /// Optional server-side transcriber, preferred over [_captionGenerator] when
  /// present. Falls back to on-device when a merge or remote call fails.
  final CaptionRemoteTranscriber? _remoteTranscriber;

  static const String _logName = 'CaptionGenerationService';

  /// Output format for the merged audio — 16 kHz mono is the standard speech
  /// recognition input and keeps the uploaded file small.
  static const int _asrSampleRate = 16000;
  static const int _asrChannels = 1;

  /// Guard rails so a stalled network / recognizer can never hang the editor.
  static const Duration _defaultRemoteTimeout = Duration(seconds: 60);
  static const Duration _defaultOnDeviceClipTimeout = Duration(seconds: 30);

  /// Max time for the whole server transcription before falling back.
  final Duration _remoteTimeout;

  /// Max time for one source's on-device transcription before failing.
  final Duration _onDeviceClipTimeout;

  /// How far apart two sources may be on the timeline and still count as
  /// playing back to back. A take's probed length and its placed window can
  /// differ by a few milliseconds.
  static const Duration _backToBackTolerance = Duration(milliseconds: 100);

  /// Transcribes [clips] and the speech among [audioTracks] into
  /// timeline-mapped caption cues.
  ///
  /// Of [audioTracks], only voice-over takes and sound extracted from a clip
  /// are transcribed, where they play on the timeline. A track is recognized
  /// from its recording as made, before any voice effect, which would only
  /// make it harder to understand, and before noise reduction. A track with a
  /// voice effect is recognized on the device only.
  ///
  /// [localeIdentifier] is the BCP-47 recognition language (the app locale).
  /// Never throws — failures come back as [CaptionsFailed].
  Future<CaptionGenerationOutcome> generateForClips({
    required List<DivineVideoClip> clips,
    required String localeIdentifier,
    List<AudioEvent> audioTracks = const [],
  }) async {
    final totalDuration = clips.fold(
      Duration.zero,
      (sum, clip) => sum + clip.playbackDuration,
    );
    final sources = _speechSources(
      clips: clips,
      audioTracks: audioTracks,
      totalDuration: totalDuration,
    );
    if (sources.isEmpty) return const CaptionsEmpty();

    final remote = _remoteTranscriber;
    final serverSources = [
      for (final source in sources)
        if (!source.onDeviceOnly) source,
    ];
    if (remote != null && serverSources.isNotEmpty) {
      final serverCues = await _transcribeViaServerMerge(
        remote: remote,
        sources: serverSources,
        localeIdentifier: localeIdentifier,
      );
      if (serverCues != null) {
        return _outcome(
          [
            ...serverCues,
            ...await _onDeviceOnlyCues(
              sources: sources,
              localeIdentifier: localeIdentifier,
            ),
          ],
          totalDuration,
        );
      }
      // The merge or the server call failed — fall through to on-device.
    }
    return _generateOnDevicePerSource(
      sources: sources,
      totalDuration: totalDuration,
      localeIdentifier: localeIdentifier,
    );
  }

  /// The audible stretches of [clips] and [audioTracks], in timeline order.
  List<_SpeechSource> _speechSources({
    required List<DivineVideoClip> clips,
    required List<AudioEvent> audioTracks,
    required Duration totalDuration,
  }) {
    final sources = <_SpeechSource>[];
    final audibleClips = <String, _SpeechSource>{};
    var clipStart = Duration.zero;
    for (final clip in clips) {
      final source = _clipSource(clip, timelineStart: clipStart);
      if (source != null) {
        sources.add(source);
        audibleClips[clip.id] = source;
      }
      clipStart += clip.playbackDuration;
    }
    for (final track in audioTracks) {
      final source = _trackSource(track, totalDuration: totalDuration);
      if (source == null) continue;
      final anchor = audibleClips[track.anchorClipId];
      if (anchor == null) {
        sources.add(source);
        continue;
      }
      // Anchored audio keeps its full sound across the clip's trims (J/L-cut).
      // Only the shared window repeats the clip; keep the unique head/tail.
      final beforeEnd = source.timelineEnd < anchor.timelineStart
          ? source.timelineEnd
          : anchor.timelineStart;
      if (beforeEnd > source.timelineStart) {
        sources.add(_trackWindow(source, source.timelineStart, beforeEnd));
      }
      final afterStart = source.timelineStart > anchor.timelineEnd
          ? source.timelineStart
          : anchor.timelineEnd;
      if (afterStart < source.timelineEnd) {
        sources.add(_trackWindow(source, afterStart, source.timelineEnd));
      }
    }
    mergeSort(
      sources,
      compare: (a, b) => a.timelineStart.compareTo(b.timelineStart),
    );
    return sources;
  }

  /// A track's sound restricted to the timeline window [start] to [end].
  static _SpeechSource _trackWindow(
    _SpeechSource source,
    Duration start,
    Duration end,
  ) {
    final startOffset = start - source.timelineStart;
    final endOffset = end - source.timelineStart;
    return _SpeechSource(
      id: source.id,
      lane: source.lane,
      media: source.media,
      filePath: source.filePath,
      sourceStart: source.sourceStart + startOffset * source.speed,
      sourceEnd: source.sourceStart + endOffset * source.speed,
      speed: source.speed,
      timelineStart: start,
      extractedStart: source.extractedStart + startOffset,
      extractedEnd: source.extractedStart + endOffset,
      onDeviceOnly: source.onDeviceOnly,
    );
  }

  /// The clip's own sound, or `null` when it is muted, has no local file or
  /// an empty trim window.
  ///
  /// A clip under a speed ramp is transcribed at its recorded speed (see
  /// [_effectiveSpeed]), so its words are moved through the ramp.
  static _SpeechSource? _clipSource(
    DivineVideoClip clip, {
    required Duration timelineStart,
  }) {
    final video = clip.video;
    final path = video?.file?.path;
    final sourceEnd = clip.duration - clip.trimEnd;
    if (video == null ||
        path == null ||
        clip.volume <= 0 ||
        sourceEnd <= clip.trimStart) {
      return null;
    }
    final ramped = clip.speedRamp != null;
    final extractedStart = ramped
        ? clip.trimStart
        : clip.sourceDurationToPlaybackDuration(clip.trimStart);
    return _SpeechSource(
      id: clip.id,
      lane: _SpeechSource.clipsLane,
      media: video,
      filePath: path,
      sourceStart: clip.trimStart,
      sourceEnd: sourceEnd,
      speed: _effectiveSpeed(clip),
      timelineStart: timelineStart,
      extractedStart: extractedStart,
      extractedEnd:
          extractedStart +
          (ramped ? clip.trimmedDuration : clip.playbackDuration),
      toPlayback: ramped ? clip.sourceOffsetToPlaybackOffset : null,
    );
  }

  /// A voice-over take or sound extracted from a clip, as far as it plays
  /// inside the video, or `null` for any other track, a muted one, or one
  /// that plays nothing there.
  ///
  /// The sound is read from the recording as made, without its voice effect
  /// or noise reduction. A voice effect can be what keeps a speaker from
  /// being recognized, so a track with one is recognized on the device only.
  ///
  /// Takes and extracted sound are always placed with an end; a track
  /// without one is skipped.
  static _SpeechSource? _trackSource(
    AudioEvent track, {
    required Duration totalDuration,
  }) {
    if (!track.isVoiceOver && !track.isLocalExtracted) return null;
    final path = track.originalLocalFilePath;
    final endTime = track.endTime;
    if (path == null || endTime == null || track.volume <= 0) return null;

    final timelineEnd = endTime < totalDuration ? endTime : totalDuration;
    var sourceEnd =
        track.startOffset + track.sourceSpanOf(timelineEnd - track.startTime);
    final soundSeconds = track.duration;
    if (soundSeconds != null) {
      final soundLength = Duration(
        microseconds: (soundSeconds * Duration.microsecondsPerSecond).round(),
      );
      if (sourceEnd > soundLength) sourceEnd = soundLength;
    }
    if (sourceEnd <= track.startOffset) return null;

    final extractedStart = track.timelineSpanOf(track.startOffset);
    return _SpeechSource(
      id: track.id,
      lane: track.id,
      media: EditorVideo.file(path),
      filePath: path,
      sourceStart: track.startOffset,
      sourceEnd: sourceEnd,
      speed: track.playbackSpeed,
      timelineStart: track.startTime,
      extractedStart: extractedStart,
      extractedEnd:
          extractedStart + track.timelineSpanOf(sourceEnd - track.startOffset),
      onDeviceOnly: !track.voiceEffect.isNone,
    );
  }

  /// Server path: merge the sources into one WAV and transcribe it remotely.
  ///
  /// Returns the cues, or `null` when the merge or the remote call failed so
  /// the caller can fall back to on-device. An empty transcript is a valid
  /// "no speech" result, not a fallback trigger.
  Future<List<CaptionSegment>?> _transcribeViaServerMerge({
    required CaptionRemoteTranscriber remote,
    required List<_SpeechSource> sources,
    required String localeIdentifier,
  }) async {
    final AudioMergeResult merged;
    try {
      merged = await _audioExtractionService.mergeClipAudio(
        segments: [
          for (final source in sources)
            AudioMergeSegment(
              video: source.media,
              startTime: source.sourceStart,
              endTime: source.sourceEnd,
              speed: source.speed,
            ),
        ],
        sampleRate: _asrSampleRate,
        channels: _asrChannels,
      );
    } on AudioExtractionException catch (e) {
      Log.warning(
        '🎬 Caption audio merge failed; falling back to on-device: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    try {
      final words = await remote
          .transcribe(
            audioPath: merged.outputPath,
            localeIdentifier: localeIdentifier,
          )
          .timeout(_remoteTimeout);
      // The server times whole cues only, so the words the grouper spreads
      // over them are an estimate. The cues keep none: an estimate stored as
      // if it were spoken would stop following the cue when it is trimmed,
      // while an empty list lets the cue spread its words over whatever
      // window it ends up with.
      return _group(
        _mapMergedToTimeline(words, merged.segments, sources),
        keepWords: false,
      );
    } on Object catch (e) {
      Log.warning(
        '🎬 Server caption transcription failed; falling back to '
        'on-device: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    } finally {
      await _cleanupQuietly(merged.outputPath);
    }
  }

  /// On-device path: transcribe each source's audio separately.
  Future<CaptionGenerationOutcome> _generateOnDevicePerSource({
    required List<_SpeechSource> sources,
    required Duration totalDuration,
    required String localeIdentifier,
  }) async {
    final result = await _transcribeOnDevice(
      sources: sources,
      localeIdentifier: localeIdentifier,
    );
    final failure = result.failure;
    if (failure != null) return CaptionsFailed(failure);
    return _outcome(_group(result.words), totalDuration);
  }

  /// The cues of the [sources] only ever recognized on the device, for a run
  /// whose other sources the server transcribed.
  ///
  /// A failure here leaves those sources without cues rather than discarding
  /// the server's.
  Future<List<CaptionSegment>> _onDeviceOnlyCues({
    required List<_SpeechSource> sources,
    required String localeIdentifier,
  }) async {
    final onDeviceOnly = [
      for (final source in sources)
        if (source.onDeviceOnly) source,
    ];
    if (onDeviceOnly.isEmpty) return const [];
    final words = <_LaneWord>[];
    for (final source in onDeviceOnly) {
      final result = await _transcribeOnDevice(
        sources: [source],
        localeIdentifier: localeIdentifier,
      );
      words.addAll(result.words);
      if (result.failure != null) {
        Log.warning(
          '🎬 On-device captions failed for ${source.id}; '
          'keeping the other captions: ${result.failure}',
          name: _logName,
          category: LogCategory.video,
        );
      }
    }
    return _group(words);
  }

  /// Transcribes each of [sources] on the device, or stops at the first
  /// failure.
  ///
  /// The OS recognizer is designed for short utterances, so each source is
  /// extracted and transcribed on its own (with a per-source timeout) and its
  /// words are windowed to the part that plays and shifted onto the timeline.
  Future<_OnDeviceResult> _transcribeOnDevice({
    required List<_SpeechSource> sources,
    required String localeIdentifier,
  }) async {
    final words = <_LaneWord>[];
    CaptionGenerationFailure? localOnlyFailure;

    // Some on-device recognizers reject an explicit language even when it is
    // the device's own default, so [_recognizeOnDevice] retries without one.
    // Once that happens, drop the language for the remaining sources too
    // rather than pay the failed first attempt on every one.
    String? effectiveLocale = localeIdentifier;

    for (final source in sources) {
      final String audioPath;
      try {
        final extraction = await _audioExtractionService.extractAudio(
          videoPath: source.filePath,
          speed: source.speed,
        );
        audioPath = extraction.audioFilePath;
      } on AudioExtractionException catch (e) {
        if (e.message.contains('no audio track')) continue;
        Log.warning(
          '🎬 Caption audio extraction failed for ${source.id}: $e',
          name: _logName,
          category: LogCategory.video,
        );
        if (source.onDeviceOnly) {
          localOnlyFailure ??= CaptionGenerationFailure.failed;
          continue;
        }
        return (words: words, failure: CaptionGenerationFailure.failed);
      }

      try {
        final result = await _recognizeOnDevice(
          audioPath: audioPath,
          localeIdentifier: effectiveLocale,
          requireOnDeviceRecognition: source.onDeviceOnly,
        );
        if (result.localeRejected) effectiveLocale = null;
        words.addAll(_windowToTimeline(result.segments, source));
      } on TimeoutException {
        Log.warning(
          '🎬 On-device caption transcription timed out for ${source.id}',
          name: _logName,
          category: LogCategory.video,
        );
        if (source.onDeviceOnly) {
          localOnlyFailure ??= CaptionGenerationFailure.failed;
          continue;
        }
        return (words: words, failure: CaptionGenerationFailure.failed);
      } on CaptionGenerationException catch (e) {
        Log.warning(
          '🎬 Caption transcription failed for ${source.id}: $e',
          name: _logName,
          category: LogCategory.video,
        );
        if (source.onDeviceOnly) {
          localOnlyFailure ??= _mapFailure(e);
          continue;
        }
        return (words: words, failure: _mapFailure(e));
      } on Object catch (e) {
        // The OS recognizer can throw untyped errors (missing plugin,
        // malformed native result). Honor the "never throws" contract so the
        // caller shows the manual-entry fallback instead of stalling.
        Log.warning(
          '🎬 On-device caption transcription failed unexpectedly for '
          '${source.id}: $e',
          name: _logName,
          category: LogCategory.video,
        );
        if (source.onDeviceOnly) {
          localOnlyFailure ??= CaptionGenerationFailure.failed;
          continue;
        }
        return (words: words, failure: CaptionGenerationFailure.failed);
      } finally {
        await _cleanupQuietly(audioPath);
      }
    }

    return (words: words, failure: words.isEmpty ? localOnlyFailure : null);
  }

  /// Runs on-device recognition for one source. Some on-device recognizers
  /// reject an explicit language even when it is the device's own default, so
  /// on [SpeechRecognizerUnavailableException] this retries once without a
  /// language (the device default). Returns the words and whether the language
  /// was dropped, so the caller can skip the doomed first attempt on later
  /// sources.
  Future<({List<CaptionSegment> segments, bool localeRejected})>
  _recognizeOnDevice({
    required String audioPath,
    required String? localeIdentifier,
    required bool requireOnDeviceRecognition,
  }) async {
    try {
      final segments = await _captionGenerator
          .generateCaptions(
            audioPath: audioPath,
            localeIdentifier: localeIdentifier,
            requireOnDeviceRecognition: requireOnDeviceRecognition,
          )
          .timeout(_onDeviceClipTimeout);
      return (segments: segments, localeRejected: false);
    } on SpeechRecognizerUnavailableException {
      if (localeIdentifier == null) rethrow;
      Log.warning(
        '🎬 On-device recognizer rejected locale "$localeIdentifier"; '
        'retrying with the device default',
        name: _logName,
        category: LogCategory.video,
      );
      final segments = await _captionGenerator
          .generateCaptions(
            audioPath: audioPath,
            requireOnDeviceRecognition: requireOnDeviceRecognition,
          )
          .timeout(_onDeviceClipTimeout);
      return (segments: segments, localeRejected: true);
    }
  }

  /// Shifts each transcribed cue from merged-output time onto the composition
  /// timeline.
  ///
  /// The merged audio is gap-free, and the server times whole cues, often a
  /// little early or late, so a cue near the boundary between two
  /// concatenated sources can start in one and lie mostly in the other, or
  /// cover both. A cue across sources that also play back to back on the
  /// timeline (consecutive clips, takes laid one after another) has each end
  /// moved through its own source. Any other cue belongs to the source it
  /// overlaps most and is clamped to it, so it never spills into a skipped
  /// clip's muted gap or onto a source that plays elsewhere. The full text is
  /// kept intact; only its timing is bounded. So when the server returns one
  /// sentence for the end of a clip and the start of a take merged after it,
  /// the clip's words show in the take's cue, and that part of the clip gets
  /// no cue of its own.
  List<_LaneWord> _mapMergedToTimeline(
    List<CaptionSegment> words,
    List<AudioMergeSegmentOffset> offsets,
    List<_SpeechSource> sources,
  ) {
    if (offsets.isEmpty) return const [];
    final mapped = <_LaneWord>[];
    for (final word in words) {
      final first = _segmentIndexFor(word.start, offsets);
      final last = math.max(first, _segmentIndexEndingAt(word.end, offsets));
      final owner = _mostOverlapped(word, first, last, offsets);
      if (first < last && _playBackToBack(sources, first, last)) {
        final start = _mergedToTimeline(
          word.start,
          sources[first],
          offsets[first],
        );
        final end = _mergedToTimeline(word.end, sources[last], offsets[last]);
        // Sources within the tolerance can overlap on the timeline, which
        // would end a short cue before it starts; give it to its owner then.
        if (end >= start) {
          mapped.add((
            lane: sources[owner].lane,
            word: CaptionSegment(text: word.text, start: start, end: end),
          ));
          continue;
        }
      }
      mapped.add(
        _mapWord(
          word,
          sources[owner],
          windowStart: offsets[owner].outputStart,
          windowEnd: offsets[owner].outputEnd,
        ),
      );
    }
    return mapped;
  }

  /// The index of the concatenated segment containing [time]; the last segment
  /// for a time at or past the merged end. Assumes non-empty, gap-free offsets.
  static int _segmentIndexFor(
    Duration time,
    List<AudioMergeSegmentOffset> offsets,
  ) {
    for (var i = 0; i < offsets.length; i++) {
      if (time < offsets[i].outputEnd) return i;
    }
    return offsets.length - 1;
  }

  /// The index of the concatenated segment a span ending at [time] ends in:
  /// one ending exactly on a boundary ends in the segment before it.
  static int _segmentIndexEndingAt(
    Duration time,
    List<AudioMergeSegmentOffset> offsets,
  ) {
    for (var i = 0; i < offsets.length; i++) {
      if (time <= offsets[i].outputEnd) return i;
    }
    return offsets.length - 1;
  }

  /// Of the segments [first] to [last], the one [word] overlaps most; the
  /// earliest on a tie.
  static int _mostOverlapped(
    CaptionSegment word,
    int first,
    int last,
    List<AudioMergeSegmentOffset> offsets,
  ) {
    var best = first;
    var bestOverlap = Duration.zero;
    for (var i = first; i <= last; i++) {
      final offset = offsets[i];
      final overlap =
          (word.end < offset.outputEnd ? word.end : offset.outputEnd) -
          (word.start > offset.outputStart ? word.start : offset.outputStart);
      if (overlap > bestOverlap) {
        best = i;
        bestOverlap = overlap;
      }
    }
    return best;
  }

  /// Whether the sources [first] to [last] each start where the one before
  /// ends on the timeline, as they do in the merged audio.
  static bool _playBackToBack(
    List<_SpeechSource> sources,
    int first,
    int last,
  ) {
    for (var i = first; i < last; i++) {
      final gap = sources[i + 1].timelineStart - sources[i].timelineEnd;
      if (gap.abs() > _backToBackTolerance) return false;
    }
    return true;
  }

  /// Where [time] in the merged audio, inside [source]'s [offset] window,
  /// plays on the timeline.
  static Duration _mergedToTimeline(
    Duration time,
    _SpeechSource source,
    AudioMergeSegmentOffset offset,
  ) => source.onTimeline(
    _clamp(time, offset.outputStart, offset.outputEnd) - offset.outputStart,
  );

  /// Windows [segments] (timed in the source's extracted sound) to the part of
  /// it that plays and shifts them onto the composition timeline.
  List<_LaneWord> _windowToTimeline(
    List<CaptionSegment> segments,
    _SpeechSource source,
  ) => [
    for (final segment in segments)
      if (segment.end > source.extractedStart &&
          segment.start < source.extractedEnd)
        _mapWord(
          segment,
          source,
          windowStart: source.extractedStart,
          windowEnd: source.extractedEnd,
        ),
  ];

  /// Moves [word], timed in a window from [windowStart] to [windowEnd] of
  /// [source]'s sound, to where it plays on the timeline.
  static _LaneWord _mapWord(
    CaptionSegment word,
    _SpeechSource source, {
    required Duration windowStart,
    required Duration windowEnd,
  }) {
    Duration onTimeline(Duration time) =>
        source.onTimeline(_clamp(time, windowStart, windowEnd) - windowStart);
    return (
      lane: source.lane,
      word: CaptionSegment(
        text: word.text,
        start: onTimeline(word.start),
        end: onTimeline(word.end),
      ),
    );
  }

  /// Groups [words] into cues lane by lane, so the words of a voice-over and
  /// of a clip it talks over are never joined into one cue. Each cue keeps
  /// the recognizer's word timings when [keepWords] is set.
  static List<CaptionSegment> _group(
    List<_LaneWord> words, {
    bool keepWords = true,
  }) {
    final lanes = <String, List<CaptionSegment>>{};
    for (final (:lane, :word) in words) {
      (lanes[lane] ??= []).add(word);
    }
    return [
      for (final laneWords in lanes.values)
        for (final cue in groupCaptionSegments(laneWords))
          if (keepWords)
            cue
          else
            CaptionSegment(text: cue.text, start: cue.start, end: cue.end),
    ];
  }

  /// Turns grouped [cues] into the outcome, ordered by start and cut off at
  /// [totalDuration].
  static CaptionGenerationOutcome _outcome(
    List<CaptionSegment> cues,
    Duration totalDuration,
  ) {
    if (cues.isEmpty) return const CaptionsEmpty();
    final ordered = [...cues];
    mergeSort(ordered, compare: (a, b) => a.start.compareTo(b.start));
    return CaptionsGenerated([
      for (final (index, segment) in ordered.indexed)
        CaptionCue(
          id: 'cue-$index',
          text: segment.text,
          start: segment.start,
          end: segment.end > totalDuration ? totalDuration : segment.end,
          words: segment.words,
        ),
    ]);
  }

  static Duration _clamp(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// The speed a clip's sound is transcribed at. A speed ramp has no single
  /// speed, so its sound is transcribed as recorded and its words are moved
  /// through the ramp afterwards.
  static double _effectiveSpeed(DivineVideoClip clip) {
    if (clip.speedRamp != null) return 1.0;
    final speed = clip.playbackSpeed;
    return speed != null && speed > 0 ? speed : 1.0;
  }

  static CaptionGenerationFailure _mapFailure(CaptionGenerationException e) =>
      switch (e) {
        SpeechRecognizerUnavailableException() =>
          CaptionGenerationFailure.recognizerUnavailable,
        SpeechNotAuthorizedException() =>
          CaptionGenerationFailure.notAuthorized,
        UnsupportedAudioFormatException() =>
          CaptionGenerationFailure.unsupportedAudio,
        AudioFileNotFoundException() ||
        TranscriptionFailedException() => CaptionGenerationFailure.failed,
      };

  Future<void> _cleanupQuietly(String audioPath) async {
    try {
      await _audioExtractionService.cleanupAudioFile(audioPath);
    } catch (e) {
      Log.warning(
        '🎬 Failed to clean up caption audio: $e',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }
}

/// A transcribed word on the timeline, with the lane it is grouped in.
typedef _LaneWord = ({String lane, CaptionSegment word});

/// The words recognized on the device, or the failure that stopped it.
typedef _OnDeviceResult = ({
  List<_LaneWord> words,
  CaptionGenerationFailure? failure,
});

/// One stretch of sound to transcribe and where it plays: a clip's own sound,
/// a voice-over take, or sound extracted from a clip.
class _SpeechSource {
  const _SpeechSource({
    required this.id,
    required this.lane,
    required this.media,
    required this.filePath,
    required this.sourceStart,
    required this.sourceEnd,
    required this.speed,
    required this.timelineStart,
    required this.extractedStart,
    required this.extractedEnd,
    this.toPlayback,
    this.onDeviceOnly = false,
  });

  /// The lane every clip shares. Track ids carry a marker prefix, so none
  /// is this.
  static const String clipsLane = 'clips';

  /// The clip or track id, for logs.
  final String id;

  /// Words in one lane are grouped into cues together: the clips share
  /// [clipsLane], and each track has its own.
  final String lane;

  /// The file the sound is read from, for the merge.
  final EditorVideo media;

  /// The path of [media], for on-device extraction.
  final String filePath;

  /// Where in the file the part that plays begins.
  final Duration sourceStart;

  /// Where in the file the part that plays ends.
  final Duration sourceEnd;

  /// The speed the sound is transcribed at.
  final double speed;

  /// Where on the timeline the part that plays begins.
  final Duration timelineStart;

  /// Where the part that plays begins in the whole file extracted at
  /// [speed], which is how on-device recognition times its words.
  final Duration extractedStart;

  /// Where the part that plays ends in the whole file extracted at [speed].
  final Duration extractedEnd;

  /// Moves an offset into the transcribed sound to an offset on the
  /// timeline, for a clip under a speed ramp; the two are equal otherwise.
  final Duration Function(Duration offset)? toPlayback;

  /// Whether the sound is only ever recognized on the device, never sent to
  /// the server.
  final bool onDeviceOnly;

  /// Where [offset] into the part that plays lands on the timeline.
  Duration onTimeline(Duration offset) =>
      timelineStart + (toPlayback?.call(offset) ?? offset);

  /// Where the part that plays ends on the timeline.
  Duration get timelineEnd => onTimeline(extractedEnd - extractedStart);
}
