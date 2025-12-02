// ABOUTME: Tests for FFmpeg aspect ratio crop filter generation
// ABOUTME: Validates that crop filters produce correct aspect ratios for square and vertical videos

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

/// Aspect ratio options for video recording
enum AspectRatio {
  square, // 1:1
  vertical, // 9:16
}

/// Builds FFmpeg crop filter for the specified aspect ratio
String buildCropFilter(AspectRatio aspectRatio) {
  switch (aspectRatio) {
    case AspectRatio.square:
      // Center crop to 1:1 (existing production logic)
      return "crop=min(iw\\,ih):min(iw\\,ih):(iw-min(iw\\,ih))/2:(ih-min(iw\\,ih))/2";

    case AspectRatio.vertical:
      // Center crop to 9:16 vertical
      // Target aspect ratio: 9/16 (width/height)
      // If input is wider than 9:16 (iw/ih > 9/16), crop width
      // If input is narrower than 9:16 (iw/ih < 9/16), crop height
      return "crop='if(gt(iw/ih\\,9/16)\\,ih*9/16\\,iw)':'if(gt(iw/ih\\,9/16)\\,ih\\,iw*16/9)':'(iw-if(gt(iw/ih\\,9/16)\\,ih*9/16\\,iw))/2':'(ih-if(gt(iw/ih\\,9/16)\\,ih\\,iw*16/9))/2'";
  }
}

void main() {
  group('FFmpeg Crop Filter Tests', () {
    test('Square crop filter generates valid FFmpeg syntax', () {
      final filter = buildCropFilter(AspectRatio.square);

      expect(filter, isNotEmpty);
      expect(filter, startsWith('crop='));
      expect(filter, contains('min(iw'));
      expect(filter, contains('min(iw\\,ih)'));
    });

    test('Vertical crop filter generates valid FFmpeg syntax', () {
      final filter = buildCropFilter(AspectRatio.vertical);

      expect(filter, isNotEmpty);
      expect(filter, startsWith('crop='));
      expect(filter, contains('9/16'));
    });

    test('Square crop filter matches production formula', () {
      final filter = buildCropFilter(AspectRatio.square);
      const expectedFilter =
          "crop=min(iw\\,ih):min(iw\\,ih):(iw-min(iw\\,ih))/2:(ih-min(iw\\,ih))/2";

      expect(filter, equals(expectedFilter));
    });
  });

  group('FFmpeg Integration Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ffmpeg_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Square crop produces 1:1 aspect ratio from landscape input', () async {
      // Create a test video: 1920x1080 (landscape 16:9)
      final inputPath = path.join(tempDir.path, 'input_landscape.mp4');
      final outputPath = path.join(tempDir.path, 'output_square.mp4');

      // Generate 1-second test video (1920x1080, 16:9)
      final generateCmd =
          'ffmpeg -f lavfi -i testsrc=duration=1:size=1920x1080:rate=30 -pix_fmt yuv420p "$inputPath"';
      final generateResult = await Process.run('sh', ['-c', generateCmd]);

      expect(
        generateResult.exitCode,
        equals(0),
        reason: 'Failed to generate test video: ${generateResult.stderr}',
      );
      expect(File(inputPath).existsSync(), isTrue);

      // Apply square crop filter
      final cropFilter = buildCropFilter(AspectRatio.square);
      final cropCmd =
          'ffmpeg -i "$inputPath" -vf "$cropFilter" -c:v libx264 -preset ultrafast "$outputPath"';
      final cropResult = await Process.run('sh', ['-c', cropCmd]);

      expect(
        cropResult.exitCode,
        equals(0),
        reason: 'FFmpeg crop failed: ${cropResult.stderr}',
      );
      expect(File(outputPath).existsSync(), isTrue);

      // Verify output dimensions are 1:1 (square)
      final probeCmd =
          'ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$outputPath"';
      final probeResult = await Process.run('sh', ['-c', probeCmd]);

      expect(
        probeResult.exitCode,
        equals(0),
        reason: 'FFprobe failed: ${probeResult.stderr}',
      );

      final dimensions = probeResult.stdout.toString().trim().split('x');
      final width = int.parse(dimensions[0]);
      final height = int.parse(dimensions[1]);

      expect(
        width,
        equals(height),
        reason:
            'Square crop should produce 1:1 aspect ratio, got ${width}x${height}',
      );
      expect(
        width,
        equals(1080),
        reason: 'Square crop of 1920x1080 should be 1080x1080',
      );
    });

    test('Vertical crop produces 9:16 aspect ratio from landscape input', () async {
      // Create a test video: 1920x1080 (landscape 16:9)
      final inputPath = path.join(
        tempDir.path,
        'input_landscape_vertical_test.mp4',
      );
      final outputPath = path.join(tempDir.path, 'output_vertical.mp4');

      // Generate 1-second test video (1920x1080, 16:9)
      final generateCmd =
          'ffmpeg -f lavfi -i testsrc=duration=1:size=1920x1080:rate=30 -pix_fmt yuv420p "$inputPath"';
      final generateResult = await Process.run('sh', ['-c', generateCmd]);

      expect(
        generateResult.exitCode,
        equals(0),
        reason: 'Failed to generate test video: ${generateResult.stderr}',
      );
      expect(File(inputPath).existsSync(), isTrue);

      // Apply vertical crop filter
      final cropFilter = buildCropFilter(AspectRatio.vertical);
      final cropCmd =
          'ffmpeg -i "$inputPath" -vf "$cropFilter" -c:v libx264 -preset ultrafast "$outputPath"';
      final cropResult = await Process.run('sh', ['-c', cropCmd]);

      expect(
        cropResult.exitCode,
        equals(0),
        reason: 'FFmpeg crop failed: ${cropResult.stderr}',
      );
      expect(File(outputPath).existsSync(), isTrue);

      // Verify output dimensions are 9:16 (vertical)
      final probeCmd =
          'ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$outputPath"';
      final probeResult = await Process.run('sh', ['-c', probeCmd]);

      expect(
        probeResult.exitCode,
        equals(0),
        reason: 'FFprobe failed: ${probeResult.stderr}',
      );

      final dimensions = probeResult.stdout.toString().trim().split('x');
      final width = int.parse(dimensions[0]);
      final height = int.parse(dimensions[1]);

      // 9:16 aspect ratio check (width/height ≈ 0.5625)
      final aspectRatio = width / height;
      final expected916 = 9.0 / 16.0;

      expect(
        aspectRatio,
        closeTo(expected916, 0.01),
        reason:
            'Vertical crop should produce 9:16 aspect ratio, got ${width}x${height} (ratio: $aspectRatio)',
      );

      // From 1920x1080 input, crop width to match 9:16
      // Expected: 1080 * 9/16 = 607.5 ≈ 608 width, 1080 height
      expect(
        height,
        equals(1080),
        reason: 'Height should match input height (1080)',
      );
      expect(
        width,
        closeTo(607, 2),
        reason: 'Width should be cropped to 9:16 ratio (~607)',
      );
    });

    test('Vertical crop produces 9:16 aspect ratio from portrait input', () async {
      // Create a test video: 1080x1920 (portrait 9:16 - already correct ratio)
      final inputPath = path.join(tempDir.path, 'input_portrait.mp4');
      final outputPath = path.join(
        tempDir.path,
        'output_portrait_vertical.mp4',
      );

      // Generate 1-second test video (1080x1920, 9:16)
      final generateCmd =
          'ffmpeg -f lavfi -i testsrc=duration=1:size=1080x1920:rate=30 -pix_fmt yuv420p "$inputPath"';
      final generateResult = await Process.run('sh', ['-c', generateCmd]);

      expect(
        generateResult.exitCode,
        equals(0),
        reason: 'Failed to generate test video: ${generateResult.stderr}',
      );
      expect(File(inputPath).existsSync(), isTrue);

      // Apply vertical crop filter
      final cropFilter = buildCropFilter(AspectRatio.vertical);
      final cropCmd =
          'ffmpeg -i "$inputPath" -vf "$cropFilter" -c:v libx264 -preset ultrafast "$outputPath"';
      final cropResult = await Process.run('sh', ['-c', cropCmd]);

      expect(
        cropResult.exitCode,
        equals(0),
        reason: 'FFmpeg crop failed: ${cropResult.stderr}',
      );
      expect(File(outputPath).existsSync(), isTrue);

      // Verify output dimensions remain 9:16 (no cropping needed)
      final probeCmd =
          'ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$outputPath"';
      final probeResult = await Process.run('sh', ['-c', probeCmd]);

      expect(
        probeResult.exitCode,
        equals(0),
        reason: 'FFprobe failed: ${probeResult.stderr}',
      );

      final dimensions = probeResult.stdout.toString().trim().split('x');
      final width = int.parse(dimensions[0]);
      final height = int.parse(dimensions[1]);

      // Should preserve original 9:16 dimensions
      expect(width, equals(1080), reason: 'Width should be preserved (1080)');
      expect(height, equals(1920), reason: 'Height should be preserved (1920)');

      final aspectRatio = width / height;
      final expected916 = 9.0 / 16.0;
      expect(
        aspectRatio,
        closeTo(expected916, 0.01),
        reason: 'Should preserve 9:16 aspect ratio',
      );
    });
  });
}
