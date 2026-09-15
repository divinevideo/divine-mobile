// ABOUTME: Regression tests for VideoEventService.authorVideos stable identity.
// ABOUTME: Protects profile feeds from read-time sorting and log capture churn.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _authorA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _authorB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

VideoEvent _video(
  String id, {
  required String pubkey,
  required int createdAt,
  String? vineId,
  int? nostrLikeCount,
}) => VideoEvent(
  id: id,
  pubkey: pubkey,
  createdAt: createdAt,
  content: 'content $id',
  timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
  title: 'Video $id',
  videoUrl: 'https://example.com/$id.mp4',
  vineId: vineId ?? id,
  nostrLikeCount: nostrLikeCount,
);

Event _event(
  String id, {
  required String pubkey,
  required int createdAt,
  String? dTag,
}) {
  final event = Event(
    pubkey,
    NIP71VideoKinds.addressableShortVideo,
    [
      ['d', dTag ?? id],
      ['url', 'https://example.com/$id.mp4'],
      ['title', 'Video $id'],
    ],
    'content $id',
    createdAt: createdAt,
  );
  event.id = id;
  return event;
}

void main() {
  group('VideoEventService.authorVideos identity', () {
    late VideoEventService service;
    late _MockNostrClient nostr;

    setUp(() async {
      await LogCaptureService().clearAllLogs();
      nostr = _MockNostrClient();
      when(() => nostr.publicKey).thenReturn('');
      service = VideoEventService(
        nostr,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() async {
      service.dispose();
      await LogCaptureService().clearAllLogs();
    });

    test('returns the same sorted list until that author changes', () {
      service.debugSeedAuthorBucket(_authorA, [
        _video('a-old', pubkey: _authorA, createdAt: 100),
        _video('a-new', pubkey: _authorA, createdAt: 200),
      ]);

      final first = service.authorVideos(_authorA);
      final second = service.authorVideos(_authorA);

      expect(identical(first, second), isTrue);
      expect(first.map((video) => video.id), ['a-new', 'a-old']);
    });

    test(
      'ingesting another author leaves the current author list identical',
      () {
        service.debugSeedAuthorBucket(_authorA, [
          _video('a-old', pubkey: _authorA, createdAt: 100),
        ]);
        final before = service.authorVideos(_authorA);

        service.handleEventForTesting(
          _event('b-new', pubkey: _authorB, createdAt: 300),
          SubscriptionType.profile,
        );

        expect(identical(service.authorVideos(_authorA), before), isTrue);
      },
    );

    test('ingesting this author yields a new newest-first list', () {
      service.debugSeedAuthorBucket(_authorA, [
        _video('a-old', pubkey: _authorA, createdAt: 100),
      ]);
      final before = service.authorVideos(_authorA);

      service.handleEventForTesting(
        _event('a-new', pubkey: _authorA, createdAt: 300),
        SubscriptionType.profile,
      );

      final after = service.authorVideos(_authorA);
      expect(identical(after, before), isFalse);
      expect(after.map((video) => video.id), ['a-new', 'a-old']);
    });

    test(
      'removal, like count, and replaceable update invalidate the author',
      () {
        service.handleEventForTesting(
          _event(
            'a-original',
            pubkey: _authorA,
            createdAt: 100,
            dTag: 'stable-a',
          ),
          SubscriptionType.profile,
        );
        final initial = service.authorVideos(_authorA);

        expect(
          service.applyLikeCountForTesting(
            'a-original',
            9,
            SubscriptionType.profile,
          ),
          isTrue,
        );
        final afterLikeCount = service.authorVideos(_authorA);
        expect(identical(afterLikeCount, initial), isFalse);
        expect(afterLikeCount.single.nostrLikeCount, 9);

        service.updateVideoEvent(
          _video(
            'a-replaceable-update',
            pubkey: _authorA,
            createdAt: 300,
            vineId: 'stable-a',
          ),
        );
        final afterReplaceableUpdate = service.authorVideos(_authorA);
        expect(identical(afterReplaceableUpdate, afterLikeCount), isFalse);
        expect(afterReplaceableUpdate.single.id, 'a-replaceable-update');

        service.removeVideoCompletely('a-replaceable-update');
        final afterRemoval = service.authorVideos(_authorA);
        expect(identical(afterRemoval, afterReplaceableUpdate), isFalse);
        expect(afterRemoval, isEmpty);
      },
    );

    test('does not capture logs when reading authorVideos', () {
      service.debugSeedAuthorBucket(_authorA, [
        _video('a-old', pubkey: _authorA, createdAt: 100),
      ]);
      LogCaptureService().clearAllLogs();

      service.authorVideos(_authorA);
      service.authorVideos(_authorA);

      final messages = LogCaptureService()
          .getRecentLogs()
          .map((entry) => entry.message)
          .toList();
      expect(
        messages.where((message) => message.startsWith('SVC authorVideos:')),
        isEmpty,
      );
    });
  });
}
