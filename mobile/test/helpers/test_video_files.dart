// ABOUTME: Test video file helpers for comprehensive video processing pipeline testing
// ABOUTME: Provides test data factories for various video formats, sizes, and error scenarios

import 'dart:math';
import 'dart:typed_data';

/// Test video file helpers for comprehensive pipeline testing
class TestVideoFiles {
  static const int standardWidth = 640;
  static const int standardHeight = 480;
  static const int smallWidth = 320;
  static const int smallHeight = 240;
  static const int largeWidth = 1920;
  static const int largeHeight = 1080;

  /// Create test video frames with specific dimensions and format
  static List<Uint8List> createVideoFrames({
    int frameCount = 30,
    int width = standardWidth,
    int height = standardHeight,
    VideoTestFormat format = VideoTestFormat.rgb,
    VideoTestPattern pattern = VideoTestPattern.gradient,
  }) {
    final frames = <Uint8List>[];

    for (var i = 0; i < frameCount; i++) {
      frames.add(
        _createSingleFrame(
          width: width,
          height: height,
          frameIndex: i,
          format: format,
          pattern: pattern,
        ),
      );
    }

    return frames;
  }

  /// Create a single test frame with specified parameters
  static Uint8List _createSingleFrame({
    required int width,
    required int height,
    required int frameIndex,
    required VideoTestFormat format,
    required VideoTestPattern pattern,
  }) {
    final bytesPerPixel = format == VideoTestFormat.rgb ? 3 : 4;
    final frameSize = width * height * bytesPerPixel;
    final data = Uint8List(frameSize);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixelIndex = (y * width + x) * bytesPerPixel;
        final color = _generatePixelColor(
          x: x,
          y: y,
          width: width,
          height: height,
          frameIndex: frameIndex,
          pattern: pattern,
        );

        data[pixelIndex] = color.red;
        data[pixelIndex + 1] = color.green;
        data[pixelIndex + 2] = color.blue;

        if (format == VideoTestFormat.rgba) {
          data[pixelIndex + 3] = color.alpha;
        }
      }
    }

    return data;
  }

  /// Generate pixel color based on test pattern
  static TestColor _generatePixelColor({
    required int x,
    required int y,
    required int width,
    required int height,
    required int frameIndex,
    required VideoTestPattern pattern,
  }) {
    switch (pattern) {
      case VideoTestPattern.gradient:
        return _generateGradientColor(x, y, width, height);

      case VideoTestPattern.checkerboard:
        return _generateCheckerboardColor(x, y);

      case VideoTestPattern.animated:
        return _generateAnimatedColor(x, y, width, height, frameIndex);

      case VideoTestPattern.solid:
        return const TestColor(128, 128, 128, 255);

      case VideoTestPattern.noise:
        return _generateNoiseColor();
    }
  }

  static TestColor _generateGradientColor(int x, int y, int width, int height) {
    final normalizedX = x / width;
    final normalizedY = y / height;

    return TestColor(
      (normalizedX * 255).round(),
      (normalizedY * 255).round(),
      ((normalizedX + normalizedY) / 2 * 255).round(),
      255,
    );
  }

  static TestColor _generateCheckerboardColor(int x, int y) {
    const squareSize = 8;
    final isWhite = ((x ~/ squareSize) + (y ~/ squareSize)) % 2 == 0;

    return isWhite
        ? const TestColor(255, 255, 255, 255)
        : const TestColor(0, 0, 0, 255);
  }

  static TestColor _generateAnimatedColor(
    int x,
    int y,
    int width,
    int height,
    int frameIndex,
  ) {
    final time = frameIndex / 30.0; // Assuming 30 FPS
    final centerX = width / 2;
    final centerY = height / 2;
    final distance = sqrt(pow(x - centerX, 2) + pow(y - centerY, 2));

    final wave = sin((distance / 20.0) - (time * 2.0));
    final intensity = ((wave + 1.0) / 2.0 * 255).round();

    return TestColor(intensity, intensity, intensity, 255);
  }

  static TestColor _generateNoiseColor() {
    final random = Random();
    return TestColor(
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
      255,
    );
  }

  /// Create test metadata for various video scenarios
  static Map<String, dynamic> createVideoMetadata({
    String? format,
    Duration? duration,
    double? framerate,
    String? codec,
    int? bitrate,
  }) => {
    'format': format ?? 'mp4',
    'duration': (duration ?? const Duration(seconds: 6)).inMilliseconds,
    'framerate': framerate ?? 30.0,
    'codec': codec ?? 'h264',
    'bitrate': bitrate ?? 2000000, // 2 Mbps
    'created_at': DateTime.now().toIso8601String(),
  };

  /// Create test scenarios for error conditions
  static List<TestVideoScenario> getErrorScenarios() => [
    const TestVideoScenario(
      name: 'Empty frames list',
      frames: [],
      expectedError: 'ArgumentError',
      description: 'Should handle empty frame list gracefully',
    ),
    TestVideoScenario(
      name: 'Invalid dimensions',
      frames: createVideoFrames(width: 0, height: 0),
      expectedError: 'ArgumentError',
      description: 'Should validate frame dimensions',
    ),
    TestVideoScenario(
      name: 'Mismatched frame sizes',
      frames: [
        _createSingleFrame(
          width: 640,
          height: 480,
          frameIndex: 0,
          format: VideoTestFormat.rgb,
          pattern: VideoTestPattern.solid,
        ),
        _createSingleFrame(
          width: 320,
          height: 240,
          frameIndex: 1,
          format: VideoTestFormat.rgb,
          pattern: VideoTestPattern.solid,
        ),
      ],
      expectedError: 'ArgumentError',
      description: 'Should handle inconsistent frame sizes',
    ),
    TestVideoScenario(
      name: 'Corrupted frame data',
      frames: [Uint8List(100)], // Too small for declared dimensions
      expectedError: 'ProcessingException',
      description: 'Should handle corrupted frame data',
    ),
  ];

  /// Create test scenarios for performance testing
  static List<TestVideoScenario> getPerformanceScenarios() => [
    TestVideoScenario(
      name: 'Short vine (6 seconds, 30 frames)',
      frames: createVideoFrames(frameCount: 30),
      description: 'Standard vine recording',
      expectedProcessingTime: const Duration(milliseconds: 500),
    ),
    TestVideoScenario(
      name: 'Long video (30 seconds, 150 frames)',
      frames: createVideoFrames(frameCount: 150),
      description: 'Extended video processing',
      expectedProcessingTime: const Duration(seconds: 2),
    ),
    TestVideoScenario(
      name: 'High resolution (1080p, 30 frames)',
      frames: createVideoFrames(
        frameCount: 30,
        width: largeWidth,
        height: largeHeight,
      ),
      description: 'High resolution processing test',
      expectedProcessingTime: const Duration(seconds: 1),
    ),
    TestVideoScenario(
      name: 'Low resolution (240p, 30 frames)',
      frames: createVideoFrames(
        frameCount: 30,
        width: smallWidth,
        height: smallHeight,
      ),
      description: 'Low resolution optimization test',
      expectedProcessingTime: const Duration(milliseconds: 200),
    ),
  ];

  /// Create test scenarios for different video formats
  static List<TestVideoScenario> getFormatScenarios() => [
    TestVideoScenario(
      name: 'RGB format',
      frames: createVideoFrames(format: VideoTestFormat.rgb),
      description: 'Standard RGB color format',
    ),
    TestVideoScenario(
      name: 'RGBA format with transparency',
      frames: createVideoFrames(format: VideoTestFormat.rgba),
      description: 'RGBA format with alpha channel',
    ),
    TestVideoScenario(
      name: 'Animated pattern',
      frames: createVideoFrames(pattern: VideoTestPattern.animated),
      description: 'Complex animated content',
    ),
    TestVideoScenario(
      name: 'High contrast checkerboard',
      frames: createVideoFrames(pattern: VideoTestPattern.checkerboard),
      description: 'High contrast pattern for compression testing',
    ),
    TestVideoScenario(
      name: 'Random noise pattern',
      frames: createVideoFrames(pattern: VideoTestPattern.noise),
      description: 'Random noise for worst-case compression',
    ),
  ];

  /// Create comprehensive test suite combining all scenarios
  static List<TestVideoScenario> getAllTestScenarios() => [
    ...getPerformanceScenarios(),
    ...getFormatScenarios(),
    ...getErrorScenarios(),
  ];
}

/// Video test format enumeration
enum VideoTestFormat {
  rgb, // 3 bytes per pixel
  rgba, // 4 bytes per pixel
}

/// Video test pattern enumeration
enum VideoTestPattern {
  solid, // Single solid color
  gradient, // Color gradient
  checkerboard, // Checkerboard pattern
  animated, // Animated pattern (varies by frame)
  noise, // Random noise
}

/// Test color representation
class TestColor {
  const TestColor(this.red, this.green, this.blue, this.alpha);
  final int red;
  final int green;
  final int blue;
  final int alpha;
}

/// Test video scenario for comprehensive testing
class TestVideoScenario {
  const TestVideoScenario({
    required this.name,
    required this.frames,
    required this.description,
    this.expectedError,
    this.expectedProcessingTime,
    this.metadata,
  });
  final String name;
  final List<Uint8List> frames;
  final String? expectedError;
  final String description;
  final Duration? expectedProcessingTime;
  final Map<String, dynamic>? metadata;

  bool get shouldThrowError => expectedError != null;

  int get totalDataSize => frames.fold(0, (sum, frame) => sum + frame.length);

  String get dataSizeDescription {
    final sizeInMB = totalDataSize / (1024 * 1024);
    return '${sizeInMB.toStringAsFixed(2)} MB';
  }

  @override
  String toString() =>
      'TestVideoScenario(name: $name, frames: ${frames.length}, '
      'size: $dataSizeDescription, error: $expectedError)';
}
