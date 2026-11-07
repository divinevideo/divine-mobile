// ABOUTME: Unit tests for merging the viewer's video and people lists
// ABOUTME: into the profile gallery's newest-first order.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/profile/profile_list_entries.dart';

CuratedList _video(String id, DateTime createdAt) => CuratedList(
  id: id,
  name: id,
  videoEventIds: const [],
  createdAt: createdAt,
  updatedAt: createdAt,
);

UserList _people(String id, DateTime createdAt) => UserList(
  id: id,
  name: id,
  pubkeys: const [],
  createdAt: createdAt,
  updatedAt: createdAt,
);

String _idOf(ProfileListEntry entry) => switch (entry) {
  ProfileVideoListEntry(:final list) => 'video:${list.id}',
  ProfilePeopleListEntry(:final list) => 'people:${list.id}',
};

void main() {
  group('mergeProfileLists', () {
    test('returns an empty list when both sources are empty', () {
      expect(
        mergeProfileLists(videoLists: const [], peopleLists: const []),
        isEmpty,
      );
    });

    test('interleaves both kinds newest first', () {
      final merged = mergeProfileLists(
        videoLists: [
          _video('oldest', DateTime(2026)),
          _video('newest', DateTime(2026, 4)),
        ],
        peopleLists: [
          _people('second', DateTime(2026, 3)),
          _people('third', DateTime(2026, 2)),
        ],
      );

      expect(merged.map(_idOf), [
        'video:newest',
        'people:second',
        'people:third',
        'video:oldest',
      ]);
    });

    test('keeps source order, videos first, for equal timestamps', () {
      final at = DateTime(2026, 5);
      final merged = mergeProfileLists(
        videoLists: [_video('v1', at), _video('v2', at)],
        peopleLists: [_people('p1', at), _people('p2', at)],
      );

      expect(merged.map(_idOf), [
        'video:v1',
        'video:v2',
        'people:p1',
        'people:p2',
      ]);
    });

    test('exposes each entry creation time', () {
      final at = DateTime(2026, 6);
      final merged = mergeProfileLists(
        videoLists: [_video('v', at)],
        peopleLists: [_people('p', at)],
      );

      expect(merged.map((entry) => entry.createdAt), [at, at]);
    });
  });
}
