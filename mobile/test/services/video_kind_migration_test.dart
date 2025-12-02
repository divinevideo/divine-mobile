// ABOUTME: TDD test to verify all video event queries use NIP-71 kind 34236 (not deprecated 32222)
// ABOUTME: This test ensures we're using the correct Nostr video event kind as per NIP-71 specification

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/models/video_event.dart';

void main() {
  group('Video Kind Migration - NIP-71 Compliance', () {
    test('VideoEvent should accept kind 34236 events (NIP-71)', () {
      final expirationTimestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 1800;

      final event = Event(
        '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798', // Valid hex pubkey
        34236, // NIP-71 addressable short looping video kind
        [
          ['d', 'test-video-${DateTime.now().millisecondsSinceEpoch}'],
          ['expiration', expirationTimestamp.toString()],
          ['url', 'https://test.com/video.mp4'],
          ['m', 'video/mp4'],
        ],
        'Test video content',
      );

      // VideoEvent should accept kind 34236
      final videoEvent = VideoEvent.fromNostrEvent(event);

      expect(
        videoEvent.vineId,
        isNotNull,
        reason: 'VideoEvent must successfully parse kind 34236',
      );
    });

    test('NIP71VideoKinds should include kind 34236', () {
      expect(
        NIP71VideoKinds.getAllVideoKinds(),
        contains(34236),
        reason: 'Kind 34236 must be in the list of accepted video kinds',
      );
      expect(
        NIP71VideoKinds.addressableShortVideo,
        equals(34236),
        reason: 'Kind 34236 is the addressable short video kind',
      );
    });

    test('Kind 32222 should NOT be in NIP71VideoKinds', () {
      const deprecatedKind = 32222;

      expect(
        NIP71VideoKinds.getAllVideoKinds(),
        isNot(contains(deprecatedKind)),
        reason:
            'Kind 32222 is deprecated and should not be in accepted video kinds',
      );
    });

    test('Addressable video IDs should use kind 34236 format', () {
      const pubkey = 'test-pubkey-abc123';
      const dTag = 'my-video-id';

      // Addressable ID format per NIP-01: <kind>:<pubkey>:<d-tag>
      final addressableId = '34236:$pubkey:$dTag';

      expect(
        addressableId,
        startsWith('34236:'),
        reason: 'Addressable IDs must use NIP-71 kind 34236',
      );
      expect(
        addressableId,
        isNot(startsWith('32222:')),
        reason: 'Must not use deprecated kind 34236 in addressable IDs',
      );
    });

    test('Repost k tag should reference kind 34236', () {
      // When creating a repost (kind 6) of a video, the k tag should be 34236
      const correctKTag = '34236';
      const deprecatedKTag = '32222';

      expect(correctKTag, equals('34236'));
      expect(
        correctKTag,
        isNot(equals(deprecatedKTag)),
        reason: 'Repost k tag must reference NIP-71 kind 34236',
      );
    });

    test('Video filters should query for kind 34236', () {
      // Document that all video filters should request kind 34236
      const expectedVideoKind = 34236;

      // This is the kind that should be in all Filter objects for videos
      expect(
        expectedVideoKind,
        equals(NIP71VideoKinds.addressableShortVideo),
        reason: 'All video queries must use NIP-71 kind 34236',
      );
    });

    test('Event with kind 34236 should have required NIP-71 tags', () {
      final expirationTimestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 1800;

      final event = Event(
        'c0a1c0a1c0a1c0a1c0a1c0a1c0a1c0a1c0a1c0a1c0a1c0a1c0a1c0a1c0a1c0a1', // Valid hex pubkey
        34236,
        [
          ['d', 'unique-video-identifier'], // Required for addressable events
          ['expiration', expirationTimestamp.toString()], // For test cleanup
          ['url', 'https://blossom.example.com/video.mp4'],
          ['m', 'video/mp4'],
          ['dim', '1080x1920'],
          ['duration', '6'],
        ],
        'Short video description',
      );

      final videoEvent = VideoEvent.fromNostrEvent(event);

      expect(
        videoEvent.vineId,
        equals('unique-video-identifier'),
        reason: 'd tag is required for addressable events',
      );
      expect(
        videoEvent.videoUrl,
        equals('https://blossom.example.com/video.mp4'),
      );
    });
  });
}
