// ABOUTME: Service for exporting video clips with FFmpeg operations
// ABOUTME: Handles concatenation, text overlays, audio mixing, and thumbnail generation

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/text_overlay.dart';
import 'package:openvine/services/text_overlay_renderer.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Export stages for progress reporting
enum ExportStage {
  concatenating,
  applyingTextOverlay,
  mixingAudio,
  generatingThumbnail,
  complete,
}

/// Result of video export operation
class ExportResult {
  const ExportResult({
    required this.videoPath,
    required this.duration,
    this.thumbnailPath,
  });

  final String videoPath;
  final String? thumbnailPath;
  final Duration duration;
}

/// Service for exporting video clips with FFmpeg operations
class VideoExportService {
  /// Build crop filter string for the given aspect ratio
  ///
  /// Handles any input orientation (landscape or portrait) by conditionally
  /// cropping width or height to achieve the target aspect ratio.
  String _buildCropFilter(AspectRatio aspectRatio) {
    switch (aspectRatio) {
      case AspectRatio.square:
        // Center crop to 1:1 (minimum dimension)
        return "crop=min(iw\\,ih):min(iw\\,ih):(iw-min(iw\\,ih))/2:(ih-min(iw\\,ih))/2";
      case AspectRatio.vertical:
        // Center crop to 9:16 (portrait) - handles both landscape and portrait inputs
        // If input is wider than 9:16: crop width, keep height
        // If input is taller than 9:16: keep width, crop height
        // Uses if(condition, true_val, false_val) to select crop dimensions
        return "crop=if(gt(iw/ih\\,9/16)\\,ih*9/16\\,iw):if(gt(iw/ih\\,9/16)\\,ih\\,iw*16/9):(iw-out_w)/2:(ih-out_h)/2";
    }
  }

  /// Get platform-appropriate video encoder arguments
  String _getVideoEncoderArgs() {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return '-c:v h264_videotoolbox -b:v 4M';
    }
    return '-c:v libx264 -preset fast -crf 23';
  }

  /// Concatenates multiple video segments into a single video with optional aspect ratio crop
  ///
  /// If [aspectRatio] is provided, applies the crop filter to the final output.
  /// If [muteAudio] is true, strips all audio from the output.
  /// Otherwise uses lossless copy mode.
  Future<String> concatenateSegments(
    List<RecordingClip> clips, {
    AspectRatio? aspectRatio,
    bool muteAudio = false,
  }) async {
    if (clips.isEmpty) {
      throw ArgumentError('Cannot concatenate empty clip list');
    }

    // If only one clip and no processing needed, return it directly
    // If crop or mute is needed, we still need to process even a single clip
    if (clips.length == 1 && aspectRatio == null && !muteAudio) {
      Log.info(
        'Single clip detected, no processing needed, skipping FFmpeg',
        name: 'VideoExportService',
        category: LogCategory.system,
      );
      return clips.first.filePath;
    }

    try {
      Log.info(
        'Processing ${clips.length} clips${aspectRatio != null ? " with ${aspectRatio.name} crop" : ""}${muteAudio ? " (muted)" : ""}',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      // Get temp directory for concat list file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final listFilePath = '${tempDir.path}/concat_list_$timestamp.txt';
      final outputPath = '${tempDir.path}/concatenated_$timestamp.mp4';

      // Create concat list file
      final sortedClips = List<RecordingClip>.from(clips)
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      final listContent = sortedClips
          .map((clip) => "file '${clip.filePath}'")
          .join('\n');

      await File(listFilePath).writeAsString(listContent);

      Log.info(
        'Created concat list file: $listFilePath',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      // Build FFmpeg command - with or without crop filter and audio
      String command;
      final audioArgs = muteAudio ? '-an' : '-c:a aac';

      if (aspectRatio != null) {
        // With crop: need to re-encode
        final cropFilter = _buildCropFilter(aspectRatio);
        command =
            '-y -f concat -safe 0 -i "$listFilePath" -vf "$cropFilter" ${_getVideoEncoderArgs()} $audioArgs "$outputPath"';
      } else if (muteAudio) {
        // No crop but muting: need to process to strip audio
        command =
            '-y -f concat -safe 0 -i "$listFilePath" -c:v copy $audioArgs "$outputPath"';
      } else {
        // Without crop or mute: lossless copy
        command = '-f concat -safe 0 -i "$listFilePath" -c copy "$outputPath"';
      }

      Log.info(
        'Running FFmpeg: $command',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        Log.info(
          'Successfully processed clips to: $outputPath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );

        // Clean up list file
        await File(listFilePath).delete();

        return outputPath;
      } else {
        final output = await session.getOutput();
        throw Exception('FFmpeg processing failed: $output');
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to process clips: $e',
        name: 'VideoExportService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Applies a text overlay PNG image to a video
  ///
  /// Uses FFmpeg overlay filter to composite the PNG on the video.
  /// The PNG should contain all text rendered by TextOverlayRenderer.
  Future<String> applyTextOverlay(
    String videoPath,
    Uint8List textOverlayImage,
  ) async {
    try {
      Log.info(
        'Applying text overlay to video: $videoPath',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      // Get temp directory for overlay PNG and output
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final overlayPngPath = '${tempDir.path}/overlay_$timestamp.png';
      final outputPath = '${tempDir.path}/with_overlay_$timestamp.mp4';

      // Write overlay PNG to temp file
      await File(overlayPngPath).writeAsBytes(textOverlayImage);

      Log.info(
        'Saved overlay PNG to: $overlayPngPath',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      // Run FFmpeg overlay command
      // Use overlay filter to composite PNG on video
      final command =
          '-i "$videoPath" -i "$overlayPngPath" -filter_complex "[0:v][1:v]overlay=0:0" -c:a copy "$outputPath"';

      Log.info(
        'Running FFmpeg overlay: $command',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        Log.info(
          'Successfully applied overlay to: $outputPath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );

        // Clean up overlay PNG
        await File(overlayPngPath).delete();

        return outputPath;
      } else {
        final output = await session.getOutput();
        throw Exception('FFmpeg overlay failed: $output');
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to apply text overlay: $e',
        name: 'VideoExportService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mixes background audio with video
  ///
  /// For bundled assets, copies from Flutter assets to temp file.
  /// For custom sounds (file paths), uses the file directly.
  /// Runs: `ffmpeg -i video.mp4 -i audio.mp3 -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest output.mp4`
  Future<String> mixAudio(
    String videoPath,
    String audioPath,
  ) async {
    try {
      Log.info(
        'Mixing audio: $audioPath with video: $videoPath',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      // Get temp directory for output
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/with_audio_$timestamp.mp4';

      String audioFilePath;

      // Check if it's a file path (custom sound) or asset path (bundled sound)
      if (audioPath.startsWith('/') || audioPath.startsWith('file://')) {
        // Custom sound - use file path directly
        audioFilePath = audioPath.replaceFirst('file://', '');
        Log.info(
          'Using custom sound file: $audioFilePath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );
      } else {
        // Bundled asset - copy to temp file
        audioFilePath = '${tempDir.path}/audio_$timestamp.mp3';
        final audioBytes = await rootBundle.load(audioPath);
        await File(audioFilePath).writeAsBytes(
          audioBytes.buffer.asUint8List(),
        );
        Log.info(
          'Copied asset to: $audioFilePath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );
      }

      // Run FFmpeg audio mixing command
      // -c:v copy = copy video codec (no re-encoding)
      // -c:a aac = encode audio to AAC
      // -map 0:v:0 = use video from first input
      // -map 1:a:0 = use audio from second input
      // -shortest = finish when shortest stream ends
      final command =
          '-i "$videoPath" -i "$audioFilePath" -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest "$outputPath"';

      Log.info(
        'Running FFmpeg audio mix: $command',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        Log.info(
          'Successfully mixed audio to: $outputPath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );

        // Clean up temp audio file only if we copied from assets
        if (!audioPath.startsWith('/') && !audioPath.startsWith('file://')) {
          await File(audioFilePath).delete();
        }

        return outputPath;
      } else {
        final output = await session.getOutput();
        throw Exception('FFmpeg audio mix failed: $output');
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to mix audio: $e',
        name: 'VideoExportService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Generates a thumbnail from a video file
  ///
  /// Extracts a frame from the middle of the video
  Future<String?> generateThumbnail(String videoPath) async {
    try {
      Log.info(
        'Generating thumbnail from video: $videoPath',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        quality: 85,
      );

      if (thumbnailPath != null) {
        Log.info(
          'Generated thumbnail: $thumbnailPath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );
      } else {
        Log.warning(
          'Failed to generate thumbnail for: $videoPath',
          name: 'VideoExportService',
          category: LogCategory.system,
        );
      }

      return thumbnailPath;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to generate thumbnail: $e',
        name: 'VideoExportService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Exports video clips with optional text overlays and audio mixing
  ///
  /// Full pipeline:
  /// 1. Concatenate segments (if multiple clips)
  /// 2. Apply text overlay (if textOverlays provided)
  /// 3. Mix audio (if soundId provided)
  /// 4. Generate thumbnail
  ///
  /// Progress is reported through [onProgress] callback with stage and progress (0.0-1.0)
  Future<ExportResult> export({
    required List<RecordingClip> clips,
    List<TextOverlay>? textOverlays,
    String? soundId,
    required void Function(ExportStage, double) onProgress,
  }) async {
    if (clips.isEmpty) {
      throw ArgumentError('Cannot export empty clip list');
    }

    try {
      Log.info(
        'Starting export pipeline: ${clips.length} clips, ${textOverlays?.length ?? 0} overlays, sound: ${soundId != null ? "yes" : "no"}',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      String currentVideoPath;

      // Step 1: Concatenate segments
      onProgress(ExportStage.concatenating, 0.0);
      currentVideoPath = await concatenateSegments(clips);
      onProgress(ExportStage.concatenating, 1.0);

      // Step 2: Apply text overlay (if provided)
      if (textOverlays != null && textOverlays.isNotEmpty) {
        onProgress(ExportStage.applyingTextOverlay, 0.0);

        // Render text overlays to PNG
        final renderer = TextOverlayRenderer();
        final overlayImage = await renderer.renderOverlays(
          textOverlays,
          const Size(1080, 1920), // Standard 9:16 vertical video
        );

        final previousPath = currentVideoPath;
        currentVideoPath = await applyTextOverlay(currentVideoPath, overlayImage);

        // Clean up previous file if it was a temp file
        if (previousPath != clips.first.filePath) {
          await File(previousPath).delete();
        }

        onProgress(ExportStage.applyingTextOverlay, 1.0);
      }

      // Step 3: Mix audio (if provided)
      if (soundId != null) {
        onProgress(ExportStage.mixingAudio, 0.0);

        // Audio asset path should be provided or looked up from SoundLibraryService
        // For now, assume soundId is the asset path
        final audioAssetPath = soundId;

        final previousPath = currentVideoPath;
        currentVideoPath = await mixAudio(currentVideoPath, audioAssetPath);

        // Clean up previous file if it was a temp file
        if (previousPath != clips.first.filePath) {
          await File(previousPath).delete();
        }

        onProgress(ExportStage.mixingAudio, 1.0);
      }

      // Step 4: Generate thumbnail
      onProgress(ExportStage.generatingThumbnail, 0.0);
      final thumbnailPath = await generateThumbnail(currentVideoPath);
      onProgress(ExportStage.generatingThumbnail, 1.0);

      // Calculate total duration
      final totalDuration = clips.fold<Duration>(
        Duration.zero,
        (sum, clip) => sum + clip.duration,
      );

      onProgress(ExportStage.complete, 1.0);

      Log.info(
        'Export complete: $currentVideoPath (${totalDuration.inSeconds}s)',
        name: 'VideoExportService',
        category: LogCategory.system,
      );

      return ExportResult(
        videoPath: currentVideoPath,
        thumbnailPath: thumbnailPath,
        duration: totalDuration,
      );
    } catch (e, stackTrace) {
      Log.error(
        'Export failed: $e',
        name: 'VideoExportService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
