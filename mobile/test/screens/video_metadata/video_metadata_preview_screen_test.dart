// ABOUTME: Tests for VideoMetadataPreviewScreen widget
// ABOUTME: Verifies rendering, DivineVideoPlayer integration, and layout

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_preview_screen.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/stop_motion/stop_motion_player.dart';
import 'package:openvine/widgets/video_feed_item/blurred_video_backdrop.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_clip_preview.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks/mock_nostr_service.dart';

class _MockVideoPublishNotifier extends VideoPublishNotifier {
  _MockVideoPublishNotifier(this._initialState);

  final VideoPublishProviderState _initialState;

  @override
  VideoPublishProviderState build() => _initialState;
}

/// Returns a default editor state so the post-mode overlay can render without
/// the real editor's dependency chain.
class _MockVideoEditorNotifier extends VideoEditorNotifier {
  @override
  VideoEditorProviderState build() => VideoEditorProviderState();
}

/// Reports a finished render so [VideoMetadataCaptureClipPreview] shows the
/// thumbnail rather than its processing overlay.
class _MockRenderedVideoEditorNotifier extends VideoEditorNotifier {
  _MockRenderedVideoEditorNotifier(this._clip);

  final DivineVideoClip _clip;

  @override
  VideoEditorProviderState build() =>
      VideoEditorProviderState(finalRenderedClip: _clip);
}

class _MockClipManagerNotifier extends ClipManagerNotifier {
  _MockClipManagerNotifier(this._clips);

  final List<DivineVideoClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

/// Supplies a stable public key so the post-mode overlay can resolve the author
/// pubkey without a real nostr session. [NostrClient.publicKey] is non-null, so
/// the base mock's `noSuchMethod` (which returns null) is not enough here.
class _FakeNostrClient extends MockNostrService {
  @override
  String get publicKey =>
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
}

DivineVideoClip _createTestClip({
  String id = 'test-clip',
  models.AspectRatio targetAspectRatio = models.AspectRatio.square,
  String? thumbnailPath,
  List<StopMotionClipFrame>? stopMotionFrames,
}) {
  return DivineVideoClip(
    id: id,
    video: stopMotionFrames == null ? EditorVideo.file('test.mp4') : null,
    duration: const Duration(seconds: 10),
    recordedAt: DateTime.now(),
    targetAspectRatio: targetAspectRatio,
    originalAspectRatio: 9 / 16,
    thumbnailPath: thumbnailPath,
    stopMotionFrames: stopMotionFrames,
  );
}

class _PlayerEventsStreamHandler extends MockStreamHandler {
  MockStreamHandlerEventSink? _events;

  void addState(Map<Object?, Object?> state) => _events?.success(state);

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    _events = events;
  }

  @override
  void onCancel(Object? arguments) {
    _events = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _PlayerEventsStreamHandler playerEvents;
  late List<Map<Object?, Object?>> setClipsArguments;

  final createdPlayerIds = <int>{};

  setUp(() async {
    createdPlayerIds.clear();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    playerEvents = _PlayerEventsStreamHandler();
    setClipsArguments = [];
    DivineVideoPlayerController.resetIdCounterForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('divine_video_player'), (
          call,
        ) async {
          if (call.method == 'create') {
            final args = call.arguments! as Map<Object?, Object?>;
            final id = args['id']! as int;
            createdPlayerIds.add(id);
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(
                  MethodChannel('divine_video_player/player_$id'),
                  (call) async {
                    if (call.method == 'setClips') {
                      setClipsArguments.add(
                        call.arguments! as Map<Object?, Object?>,
                      );
                    }
                    return null;
                  },
                );
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockStreamHandler(
                  EventChannel('divine_video_player/player_$id/events'),
                  playerEvents,
                );
            return <String, Object?>{'textureId': 1};
          }
          return null;
        });
  });

  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(
            const MethodChannel('divine_video_player'),
            null,
          );
    // Clear exactly what `create` installed. Clearing `player_0` alone stayed
    // matched only while every test created a single controller; a second one
    // would leave `player_1` installed for the rest of the isolate.
    for (final id in createdPlayerIds) {
      messenger
        ..setMockMethodCallHandler(
          MethodChannel('divine_video_player/player_$id'),
          null,
        )
        ..setMockStreamHandler(
          EventChannel('divine_video_player/player_$id/events'),
          null,
        );
    }
    createdPlayerIds.clear();
  });

  group(VideoMetadataPreviewScreen, () {
    testWidgets('preview overlay renders metadata without a VideoEvent', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoOverlayActions.preview(
                previewData: VideoOverlayPreviewData(
                  pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                  title: 'A title',
                  description: 'description with nostr:npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
                ),
                isVisible: true,
                isActive: true,
              ),
            ),
          ),
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text('A title'), findsOneWidget);
      expect(find.textContaining('description with'), findsOneWidget);
      expect(
        find.textContaining(
          l10n.videoFeedLoopCountLine(StringUtils.formatCompactNumber(0), 0),
        ),
        findsNothing,
      );
      expect(find.byType(VideoOverlayActions), findsOneWidget);
    });

    Widget buildTestWidget({DivineVideoClip? clip}) {
      // Use previewOnly to avoid deep Riverpod dependency chain from
      // the overlay's VideoOverlayActions widget. The overlay is unrelated
      // to the video_player → DivineVideoPlayer migration.
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          videoPublishProvider.overrideWith(
            () => _MockVideoPublishNotifier(const VideoPublishProviderState()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoMetadataPreviewScreen(
            clip: clip ?? _createTestClip(),
            previewOnly: true,
          ),
        ),
      );
    }

    test('can be instantiated', () {
      expect(
        VideoMetadataPreviewScreen(clip: _createTestClip()),
        isA<VideoMetadataPreviewScreen>(),
      );
    });

    testWidgets('renders $VideoMetadataPreviewScreen with scaffold', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      // Let the enclosing MaterialPageRoute finish its entrance animation.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(VideoMetadataPreviewScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders $DivineVideoPlayer widget', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DivineVideoPlayer), findsOneWidget);
    });

    testWidgets('matches the feed common-track-end loop boundary', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 400));

      final clips = setClipsArguments.single['clips']! as List<Object?>;
      final clip = clips.single! as Map<Object?, Object?>;
      expect(clip['trimToCommonTrackEnd'], isTrue);
    });

    testWidgets('cover-fits a non-square clip like the feed does', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          clip: _createTestClip(
            targetAspectRatio: models.AspectRatio.vertical,
            thumbnailPath: '/tmp/poster.jpg',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final fittedBox = tester.widget<FittedBox>(
        find
            .ancestor(
              of: find.byType(DivineVideoPlayer),
              matching: find.byType(FittedBox),
            )
            .first,
      );
      expect(fittedBox.fit, equals(BoxFit.cover));
      // A cover-fit video occludes the backdrop, so the feed never mounts it.
      expect(find.byType(BlurredVideoBackdrop), findsNothing);
    });

    testWidgets('sizes the fitted video from decoded source dimensions', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          clip: _createTestClip(thumbnailPath: '/tmp/poster.jpg'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      playerEvents.addState(<Object?, Object?>{
        'status': 'playing',
        'positionMs': 0,
        'durationMs': 1000,
        'bufferedPositionMs': 1000,
        'currentClipIndex': 0,
        'clipCount': 1,
        'isLooping': true,
        'volume': 1.0,
        'playbackSpeed': 1.0,
        'isFirstFrameRendered': true,
        'videoWidth': 1080,
        'videoHeight': 1920,
      });
      await tester.pump();
      await tester.pump();

      final surfaceBox = tester.widget<SizedBox>(
        find
            .ancestor(
              of: find.byType(DivineVideoPlayer),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(surfaceBox.width, equals(56.25));
      expect(surfaceBox.height, equals(100));
    });

    testWidgets('letterboxes a square clip on the blurred poster backdrop', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          clip: _createTestClip(thumbnailPath: '/tmp/poster.jpg'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final fittedBox = tester.widget<FittedBox>(
        find
            .ancestor(
              of: find.byType(DivineVideoPlayer),
              matching: find.byType(FittedBox),
            )
            .first,
      );
      expect(fittedBox.fit, equals(BoxFit.contain));
      final backdrop = tester.widget<BlurredVideoBackdrop>(
        find.byType(BlurredVideoBackdrop),
      );
      expect(backdrop.filePath, equals('/tmp/poster.jpg'));
      expect(backdrop.videoAspectRatio, equals(1.0));
    });

    testWidgets('renders close button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DivineIconButton), findsOneWidget);
    });

    testWidgets('stays edge to edge in preview-only mode', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 400));

      // The rounded bottom corners seam into the post bar; without a post
      // bar there is nothing to seam into, so the preview fills the screen.
      final rounded = tester.widgetList<ClipRRect>(find.byType(ClipRRect));
      expect(
        rounded.any(
          (clip) =>
              clip.borderRadius ==
              const BorderRadius.vertical(
                bottom: Radius.circular(VineTheme.shellCornerRadius),
              ),
        ),
        isFalse,
      );
    });

    testWidgets('rounds the bottom corners in the post flow', (tester) async {
      // The post flow (previewOnly: false, the default) mounts the metadata
      // overlay, so its editor/nostr dependencies are stubbed here. The stage
      // seams into the post bar with rounded bottom corners.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            videoPublishProvider.overrideWith(
              () =>
                  _MockVideoPublishNotifier(const VideoPublishProviderState()),
            ),
            videoEditorProvider.overrideWith(_MockVideoEditorNotifier.new),
            nostrServiceProvider.overrideWithValue(_FakeNostrClient()),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: VideoMetadataPreviewScreen(clip: _createTestClip()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final rounded = tester.widgetList<ClipRRect>(find.byType(ClipRRect));
      expect(
        rounded.any(
          (clip) =>
              clip.borderRadius ==
              const BorderRadius.vertical(
                bottom: Radius.circular(VineTheme.shellCornerRadius),
              ),
        ),
        isTrue,
      );
    });

    testWidgets(
      'activates the overlay only when its route animation completes',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              videoPublishProvider.overrideWith(
                () => _MockVideoPublishNotifier(
                  const VideoPublishProviderState(),
                ),
              ),
              videoEditorProvider.overrideWith(_MockVideoEditorNotifier.new),
              nostrServiceProvider.overrideWithValue(_FakeNostrClient()),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      PageRouteBuilder<void>(
                        transitionDuration: const Duration(seconds: 1),
                        pageBuilder: (_, _, _) =>
                            VideoMetadataPreviewScreen(clip: _createTestClip()),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final route = ModalRoute.of(
          tester.element(find.byType(VideoMetadataPreviewScreen)),
        )!;
        expect(route.animation!.status, isNot(AnimationStatus.completed));
        expect(route.animation!.value, lessThan(1));
        expect(
          tester
              .widget<VideoOverlayActions>(find.byType(VideoOverlayActions))
              .isActive,
          isFalse,
          reason:
              'elapsed time alone must not reveal the overlay mid-transition',
        );

        await tester.pumpAndSettle();

        expect(route.animation!.status, AnimationStatus.completed);
        expect(
          tester
              .widget<VideoOverlayActions>(find.byType(VideoOverlayActions))
              .isActive,
          isTrue,
        );
      },
    );

    testWidgets('morphs the hero flight corners in both directions', (
      tester,
    ) async {
      // The flying hero is lifted into the navigator overlay, above the stage's
      // clip, so without its own rounding the preview arrived square-bottomed
      // and only snapped into shape once the flight landed.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            videoPublishProvider.overrideWith(
              () =>
                  _MockVideoPublishNotifier(const VideoPublishProviderState()),
            ),
            videoEditorProvider.overrideWith(_MockVideoEditorNotifier.new),
            nostrServiceProvider.overrideWithValue(_FakeNostrClient()),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: SizedBox.square(
                    dimension: 200,
                    // Clip outside the Hero, the way both real thumbnails do:
                    // inside, it rides into the shuttle and pins the corners.
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        VideoEditorConstants.clipPreviewCornerRadius,
                      ),
                      child: Hero(
                        tag: VideoEditorConstants.heroMetaPreviewId,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            PageRouteBuilder<void>(
                              pageBuilder: (_, _, _) =>
                                  VideoMetadataPreviewScreen(
                                    clip: _createTestClip(),
                                  ),
                            ),
                          ),
                          child: const Text('open'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // The shuttle is the only clip caught mid-lerp: strictly inside both
      // endpoints on both corners. The stage's own clip sits exactly on them.
      final shuttleClip = find.byWidgetPredicate((widget) {
        if (widget is! ClipRRect) return false;
        final radius = widget.borderRadius;
        return radius is BorderRadius &&
            radius.topLeft.x > 0 &&
            radius.topLeft.x < VideoEditorConstants.clipPreviewCornerRadius &&
            radius.bottomLeft.x >
                VideoEditorConstants.clipPreviewCornerRadius &&
            radius.bottomLeft.x < VineTheme.shellCornerRadius;
      });
      BorderRadius shuttleRadius() =>
          tester.widget<ClipRRect>(shuttleClip).borderRadius as BorderRadius;

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // Mid-flight the shuttle sits between the thumbnail's all-round corners
      // and the stage's bottom-only rounding.
      expect(shuttleClip, findsOneWidget);
      final early = shuttleRadius();

      await tester.pump(const Duration(milliseconds: 130));
      final mid = shuttleRadius();

      // It morphs from the thumbnail's shape towards the stage's, so the top
      // opens out as the bottom tightens. A single sample cannot tell that
      // from a lerp running backwards, or from one pinned to a constant --
      // both leave the preview in the wrong shape, which is the bug here.
      expect(mid.topLeft.x, lessThan(early.topLeft.x));
      expect(mid.bottomLeft.x, greaterThan(early.bottomLeft.x));

      await tester.pumpAndSettle();

      // Coming back, the shuttle carries the destination thumbnail -- so a
      // rounding that lives inside that Hero rides along and pins the top
      // corners at 16 for the whole flight, whatever the lerp is doing.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(shuttleClip, findsOneWidget);
      expect(
        find.descendant(
          of: shuttleClip,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ClipRRect &&
                widget.borderRadius ==
                    BorderRadius.circular(
                      VideoEditorConstants.clipPreviewCornerRadius,
                    ),
          ),
        ),
        findsNothing,
      );

      // Settle the flight and the route-driven overlay readiness listener.
      await tester.pumpAndSettle();
    });

    testWidgets('the real capture thumbnail rounds itself outside its Hero', (
      tester,
    ) async {
      // The test above flies from a Hero this file builds, so it pins the
      // flight but not the shape the app actually hands it. Fly from the real
      // thumbnail instead: on a pop the shuttle renders the destination Hero's
      // child, so a rounding inside that Hero rides along and pins the corners
      // the flight is morphing.
      final clip = _createTestClip(thumbnailPath: 'test_thumbnail.jpg');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            videoPublishProvider.overrideWith(
              () =>
                  _MockVideoPublishNotifier(const VideoPublishProviderState()),
            ),
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([clip]),
            ),
            videoEditorProvider.overrideWith(
              () => _MockRenderedVideoEditorNotifier(clip),
            ),
            nostrServiceProvider.overrideWithValue(_FakeNostrClient()),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    const Expanded(child: VideoMetadataCaptureClipPreview()),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        PageRouteBuilder<void>(
                          pageBuilder: (_, _, _) =>
                              VideoMetadataPreviewScreen(clip: clip),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final shuttleClip = find.byWidgetPredicate((widget) {
        if (widget is! ClipRRect) return false;
        final radius = widget.borderRadius;
        return radius is BorderRadius &&
            radius.topLeft.x > 0 &&
            radius.topLeft.x < VideoEditorConstants.clipPreviewCornerRadius &&
            radius.bottomLeft.x >
                VideoEditorConstants.clipPreviewCornerRadius &&
            radius.bottomLeft.x < VineTheme.shellCornerRadius;
      });
      expect(shuttleClip, findsOneWidget);
      expect(
        find.descendant(
          of: shuttleClip,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ClipRRect &&
                widget.borderRadius ==
                    BorderRadius.circular(
                      VideoEditorConstants.clipPreviewCornerRadius,
                    ),
          ),
        ),
        findsNothing,
      );

      await tester.pumpAndSettle();
    });

    testWidgets('constrains square stop-motion clips to the target box', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          clip: _createTestClip(
            stopMotionFrames: const <StopMotionClipFrame>[],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(StopMotionPlayer), findsOneWidget);
      final targetBox = tester.widget<AspectRatio>(
        find
            .ancestor(
              of: find.byType(StopMotionPlayer),
              matching: find.byType(AspectRatio),
            )
            .first,
      );
      expect(targetBox.aspectRatio, equals(1.0));
      expect(
        find.ancestor(
          of: find.byType(StopMotionPlayer),
          matching: find.byType(Center),
        ),
        findsOneWidget,
      );
    });

    testWidgets('cover-fills vertical stop-motion clips edge to edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          clip: _createTestClip(
            targetAspectRatio: models.AspectRatio.vertical,
            stopMotionFrames: const <StopMotionClipFrame>[],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(StopMotionPlayer), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(StopMotionPlayer),
          matching: find.byType(AspectRatio),
        ),
        findsNothing,
      );
      expect(find.byType(BlurredVideoBackdrop), findsNothing);
    });

    testWidgets('hides bottom bar and overlay in preview-only mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 400));

      // Post button and overlay should not be present in previewOnly mode
      expect(find.text('Post'), findsNothing);
    });
  });
}
