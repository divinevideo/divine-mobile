// ABOUTME: Tests for the video routes' recorder builder and engagement paths.
// ABOUTME: Pins recorder query parsing and the flat engagement registration.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/screens/video_recorder_screen.dart';

class _FakeBuildContext extends Fake implements BuildContext {}

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState(this.uri);

  @override
  final Uri uri;

  @override
  ValueKey<String> get pageKey => const ValueKey('video-recorder');

  @override
  String? get name => VideoRecorderScreen.routeName;

  @override
  String? get path => VideoRecorderScreen.path;

  @override
  GoRoute? get topRoute => null;

  @override
  String? get fullPath => null;

  @override
  Map<String, String> get pathParameters => const {};
}

/// Runs the recorder route's page builder for [location] and returns the
/// widget it mounts, without building it.
VideoRecorderRoute _recorderRouteFor(String location) {
  final route = videoRoutes().whereType<GoRoute>().firstWhere(
    (route) => route.path == VideoRecorderScreen.path,
  );
  final page = route.pageBuilder!(
    _FakeBuildContext(),
    _FakeGoRouterState(Uri.parse(location)),
  );
  return (page as CustomTransitionPage<void>).child as VideoRecorderRoute;
}

void main() {
  group('videoRoutes recorder route', () {
    test('a bare location opens directly, without auto-record', () {
      final recorder = _recorderRouteFor(VideoRecorderScreen.path);

      expect(recorder.entryPoint, CreationEntryPoint.direct);
      expect(recorder.autoRecord, isFalse);
    });

    test('reads the entry point from the query', () {
      final recorder = _recorderRouteFor(
        VideoRecorderScreen.pathForEntryPoint(CreationEntryPoint.bottomNav),
      );

      expect(recorder.entryPoint, CreationEntryPoint.bottomNav);
      expect(recorder.autoRecord, isFalse);
    });

    test('reads the auto-record flag from the query', () {
      final recorder = _recorderRouteFor(
        VideoRecorderScreen.pathForEntryPoint(
          CreationEntryPoint.bottomNav,
          autoRecord: true,
        ),
      );

      expect(recorder.entryPoint, CreationEntryPoint.bottomNav);
      expect(recorder.autoRecord, isTrue);
    });
  });

  group('videoRoutes engagement routes', () {
    // videoRoutes() is spread straight into GoRouter.routes, so entering
    // either of these cold leaves a one-entry stack — the reason
    // VideoEngagementListView's back arrow needs safePop (#9359). The
    // behavioural test for that builds its own router, so this is the only
    // check bound to the real table.
    for (final path in const [
      '/video/:eventId/likers',
      '/video/:eventId/reposters',
    ]) {
      test('$path is registered flat and top-level', () {
        final matches = videoRoutes().whereType<GoRoute>().where(
          (route) => route.path == path,
        );

        expect(
          matches,
          hasLength(1),
          reason:
              'Expected exactly one top-level GoRoute at $path. Nesting it '
              'under another route makes canPop() true on cold entry, which '
              'retires the safePop fallback in VideoEngagementListView; '
              'renaming it strands the location hardcoded by '
              'video_engagement_list_screen_test.dart. Either way, revisit '
              'that test before updating this one.',
        );
      });
    }
  });
}
