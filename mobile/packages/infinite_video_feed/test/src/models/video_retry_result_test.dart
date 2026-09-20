import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';

void main() {
  group(VideoRetryResult, () {
    test('reports not attempted when initialization did not complete', () {
      expect(
        VideoRetryResult.fromInitialization(
          initialized: false,
          hasError: false,
        ),
        VideoRetryResult.notAttempted,
      );
    });

    test('keeps completed failures distinct from not attempted', () {
      expect(
        VideoRetryResult.fromInitialization(initialized: true, hasError: true),
        VideoRetryResult.failed,
      );
    });

    test(
      'reports playback only after initialization completes without error',
      () {
        expect(
          VideoRetryResult.fromInitialization(
            initialized: true,
            hasError: false,
          ),
          VideoRetryResult.played,
        );
      },
    );
  });
}
