// ABOUTME: Locks the analytics tags published as view_traffic_sources.source_detail
// ABOUTME: so renaming one cannot silently split its history in the funnelcake data

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

// Full-length 64-char pubkeys — never truncate.
const _ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _ownerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

PeopleListSearchResult _followed(String ownerPubkey, String listId) {
  final stamp = DateTime.utc(2026);
  return PeopleListSearchResult(
    ownerPubkey: ownerPubkey,
    list: UserList(
      id: listId,
      name: 'List $listId',
      pubkeys: const [_ownerA],
      createdAt: stamp,
      updatedAt: stamp,
      isEditable: false,
    ),
  );
}

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
      expect(VideoFeedSourceType.peopleList.analyticsTag, 'peoplelist');
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
        6,
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

  group(VideoFeedSource, () {
    group('peopleList', () {
      test('projects onto the Following mode, labelled by the list', () {
        const source = VideoFeedSource.peopleList(
          listId: 'crew',
          listName: 'Crew',
          listOwnerPubkey: _ownerA,
        );

        expect(source.type, equals(VideoFeedSourceType.peopleList));
        expect(source.mode, equals(FeedMode.following));
        expect(source.labelFallback, equals('Crew'));
      });

      test('persists the owner with the d tag', () {
        const source = VideoFeedSource.peopleList(
          listId: 'crew',
          listName: 'Crew',
          listOwnerPubkey: _ownerA,
        );

        expect(source.persistenceValue, equals('people:$_ownerA:crew'));
      });

      test('tells apart two owners who share a d tag', () {
        const mine = VideoFeedSource.peopleList(
          listId: 'friends',
          listName: 'Friends',
          listOwnerPubkey: _ownerA,
        );
        const theirs = VideoFeedSource.peopleList(
          listId: 'friends',
          listName: 'Friends',
          listOwnerPubkey: _ownerB,
        );

        expect(mine, isNot(equals(theirs)));
        expect(mine.persistenceValue, isNot(equals(theirs.persistenceValue)));
      });

      test('never collides with a curated list of the same id', () {
        const people = VideoFeedSource.peopleList(
          listId: 'crew',
          listName: 'Crew',
          listOwnerPubkey: _ownerA,
        );
        const curated = VideoFeedSource.subscribedList(
          listId: 'crew',
          listName: 'Crew',
        );

        expect(people, isNot(equals(curated)));
        expect(
          people.persistenceValue,
          isNot(equals(curated.persistenceValue)),
        );
      });
    });
  });

  group(VideoFeedBlocState, () {
    group('selectedPeopleList', () {
      test('is the followed list the source names, by owner and id', () {
        final state = VideoFeedBlocState(
          source: const VideoFeedSource.peopleList(
            listId: 'friends',
            listName: 'Friends',
            listOwnerPubkey: _ownerB,
          ),
          followedPeopleLists: [
            _followed(_ownerA, 'friends'),
            _followed(_ownerB, 'friends'),
          ],
        );

        expect(state.selectedPeopleList?.ownerPubkey, equals(_ownerB));
      });

      test('is null once the list is no longer followed', () {
        final state = VideoFeedBlocState(
          source: const VideoFeedSource.peopleList(
            listId: 'gone',
            listName: 'Gone',
            listOwnerPubkey: _ownerA,
          ),
          followedPeopleLists: [_followed(_ownerA, 'friends')],
        );

        expect(state.selectedPeopleList, isNull);
      });

      test('is null for any other source', () {
        final state = VideoFeedBlocState(
          source: const VideoFeedSource.subscribedList(
            listId: 'friends',
            listName: 'Friends',
          ),
          followedPeopleLists: [_followed(_ownerA, 'friends')],
        );

        expect(state.selectedPeopleList, isNull);
      });
    });
  });
}
