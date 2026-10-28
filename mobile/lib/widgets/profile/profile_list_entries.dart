// ABOUTME: Merges the viewer's video and people lists into one gallery order.
// ABOUTME: Newest list first, so a just-created list lands in the top-left slot.

import 'package:models/models.dart';

/// One card in the own-profile Lists gallery.
sealed class ProfileListEntry {
  const ProfileListEntry();

  /// When the underlying list was created; drives the gallery order.
  DateTime get createdAt;
}

/// A curated video list (kind 30005) card.
final class ProfileVideoListEntry extends ProfileListEntry {
  const ProfileVideoListEntry(this.list);

  final CuratedList list;

  @override
  DateTime get createdAt => list.createdAt;
}

/// A people list (kind 30000) card.
final class ProfilePeopleListEntry extends ProfileListEntry {
  const ProfilePeopleListEntry(this.list);

  final UserList list;

  @override
  DateTime get createdAt => list.createdAt;
}

/// [videoLists] and [peopleLists] as one list, newest `createdAt` first.
///
/// Lists created at the same instant keep their source order, video lists
/// before people lists, so equal timestamps never reshuffle between builds.
List<ProfileListEntry> mergeProfileLists({
  required List<CuratedList> videoLists,
  required List<UserList> peopleLists,
}) {
  final indexed =
      <(int, ProfileListEntry)>[
        ...<ProfileListEntry>[
          for (final list in videoLists) ProfileVideoListEntry(list),
          for (final list in peopleLists) ProfilePeopleListEntry(list),
        ].indexed,
      ]..sort((a, b) {
        final byDate = b.$2.createdAt.compareTo(a.$2.createdAt);
        return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
      });
  return [for (final (_, entry) in indexed) entry];
}
