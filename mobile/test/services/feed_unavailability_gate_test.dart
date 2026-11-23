// ABOUTME: Tests FeedUnavailabilityGate — fails closed until its per-identity
// ABOUTME: tracker and guard attach, then answers from whichever is current.

import 'dart:async';

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
      when(
        () => tracker.markedVideoIds,
      ).thenAnswer((_) => const Stream<String>.empty());
      when(() => tracker.brokenVideoIds).thenReturn(const []);
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

    group('markedVideoIds', () {
      test('forwards marks only from the currently attached tracker', () async {
        final first = StreamController<String>.broadcast();
        final second = StreamController<String>.broadcast();
        addTearDown(first.close);
        addTearDown(second.close);
        final next = _MockTracker();
        when(() => tracker.markedVideoIds).thenAnswer((_) => first.stream);
        when(() => next.markedVideoIds).thenAnswer((_) => second.stream);
        when(() => next.brokenVideoIds).thenReturn(const []);
        final forwarded = <String>[];
        final subscription = gate.markedVideoIds.listen(forwarded.add);
        addTearDown(subscription.cancel);

        gate.attachTracker(tracker);
        first.add('first-account');
        await pumpEventQueue();
        // An identity change replaces the tracker.
        gate.attachTracker(next);
        first.add('previous-account');
        second.add('second-account');
        await pumpEventQueue();
        gate.attachTracker(null);
        second.add('detached');
        await pumpEventQueue();

        expect(forwarded, ['first-account', 'second-account']);
      });

      test(
        'replays the ids a tracker already holds when it attaches',
        () async {
          // Home can serve its cached window before the tracker resolves, so
          // nothing filtered these; the feed has to hear about them now.
          when(() => tracker.brokenVideoIds).thenReturn(['held-1', 'held-2']);
          final forwarded = <String>[];
          final subscription = gate.markedVideoIds.listen(forwarded.add);
          addTearDown(subscription.cancel);

          gate.attachTracker(tracker);
          // Reattaching the same tracker must not replay it a second time.
          gate.attachTracker(tracker);
          await pumpEventQueue();

          expect(forwarded, ['held-1', 'held-2']);
        },
      );
    });

    group('dispose', () {
      test('stops forwarding the tracker and ends markedVideoIds', () async {
        final marks = StreamController<String>.broadcast();
        addTearDown(marks.close);
        when(() => tracker.markedVideoIds).thenAnswer((_) => marks.stream);
        gate.attachTracker(tracker);
        expect(marks.hasListener, isTrue);
        final forwarded = gate.markedVideoIds.toList();

        gate.dispose();
        await pumpEventQueue();

        expect(marks.hasListener, isFalse);
        expect(await forwarded.timeout(const Duration(seconds: 5)), isEmpty);
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
