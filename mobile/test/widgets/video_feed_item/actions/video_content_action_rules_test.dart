// ABOUTME: Tests for the rules deciding which content actions a video offers.
// ABOUTME: Covers the remix consent rule: absent tag allows, an explicit false declines.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_action_rules.dart';

VideoEvent _video({
  Map<String, String> rawTags = const {},
  List<List<String>>? tags,
}) {
  return VideoEvent(
    id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    pubkey: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
    createdAt: 1757385263,
    content: 'Test video',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
    videoUrl: 'https://example.com/video.mp4',
    rawTags: rawTags,
    nostrEventTags: tags ?? const [],
  );
}

void main() {
  group('canRemixVideo', () {
    test('is true when the video carries no reuse tag', () {
      expect(canRemixVideo(video: _video(), isOwnContent: false), isTrue);
    });

    test('is true when the creator allows video reuse', () {
      expect(
        canRemixVideo(
          video: _video(
            tags: const [
              ['allow_video_reuse', 'true'],
            ],
          ),
          isOwnContent: false,
        ),
        isTrue,
      );
    });

    test('is false when the creator declines video reuse', () {
      expect(
        canRemixVideo(
          video: _video(
            tags: const [
              ['allow_video_reuse', 'false'],
            ],
          ),
          isOwnContent: false,
        ),
        isFalse,
      );
    });

    test('is true for a classic Vine even when its tag says false', () {
      expect(
        canRemixVideo(
          video: _video(
            rawTags: const {'platform': 'vine'},
            tags: const [
              ['allow_video_reuse', 'false'],
            ],
          ),
          isOwnContent: false,
        ),
        isTrue,
      );
    });

    test('is true for the viewer own video even when its tag says false', () {
      expect(
        canRemixVideo(
          video: _video(
            tags: const [
              ['allow_video_reuse', 'false'],
            ],
          ),
          isOwnContent: true,
        ),
        isTrue,
      );
    });
  });
}
