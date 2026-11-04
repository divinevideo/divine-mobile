// ABOUTME: Unit tests for the ViewSource sealed class value semantics.

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

VideoEvent _video(String id, {String pubkey = 'author'}) => VideoEvent(
  id: id,
  pubkey: pubkey,
  createdAt: 1000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
);

void main() {
  group('ViewSource', () {
    test('singleton feeds compare equal by type', () {
      expect(const ForYouViewSource(), equals(const ForYouViewSource()));
      expect(const PopularViewSource(), equals(const PopularViewSource()));
      expect(
        const ClassicVinesViewSource(),
        equals(const ClassicVinesViewSource()),
      );
      expect(const NewVideosViewSource(), equals(const NewVideosViewSource()));
    });

    test('distinct singleton feeds are not equal', () {
      expect(
        const ForYouViewSource(),
        isNot(equals(const PopularViewSource())),
      );
    });

    test('author-keyed feeds compare by user id', () {
      expect(
        const ProfileViewSource('npub-a'),
        equals(const ProfileViewSource('npub-a')),
      );
      expect(
        const ProfileViewSource('npub-a'),
        isNot(equals(const ProfileViewSource('npub-b'))),
      );
    });

    test('the same user id on different feeds is not equal', () {
      expect(
        const ProfileViewSource('npub-a'),
        isNot(equals(const LikedViewSource('npub-a'))),
      );
    });

    test('hashtag / search / list feeds compare by their payload', () {
      expect(
        const HashtagViewSource('vine'),
        equals(const HashtagViewSource('vine')),
      );
      expect(
        const SearchViewSource('cats'),
        isNot(equals(const SearchViewSource('dogs'))),
      );
      expect(
        const CuratedListViewSource('list-1'),
        equals(const CuratedListViewSource('list-1')),
      );
      expect(
        const UserListViewSource('list-1'),
        equals(const UserListViewSource('list-1')),
      );
    });

    test('SingleVideoViewSource compares by video id', () {
      expect(
        SingleVideoViewSource(_video('1')),
        equals(SingleVideoViewSource(_video('1'))),
      );
      expect(
        SingleVideoViewSource(_video('1')),
        isNot(equals(SingleVideoViewSource(_video('2')))),
      );
    });

    test('VideoListViewSource compares by ordered video ids', () {
      expect(
        VideoListViewSource([_video('1'), _video('2')]),
        equals(VideoListViewSource([_video('1'), _video('2')])),
      );
      expect(
        VideoListViewSource([_video('1'), _video('2')]),
        isNot(equals(VideoListViewSource([_video('2'), _video('1')]))),
      );
    });

    test('VideoListViewSource exposes an unmodifiable copy', () {
      final input = [_video('1')];
      final source = VideoListViewSource(input);
      input.add(_video('2'));

      expect(source.videos, hasLength(1));
      expect(() => source.videos.add(_video('3')), throwsUnsupportedError);
    });

    test('switch is exhaustive over every variant', () {
      String label(ViewSource source) => switch (source) {
        ForYouViewSource() => 'for-you',
        PopularViewSource() => 'popular',
        ClassicVinesViewSource() => 'classics',
        NewVideosViewSource() => 'new',
        NewCreatorsViewSource() => 'new-creators',
        ProfileViewSource() => 'profile',
        LikedViewSource() => 'liked',
        RepostsViewSource() => 'reposts',
        SavedViewSource() => 'saved',
        CollabsViewSource() => 'collabs',
        HashtagViewSource() => 'hashtag',
        CuratedListViewSource() => 'curated',
        UserListViewSource() => 'user-list',
        ExploreViewSource() => 'explore',
        CategoryViewSource() => 'category',
        SearchViewSource() => 'search',
        SingleVideoViewSource() => 'single',
        VideoListViewSource() => 'list',
      };

      expect(label(const ForYouViewSource()), 'for-you');
      expect(label(const ProfileViewSource('x')), 'profile');
      expect(label(SingleVideoViewSource(_video('1'))), 'single');
    });
  });
}
