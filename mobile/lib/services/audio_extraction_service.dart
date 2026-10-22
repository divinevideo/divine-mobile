// ABOUTME: Service for extracting audio tracks from video files using ProVideoEditor
// ABOUTME: Used by the audio reuse feature to create separate audio files for publishing

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/utils/draft_audio_path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Result of an audio extraction operation.
///
/// Contains the path to the extracted audio file along with metadata
/// needed for Blossom upload and Nostr event creation.
class AudioExtractionResult {
  /// Creates a new [AudioExtractionResult].
  const AudioExtractionResult({
    required this.audioFilePath,
    required this.duration,
    required this.fileSize,
    required this.sha256Hash,
    required this.mimeType,
  });

  /// Path to the extracted audio file.
  final String audioFilePath;

  /// Duration of the audio in seconds.
  final double duration;

  /// File size in bytes.
  final int fileSize;

  /// SHA-256 hash of the audio file (hex string).
  final String sha256Hash;

  /// MIME type of the audio file (e.g., "audio/wav").
  final String mimeType;

  @override
  String toString() {
    return 'AudioExtractionResult('
        'duration: ${duration.toStringAsFixed(2)}s, '
        'size: ${(fileSize / 1024).toStringAsFixed(2)}KB, '
        'mimeType: $mimeType'
        ')';
  }
}

/// Exception thrown when audio extraction fails.
class AudioExtractionException implements Exception {
  /// Creates a new [AudioExtractionException].
  const AudioExtractionException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying cause of the exception, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'AudioExtractionException: $message (caused by: $cause)';
    }
    return 'AudioExtractionException: $message';
  }
}

/// Service for extracting audio tracks from video files.
///
/// Uses ProVideoEditor to extract the audio track from a video file and save it
/// as a separate WAV file. This is used by the audio reuse feature when
/// a user publishes a video with "Allow others to use this audio" enabled.
///
/// Usage:
/// ```dart
/// final service = AudioExtractionService();
/// try {
///   final result = await service.extractAudio(videoPath: '/path/to/video.mp4');
///   print('Audio extracted: ${result.audioFilePath}');
///   print('Duration: ${result.duration}s');
///   print('Hash: ${result.sha256Hash}');
/// } on AudioExtractionException catch (e) {
///   print('Failed: $e');
/// }
/// ```
class AudioExtractionService {
  static const String _logName = 'AudioExtractionService';
  static const LogCategory _logCategory = LogCategory.video;

  /// MIME type for WAV audio files.
  static const String _wavMimeType = 'audio/wav';

  /// Tracks temporary audio files created by this service for cleanup.
  final List<String> _temporaryFiles = [];

  /// Extracts the audio track from a video file.
  ///
  /// The audio is extracted as a WAV to ensure compatibility with all source
  /// codecs. The M4A passthrough path fails on macOS when the source audio
  /// cannot be copied without re-encoding (e.g. LPCM).
  ///
  /// [videoPath] - Path to the source video file.
  /// [speed] - Optional playback speed to apply to the extracted audio.
  /// [outputDirectory] - Where to write the file. Defaults to the temporary
  /// directory, which suits one-shot consumers that read the audio and drop
  /// it. Pass a persistent directory when the result outlives the session —
  /// see [extractAudioForDraft].
  ///
  /// Returns an [AudioExtractionResult] containing the path to the extracted
  /// audio file and metadata (duration, file size, SHA-256 hash, MIME type).
  ///
  /// Throws [AudioExtractionException] if:
  /// - The video file does not exist
  /// - The video has no audio track
  /// - Audio extraction fails
  Future<AudioExtractionResult> extractAudio({
    required String videoPath,
    double? speed,
    Directory? outputDirectory,
  }) async {
    final effectiveSpeed = speed != null && speed > 0 ? speed : 1.0;

    Log.info(
      'Starting audio extraction from: $videoPath',
      name: _logName,
      category: _logCategory,
    );

    // Verify video file exists
    final videoFile = File(videoPath);
    if (!videoFile.existsSync()) {
      Log.error(
        'Video file not found: $videoPath',
        name: _logName,
        category: _logCategory,
      );
      throw const AudioExtractionException('Video file not found');
    }

    // Check if video has an audio stream
    final hasAudio = await _hasAudioStream(videoPath);
    if (!hasAudio) {
      Log.warning(
        'Video has no audio track: $videoPath',
        name: _logName,
        category: _logCategory,
      );
      throw const AudioExtractionException('Video has no audio track');
    }

    // Get duration from the video before extraction
    final videoDuration = await _getAudioDuration(videoPath);
    if (videoDuration == null || videoDuration <= 0) {
      Log.warning(
        'Could not determine audio duration for: $videoPath',
        name: _logName,
        category: _logCategory,
      );
      throw const AudioExtractionException(
        'Could not determine audio duration',
      );
    }

    // Generate output path — extension must match AudioFormat.wav
    final isTemporary = outputDirectory == null;
    final directory = outputDirectory ?? await getTemporaryDirectory();
    await directory.create(recursive: true);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${directory.path}/extracted_audio_$timestamp.wav';

    Log.debug(
      'Extracting audio to: $outputPath',
      name: _logName,
      category: _logCategory,
    );
    try {
      await ProVideoEditor.instance.extractAudioToFile(
        outputPath,
        AudioExtractConfigs(
          video: EditorVideo.file(videoPath),
          speed: effectiveSpeed,
          format: AudioFormat.wav,
        ),
      );
    } on AudioNoTrackException {
      throw const AudioExtractionException('Video has no audio track');
    } catch (e) {
      Log.error(
        'Audio extraction failed: $e',
        name: _logName,
        category: _logCategory,
      );
      throw AudioExtractionException('Failed to extract audio', cause: e);
    }

    // Verify output file exists
    final audioFile = File(outputPath);
    if (!audioFile.existsSync()) {
      Log.error(
        'Audio file was not created: $outputPath',
        name: _logName,
        category: _logCategory,
      );
      throw const AudioExtractionException('Audio file was not created');
    }

    // Track this file for potential cleanup. A caller-owned directory is not
    // tracked: `cleanupTemporaryFiles()` with no argument sweeps the whole
    // list, and a draft-owned track must not be reachable that way. Deleting
    // one by explicit path still works — see [cleanupAudioFile].
    if (isTemporary) _temporaryFiles.add(outputPath);

    // Calculate hash and get file size using streaming (memory efficient)
    Log.debug(
      'Calculating SHA-256 hash for audio file',
      name: _logName,
      category: _logCategory,
    );
    final hashResult = await HashUtil.sha256File(audioFile);

    Log.info(
      'Audio extraction complete: $outputPath',
      name: _logName,
      category: _logCategory,
    );
    final adjustedDuration = videoDuration / effectiveSpeed;

    Log.debug(
      'Audio details: duration=${adjustedDuration.toStringAsFixed(2)}s, '
      'size=${(hashResult.size / 1024).toStringAsFixed(2)}KB, '
      'hash=${hashResult.hash}',
      name: _logName,
      category: _logCategory,
    );

    return AudioExtractionResult(
      audioFilePath: outputPath,
      duration: adjustedDuration,
      fileSize: hashResult.size,
      sha256Hash: hashResult.hash,
      mimeType: _wavMimeType,
    );
  }

  /// Checks if a video file has an audio stream.
  ///
  /// Uses ProVideoEditor to analyze the media and check for an audio track.
  Future<bool> _hasAudioStream(String videoPath) async {
    try {
      final bool hasAudio = await ProVideoEditor.instance.hasAudioTrack(
        EditorVideo.file(videoPath),
      );

      return hasAudio;
    } catch (e) {
      Log.error(
        'Error checking audio stream: $e',
        name: _logName,
        category: _logCategory,
      );
      return false;
    }
  }

  /// Gets the audio duration from a video file in seconds.
  ///
  /// Uses ProVideoEditor to get media metadata and extract duration.
  Future<double?> _getAudioDuration(String videoPath) async {
    try {
      final metadata = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(videoPath),
      );

      return metadata.duration.inMilliseconds / 1000;
    } catch (e) {
      Log.error(
        'Error getting audio duration: $e',
        name: _logName,
        category: _logCategory,
      );
      return null;
    }
  }

  /// Merges the trimmed audio of several source [segments] into one WAV whose
  /// timeline is their gap-free concatenation, returning the written path plus
  /// a per-segment offset map. Caption generation uses this to transcribe a
  /// multi-clip video in a single pass instead of one call per clip.
  ///
  /// [sampleRate] / [channels] pin the output format (e.g. 16 kHz mono for
  /// speech recognition, which also keeps the file small).
  ///
  /// Throws [AudioExtractionException] if merging or file writing fails.
  Future<AudioMergeResult> mergeClipAudio({
    required List<AudioMergeSegment> segments,
    int? sampleRate,
    int? channels,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${tempDir.path}/merged_audio_$timestamp.wav';

    try {
      final result = await ProVideoEditor.instance.mergeAudioToFile(
        outputPath,
        AudioMergeConfigs(
          segments: segments,
          sampleRate: sampleRate,
          channels: channels,
        ),
      );
      _temporaryFiles.add(result.outputPath);
      return result;
    } catch (e) {
      Log.error(
        'Audio merge failed: $e',
        name: _logName,
        category: _logCategory,
      );
      throw AudioExtractionException('Failed to merge audio', cause: e);
    }
  }

  /// Extracts audio that will be attached to a draft's timeline.
  ///
  /// Same contract as [extractAudio], except the file is written where it can
  /// survive: an extracted track is persisted into the draft's editor history,
  /// and the temporary directory is both replaced on an app update and
  /// purgeable by iOS at any time, so a track left there goes silent without
  /// warning. The caller owns the file from here — draft deletion reclaims it
  /// through [AudioEvent.localFilePath].
  Future<AudioExtractionResult> extractAudioForDraft({
    required String videoPath,
    double? speed,
  }) async => extractAudio(
    videoPath: videoPath,
    speed: speed,
    outputDirectory: await _draftAudioDirectory(),
  );

  /// [extractAudioForDraft] for a clip under a speed ramp, whose sound
  /// follows the ramp: renders the window from [start] to [end] of
  /// [videoPath] with [speedRamp] and extracts the sound of that, so the track
  /// plays in step with the clip. Unlike a constant speed it covers the
  /// window only, from its first frame.
  ///
  /// Throws [AudioExtractionException] like [extractAudio], or when the
  /// window cannot be rendered.
  Future<AudioExtractionResult> extractRampedAudioForDraft({
    required String videoPath,
    required Duration start,
    required Duration end,
    required VideoSpeedRamp speedRamp,
  }) async {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final renderedPath = p.join(
      (await getTemporaryDirectory()).path,
      'ramped_audio_source_$timestamp.mp4',
    );
    try {
      await VideoEditorRenderService.renderNativeVideoToFile(
        renderedPath,
        VideoRenderData(
          id: 'ramped_audio_$timestamp',
          videoSegments: [
            VideoSegment(
              video: EditorVideo.file(videoPath),
              startTime: start == Duration.zero ? null : start,
              endTime: end,
              speedRamp: speedRamp,
            ),
          ],
        ),
      );
    } on Exception catch (e) {
      await _deleteQuietly(renderedPath);
      throw AudioExtractionException(
        'Failed to render the speed ramp',
        cause: e,
      );
    }
    try {
      return await extractAudioForDraft(videoPath: renderedPath);
    } finally {
      await _deleteQuietly(renderedPath);
    }
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone: the render failed before writing, or a cleanup ran.
    }
  }

  static Future<Directory> _draftAudioDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, extractedClipAudioDirName));
  }

  /// Cleans up temporary audio files created by this service.
  ///
  /// Call this method when you no longer need the extracted audio files
  /// (e.g., after uploading to Blossom server).
  ///
  /// [paths] - Optional list of specific paths to clean up. If not provided,
  /// cleans up all temporary files tracked by this service instance.
  Future<void> cleanupTemporaryFiles([List<String>? paths]) async {
    final filesToDelete = paths ?? List<String>.from(_temporaryFiles);

    Log.debug(
      'Cleaning up ${filesToDelete.length} temporary audio files',
      name: _logName,
      category: _logCategory,
    );

    for (final path in filesToDelete) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          await file.delete();
          Log.debug(
            'Deleted temporary file: $path',
            name: _logName,
            category: _logCategory,
          );
        }
        _temporaryFiles.remove(path);
      } catch (e) {
        Log.warning(
          'Failed to delete temporary file: $path ($e)',
          name: _logName,
          category: _logCategory,
        );
      }
    }
  }

  /// Cleans up a single audio file.
  ///
  /// [audioPath] - Path to the audio file to delete.
  Future<void> cleanupAudioFile(String audioPath) async {
    await cleanupTemporaryFiles([audioPath]);
  }
}
