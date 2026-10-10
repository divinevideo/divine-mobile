// ABOUTME: Locks the analytics tags published as view_traffic_sources.source_detail
// ABOUTME: so renaming one cannot silently split its history in the funnelcake data

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';

void main() {
  group('VideoFeedSourceTypeAnalytics', () {
    test('every source type has a distinct, stable tag', () {
      // These strings are written to funnelcake's
      // view_traffic_sources.source_detail and queried historically. Renaming
      // one splits its history in two, so this asserts the exact values rather
      // than merely that a tag exists.
      expect(VideoFeedSourceType.forYou.analyticsTag, 'foryou');
      expect(VideoFeedSourceType.following.analyticsTag, 'following');
      expect(VideoFeedSourceType.subscribedList.analyticsTag, 'list');
      expect(VideoFeedSourceType.newVideos.analyticsTag, 'new');
      expect(VideoFeedSourceType.classic.analyticsTag, 'classic');
    });

    test('tags are unique across all source types', () {
      // A duplicate tag would silently merge two feeds into one bucket, which
      // is the exact problem this detail field exists to solve.
      final tags = VideoFeedSourceType.values
          .map((type) => type.analyticsTag)
          .toList();

      expect(tags.toSet().length, tags.length, reason: 'tags must be unique');
    });

    test('a new source type must be given a tag', () {
      // The switch in analyticsTag is exhaustive, so adding an enum value
      // without a tag is a compile error. This asserts the count so the intent
      // is visible at review time when someone adds a feed mode.
      expect(
        VideoFeedSourceType.values.length,
        5,
        reason:
            'new feed mode added: give it an analyticsTag and update this '
            'test, otherwise its views land in an unattributed bucket',
      );
    });

    test('no tag is empty or whitespace', () {
      for (final type in VideoFeedSourceType.values) {
        expect(type.analyticsTag.trim(), isNotEmpty, reason: '$type');
        // The publisher omits the detail element entirely when it is empty,
        // which would collapse the mode back into the bare `home` bucket.
        expect(type.analyticsTag, isNot(contains(' ')), reason: '$type');
      }
    });
  });

  group('VideoFeedBlocState feed session', () {
    test('defaults to zero and participates in copies and equality', () {
      const initial = VideoFeedBlocState();
      final next = initial.copyWith(feedSessionRevision: 1);

      expect(initial.feedSessionRevision, 0);
      expect(next.feedSessionRevision, 1);
      expect(next, isNot(initial));
    });
  });
}
