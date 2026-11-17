import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';

void main() {
  group(VideoRecorderMode, () {
    group('label', () {
      test('capture has label "Capture"', () {
        expect(VideoRecorderMode.capture.label, equals('Capture'));
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

      test('classic has recording limit', () {
        expect(VideoRecorderMode.classic.hasRecordingLimit, isTrue);
      });

      test('upload has no recording limit', () {
        expect(VideoRecorderMode.upload.hasRecordingLimit, isFalse);
      });
    });

    group('supportsDualCamera', () {
      test('offers dual-camera capture in Capture only', () {
        expect(
          [
            for (final mode in VideoRecorderMode.values)
              if (mode.supportsDualCamera) mode,
          ],
          equals([VideoRecorderMode.capture]),
        );
      });
    });

    group('hasVideoEditor', () {
      test('capture has video editor', () {
        expect(VideoRecorderMode.capture.hasVideoEditor, isTrue);
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

      test('cycles its interval through 3, 5 and 10 seconds', () {
        expect(
          VideoRecorderMode.stopMotion.timerDurations,
          equals(const [
            TimerDuration.off,
            TimerDuration.three,
            TimerDuration.five,
            TimerDuration.ten,
          ]),
        );
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
        expect(VideoRecorderMode.classic.capturesStills, isFalse);
        expect(VideoRecorderMode.upload.capturesStills, isFalse);
      });
    });

    group('supportsGhostFrame', () {
      test('is false only for upload', () {
        for (final mode in VideoRecorderMode.values) {
          expect(
            mode.supportsGhostFrame,
            mode != VideoRecorderMode.upload,
            reason: mode.name,
          );
        }
      });
    });

    group('timerDurations', () {
      test('starts at off in every mode that shows a timer', () {
        for (final mode in VideoRecorderMode.values) {
          expect(
            mode.timerDurations.firstOrNull,
            mode.supportsCountdownTimer ? TimerDuration.off : isNull,
            reason: mode.name,
          );
        }
      });

      test('shows no timer in classic or upload', () {
        expect(VideoRecorderMode.classic.supportsCountdownTimer, isFalse);
        expect(VideoRecorderMode.upload.supportsCountdownTimer, isFalse);
      });

      test('delays the take by 3 or 10 seconds in capture', () {
        expect(
          VideoRecorderMode.capture.timerDurations,
          equals(const [
            TimerDuration.off,
            TimerDuration.three,
            TimerDuration.ten,
          ]),
        );
      });
    });

    group('supportsChromaKey', () {
      test('is true only for capture', () {
        for (final mode in VideoRecorderMode.values) {
          expect(
            mode.supportsChromaKey,
            mode == VideoRecorderMode.capture,
            reason: mode.name,
          );
        }
      });
    });

    group('supportsSound', () {
      test('is true only for capture', () {
        for (final mode in VideoRecorderMode.values) {
          expect(
            mode.supportsSound,
            mode == VideoRecorderMode.capture,
            reason: mode.name,
          );
        }
      });
    });

    group('fromName', () {
      test('reopens the former lip sync and chroma key modes in capture', () {
        expect(
          VideoRecorderMode.fromName('lipSync'),
          equals(VideoRecorderMode.capture),
        );
        expect(
          VideoRecorderMode.fromName('chromaKey'),
          equals(VideoRecorderMode.capture),
        );
      });

      test('restores a mode that still exists', () {
        expect(
          VideoRecorderMode.fromName('classic'),
          equals(VideoRecorderMode.classic),
        );
      });
    });
  });
}
