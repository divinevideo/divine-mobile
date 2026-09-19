// ABOUTME: Tests FeedUnavailabilityGate — fails closed until its per-identity
// ABOUTME: tracker and guard attach, then answers from whichever is current.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/dead_media_feed_guard.dart';
import 'package:openvine/services/feed_unavailability_gate.dart';

class _MockTracker extends Mock implements BrokenVideoTracker {}

class _MockGuard extends Mock implements DeadMediaFeedGuard {}

const _videoId = 'video-1';
const _videoUrl = 'https://media.example.com/video-1.mp4';

void main() {
  group(FeedUnavailabilityGate, () {
    late FeedUnavailabilityGate gate;
    late _MockTracker tracker;
    late _MockGuard guard;

    setUp(() {
      gate = FeedUnavailabilityGate();
      tracker = _MockTracker();
      guard = _MockGuard();
    });

    group('isVideoBroken', () {
      test('filters nothing before a tracker is attached', () {
        expect(gate.isVideoBroken(_videoId), isFalse);
      });

      test('reads the attached tracker on every call', () {
        when(() => tracker.isVideoBroken(_videoId)).thenReturn(true);
        gate.attachTracker(tracker);

        expect(gate.isVideoBroken(_videoId), isTrue);

        // An identity change detaches the old tracker until the new resolves.
        gate.attachTracker(null);
        expect(gate.isVideoBroken(_videoId), isFalse);
      });
    });

    group('confirmVideoUnavailable', () {
      test('fails closed before a guard is attached', () async {
        await expectLater(
          gate.confirmVideoUnavailable(videoId: _videoId, videoUrl: _videoUrl),
          completion(FeedUnavailability.none),
        );
      });

      test('delegates to the attached guard', () async {
        when(
          () => guard.isConfirmedUnavailable(
            videoId: _videoId,
            videoUrl: _videoUrl,
            explicitSha256: 'abc',
          ),
        ).thenAnswer((_) async => FeedUnavailability.persistent);
        gate.attachGuard(guard);

        await expectLater(
          gate.confirmVideoUnavailable(
            videoId: _videoId,
            videoUrl: _videoUrl,
            explicitSha256: 'abc',
          ),
          completion(FeedUnavailability.persistent),
        );
      });
    });

    group('markVideoBroken', () {
      test('persists through the attached tracker', () async {
        when(
          () => tracker.markVideoBroken(_videoId, 'reason'),
        ).thenAnswer((_) async {});
        gate.attachTracker(tracker);

        await gate.markVideoBroken(_videoId, 'reason');

        verify(() => tracker.markVideoBroken(_videoId, 'reason')).called(1);
      });

      test('swallows a persistence failure', () async {
        when(
          () => tracker.markVideoBroken(_videoId, 'reason'),
        ).thenThrow(Exception('disk full'));
        gate.attachTracker(tracker);

        await expectLater(gate.markVideoBroken(_videoId, 'reason'), completes);
      });
    });
  });
}
