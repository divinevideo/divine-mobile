// ABOUTME: Verifies the Add sound route sits under the Library's sounds route
// ABOUTME: and does not shadow the sound detail route.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/sounds/add_sound_page.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  group('add sound route', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: getStandardTestOverrides());
      addTearDown(container.dispose);
    });

    test('resolves as a child of the sounds library route', () {
      final router = container.read(goRouterProvider);

      final match = router.configuration.findMatch(
        Uri.parse(AddSoundPage.path),
      );

      expect(match.isError, isFalse);
      expect(match.matches.map((m) => (m.route as GoRoute).path), [
        LibraryScreen.soundsPath,
        AddSoundPage.subpath,
      ]);
    });

    test('keeps the sounds tab and sound detail routes distinct', () {
      final router = container.read(goRouterProvider);

      expect(
        router.configuration
            .findMatch(Uri.parse(RoutePaths.librarySounds))
            .isError,
        isFalse,
      );
      final detail = router.configuration.findMatch(
        Uri.parse(RoutePaths.soundDetailForId('add')),
      );
      expect(detail.isError, isFalse);
      expect(detail.pathParameters['id'], 'add');
    });
  });
}
