// ABOUTME: Tests for the rules deciding which content actions a video offers.
// ABOUTME: Covers the add-to-clips visibility rule, including the web exclusion.

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
  group('canAddVideoToClips', () {
    test('is true for a classic Vine', () {
      expect(
        canAddVideoToClips(
          video: _video(rawTags: const {'platform': 'vine'}),
          isOwnContent: false,
          isWeb: false,
        ),
        isTrue,
      );
    });

    test('is true for the viewer own video', () {
      expect(
        canAddVideoToClips(
          video: _video(),
          isOwnContent: true,
          isWeb: false,
        ),
        isTrue,
      );
    });

    test('is true when the creator allows video reuse', () {
      expect(
        canAddVideoToClips(
          video: _video(
            tags: const [
              ['allow_video_reuse', 'true'],
            ],
          ),
          isOwnContent: false,
          isWeb: false,
        ),
        isTrue,
      );
    });

    test('is false for a plain video from someone else', () {
      expect(
        canAddVideoToClips(
          video: _video(),
          isOwnContent: false,
          isWeb: false,
        ),
        isFalse,
      );
    });

    test('is false on web even for the viewer own video', () {
      expect(
        canAddVideoToClips(
          video: _video(),
          isOwnContent: true,
          isWeb: true,
        ),
        isFalse,
      );
    });
  });
}
