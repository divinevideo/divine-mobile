// ABOUTME: Verifies the standalone sound upload route sits under the Library's
// ABOUTME: sounds route and does not shadow the sound detail route.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/sound_upload/sound_upload_screen.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  group('sound upload route', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: getStandardTestOverrides());
      addTearDown(container.dispose);
    });

    test('resolves as a child of the sounds library route', () {
      final router = container.read(goRouterProvider);

      final match = router.configuration.findMatch(
        Uri.parse(SoundUploadScreen.path),
      );

      expect(match.isError, isFalse);
      expect(match.matches.map((m) => (m.route as GoRoute).path), [
        LibraryScreen.soundsPath,
        SoundUploadScreen.subpath,
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
        Uri.parse(RoutePaths.soundDetailForId('upload')),
      );
      expect(detail.isError, isFalse);
      expect(detail.pathParameters['id'], 'upload');
    });
  });
}
