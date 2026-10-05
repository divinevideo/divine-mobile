// ABOUTME: Tests for HomeFeedResumeManager — verifies same-key resume-window
// ABOUTME: writes are serialised so a slow earlier write cannot clobber the
// ABOUTME: freshest window.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/home_feed_cache.dart';
import 'package:openvine/blocs/video_feed/home_feed_resume_manager.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

/// [HomeFeedCache] fake whose writes block until [releaseNextWrite] is called,
/// recording the order in which writes actually *complete* (not just start).
class _GatedCache implements HomeFeedCache {
  final List<Completer<void>> _gates = [];
  final List<List<String>> completedWrites = [];
  int writeCallCount = 0;
  int clearCallCount = 0;

  @override
  Future<void> writeVideos({
    required String? pubkey,
    required String mode,
    required List<VideoEvent> videos,
  }) async {
    writeCallCount++;
    final gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
    completedWrites.add(videos.map((v) => v.id).toList());
  }

  void releaseNextWrite() {
    _gates.firstWhere((gate) => !gate.isCompleted).complete();
  }

  @override
  Future<void> clearVideos({
    required String? pubkey,
    required String mode,
  }) async {
    clearCallCount++;
  }

  @override
  Future<List<VideoEvent>?> readVideos({
    required String? pubkey,
    required String mode,
  }) async => null;
}

VideoEvent _video(String id, {String? vineId}) => VideoEvent(
  id: id,
  pubkey: 'a' * 64,
  createdAt: 1700000000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(
    1700000000 * 1000,
    isUtc: true,
  ),
  videoUrl: 'https://cdn.divine.video/$id.mp4',
  vineId: vineId,
  addressableDTag: vineId,
);

Future<void> _pump() => pumpEventQueue();

void main() {
  group(HomeFeedResumeManager, () {
    late _GatedCache cache;
    late HomeFeedResumeManager manager;

    setUp(() {
      cache = _GatedCache();
      manager = HomeFeedResumeManager(
        cache: cache,
        videosRepository: _MockVideosRepository(),
      );
    });

    test(
      'serialises same-key writes so a slow earlier write cannot clobber the '
      'freshest window',
      () async {
        // Cold-start order: the stale served window is persisted first, then
        // the fresh-spliced window. (_resumeOffset is 1, so activeIndex 0
        // persists sublist(1).)
        manager.persistNow(
          pubkey: 'p',
          mode: 'forYou',
          videos: [_video('s0'), _video('s1'), _video('s2')],
          activeIndex: 0,
        );
        manager.persistNow(
          pubkey: 'p',
          mode: 'forYou',
          videos: [_video('f0'), _video('f1'), _video('f2')],
          activeIndex: 0,
        );

        // The second (fresh) write must not even be issued until the first
        // completes — without serialisation both would fire immediately and
        // could complete out of order.
        await _pump();
        expect(
          cache.writeCallCount,
          1,
          reason: 'fresh write must wait for the stale write to complete',
        );

        // Complete the stale write → the fresh write is now issued.
        cache.releaseNextWrite();
        await _pump();
        expect(cache.writeCallCount, 2);

        cache.releaseNextWrite();
        await _pump();

        // Writes completed strictly in submission order, so the fresh window
        // is written last and wins.
        expect(cache.completedWrites, [
          ['s1', 's2'],
          ['f1', 'f2'],
        ]);
      },
    );

    test('runs a later write even after an earlier one completes', () async {
      manager.persistNow(
        pubkey: 'p',
        mode: 'forYou',
        videos: [_video('a0'), _video('a1')],
        activeIndex: 0,
      );
      await _pump();
      cache.releaseNextWrite();
      await _pump();

      manager.persistNow(
        pubkey: 'p',
        mode: 'forYou',
        videos: [_video('b0'), _video('b1')],
        activeIndex: 0,
      );
      await _pump();
      cache.releaseNextWrite();
      await _pump();

      expect(cache.completedWrites, [
        ['a1'],
        ['b1'],
      ]);
    });

    test('serialises a clear behind an earlier in-flight write', () async {
      manager.persistNow(
        pubkey: 'p',
        mode: 'forYou',
        videos: [_video('a0'), _video('a1')],
        activeIndex: 0,
      );
      manager.persistNow(
        pubkey: 'p',
        mode: 'forYou',
        videos: [_video('b0')],
        activeIndex: 0,
      );

      await _pump();
      expect(cache.writeCallCount, 1);
      expect(
        cache.clearCallCount,
        0,
        reason: 'clear must wait for the older write to complete',
      );

      cache.releaseNextWrite();
      await _pump();
      expect(cache.clearCallCount, 1);
    });

    group('splice', () {
      test(
        'drops a fresh addressable video republished with a new event id',
        () {
          // Cached head holds the addressable video under its original event
          // id; the fresh page carries the same kind:pubkey:d-tag video under a
          // fresh event id. Keyed on the raw event id they would both survive
          // as a visible duplicate; keyed on feedDedupKey the fresh copy drops.
          final result = manager.splice(
            existing: [
              _video('old-event', vineId: 'shared-d'),
              _video('c1'),
            ],
            fresh: [
              _video('new-event', vineId: 'shared-d'),
              _video('f1'),
            ],
            currentIndex: 0,
          );

          expect(
            result.map((v) => v.id),
            equals(['old-event', 'c1', 'f1']),
          );
        },
      );

      test('keeps fresh videos with distinct identities', () {
        final result = manager.splice(
          existing: [_video('c0'), _video('c1')],
          fresh: [_video('f0'), _video('f1')],
          currentIndex: 0,
        );

        expect(
          result.map((v) => v.id),
          equals(['c0', 'c1', 'f0', 'f1']),
        );
      });
    });
  });
}
