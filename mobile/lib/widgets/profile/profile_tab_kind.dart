// ABOUTME: Ordered profile tab kinds, differing between own and other profiles.
// ABOUTME: Pure ordering logic extracted from ProfileGridView for testability.

/// The distinct content tabs a profile can show.
enum ProfileTabKind {
  videos,
  collabs,
  liked,
  reposts,
  bookmarks,
  lists,
  comments,
}

/// Returns the ordered tabs for a profile.
///
/// The own profile surfaces the user's confirmed collaborations (between
/// Videos and Liked, per #5213) in addition to the owned Bookmarks and Lists
/// tabs. Bookmarks sits between Reposts and Lists, as the design draws it
/// (#8972).
/// Other profiles keep their existing order — Collabs in the 4th slot and
/// neither owned tab — so their layout is unchanged. Bookmarks are the
/// viewer's own list, so there is no other-profile variant to show.
List<ProfileTabKind> profileTabKinds({required bool isOwnProfile}) {
  if (isOwnProfile) {
    return const [
      ProfileTabKind.videos,
      ProfileTabKind.collabs,
      ProfileTabKind.liked,
      ProfileTabKind.reposts,
      ProfileTabKind.bookmarks,
      ProfileTabKind.lists,
      ProfileTabKind.comments,
    ];
  }
  return const [
    ProfileTabKind.videos,
    ProfileTabKind.liked,
    ProfileTabKind.reposts,
    ProfileTabKind.collabs,
    ProfileTabKind.comments,
  ];
}
