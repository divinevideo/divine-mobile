// ABOUTME: Generates caption cues for the editor timeline from clip audio.
// ABOUTME: Server path merges audio once; on-device fallback stays per-clip.

import 'dart:async';

import 'package:caption_generator/caption_generator.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_generation_outcome.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/video_editor/caption_remote_transcriber.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

export 'package:openvine/models/video_editor/caption_generation_outcome.dart';

/// Generates caption cues from the editor's clip timeline.
///
/// Two transcription paths, matched to what each backend handles well:
///
/// * **Server** (when a [CaptionRemoteTranscriber] is present): the audible
///   clips' trimmed audio is merged into a single continuous WAV and
///   transcribed in one pass, then mapped back onto the composition timeline
///   via the merge's per-segment offset map. One continuous stream gives cloud
///   ASR more context than isolated short clips.
/// * **On-device** (no remote, or the server path failed): each clip's audio is
///   transcribed separately. The OS recognizer is built for short utterances
///   and stalls on a long merged file, so the fallback must stay per-clip.
///
/// Both paths carry a timeout so a stalled recognizer or network never hangs
/// the editor. Muted clips, clips without a local file, and empty trim windows
/// are excluded; their timeline span is still counted so later cues stay
/// aligned. Voice-over and music tracks are not transcribed.
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

  /// Max time for one clip's on-device transcription before failing.
  final Duration _onDeviceClipTimeout;

  /// Transcribes [clips] into timeline-mapped caption cues.
  ///
  /// [localeIdentifier] is the BCP-47 recognition language (the app locale).
  /// Never throws — failures come back as [CaptionsFailed].
  Future<CaptionGenerationOutcome> generateForClips({
    required List<DivineVideoClip> clips,
    required String localeIdentifier,
  }) async {
    final remote = _remoteTranscriber;
    if (remote != null) {
      final outcome = await _generateViaServerMerge(
        remote: remote,
        clips: clips,
        localeIdentifier: localeIdentifier,
      );
      if (outcome != null) return outcome;
      // The merge or the server call failed — fall through to on-device.
    }
    return _generateOnDevicePerClip(
      clips: clips,
      localeIdentifier: localeIdentifier,
    );
  }

  /// Server path: merge audible clips into one WAV and transcribe it remotely.
  ///
  /// Returns the outcome, or `null` when the merge or the remote call failed so
  /// the caller can fall back to on-device. An empty transcript is a valid
  /// "no speech" result ([CaptionsEmpty]), not a fallback trigger.
  Future<CaptionGenerationOutcome?> _generateViaServerMerge({
    required CaptionRemoteTranscriber remote,
    required List<DivineVideoClip> clips,
    required String localeIdentifier,
  }) async {
    final segments = <AudioMergeSegment>[];
    final timelineStarts = <Duration>[];
    var clipStart = Duration.zero;
    var totalDuration = Duration.zero;

    for (final clip in clips) {
      final start = clipStart;
      clipStart += clip.playbackDuration;
      totalDuration += clip.playbackDuration;

      final video = clip.video;
      final endTime = clip.duration - clip.trimEnd;
      if (video?.file == null ||
          clip.volume <= 0 ||
          endTime <= clip.trimStart) {
        continue;
      }

      timelineStarts.add(start);
      segments.add(
        AudioMergeSegment(
          video: video!,
          startTime: clip.trimStart,
          endTime: endTime,
          speed: _effectiveSpeed(clip),
        ),
      );
    }

    if (segments.isEmpty) return const CaptionsEmpty();

    final AudioMergeResult merged;
    try {
      merged = await _audioExtractionService.mergeClipAudio(
        segments: segments,
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
      final mapped = _mapMergedToTimeline(
        words,
        merged.segments,
        timelineStarts,
      );
      if (mapped.isEmpty) return const CaptionsEmpty();
      final cues = _buildCues(groupCaptionSegments(mapped), totalDuration);
      return cues.isEmpty ? const CaptionsEmpty() : CaptionsGenerated(cues);
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

  /// On-device path: transcribe each clip's audio separately.
  ///
  /// The OS recognizer is designed for short utterances, so each clip is
  /// extracted and transcribed on its own (with a per-clip timeout) and its
  /// words are windowed to the clip's trim range and shifted onto the timeline.
  Future<CaptionGenerationOutcome> _generateOnDevicePerClip({
    required List<DivineVideoClip> clips,
    required String localeIdentifier,
  }) async {
    final words = <CaptionSegment>[];
    var clipStart = Duration.zero;
    var totalDuration = Duration.zero;
    for (final clip in clips) {
      totalDuration += clip.playbackDuration;
    }

    // Some on-device recognizers reject an explicit language even when it is
    // the device's own default, so [_recognizeOnDevice] retries without one.
    // Once that happens, drop the language for the remaining clips too rather
    // than pay the failed first attempt on every clip.
    String? effectiveLocale = localeIdentifier;

    for (final clip in clips) {
      final videoPath = clip.video?.file?.path;
      final start = clipStart;
      clipStart += clip.playbackDuration;
      if (videoPath == null || clip.volume <= 0) continue;

      final String audioPath;
      try {
        final extraction = await _audioExtractionService.extractAudio(
          videoPath: videoPath,
          speed: _effectiveSpeed(clip),
        );
        audioPath = extraction.audioFilePath;
      } on AudioExtractionException catch (e) {
        if (e.message.contains('no audio track')) continue;
        Log.warning(
          '🎬 Caption audio extraction failed for clip ${clip.id}: $e',
          name: _logName,
          category: LogCategory.video,
        );
        return const CaptionsFailed(CaptionGenerationFailure.failed);
      }

      try {
        final result = await _recognizeOnDevice(
          audioPath: audioPath,
          localeIdentifier: effectiveLocale,
        );
        if (result.localeRejected) effectiveLocale = null;
        words.addAll(
          _windowToTimeline(result.segments, clip, clipStartTime: start),
        );
      } on TimeoutException {
        Log.warning(
          '🎬 On-device caption transcription timed out for clip ${clip.id}',
          name: _logName,
          category: LogCategory.video,
        );
        return const CaptionsFailed(CaptionGenerationFailure.failed);
      } on CaptionGenerationException catch (e) {
        Log.warning(
          '🎬 Caption transcription failed for clip ${clip.id}: $e',
          name: _logName,
          category: LogCategory.video,
        );
        return CaptionsFailed(_mapFailure(e));
      } on Object catch (e) {
        // The OS recognizer can throw untyped errors (missing plugin,
        // malformed native result). Honor the "never throws" contract so the
        // caller shows the manual-entry fallback instead of stalling.
        Log.warning(
          '🎬 On-device caption transcription failed unexpectedly for clip '
          '${clip.id}: $e',
          name: _logName,
          category: LogCategory.video,
        );
        return const CaptionsFailed(CaptionGenerationFailure.failed);
      } finally {
        await _cleanupQuietly(audioPath);
      }
    }

    if (words.isEmpty) return const CaptionsEmpty();
    final cues = _buildCues(groupCaptionSegments(words), totalDuration);
    return cues.isEmpty ? const CaptionsEmpty() : CaptionsGenerated(cues);
  }

  /// Runs on-device recognition for one clip. Some on-device recognizers reject
  /// an explicit language even when it is the device's own default, so on
  /// [SpeechRecognizerUnavailableException] this retries once without a
  /// language (the device default). Returns the words and whether the language
  /// was dropped, so the caller can skip the doomed first attempt on later
  /// clips.
  Future<({List<CaptionSegment> segments, bool localeRejected})>
  _recognizeOnDevice({
    required String audioPath,
    required String? localeIdentifier,
  }) async {
    try {
      final segments = await _captionGenerator
          .generateCaptions(
            audioPath: audioPath,
            localeIdentifier: localeIdentifier,
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
          .generateCaptions(audioPath: audioPath)
          .timeout(_onDeviceClipTimeout);
      return (segments: segments, localeRejected: true);
    }
  }

  /// Shifts each transcribed word from merged-output time onto the composition
  /// timeline. A word is attributed to the segment whose output window contains
  /// its start, then moved by that segment's `timelineStart - outputStart`
  /// delta — the two differ only when clips were skipped from the merge (muted
  /// / no file), leaving the skipped clip's timeline span as a caption-free gap.
  ///
  /// The merged audio is gap-free, so a word can straddle the boundary between
  /// two concatenated segments. Its endpoints are clamped to the attributed
  /// segment's output window before the shift, so a word whose tail belongs to
  /// the next audible clip is capped at this clip's timeline end instead of
  /// spilling later speech into the skipped clip's muted gap. The full word
  /// text is kept intact; only its timing is bounded.
  List<CaptionSegment> _mapMergedToTimeline(
    List<CaptionSegment> words,
    List<AudioMergeSegmentOffset> offsets,
    List<Duration> timelineStarts,
  ) {
    if (offsets.isEmpty) return const [];
    final mapped = <CaptionSegment>[];
    for (final word in words) {
      final index = _segmentIndexFor(word.start, offsets);
      final offset = offsets[index];
      final delta = timelineStarts[index] - offset.outputStart;
      final start =
          _clamp(word.start, offset.outputStart, offset.outputEnd) + delta;
      final end =
          _clamp(word.end, offset.outputStart, offset.outputEnd) + delta;
      mapped.add(CaptionSegment(text: word.text, start: start, end: end));
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

  /// Windows [segments] (timed in the clip's full-source playback time) to the
  /// clip's trim range and shifts them onto the composition timeline.
  List<CaptionSegment> _windowToTimeline(
    List<CaptionSegment> segments,
    DivineVideoClip clip, {
    required Duration clipStartTime,
  }) {
    final windowStart = clip.sourceDurationToPlaybackDuration(clip.trimStart);
    final windowEnd = windowStart + clip.playbackDuration;
    final shift = clipStartTime - windowStart;
    return [
      for (final segment in segments)
        if (segment.end > windowStart && segment.start < windowEnd)
          CaptionSegment(
            text: segment.text,
            start: _clamp(segment.start, windowStart, windowEnd) + shift,
            end: _clamp(segment.end, windowStart, windowEnd) + shift,
          ),
    ];
  }

  /// Turns grouped segments into cues that keep their word timings. The
  /// server transcript only times whole cues, so its words arrive spread over
  /// each cue by `groupCaptionSegments`.
  List<CaptionCue> _buildCues(
    List<CaptionSegment> grouped,
    Duration totalDuration,
  ) => [
    for (final (index, segment) in grouped.indexed)
      CaptionCue(
        id: 'cue-$index',
        text: segment.text,
        start: segment.start,
        end: segment.end > totalDuration ? totalDuration : segment.end,
        words: segment.words,
      ),
  ];

  static Duration _clamp(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static double _effectiveSpeed(DivineVideoClip clip) {
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
