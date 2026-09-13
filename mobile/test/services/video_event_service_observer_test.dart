// ABOUTME: Tests the addVideoObserver side-channel hook on VideoEventService.
// ABOUTME: Cross-cutting consumers (badge caches) rely on it firing universally.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeFilter extends Fake implements Filter {}

VideoEvent _video(String id, {String? pubkey}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey ?? 'pubkey-$id',
    createdAt: DateTime(2025).millisecondsSinceEpoch,
    content: 'test',
    timestamp: DateTime(2025),
    videoUrl: 'https://example.com/$id.mp4',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[_FakeFilter()]);
  });

  late _MockNostrClient mockNostrClient;
  late VideoEventService service;

  setUp(() {
    mockNostrClient = _MockNostrClient();
    when(() => mockNostrClient.publicKey).thenReturn('');
    service = VideoEventService(
      mockNostrClient,
      crashReporter: const SilentCrashReporter(),
    );
  });

  group('addVideoObserver', () {
    test('fires for every batch returned by filterVideoList', () {
      final received = <List<String>>[];
      service.addVideoObserver(
        (videos) => received.add(videos.map((v) => v.id).toList()),
      );

      service.filterVideoList([_video('a'), _video('b')]);
      service.filterVideoList([_video('c')]);

      expect(received, [
        ['a', 'b'],
        ['c'],
      ]);
    });

    test(
      'fires per video added via addVideoEvent (covers WebSocket path '
      'including historical pagination)',
      () {
        final received = <String>[];
        service.addVideoObserver(
          (videos) => received.addAll(videos.map((v) => v.id)),
        );

        service.addVideoEvent(_video('socket-1'));
        service.addVideoEvent(_video('socket-2'));

        expect(received, ['socket-1', 'socket-2']);
      },
    );

    test('disposer removes the observer', () {
      final received = <String>[];
      final dispose = service.addVideoObserver(
        (videos) => received.addAll(videos.map((v) => v.id)),
      );

      service.filterVideoList([_video('before')]);
      dispose();
      service.filterVideoList([_video('after')]);

      expect(received, ['before']);
    });

    test('multiple observers each receive every batch', () {
      final receivedA = <String>[];
      final receivedB = <String>[];
      service
        ..addVideoObserver(
          (videos) => receivedA.addAll(videos.map((v) => v.id)),
        )
        ..addVideoObserver(
          (videos) => receivedB.addAll(videos.map((v) => v.id)),
        );

      service.filterVideoList([_video('x'), _video('y')]);

      expect(receivedA, ['x', 'y']);
      expect(receivedB, ['x', 'y']);
    });

    test('one observer throwing does not block the others', () {
      final received = <String>[];
      service
        ..addVideoObserver((_) => throw StateError('boom'))
        ..addVideoObserver(
          (videos) => received.addAll(videos.map((v) => v.id)),
        );

      service.filterVideoList([_video('z')]);

      expect(received, ['z']);
    });
  });
}
