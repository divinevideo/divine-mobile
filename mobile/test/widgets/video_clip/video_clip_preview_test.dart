// ABOUTME: Tests for VideoClipPreview widget
// ABOUTME: Verifies rendering, DivineVideoPlayer integration, and button layout

import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/widgets/stop_motion/stop_motion_player.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';
import 'package:openvine/widgets/video_clip/video_clip_hero.dart';
import 'package:openvine/widgets/video_clip/video_clip_preview.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../helpers/divine_video_player_channel.dart';
import '../../helpers/go_router.dart';

class _MockGallerySaveService extends Mock implements GallerySaveService {}

/// Reports a decoded first frame as soon as the controller subscribes, which
/// is what drops [DivineVideoPlayer]'s placeholder from the tree.
class _FirstFrameStreamHandler extends MockStreamHandler {
  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    events.success(<Object?, Object?>{
      'status': 'playing',
      'positionMs': 0,
      'durationMs': 1000,
      'bufferedPositionMs': 500,
      'currentClipIndex': 0,
      'clipCount': 1,
      'isLooping': true,
      'volume': 1.0,
      'playbackSpeed': 1.0,
      'isFirstFrameRendered': true,
      'videoWidth': 1080,
      'videoHeight': 1920,
    });
  }

  @override
  void onCancel(Object? arguments) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGoRouter mockGoRouter;
  late _MockGallerySaveService mockGallerySaveService;

  setUpAll(() {
    registerFallbackValue(EditorVideo.file('/fallback.mp4'));
  });

  setUp(() {
    mockGallerySaveService = _MockGallerySaveService();
    DivineVideoPlayerController.resetIdCounterForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('divine_video_player'), (
          call,
        ) async {
          if (call.method == 'create') {
            return <String, Object?>{'textureId': 1};
          }
          return null;
        });

    mockGoRouter = MockGoRouter();
    when(() => mockGoRouter.pop<Object?>(any())).thenReturn(null);
    when(() => mockGoRouter.canPop()).thenReturn(true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          null,
        );
  });

  group(VideoClipPreview, () {
    final testClip = DivineVideoClip(
      id: 'test-clip-1',
      video: EditorVideo.file('/path/to/video.mp4'),
      libraryTitle: 'Rooftop loop',
      duration: const Duration(seconds: 5),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
    );

    Widget buildTestWidget({
      DivineVideoClip? clip,
      VoidCallback? onDelete,
      Widget? home,
    }) {
      return ProviderScope(
        overrides: [
          gallerySaveServiceProvider.overrideWithValue(mockGallerySaveService),
        ],
        child: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home:
                home ??
                Scaffold(
                  body: VideoClipPreview(
                    clip: clip ?? testClip,
                    onDelete: onDelete,
                  ),
                ),
          ),
        ),
      );
    }

    test('can be instantiated', () {
      expect(VideoClipPreview(clip: testClip), isA<VideoClipPreview>());
    });

    test('accepts onDelete callback', () {
      expect(
        VideoClipPreview(clip: testClip, onDelete: () {}),
        isA<VideoClipPreview>(),
      );
    });

    testWidgets('exposes an action to close the video preview', (tester) async {
      installMockDivineVideoPlayer();

      await tester.pumpWidget(buildTestWidget());
      final l10n = lookupAppLocalizations(const Locale('en'));
      final semantics = tester.getSemantics(find.byType(VideoClipPreview));

      expect(semantics.label, l10n.videoMetadataClosePreviewSemanticLabel);
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(
        find.bySemanticsLabel(
          l10n.videoClipSaveTo(GallerySaveService.destinationName),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders $DivineVideoPlayer and save button', (tester) async {
      installMockDivineVideoPlayer();

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DivineVideoPlayer), findsOneWidget);
      expect(find.text('Rooftop loop'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.downloadSimple,
        ),
        findsOneWidget,
      );
    });

    /// Loads [clip] into the sheet and returns the single serialized clip the
    /// controller sent over `setClips`.
    Future<Map<Object?, Object?>> pumpAndCaptureSetClips(
      WidgetTester tester,
      DivineVideoClip Function(String videoPath) clip,
    ) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'clip_preview_track_end',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final videoFile = File('${tempDir.path}/video.mp4')
        ..writeAsBytesSync(const [0]);
      Map<Object?, Object?>? setClipsArguments;
      installMockDivineVideoPlayer(
        onMethodCall: (call) async {
          if (call.method == 'setClips') {
            setClipsArguments = call.arguments! as Map<Object?, Object?>;
          }
          return null;
        },
      );

      await tester.pumpWidget(buildTestWidget(clip: clip(videoFile.path)));
      await tester.pump(const Duration(milliseconds: 100));

      final clips = setClipsArguments!['clips']! as List<Object?>;
      return clips.single! as Map<Object?, Object?>;
    }

    testWidgets('loops the span the editor and the export play', (
      tester,
    ) async {
      final clip = await pumpAndCaptureSetClips(
        tester,
        (path) => testClip.copyWith(
          video: EditorVideo.file(path),
          trimStart: const Duration(milliseconds: 400),
          trimEnd: const Duration(milliseconds: 750),
          volume: 0.5,
          playbackSpeed: 2,
        ),
      );

      // `duration - trimEnd`, the boundary video_clip_chroma_key_screen and
      // video_clip_transform_screen pass for the same clip.
      expect(clip['startMs'], 400);
      expect(clip['endMs'], 4250);
      expect(clip['volume'], 0.5);
      expect(clip['playbackSpeed'], 2.0);
    });

    testWidgets('does not ask the player to re-derive the track end', (
      tester,
    ) async {
      final clip = await pumpAndCaptureSetClips(
        tester,
        (path) => testClip.copyWith(video: EditorVideo.file(path)),
      );

      // The recorded clip's own `commonTrackEnd` is already in `endMs`. A
      // second, stricter native rule on top could only disagree with it.
      expect(clip['endMs'], 5000);
      expect(clip['trimToCommonTrackEnd'], isNull);
    });

    testWidgets('renders delete button when onDelete is provided', (
      tester,
    ) async {
      installMockDivineVideoPlayer();

      await tester.pumpWidget(buildTestWidget(onDelete: () {}));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.trash,
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides delete button when onDelete is null', (tester) async {
      installMockDivineVideoPlayer();

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.trash,
        ),
        findsNothing,
      );
    });

    testWidgets('renders placeholder with progress indicator', (tester) async {
      installMockDivineVideoPlayer();

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('keeps the hero mounted once the video replaces the '
        'placeholder', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('clip_preview_hero');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final videoFile = File('${tempDir.path}/video.mp4')
        ..writeAsBytesSync(const [0]);
      final thumbnailFile = File('${tempDir.path}/thumbnail.jpg')
        ..writeAsBytesSync(_transparentPngBytes);

      installMockDivineVideoPlayer(
        streamHandler: _FirstFrameStreamHandler(),
      );

      final clip = testClip.copyWith(
        video: EditorVideo.file(videoFile.path),
        thumbnailPath: thumbnailFile.path,
      );

      await tester.pumpWidget(buildTestWidget(clip: clip));
      // pumpAndSettle cannot be used here because the pre-fix placeholder owns
      // a CircularProgressIndicator that never settles.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The placeholder — which used to own the hero — is gone once the first
      // frame is up, so a hero living inside it would be unmounted here and
      // the dismiss animation would have nothing to fly back from.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Hero && w.tag == videoClipPreviewHeroTag(clip.id),
        ),
        findsOneWidget,
      );
    });

    testWidgets('builds a decorative thumbnail shuttle for stop-motion clips', (
      tester,
    ) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'clip_preview_stop_motion_hero',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final frameFile = File('${tempDir.path}/frame.png')
        ..writeAsBytesSync(_transparentPngBytes);

      final clip = _stopMotionClip(
        id: 'stop-motion-clip-1',
        framePath: frameFile.path,
        thumbnailPath: frameFile.path,
      );

      await tester.pumpWidget(buildTestWidget(clip: clip));

      expect(find.byType(StopMotionPlayer), findsOneWidget);

      final heroFinder = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == videoClipPreviewHeroTag(clip.id),
      );
      final hero = tester.widget<Hero>(heroFinder);
      final shuttle = hero.flightShuttleBuilder!(
        tester.element(find.byType(VideoClipPreview)),
        const AlwaysStoppedAnimation<double>(0),
        HeroFlightDirection.push,
        tester.element(heroFinder),
        tester.element(heroFinder),
      );

      // Nothing in a flight is worth announcing, and the exclusion has to sit
      // outside the image: `Image` returns its `errorBuilder` before applying
      // `excludeFromSemantics`, so the fallback icon would announce itself.
      final excluded = shuttle as ExcludeSemantics;
      final thumbnail = excluded.child! as ClipThumbnailImage;
      expect(thumbnail.path, frameFile.path);
      expect(thumbnail.fit, BoxFit.cover);
      expect(thumbnail.excludeFromSemantics, isTrue);
      expect(thumbnail.placeholder, isA<VideoClipThumbnailTile>());

      // The shuttle and the player resolve to one cache entry, so their decode
      // bounds have to stay in step — pinned to the real value as well, or a
      // pair that both collapsed to null would still match.
      final player = tester.widget<StopMotionPlayer>(
        find.byType(StopMotionPlayer),
      );
      expect(player.cacheHeight, tester.view.physicalSize.height.round());
      expect(thumbnail.cacheHeight, player.cacheHeight);
    });

    group('hero flight', () {
      /// The grid bounds its decode to the cell rather than the screen, so the
      /// two ends of the flight carry different values and a test can tell
      /// which one is flying.
      const gridCardKey = Key('hero-flight-grid-card');

      int gridCacheHeight(WidgetTester tester) =>
          (tester.view.physicalSize.width / 2).round();

      Widget buildFlightApp(DivineVideoClip clip) {
        return buildTestWidget(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 80,
                height: 140,
                child: Builder(
                  builder: (context) => VideoClipThumbnailCard(
                    key: gridCardKey,
                    clip: clip,
                    showSelectionIndicator: false,
                    onTap: () => Navigator.of(
                      context,
                    ).push(videoClipPreviewRoute(clip: clip)),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      /// A failed resolution stays live in the process-global image cache, so
      /// each test evicts the two keys it created rather than clearing the
      /// cache other suites in the merged isolate share.
      void evictAfterTest(WidgetTester tester, String path) {
        addTearDown(() {
          for (final height in <int?>[
            gridCacheHeight(tester),
            tester.view.physicalSize.height.round(),
          ]) {
            PaintingBinding.instance.imageCache.evict(
              ResizeImage.resizeIfNeeded(null, height, FileImage(File(path))),
            );
          }
        });
      }

      /// Taps the grid card and stops halfway through the push flight.
      Future<void> flyToPreview(WidgetTester tester) async {
        await tester.tap(find.byKey(gridCardKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }

      /// Waits for the shuttle's decode to actually fail, then renders it.
      ///
      /// Resolving the file is real I/O, so the failure needs a real
      /// event-loop turn — taken here by performing the same read the decode
      /// performs, rather than by guessing at a wall-clock delay. The pump
      /// after it is load-bearing twice over: it drains the fake-async
      /// microtask queue the widget's error continuation is parked in (so
      /// blocking inside `runAsync` instead would deadlock), and it carries no
      /// duration, so the flight stays where [flyToPreview] left it.
      Future<void> settleDecodeFailure(WidgetTester tester, String path) async {
        for (var attempt = 0; attempt < 50; attempt++) {
          if (find.byType(VideoClipThumbnailTile).evaluate().isNotEmpty) return;
          await tester.runAsync(
            () =>
                File(path).readAsBytes().then<void>((_) {}, onError: (_, _) {}),
          );
          await tester.pump();
        }
      }

      /// The one thumbnail on screen mid-flight: a [Hero] hides both endpoints
      /// while the shuttle is up.
      ClipThumbnailImage flyingThumbnail(WidgetTester tester) =>
          tester.widget<ClipThumbnailImage>(find.byType(ClipThumbnailImage));

      testWidgets('flies the preview still out and back without errors', (
        tester,
      ) async {
        final tempDir = Directory.systemTemp.createTempSync('clip_hero_flight');
        addTearDown(() => tempDir.deleteSync(recursive: true));
        final frameFile = File('${tempDir.path}/frame.png')
          ..writeAsBytesSync(_transparentPngBytes);
        evictAfterTest(tester, frameFile.path);

        final clip = _stopMotionClip(
          id: 'flight-clip-1',
          framePath: frameFile.path,
          thumbnailPath: frameFile.path,
        );

        await tester.pumpWidget(buildFlightApp(clip));
        await flyToPreview(tester);

        // A flight at all proves both ends resolved the same tag from the clip
        // id; the decode bound proves it is the preview's shuttle flying and
        // not Flutter's default (the grid card's own child).
        expect(
          flyingThumbnail(tester).cacheHeight,
          tester.view.physicalSize.height.round(),
        );
        expect(
          flyingThumbnail(tester).cacheHeight,
          isNot(gridCacheHeight(tester)),
        );

        await tester.pumpAndSettle();
        expect(find.byType(StopMotionPlayer), findsOneWidget);

        // The grid card declares no shuttle of its own, so the return flight
        // falls back to the preview's — which is why the hero has to outlive
        // the placeholder it used to live in.
        Navigator.of(tester.element(find.byType(VideoClipPreview))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          flyingThumbnail(tester).cacheHeight,
          tester.view.physicalSize.height.round(),
        );

        await tester.pumpAndSettle();
        expect(find.byType(VideoClipPreview), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('falls back to the grid tile when the still is missing', (
        tester,
      ) async {
        final tempDir = Directory.systemTemp.createTempSync('clip_hero_gone');
        addTearDown(() => tempDir.deleteSync(recursive: true));
        // The frame is real so the player still renders; only the thumbnail
        // the shuttle decodes is gone, which is the iOS container-UUID case
        // #5796 covers for the grid.
        final frameFile = File('${tempDir.path}/frame.png')
          ..writeAsBytesSync(_transparentPngBytes);
        final missingThumbnail = '${tempDir.path}/evicted_thumbnail.jpg';
        evictAfterTest(tester, missingThumbnail);

        final clip = _stopMotionClip(
          id: 'flight-clip-2',
          framePath: frameFile.path,
          thumbnailPath: missingThumbnail,
        );

        await tester.pumpWidget(buildFlightApp(clip));
        await flyToPreview(tester);
        await settleDecodeFailure(tester, missingThumbnail);

        // Without a ground of its own the shuttle would fly the bare icon over
        // whatever is beneath it; the grid paints its card outside the hero.
        expect(find.byType(VideoClipThumbnailTile), findsOneWidget);
        final tile = tester.element(find.byType(VideoClipThumbnailTile));
        final ground = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byType(VideoClipThumbnailTile),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(ground.color, tile.vineColors.card);

        // The fallback bypasses `Image.excludeFromSemantics`, so the shuttle
        // keeps it out of the tree itself.
        expect(
          find.ancestor(
            of: find.byType(VideoClipThumbnailTile),
            matching: find.byType(ExcludeSemantics),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    });

    group('save result snackbar', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final destination = GallerySaveService.destinationName;

      Future<void> pumpAndSave(
        WidgetTester tester,
        GallerySaveResult result,
      ) async {
        installMockDivineVideoPlayer();

        when(
          () => mockGallerySaveService.saveVideoToGallery(any()),
        ).thenAnswer((_) async => result);

        await tester.pumpWidget(buildTestWidget());
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is DivineIcon && w.icon == DivineIconName.downloadSimple,
          ),
        );
        await tester.pump();
        await tester.pump();
      }

      testWidgets('shows saved message on $GallerySaveSuccess', (tester) async {
        await pumpAndSave(tester, const GallerySaveSuccess());

        expect(
          find.text(l10n.libraryClipsSavedToDestination(1, destination)),
          findsOneWidget,
        );
      });

      testWidgets('shows permission message on $GallerySavePermissionDenied', (
        tester,
      ) async {
        await pumpAndSave(tester, const GallerySavePermissionDenied());

        expect(
          find.text(l10n.libraryGalleryPermissionDenied(destination)),
          findsOneWidget,
        );
      });

      testWidgets('shows failure message on $GallerySaveFailure', (
        tester,
      ) async {
        await pumpAndSave(tester, const GallerySaveFailure('disk full'));

        expect(find.text(l10n.videoClipSaveFailed), findsOneWidget);
      });
    });
  });
}

/// A one-frame stop-motion clip: the frames path drives [StopMotionPlayer] and
/// [thumbnailPath] drives the hero shuttle, so the two can be pointed at
/// different files. One frame means no ticker, so the tree settles.
DivineVideoClip _stopMotionClip({
  required String id,
  required String framePath,
  required String thumbnailPath,
}) {
  return DivineVideoClip(
    id: id,
    stopMotionFrames: [
      StopMotionClipFrame(
        path: framePath,
        duration: const Duration(milliseconds: 83),
      ),
    ],
    thumbnailPath: thumbnailPath,
    libraryTitle: 'Tiny jump',
    duration: const Duration(milliseconds: 83),
    recordedAt: DateTime(2026),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
  );
}

const _transparentPngBytes = <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x60,
  0x00,
  0x00,
  0x00,
  0x02,
  0x00,
  0x01,
  0xe2,
  0x21,
  0xbc,
  0x33,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
];
