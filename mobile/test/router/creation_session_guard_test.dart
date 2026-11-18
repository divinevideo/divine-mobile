// ABOUTME: Checks session protection against the actual generated video routes.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/creation_session_guard.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/library_routes.dart';
import 'package:openvine/router/routes/video_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hasCreationSessionInRouteStack', () {
    late GoRouter router;

    setUp(() {
      router = GoRouter(
        navigatorKey: NavigatorKeys.root,
        initialLocation: RoutePaths.libraryDrafts,
        routes: [...videoRoutes(), ...libraryRoutes()],
      );
    });

    tearDown(() => router.dispose());

    for (final location in [
      const VideoRecorderRouteData().location,
      const VideoEditorRouteData().location,
      const VideoEditorDraftRouteData(draftId: 'synthetic-draft').location,
      const VideoMetadataRouteData().location,
    ]) {
      test('protects the real creation route $location', () {
        final matches = router.configuration.findMatch(Uri.parse(location));
        expect(matches.isError, isFalse);
        expect(hasCreationSessionInRouteStack(matches), isTrue);
      });
    }

    test('does not confuse the standalone library with a creation session', () {
      final matches = router.configuration.findMatch(
        Uri.parse(const LibraryClipsRouteData().location),
      );
      expect(matches.isError, isFalse);
      expect(hasCreationSessionInRouteStack(matches), isFalse);
    });
  });
}
