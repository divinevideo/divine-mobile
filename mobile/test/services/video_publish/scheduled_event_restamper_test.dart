// ABOUTME: Tests for restampScheduledEvent: a held event moves to a new
// ABOUTME: publish time with its media and credit tags intact.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/video_publish/scheduled_event_restamper.dart';

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final collaborator = 'b' * 64;

  Event held({int? expiration}) => Event(
    pubkey,
    34236,
    [
      const ['d', 'video-id'],
      const ['imeta', 'url https://cdn.example.com/video.mp4'],
      const ['title', 'Plants'],
      const ['published_at', '1800000000'],
      if (expiration != null) ['expiration', '$expiration'],
      ['p', collaborator, 'wss://relay.divine.video', 'collaborator'],
      const ['client', 'Divine'],
    ],
    'A plant video',
    createdAt: 1800000000,
  );

  group('restampScheduledEvent', () {
    test('replaces published_at in place and keeps every tag in order', () {
      final result = restampScheduledEvent(held(), createdAt: 1800003600);

      expect(result.content, 'A plant video');
      expect(result.tags, [
        ['d', 'video-id'],
        ['imeta', 'url https://cdn.example.com/video.mp4'],
        ['title', 'Plants'],
        ['published_at', '1800003600'],
        ['p', collaborator, 'wss://relay.divine.video', 'collaborator'],
        ['client', 'Divine'],
      ]);
    });

    test('recomputes the expiration from the new time, in place', () {
      final source = held(expiration: 1800086400);
      final result = restampScheduledEvent(
        source,
        createdAt: 1800003600,
        expireAfterSecs: 86400,
      );

      final position = source.tags.indexWhere((t) => t[0] == 'expiration');
      expect(result.tags[position], ['expiration', '1800090000']);
      expect(result.tags.where((t) => t[0] == 'expiration'), hasLength(1));
    });

    test('rebuilds the same event for the time it already has', () {
      // A reschedule to an unchanged time must sign the same id, which is
      // how the coordinator tells it apart from a real move.
      final source = held(expiration: 1800086400);
      final result = restampScheduledEvent(
        source,
        createdAt: 1800000000,
        expireAfterSecs: 86400,
      );
      final resigned = Event(
        pubkey,
        source.kind,
        result.tags,
        result.content,
        createdAt: 1800000000,
      );

      expect(result.tags, source.tags);
      expect(resigned.id, source.id);
    });

    test('adds published_at and the expiration when the source has none', () {
      final source = Event(
        pubkey,
        34236,
        [
          const ['d', 'video-id'],
          const ['title', 'Plants'],
        ],
        'A plant video',
        createdAt: 1800000000,
      );

      final result = restampScheduledEvent(
        source,
        createdAt: 1800003600,
        expireAfterSecs: 86400,
      );

      expect(result.tags, [
        ['d', 'video-id'],
        ['title', 'Plants'],
        ['published_at', '1800003600'],
        ['expiration', '1800090000'],
      ]);
    });

    test('writes published_at and the expiration once each', () {
      final source = Event(
        pubkey,
        34236,
        [
          const ['published_at', '1800000000'],
          const ['expiration', '1800086400'],
          const ['published_at', '1800000000'],
          const ['expiration', '1800086400'],
        ],
        'A plant video',
        createdAt: 1800000000,
      );

      final result = restampScheduledEvent(
        source,
        createdAt: 1800003600,
        expireAfterSecs: 86400,
      );

      expect(result.tags, [
        ['published_at', '1800003600'],
        ['expiration', '1800090000'],
      ]);
    });

    test('drops a stale expiration when the post no longer expires', () {
      final result = restampScheduledEvent(
        held(expiration: 1800086400),
        createdAt: 1800003600,
      );

      expect(result.tags.any((t) => t[0] == 'expiration'), isFalse);
    });

    test('returns fresh lists the caller may mutate', () {
      final source = held();
      final result = restampScheduledEvent(source, createdAt: 1800003600)
        ..tags.first.add('mutated');

      expect(source.tags.first, ['d', 'video-id']);
      expect(result.tags.first, ['d', 'video-id', 'mutated']);
    });
  });
}
