# Android Video Concatenation Implementation Plan

## Problem
- FFmpegKit retired January 2025
- `ffmpeg_kit_flutter_new` 1.6.1 has Android compilation errors
- Need video segment concatenation for Vine-style recording

## Solution: Native Android Implementation

### Architecture
Replace FFmpeg with platform-specific native implementations:

**Android**: MediaCodec + MediaMuxer (Android SDK native APIs)
**iOS/macOS**: Keep existing approach (works fine)

### Implementation Steps

#### 1. Create Platform Channel Interface

```dart
// lib/services/video_concatenation_service.dart
class VideoConcatenationService {
  static const MethodChannel _channel = MethodChannel('video_concatenation');

  /// Concatenate video segments into a single output file
  /// Returns path to concatenated video
  static Future<String> concatenateVideos({
    required List<String> inputPaths,
    required String outputPath,
    CropType cropType = CropType.square,
  }) async {
    return await _channel.invokeMethod('concatenateVideos', {
      'inputPaths': inputPaths,
      'outputPath': outputPath,
      'cropType': cropType.toString(),
    });
  }
}

enum CropType {
  square,  // 1:1 aspect ratio
  none,    // Keep original
}
```

#### 2. Android Implementation (Kotlin)

Create `android/app/src/main/kotlin/co/openvine/app/VideoConcatenationPlugin.kt`:

```kotlin
class VideoConcatenationPlugin : MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "concatenateVideos" -> {
                val inputPaths = call.argument<List<String>>("inputPaths")
                val outputPath = call.argument<String>("outputPath")
                val cropType = call.argument<String>("cropType")

                if (inputPaths == null || outputPath == null) {
                    result.error("INVALID_ARGS", "Missing required arguments", null)
                    return
                }

                // Run concatenation in background thread
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        val result = concatenateVideosNative(inputPaths, outputPath, cropType)
                        withContext(Dispatchers.Main) {
                            result.success(result)
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("CONCAT_ERROR", e.message, null)
                        }
                    }
                }
            }
        }
    }

    private suspend fun concatenateVideosNative(
        inputPaths: List<String>,
        outputPath: String,
        cropType: String?
    ): String {
        // Implementation using MediaCodec + MediaMuxer
        // See: https://github.com/android/media-samples
        // Uses MediaExtractor to read each input video
        // MediaCodec to decode/re-encode with cropping
        // MediaMuxer to write output

        // Pseudocode:
        // 1. Create MediaMuxer for output
        // 2. For each input video:
        //    - Extract video and audio tracks
        //    - Decode frames
        //    - Apply crop if needed (square 1:1)
        //    - Re-encode with same codec
        //    - Write to muxer
        // 3. Finalize muxer

        return outputPath
    }
}
```

#### 3. Update vine_recording_controller.dart

Replace FFmpeg concatenation with platform channel:

```dart
Future<File?> _concatenateSegments(List<RecordingSegment> segments) async {
  if (kIsWeb) {
    throw Exception('Video concatenation not supported on web');
  }

  // Collect segment file paths
  final inputPaths = segments
      .where((s) => s.filePath != null)
      .map((s) => s.filePath!)
      .toList();

  if (inputPaths.isEmpty) {
    throw Exception('No segments to concatenate');
  }

  // Generate output path
  final tempDir = await getTemporaryDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final outputPath = '${tempDir.path}/vine_$timestamp.mp4';

  // Use native concatenation
  final resultPath = await VideoConcatenationService.concatenateVideos(
    inputPaths: inputPaths,
    outputPath: outputPath,
    cropType: CropType.square,  // 1:1 aspect ratio for Vine
  );

  return File(resultPath);
}
```

### Advantages

1. **No External Dependencies**: Uses built-in Android/iOS APIs
2. **Better Performance**: Native code optimized for each platform
3. **Smaller APK**: No FFmpeg binaries (~30MB savings)
4. **Future-Proof**: Not dependent on abandoned FFmpeg forks
5. **Platform Consistency**: iOS already uses AVFoundation natively

### Reference Implementation

Android MediaMuxer example: https://github.com/android/media-samples/tree/main/MediaMuxer

### Estimated Implementation Time

- Platform channel setup: 1 hour
- Android native implementation: 4-6 hours
- Testing and debugging: 2-3 hours
- **Total**: ~1 day

### Alternative: Quick Fix for Testing

To get Android builds working immediately for testing (without video concatenation):

1. Temporarily comment out FFmpeg dependency in pubspec.yaml
2. Add conditional compilation in vine_recording_controller.dart
3. Disable concatenation on Android for now
4. Build and test other features

```dart
Future<File?> _concatenateSegments(List<RecordingSegment> segments) async {
  if (Platform.isAndroid) {
    // TODO: Implement native Android concatenation
    throw UnimplementedError('Android concatenation coming soon');
  }

  // iOS/macOS: use FFmpeg (works fine)
  final session = await FFmpegKit.execute(command);
  // ... rest of FFmpeg implementation
}
```

This lets you proceed with Android development/testing while implementing proper concatenation.
