import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/profile/profile_tab_kind.dart';

void main() {
  group('profileTabKinds', () {
    test('own profile orders Bookmarks between Reposts and Lists', () {
      expect(
        profileTabKinds(isOwnProfile: true),
        equals(const [
          ProfileTabKind.videos,
          ProfileTabKind.collabs,
          ProfileTabKind.liked,
          ProfileTabKind.reposts,
          ProfileTabKind.bookmarks,
          ProfileTabKind.lists,
          ProfileTabKind.comments,
        ]),
      );
    });

    test('own profile surfaces a Collabs tab (the #5213 fix)', () {
      final kinds = profileTabKinds(isOwnProfile: true);
      expect(kinds, contains(ProfileTabKind.collabs));
      expect(kinds.indexOf(ProfileTabKind.collabs), equals(1));
    });

    test('own profile exposes both owned tabs, Bookmarks and Lists', () {
      expect(
        profileTabKinds(isOwnProfile: true),
        containsAll(const [ProfileTabKind.bookmarks, ProfileTabKind.lists]),
      );
    });

    test('other profile order is unchanged (Collabs in the 4th slot)', () {
      expect(
        profileTabKinds(isOwnProfile: false),
        equals(const [
          ProfileTabKind.videos,
          ProfileTabKind.liked,
          ProfileTabKind.reposts,
          ProfileTabKind.collabs,
          ProfileTabKind.comments,
        ]),
      );
    });

    test('other profile keeps Collabs at index 3 and has no owned tab', () {
      final kinds = profileTabKinds(isOwnProfile: false);
      expect(kinds.indexOf(ProfileTabKind.collabs), equals(3));
      expect(kinds, isNot(contains(ProfileTabKind.lists)));
      // Bookmarks are private: someone else's are not ours to browse.
      expect(kinds, isNot(contains(ProfileTabKind.bookmarks)));
    });

    test('own profile has 7 tabs, other profile has 5', () {
      expect(profileTabKinds(isOwnProfile: true), hasLength(7));
      expect(profileTabKinds(isOwnProfile: false), hasLength(5));
    });
  });
}
