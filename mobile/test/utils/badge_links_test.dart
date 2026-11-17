import 'package:badge_repository/badge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/badges/badge_award_screen.dart';
import 'package:openvine/screens/badges/badge_detail_screen.dart';
import 'package:openvine/screens/badges/badge_editor_screen.dart';
import 'package:openvine/screens/badges/badge_videos_screen.dart';
import 'package:openvine/utils/badge_links.dart';

void main() {
  final issuer = '2'.padLeft(64, '0');
  for (final identifier in [
    'a' * 255,
    'a' * 256,
    '界' * 85,
    '界' * 86,
    '${'a' * 256}:/?# ',
  ]) {
    test('sharing preserves the full ${identifier.length}-character badge', () {
      final coordinate = BadgeCoordinate(
        pubkey: issuer,
        identifier: identifier,
      );
      final shared = badgeShareReference(coordinate);
      if (identifier == 'a' * 255 || identifier == '界' * 85) {
        final uri = Uri.parse(shared);
        expect(uri.host, 'badges.divine.video');
        expect(
          BadgeCoordinate.fromNaddr(uri.pathSegments.last)?.identifier,
          identifier,
        );
      } else {
        expect(shared, '30009:$issuer:$identifier');
      }
    });
    for (final entry in <String, String Function(BadgeCoordinate)>{
      'detail': BadgeDetailScreen.pathFor,
      'videos': BadgeVideosScreen.pathFor,
      'edit': BadgeEditorScreen.editPathFor,
      'award': BadgeAwardScreen.pathFor,
    }.entries) {
      test(
        '${entry.key} preserves the full ${identifier.length}-character coordinate',
        () {
          final coordinate = BadgeCoordinate(
            pubkey: issuer,
            identifier: identifier,
          );
          final route = Uri.parse(entry.value(coordinate));
          final decoded = BadgeCoordinate.tryParse(route.pathSegments[2]);
          expect(decoded?.identifier, identifier);
          expect(decoded?.pubkey, issuer);
        },
      );
    }
  }
}
