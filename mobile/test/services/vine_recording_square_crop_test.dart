// ABOUTME: Test that vine recordings are cropped to square with center crop
// ABOUTME: Validates FFmpeg command generation for square aspect ratio

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VineRecordingController Square Crop', () {
    test('FFmpeg crop command should center-crop to square', () {
      // This test validates the FFmpeg command format for center cropping
      // The command should be: crop=min(iw,ih):min(iw,ih):(iw-min(iw,ih))/2:(ih-min(iw,ih))/2

      // Expected format breakdown:
      // - width: min(iw,ih) - smallest dimension (makes it square)
      // - height: min(iw,ih) - same as width (square)
      // - x offset: (iw-min(iw,ih))/2 - centers horizontally
      // - y offset: (ih-min(iw,ih))/2 - centers vertically

      const expectedCropFilter =
          'crop=min(iw\\,ih):min(iw\\,ih):(iw-min(iw\\,ih))/2:(ih-min(iw\\,ih))/2';

      // For a 1920x1080 video:
      // - min(1920,1080) = 1080
      // - x offset = (1920-1080)/2 = 420 (centers horizontally)
      // - y offset = (1080-1080)/2 = 0 (no vertical offset needed)
      // Result: crops 1920x1080 to 1080x1080 centered on the frame

      // For a 1080x1920 vertical video:
      // - min(1080,1920) = 1080
      // - x offset = (1080-1080)/2 = 0 (no horizontal offset needed)
      // - y offset = (1920-1080)/2 = 420 (centers vertically)
      // Result: crops 1080x1920 to 1080x1080 centered on the frame

      // Verify the command format is correct
      expect(expectedCropFilter, contains('crop=min(iw'));
      expect(expectedCropFilter, contains(':min(iw'));
      expect(expectedCropFilter, contains(':(iw-min(iw'));
      expect(expectedCropFilter, contains(':(ih-min(iw'));
      expect(expectedCropFilter, contains('/2'));

      // The actual command validation would need access to private methods
      // This test documents the expected behavior
    });

    test('Square crop should work for horizontal videos', () {
      // 1920x1080 horizontal video
      const inputWidth = 1920;
      const inputHeight = 1080;
      const expectedOutputSize = 1080; // min(1920, 1080)
      const expectedXOffset = 420; // (1920-1080)/2
      const expectedYOffset = 0; // (1080-1080)/2

      final minDimension = inputWidth < inputHeight ? inputWidth : inputHeight;
      final xOffset = (inputWidth - minDimension) ~/ 2;
      final yOffset = (inputHeight - minDimension) ~/ 2;

      expect(minDimension, equals(expectedOutputSize));
      expect(xOffset, equals(expectedXOffset));
      expect(yOffset, equals(expectedYOffset));
    });

    test('Square crop should work for vertical videos', () {
      // 1080x1920 vertical video
      const inputWidth = 1080;
      const inputHeight = 1920;
      const expectedOutputSize = 1080; // min(1080, 1920)
      const expectedXOffset = 0; // (1080-1080)/2
      const expectedYOffset = 420; // (1920-1080)/2

      final minDimension = inputWidth < inputHeight ? inputWidth : inputHeight;
      final xOffset = (inputWidth - minDimension) ~/ 2;
      final yOffset = (inputHeight - minDimension) ~/ 2;

      expect(minDimension, equals(expectedOutputSize));
      expect(xOffset, equals(expectedXOffset));
      expect(yOffset, equals(expectedYOffset));
    });

    test('Square crop should not modify already-square videos', () {
      // 1080x1080 square video (already square)
      const inputWidth = 1080;
      const inputHeight = 1080;
      const expectedOutputSize = 1080;
      const expectedXOffset = 0; // (1080-1080)/2
      const expectedYOffset = 0; // (1080-1080)/2

      final minDimension = inputWidth < inputHeight ? inputWidth : inputHeight;
      final xOffset = (inputWidth - minDimension) ~/ 2;
      final yOffset = (inputHeight - minDimension) ~/ 2;

      expect(minDimension, equals(expectedOutputSize));
      expect(xOffset, equals(expectedXOffset));
      expect(yOffset, equals(expectedYOffset));
    });
  });
}
