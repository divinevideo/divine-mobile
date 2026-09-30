import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';

void main() {
  group(VideoRecorderMode, () {
    group('label', () {
      test('capture has label "Capture"', () {
        expect(VideoRecorderMode.capture.label, equals('Capture'));
      });

      test('lipSync has label "Lip Sync"', () {
        expect(VideoRecorderMode.lipSync.label, equals('Lip Sync'));
      });

      test('classic has label "Classic"', () {
        expect(VideoRecorderMode.classic.label, equals('Classic'));
      });

      test('upload returns "Upload" label', () {
        expect(VideoRecorderMode.upload.label, equals('Upload'));
      });
    });

    group('hasRecordingLimit', () {
      test('capture has no recording limit', () {
        expect(VideoRecorderMode.capture.hasRecordingLimit, isFalse);
      });

      test('lipSync has no recording limit', () {
        expect(VideoRecorderMode.lipSync.hasRecordingLimit, isFalse);
      });

      test('classic has recording limit', () {
        expect(VideoRecorderMode.classic.hasRecordingLimit, isTrue);
      });

      test('upload has no recording limit', () {
        expect(VideoRecorderMode.upload.hasRecordingLimit, isFalse);
      });
    });

    group('hasVideoEditor', () {
      test('capture has video editor', () {
        expect(VideoRecorderMode.capture.hasVideoEditor, isTrue);
      });

      test('lipSync has video editor', () {
        expect(VideoRecorderMode.lipSync.hasVideoEditor, isTrue);
      });

      test('classic has no video editor', () {
        expect(VideoRecorderMode.classic.hasVideoEditor, isFalse);
      });

      test('upload has no video editor', () {
        expect(VideoRecorderMode.upload.hasVideoEditor, isFalse);
      });
    });

    group('supportGridLines', () {
      test('capture does not support grid lines', () {
        expect(VideoRecorderMode.capture.supportGridLines, isFalse);
      });

      test('lipSync does not support grid lines', () {
        expect(VideoRecorderMode.lipSync.supportGridLines, isFalse);
      });

      test('classic supports grid lines', () {
        expect(VideoRecorderMode.classic.supportGridLines, isTrue);
      });

      test('upload does not support grid lines', () {
        expect(VideoRecorderMode.upload.supportGridLines, isFalse);
      });
    });

    group('defaultAspectRatio', () {
      test('capture defaults to vertical', () {
        expect(
          VideoRecorderMode.capture.defaultAspectRatio,
          equals(model.AspectRatio.vertical),
        );
      });

      test('lipSync defaults to vertical', () {
        expect(
          VideoRecorderMode.lipSync.defaultAspectRatio,
          equals(model.AspectRatio.vertical),
        );
      });

      test('classic defaults to square', () {
        expect(
          VideoRecorderMode.classic.defaultAspectRatio,
          equals(model.AspectRatio.square),
        );
      });

      test('upload defaults to vertical aspect ratio', () {
        expect(
          VideoRecorderMode.upload.defaultAspectRatio,
          equals(model.AspectRatio.vertical),
        );
      });
    });

    group('stopMotion', () {
      test('has label "Stop Motion"', () {
        expect(VideoRecorderMode.stopMotion.label, equals('Stop Motion'));
      });

      test('has no recording limit', () {
        expect(VideoRecorderMode.stopMotion.hasRecordingLimit, isFalse);
      });

      test(
        'has a video editor (previews frames via the stop-motion player)',
        () {
          expect(VideoRecorderMode.stopMotion.hasVideoEditor, isTrue);
        },
      );

      test('supports grid lines (shot-to-shot alignment)', () {
        expect(VideoRecorderMode.stopMotion.supportGridLines, isTrue);
      });

      test('does not support a countdown timer', () {
        expect(VideoRecorderMode.stopMotion.supportsCountdownTimer, isFalse);
      });

      test('defaults to vertical aspect ratio', () {
        expect(
          VideoRecorderMode.stopMotion.defaultAspectRatio,
          equals(model.AspectRatio.vertical),
        );
      });
    });

    group('capturesStills', () {
      test('is true only for stop-motion', () {
        expect(VideoRecorderMode.stopMotion.capturesStills, isTrue);
        expect(VideoRecorderMode.capture.capturesStills, isFalse);
        expect(VideoRecorderMode.chromaKey.capturesStills, isFalse);
        expect(VideoRecorderMode.classic.capturesStills, isFalse);
        expect(VideoRecorderMode.upload.capturesStills, isFalse);
      });
    });

    group('chromaKey', () {
      test('has label "Chroma Key"', () {
        expect(VideoRecorderMode.chromaKey.label, equals('Chroma Key'));
      });

      test('records without a limit and hands off to the editor', () {
        expect(VideoRecorderMode.chromaKey.hasRecordingLimit, isFalse);
        // The key is baked there, so skipping the editor would publish the
        // raw footage.
        expect(VideoRecorderMode.chromaKey.hasVideoEditor, isTrue);
      });

      test('supports the countdown timer', () {
        expect(VideoRecorderMode.chromaKey.supportsCountdownTimer, isTrue);
      });

      test('defaults to vertical aspect ratio', () {
        expect(
          VideoRecorderMode.chromaKey.defaultAspectRatio,
          equals(model.AspectRatio.vertical),
        );
      });
    });

    group('needsLiveChromaKey', () {
      test('is true only for chroma key', () {
        for (final mode in VideoRecorderMode.values) {
          expect(
            mode.needsLiveChromaKey,
            mode == VideoRecorderMode.chromaKey,
            reason: mode.name,
          );
        }
      });
    });

    group('available', () {
      test('offers every mode when the live key can be drawn', () {
        expect(
          VideoRecorderMode.available(liveChromaKeySupported: true),
          equals(VideoRecorderMode.values),
        );
      });

      test('leaves chroma key out when the live key cannot be drawn', () {
        expect(
          VideoRecorderMode.available(liveChromaKeySupported: false),
          equals([
            VideoRecorderMode.capture,
            VideoRecorderMode.stopMotion,
            VideoRecorderMode.lipSync,
            VideoRecorderMode.classic,
            VideoRecorderMode.upload,
          ]),
        );
      });
    });
  });
}
