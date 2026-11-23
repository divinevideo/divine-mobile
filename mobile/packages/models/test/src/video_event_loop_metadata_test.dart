// ABOUTME: Tests for VideoEvent.totalLoops and hasLoopMetadata derivations
// ABOUTME: that drive the "N loops" label on the fullscreen video player.

import 'package:models/models.dart';
import 'package:test/test.dart';

VideoEvent _video({
  int? originalLoops,
  Map<String, String> rawTags = const {},
}) {
  return VideoEvent(
    id: 'a' * 64,
    pubkey: 'b' * 64,
    createdAt: 1704067200,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      1704067200 * 1000,
      isUtc: true,
    ),
    originalLoops: originalLoops,
    rawTags: rawTags,
  );
}

void main() {
  group(VideoEvent, () {
    group('totalLoops', () {
      test('returns 0 when neither originalLoops nor rawTags[views] set', () {
        expect(_video().totalLoops, equals(0));
      });

      test('sums originalLoops and rawTags[views]', () {
        final video = _video(originalLoops: 6, rawTags: const {'views': '34'});
        expect(video.totalLoops, equals(40));
      });

      test('treats unparseable rawTags[views] as 0', () {
        final video = _video(
          originalLoops: 6,
          rawTags: const {'views': 'not-a-number'},
        );
        expect(video.totalLoops, equals(6));
      });
    });

    group('hasLoopMetadata', () {
      test('is false when no loop fields present', () {
        expect(_video().hasLoopMetadata, isFalse);
      });

      test('is true when originalLoops is non-null (even if 0)', () {
        expect(_video(originalLoops: 0).hasLoopMetadata, isTrue);
      });

      test('is true when rawTags contains views', () {
        final video = _video(rawTags: const {'views': '34'});
        expect(video.hasLoopMetadata, isTrue);
      });

      test('is true when rawTags contains loops (vine archive)', () {
        final video = _video(rawTags: const {'loops': '13565'});
        expect(video.hasLoopMetadata, isTrue);
      });
    });

    test('round-trips a reconciled playback count separately from views', () {
      final fetchedAt = DateTime.utc(2026, 11, 22);
      final video = _video(rawTags: const {'views': '34'}).copyWith(
        loopCountSnapshot: (count: 50, fetchedAt: fetchedAt),
      );
      final restored = VideoEvent.fromJson(video.toJson());
      expect(restored.totalLoops, 34);
      expect(restored.loopCountSnapshot, (count: 50, fetchedAt: fetchedAt));

      final legacy = VideoEvent.fromJson(
        _video(rawTags: const {'views': '34'}).toJson(),
      );
      expect(legacy.totalLoops, 34);
      expect(legacy.loopCountSnapshot, isNull);
    });

    group('hasOriginalVineMetrics', () {
      test('is false when no archival metric is present', () {
        expect(_video().hasOriginalVineMetrics, isFalse);
      });

      test('is true when originalLoops is present (even if 0)', () {
        expect(_video(originalLoops: 0).hasOriginalVineMetrics, isTrue);
      });

      test('is true when an archival engagement count is present', () {
        final video = _video().copyWith(originalLikes: 459878);
        expect(video.hasOriginalVineMetrics, isTrue);
      });
    });
  });
}
