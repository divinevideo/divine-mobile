import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/constants/video_editor_constants.dart';

void main() {
  group('looping contract', () {
    test('feed playback loops natively rather than seeking back to zero', () {
      // The seek-based enforcement this replaced no longer exists to be passed
      // (#6445), so what is left to pin is that the loop still happens in the
      // platform player.
      const pooledPlayerPath =
          'packages/infinite_video_feed/lib/src/widgets/infinite_video_feed.dart';

      expect(
        _dartCodeOnly(pooledPlayerPath),
        contains('setLooping(looping: true)'),
      );

      // Every layer that holds a controller can hand-roll the restart, so the
      // guard covers all three rather than the one the deleted wiring sat in:
      // the subscription service owns the position stream the old seek fired
      // from, and the app-side call site configures both.
      //
      // It matches the spelling, not the value. `_seekKick` already seeks with
      // a computed duration for stale recovery, so widening to a `seekTo(`
      // regex would collide with it — the cost is that `seekTo(const
      // Duration())` reaches zero unseen. Read this as a tripwire for the
      // regression that shipped three times, not as proof no Dart seek can
      // reach zero.
      const subscriptionsPath =
          'packages/infinite_video_feed/lib/src/services/'
          'controller_subscriptions.dart';
      const seekFreePaths = [
        pooledPlayerPath,
        subscriptionsPath,
        'lib/widgets/video_feed_item/feed_videos.dart',
      ];

      for (final path in seekFreePaths) {
        expect(
          _dartCodeOnly(path),
          isNot(contains('seekTo(Duration.zero)')),
          reason:
              '$path must not restart a video with a Dart seek; '
              'seek-based restarts create audible seams (#5544).',
        );
      }
    });

    test('every feed source is opened with the cap applied', () {
      // Cache hit, first load, source failover and processing retry each re-open
      // the player, so a missed site lets a long video escape the cap on that
      // path alone. The app-side wiring is asserted behaviourally in
      // feed_videos_test.dart; only the package clip sites are pinned here,
      // because the feed builds those clips around a controller no widget test
      // can observe.
      const capArgumentByFile = {
        'packages/infinite_video_feed/lib/src/widgets/infinite_video_feed.dart':
            'end: widget.maxPlaybackDuration',
        'packages/infinite_video_feed/lib/src/utils/source_loader.dart':
            'end: maxPlaybackDuration',
      };

      for (final entry in capArgumentByFile.entries) {
        final source = _dartCodeOnly(entry.key);
        // Matches every construction form, including the unnamed
        // `VideoClip(uri: ...)` constructor and the `asset` / `memory` helpers.
        // A form this missed would drop out of both counts and hold parity.
        final clipCount = RegExp('VideoClip[.(]').allMatches(source).length;

        expect(
          clipCount,
          greaterThan(0),
          reason: 'No clips found in ${entry.key}',
        );
        expect(
          entry.value.allMatches(source),
          hasLength(clipCount),
          reason: '${entry.key} opens a clip without applying the cap.',
        );
      }
    });

    test(
      'the cap clears classic Vine assets and is not the recording limit',
      () {
        // Longest classic Vine measured with ffprobe on media.divine.video (#6421).
        // Capping below this would cut the musical loop point off every one of
        // them.
        const longestClassicVine = Duration(milliseconds: 6533);

        expect(
          AppConstants.maxFeedPlaybackDuration,
          greaterThan(longestClassicVine),
        );
        expect(
          AppConstants.maxFeedPlaybackDuration,
          greaterThan(VideoEditorConstants.maxDuration),
          reason:
              'maxDuration is the 6.3s recording limit, not a playback cap; '
              'reusing it truncates classic Vines.',
        );
      },
    );
  });
}

/// Reads [path] with comments and string-literal bodies removed, so no
/// assertion here can be satisfied — or defeated — by commented-out code.
///
/// Shares the design-system ratchets' filter rather than re-deriving one; it
/// already handles nested block comments, raw and triple-quoted strings, and a
/// `//` inside a URL.
String _dartCodeOnly(String path) {
  final result = Process.runSync('awk', [
    '-f',
    File('scripts/lib/dart_code_only.awk').absolute.path,
    path,
  ]);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return result.stdout as String;
}
