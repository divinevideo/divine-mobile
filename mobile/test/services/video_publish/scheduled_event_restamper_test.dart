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
    test('replaces published_at and keeps every other tag in order', () {
      final result = restampScheduledEvent(held(), createdAt: 1800003600);

      expect(result.content, 'A plant video');
      expect(result.tags, [
        ['d', 'video-id'],
        ['imeta', 'url https://cdn.example.com/video.mp4'],
        ['title', 'Plants'],
        ['p', collaborator, 'wss://relay.divine.video', 'collaborator'],
        ['client', 'Divine'],
        ['published_at', '1800003600'],
      ]);
    });

    test('recomputes the expiration from the new time', () {
      final result = restampScheduledEvent(
        held(expiration: 1800086400),
        createdAt: 1800003600,
        expireAfterSecs: 86400,
      );

      expect(result.tags.where((t) => t[0] == 'expiration').single, [
        'expiration',
        '1800090000',
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
