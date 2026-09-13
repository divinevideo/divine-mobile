// ABOUTME: Pins the shared upload configuration contract — retry defaults and
// ABOUTME: the progress-bar share the manager and retry policy must agree on.

import 'package:flutter_test/flutter_test.dart';
import 'package:upload_repository/upload_repository.dart';

void main() {
  group('UploadRetryConfig', () {
    test('defaults drive the shipped retry behaviour', () {
      const config = UploadRetryConfig();

      // These are the values UploadRetryPolicy backs off with; changing any of
      // them changes how long a failing upload keeps trying on a real device.
      expect(config.maxRetries, 5);
      expect(config.initialDelay, const Duration(seconds: 2));
      expect(config.maxDelay, const Duration(minutes: 5));
      expect(config.backoffMultiplier, 2.0);
      expect(config.networkTimeout, const Duration(minutes: 10));
    });

    test('exponential backoff stays within maxDelay across every attempt', () {
      const config = UploadRetryConfig();

      var delay = config.initialDelay;
      for (var attempt = 1; attempt <= config.maxRetries; attempt++) {
        expect(
          delay,
          lessThanOrEqualTo(config.maxDelay),
          reason: 'attempt $attempt exceeded maxDelay before clamping',
        );
        delay *= config.backoffMultiplier;
      }
    });

    test('overrides are honoured', () {
      const config = UploadRetryConfig(
        maxRetries: 1,
        initialDelay: Duration.zero,
        backoffMultiplier: 1.5,
      );

      expect(config.maxRetries, 1);
      expect(config.initialDelay, Duration.zero);
      expect(config.backoffMultiplier, 1.5);
      // Untouched fields keep their defaults.
      expect(config.maxDelay, const Duration(minutes: 5));
      expect(config.networkTimeout, const Duration(minutes: 10));
    });
  });

  group('videoProgressShare', () {
    test('leaves headroom for the thumbnail leg', () {
      // The bar must stop short of 1.0 so joining the thumbnail leg has
      // somewhere to go; at 1.0 the UI would sit "complete" while the publish
      // is still working. UploadManager and UploadRetryPolicy both scale
      // progress by this value, so they cannot disagree on the ceiling.
      expect(videoProgressShare, greaterThan(0.0));
      expect(videoProgressShare, lessThan(1.0));
      expect(videoProgressShare, 0.95);
    });
  });
}
