// ABOUTME: Tests for VideoEvent text-track tag parsing.
// ABOUTME: Verifies all text-track references are captured in order into
// ABOUTME: textTrackRefs, with textTrackRef as back-compat first entry.

import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:test/test.dart';

// Valid 64-character hex pubkey for testing
const testPubkey =
    'abc123def456789012345678901234'
    '567890123456789012345678901234abcd';

void main() {
  group('VideoEvent text-track parsing', () {
    test(
      'captures single text-track tag into textTrackRefs and textTrackRef',
      () {
        final event = Event(
          testPubkey,
          34236,
          [
            ['d', 'my-vine-id'],
            [
              'text-track',
              'https://media.divine.video/abc123',
              'wss://relay.divine.video',
              'captions',
              'en',
            ],
          ],
          'content',
        );

        final video = VideoEvent.fromNostrEvent(event);

        expect(
          video.textTrackRefs,
          equals(['https://media.divine.video/abc123']),
        );
        expect(video.textTrackRef, equals('https://media.divine.video/abc123'));
      },
    );

    test('captures multiple text-track tags into textTrackRefs in order', () {
      final event = Event(
        testPubkey,
        34236,
        [
          ['d', 'my-vine-id'],
          [
            'text-track',
            'https://media.divine.video/abc123',
            'wss://relay.divine.video',
            'captions',
            'en',
          ],
          [
            'text-track',
            '39307:$testPubkey:subtitles:my-vine-id',
            'wss://relay.divine.video',
            'captions',
            'en',
          ],
        ],
        'content',
      );

      final video = VideoEvent.fromNostrEvent(event);

      expect(video.textTrackRefs, [
        'https://media.divine.video/abc123',
        '39307:$testPubkey:subtitles:my-vine-id',
      ]);
      expect(video.textTrackRef, equals('https://media.divine.video/abc123'));
    });

    test('textTrackRefs is empty when no text-track tags present', () {
      final event = Event(
        testPubkey,
        34236,
        [
          ['d', 'my-vine-id'],
        ],
        'content',
      );

      final video = VideoEvent.fromNostrEvent(event);

      expect(video.textTrackRefs, isEmpty);
      expect(video.textTrackRef, isNull);
    });

    test('copyWith preserves textTrackRefs when not overridden', () {
      final event = Event(
        testPubkey,
        34236,
        [
          ['d', 'my-vine-id'],
          [
            'text-track',
            'https://media.divine.video/abc123',
            'wss://relay.divine.video',
            'captions',
            'en',
          ],
          [
            'text-track',
            '39307:$testPubkey:subtitles:my-vine-id',
            'wss://relay.divine.video',
            'captions',
            'en',
          ],
        ],
        'content',
      );

      final video = VideoEvent.fromNostrEvent(event);
      final copy = video.copyWith(title: 'Updated title');

      expect(copy.textTrackRefs, equals(video.textTrackRefs));
    });

    test('copyWith can override textTrackRefs', () {
      final event = Event(
        testPubkey,
        34236,
        [
          ['d', 'my-vine-id'],
          [
            'text-track',
            'https://media.divine.video/abc123',
            'wss://relay.divine.video',
            'captions',
            'en',
          ],
        ],
        'content',
      );

      final video = VideoEvent.fromNostrEvent(event);
      final newRefs = ['https://other.example.com/captions.vtt'];
      final copy = video.copyWith(textTrackRefs: newRefs);

      expect(copy.textTrackRefs, equals(newRefs));
    });

    test('captures the source language from the text-track tag', () {
      final event = Event(
        testPubkey,
        34236,
        [
          ['d', 'my-vine-id'],
          [
            'text-track',
            '39307:$testPubkey:subtitles:my-vine-id',
            'wss://relay.divine.video',
            'captions',
            'ja',
          ],
        ],
        'content',
      );

      final video = VideoEvent.fromNostrEvent(event);

      expect(video.textTrackLang, equals('ja'));
    });

    test('normalizes a region-qualified language to its primary subtag', () {
      final event = Event(
        testPubkey,
        34236,
        [
          ['d', 'my-vine-id'],
          [
            'text-track',
            'https://media.divine.video/abc123',
            'wss://relay.divine.video',
            'captions',
            'de-CH',
          ],
        ],
        'content',
      );

      final video = VideoEvent.fromNostrEvent(event);

      expect(video.textTrackLang, equals('de'));
    });

    test('textTrackLang is null when the tag carries no language', () {
      final event = Event(
        testPubkey,
        34236,
        [
          ['d', 'my-vine-id'],
          [
            'text-track',
            '39307:$testPubkey:subtitles:my-vine-id',
          ],
        ],
        'content',
      );

      final video = VideoEvent.fromNostrEvent(event);

      expect(video.textTrackLang, isNull);
    });

    test('copyWith preserves textTrackLang when not overridden', () {
      final event = Event(
        testPubkey,
        34236,
        [
          ['d', 'my-vine-id'],
          [
            'text-track',
            'https://media.divine.video/abc123',
            'wss://relay.divine.video',
            'captions',
            'ja',
          ],
        ],
        'content',
      );

      final video = VideoEvent.fromNostrEvent(event);
      final copy = video.copyWith(title: 'Updated title');

      expect(copy.textTrackLang, equals('ja'));
    });
  });
}
