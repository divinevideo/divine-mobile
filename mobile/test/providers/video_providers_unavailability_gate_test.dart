// ABOUTME: Pins that feedUnavailabilityGateProvider hands out one stable gate
// ABOUTME: that follows the per-identity tracker and guard as they rebuild.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/dead_media_feed_guard.dart';

class _MockTracker extends Mock implements BrokenVideoTracker {}

class _MockGuard extends Mock implements DeadMediaFeedGuard {}

const _videoId = 'video-1';
const _videoUrl = 'https://media.example.com/video-1.mp4';

void main() {
  group('feedUnavailabilityGateProvider', () {
    test(
      'the same gate follows the tracker and guard across an identity change',
      () async {
        // The bloc captures the gate once; an auth transition rebuilds both
        // per-identity providers underneath it and the gate must keep up
        // without the bloc being recreated (#9341).
        final trackers = [_MockTracker(), _MockTracker()];
        final guards = [_MockGuard(), _MockGuard()];
        when(() => trackers[0].isVideoBroken(_videoId)).thenReturn(true);
        when(() => trackers[1].isVideoBroken(_videoId)).thenReturn(false);
        for (final (index, guard) in guards.indexed) {
          when(
            () => guard.isConfirmedUnavailable(
              videoId: _videoId,
              videoUrl: _videoUrl,
            ),
          ).thenAnswer(
            (_) async => index == 0
                ? FeedUnavailability.persistent
                : FeedUnavailability.none,
          );
        }

        var identity = 0;
        final container = ProviderContainer(
          overrides: [
            brokenVideoTrackerProvider.overrideWith(
              (ref) async => trackers[identity],
            ),
            deadMediaFeedGuardProvider.overrideWith((ref) async {
              await ref.watch(brokenVideoTrackerProvider.future);
              return guards[identity];
            }),
          ],
        );
        addTearDown(container.dispose);

        final gate = container.read(feedUnavailabilityGateProvider);
        // Nothing has resolved yet: fail closed.
        expect(gate.isVideoBroken(_videoId), isFalse);

        await container.read(deadMediaFeedGuardProvider.future);
        expect(gate.isVideoBroken(_videoId), isTrue);
        await expectLater(
          gate.confirmVideoUnavailable(videoId: _videoId, videoUrl: _videoUrl),
          completion(FeedUnavailability.persistent),
        );

        identity = 1;
        container.invalidate(brokenVideoTrackerProvider);
        await container.read(deadMediaFeedGuardProvider.future);

        expect(container.read(feedUnavailabilityGateProvider), same(gate));
        expect(gate.isVideoBroken(_videoId), isFalse);
        await expectLater(
          gate.confirmVideoUnavailable(videoId: _videoId, videoUrl: _videoUrl),
          completion(FeedUnavailability.none),
        );
      },
    );
  });
}
