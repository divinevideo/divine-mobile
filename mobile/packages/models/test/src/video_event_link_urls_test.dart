// ABOUTME: Tests the web pages a video links to, read from its marked `r`
// ABOUTME: tags and kept apart from the URLs of its own media.

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('VideoEvent.linkUrls', () {
    VideoEvent video(List<List<String>> tags) => VideoEvent.fromNostrEvent(
      Event(
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        34236,
        [
          const ['d', 'video-links'],
          const ['url', 'https://media.divine.video/links.mp4'],
          ...tags,
        ],
        'Video with links',
        createdAt: 1778120201,
      ),
    );

    test('lists each marked web page once, in order', () {
      final links = video([
        ['r', 'https://divine.video/b', videoLinkTagMarker],
        ['r', 'https://divine.video/a', videoLinkTagMarker],
        ['r', 'https://divine.video/b', videoLinkTagMarker],
      ]).linkUrls;

      expect(
        links,
        equals(['https://divine.video/b', 'https://divine.video/a']),
      );
    });

    test('leaves out unmarked or otherwise marked tags and other schemes', () {
      final links = video([
        const ['r', 'https://divine.video/clip.mp4'],
        const ['r', 'https://divine.video/clip.mp4', 'video'],
        const ['r', 'javascript://alert', videoLinkTagMarker],
        const ['r', 'wss://relay.divine.video', videoLinkTagMarker],
      ]).linkUrls;

      expect(links, isEmpty);
    });

    test('keeps its links through a feed snapshot', () {
      final original = video([
        ['r', 'https://divine.video/about', videoLinkTagMarker],
      ]);

      final restored = VideoEvent.fromJson(original.toJson());

      expect(restored.nostrEventTags, isEmpty);
      expect(restored.linkUrls, equals(['https://divine.video/about']));
    });

    test('reads the links of tags it is copied with', () {
      final original = video([
        ['r', 'https://divine.video/about', videoLinkTagMarker],
      ]);

      final copied = original.copyWith(
        nostrEventTags: const [
          ['r', 'https://divine.video/press', videoLinkTagMarker],
        ],
      );

      expect(copied.linkUrls, equals(['https://divine.video/press']));
      expect(
        original.copyWith(title: 'Renamed').linkUrls,
        equals(['https://divine.video/about']),
      );
    });
  });
}
