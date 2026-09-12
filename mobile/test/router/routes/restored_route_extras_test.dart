import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/router/routes/profile_routes.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/router/widgets/other_profile_screen_router.dart';
import 'package:openvine/router/widgets/sound_detail_loader.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/screens/subtitle_editor/subtitle_editor_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState({
    required this.pathParameters,
    this.extra,
    String location = '/',
  }) : uri = Uri.parse(location),
       matchedLocation = location,
       fullPath = location,
       pageKey = ValueKey<String>(location);

  @override
  final Object? extra;

  @override
  final String? fullPath;

  @override
  final String matchedLocation;

  @override
  final Map<String, String> pathParameters;

  @override
  final ValueKey<String> pageKey;

  @override
  final Uri uri;
}

void main() {
  group('restored route extras', () {
    testWidgets('profile route accepts restored object maps', (tester) async {
      final route = _routeNamed(profileRoutes(), OtherProfileScreen.routeName);
      late OtherProfileScreenRouter screen;

      await _buildWithContext(tester, (context) {
        screen = route.builder!(
          context,
          _FakeGoRouterState(
            location: '/profile/npub1test',
            pathParameters: const {'npub': 'npub1test'},
            extra: const <Object?, Object?>{
              'displayName': 'Ada',
              'avatarUrl': 42,
            },
          ),
        ) as OtherProfileScreenRouter;
      });

      expect(screen.npub, 'npub1test');
      expect(screen.displayNameHint, 'Ada');
      expect(screen.avatarUrlHint, isNull);
    });

    testWidgets('sound route accepts restored object maps', (tester) async {
      final sound = AudioEvent(
        id: 'sound-1',
        pubkey: 'pubkey',
        createdAt: 1700000000,
      );
      final route = _routeNamed(videoRoutes(), SoundDetailScreen.routeName);
      late SoundDetailScreen screen;

      await _buildWithContext(tester, (context) {
        screen = route.builder!(
          context,
          _FakeGoRouterState(
            location: '/sound/sound-1',
            pathParameters: const {'id': 'sound-1'},
            extra: <Object?, Object?>{'sound': sound},
          ),
        ) as SoundDetailScreen;
      });

      expect(screen.sound, same(sound));
    });

    testWidgets('sound route falls back when extra is missing or decoded', (
      tester,
    ) async {
      final route = _routeNamed(videoRoutes(), SoundDetailScreen.routeName);
      late Widget missingExtra;
      late Widget decodedExtra;

      await _buildWithContext(tester, (context) {
        missingExtra = route.builder!(
          context,
          _FakeGoRouterState(
            location: '/sound/sound-1',
            pathParameters: const {'id': 'sound-1'},
          ),
        );
        decodedExtra = route.builder!(
          context,
          _FakeGoRouterState(
            location: '/sound/sound-1',
            pathParameters: const {'id': 'sound-1'},
            extra: const <Object?, Object?>{
              'sound': <Object?, Object?>{'id': 'sound-1'},
            },
          ),
        );
      });

      expect(missingExtra, isA<SoundDetailLoader>());
      expect(decodedExtra, isA<SoundDetailLoader>());
    });

    testWidgets('video editor routes read the origin from the URL, not extra', (
      tester,
    ) async {
      final routes = videoRoutes();
      final editorRoute = _routeNamed(routes, VideoEditorScreen.routeName);
      final draftRoute = _routeNamed(routes, VideoEditorScreen.draftRouteName);
      late VideoEditorScreen fromLibrary;
      late VideoEditorScreen fromRecorder;
      late VideoEditorScreen legacyExtra;
      late VideoEditorScreen draft;

      await _buildWithContext(tester, (context) {
        fromLibrary = editorRoute.builder!(
          context,
          _FakeGoRouterState(
            location: VideoEditorScreen.pathFor(fromLibrary: true),
            pathParameters: const {},
          ),
        ) as VideoEditorScreen;
        fromRecorder = editorRoute.builder!(
          context,
          _FakeGoRouterState(
            location: VideoEditorScreen.pathFor(),
            pathParameters: const {},
          ),
        ) as VideoEditorScreen;
        // The map extra this route used to read is no longer consulted, so a
        // restored session cannot resurrect a half-migrated origin (#3335).
        legacyExtra = editorRoute.builder!(
          context,
          _FakeGoRouterState(
            location: VideoEditorScreen.path,
            pathParameters: const {},
            extra: const <Object?, Object?>{'fromLibrary': true},
          ),
        ) as VideoEditorScreen;
        draft = draftRoute.builder!(
          context,
          _FakeGoRouterState(
            location: VideoEditorScreen.pathFor(
              draftId: 'draft-1',
              fromLibrary: true,
            ),
            pathParameters: const {'draftId': 'draft-1'},
          ),
        ) as VideoEditorScreen;
      });

      expect(fromLibrary.fromLibrary, isTrue);
      expect(fromRecorder.fromLibrary, isFalse);
      expect(legacyExtra.fromLibrary, isFalse);
      expect(draft.draftId, 'draft-1');
      expect(draft.fromLibrary, isTrue);
    });

    test('video editor locations round-trip the origin through the URL', () {
      expect(VideoEditorScreen.pathFor(), VideoEditorScreen.path);
      expect(
        VideoEditorScreen.pathFor(fromLibrary: true),
        '${VideoEditorScreen.path}?from=library',
      );
      expect(
        VideoEditorScreen.pathFor(draftId: 'draft-1', fromLibrary: true),
        '${VideoEditorScreen.path}/draft-1?from=library',
      );
      expect(
        VideoEditorScreen.fromLibraryForRoute(
          Uri.parse(VideoEditorScreen.pathFor(fromLibrary: true)),
        ),
        isTrue,
      );
    });

    testWidgets('video metadata route restores draft recorder modes', (
      tester,
    ) async {
      final route = _routeNamed(videoRoutes(), VideoMetadataScreen.routeName);
      late VideoMetadataScreen capture;
      late VideoMetadataScreen stopMotion;
      late VideoMetadataScreen unsupported;

      await _buildWithContext(tester, (context) {
        capture = route.builder!(
          context,
          _FakeGoRouterState(
            location: VideoMetadataScreen.pathForDraft(
              isStopMotion: false,
            ),
            pathParameters: const {},
          ),
        ) as VideoMetadataScreen;
        stopMotion = route.builder!(
          context,
          _FakeGoRouterState(
            location: VideoMetadataScreen.pathForDraft(
              isStopMotion: true,
            ),
            pathParameters: const {},
          ),
        ) as VideoMetadataScreen;
        unsupported = route.builder!(
          context,
          _FakeGoRouterState(
            location: '${VideoMetadataScreen.path}?mode=upload',
            pathParameters: const {},
          ),
        ) as VideoMetadataScreen;
      });

      expect(capture.draftMode, VideoRecorderMode.capture);
      expect(stopMotion.draftMode, VideoRecorderMode.stopMotion);
      expect(unsupported.draftMode, isNull);
    });

    testWidgets('video edit routes tolerate decoded maps and no extra', (
      tester,
    ) async {
      final routes = videoRoutes();
      final metadataRoute = _routeNamed(
        routes,
        VideoMetadataEditScreen.routeName,
      );
      final subtitleRoute = _routeNamed(routes, SubtitleEditorScreen.routeName);
      late VideoMetadataEditScreen metadata;
      late SubtitleEditorScreen subtitle;
      late VideoMetadataEditScreen metadataNoExtra;
      late SubtitleEditorScreen subtitleNoExtra;

      await _buildWithContext(tester, (context) {
        metadata = metadataRoute.builder!(
          context,
          _FakeGoRouterState(
            location: '/video-edit/video-1',
            pathParameters: const {'videoId': 'video-1'},
            extra: const <Object?, Object?>{'id': 'video-1'},
          ),
        ) as VideoMetadataEditScreen;
        subtitle = subtitleRoute.builder!(
          context,
          _FakeGoRouterState(
            location: '/subtitle-edit/video-1',
            pathParameters: const {'videoId': 'video-1'},
            extra: const <Object?, Object?>{'id': 'video-1'},
          ),
        ) as SubtitleEditorScreen;
        metadataNoExtra = metadataRoute.builder!(
          context,
          _FakeGoRouterState(
            location: '/video-edit/video-1',
            pathParameters: const {'videoId': 'video-1'},
          ),
        ) as VideoMetadataEditScreen;
        subtitleNoExtra = subtitleRoute.builder!(
          context,
          _FakeGoRouterState(
            location: '/subtitle-edit/video-1',
            pathParameters: const {'videoId': 'video-1'},
          ),
        ) as SubtitleEditorScreen;
      });

      expect(metadata.videoId, 'video-1');
      expect(metadata.prefetched, isNull);
      expect(subtitle.videoId, 'video-1');
      expect(subtitle.prefetched, isNull);
      expect(metadataNoExtra.prefetched, isNull);
      expect(subtitleNoExtra.prefetched, isNull);
    });
  });
}

Future<void> _buildWithContext(
  WidgetTester tester,
  void Function(BuildContext context) body,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          body(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}

GoRoute _routeNamed(List<RouteBase> routes, String name) {
  return routes.whereType<GoRoute>().singleWhere((route) => route.name == name);
}
