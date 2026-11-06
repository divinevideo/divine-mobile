// ABOUTME: Tests VideoEvent.addressableId uses only real addressable d tags.
// ABOUTME: Builds the coordinate under the video's own addressable kind.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('VideoEvent.addressableId', () {
    const pubkey =
        'c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0';
    const eventId =
        'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2';

    VideoEvent build({
      int? eventKind,
      String? vineId,
      String? addressableDTag,
    }) => VideoEvent(
      id: eventId,
      pubkey: pubkey,
      createdAt: 1704067200,
      content: '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
      vineId: vineId,
      addressableDTag: addressableDTag,
      eventKind: eventKind,
    );

    test('uses kind 34236 for an addressable short video', () {
      final video = build(
        eventKind: 34236,
        vineId: 'vine123',
        addressableDTag: 'vine123',
      );
      expect(video.addressableId, equals('34236:$pubkey:vine123'));
    });

    test('uses kind 34235 for an addressable normal video', () {
      final video = build(
        eventKind: 34235,
        vineId: 'reel456',
        addressableDTag: 'reel456',
      );
      expect(video.addressableId, equals('34235:$pubkey:reel456'));
    });

    test('is null for a regular short video that carries a d tag', () {
      final video = build(
        eventKind: 22,
        vineId: 'stray22',
        addressableDTag: 'stray22',
      );
      expect(video.addressableId, isNull);
    });

    test('is null for a regular normal video that carries a d tag', () {
      final video = build(
        eventKind: 21,
        vineId: 'stray21',
        addressableDTag: 'stray21',
      );
      expect(video.addressableId, isNull);
    });

    test('does not fall back to the event id for d-less videos', () {
      final video = build(eventKind: 22, vineId: eventId);
      expect(video.addressableId, isNull);
    });

    test('falls back to 34236 when the event kind is unknown', () {
      final video = build(vineId: 'vine789', addressableDTag: 'vine789');
      expect(video.addressableId, equals('34236:$pubkey:vine789'));
    });

    test('is null when the video has no d-tag', () {
      final video = build(eventKind: 34236);
      expect(video.addressableId, isNull);
    });
  });
}
