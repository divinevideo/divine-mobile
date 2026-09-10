// ABOUTME: Tests for VideoMetadataCoverScreen widget
// ABOUTME: Verifies rendering, semantics, navigation, and failure handling

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_cover_screen.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:pro_video_editor/core/platform/native_method_channel.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../helpers/go_router.dart';

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}

/// Fresh ProVideoEditor-compatible instance for tests.
///
/// This routes calls through the mocked `MethodChannel('pro_video_editor')`
/// while skipping EventChannel subscriptions that are not present in widget
/// tests. It also prevents order-dependent failures when another test file has
/// replaced [ProVideoEditor.instance] with a mock that only implements a
/// subset of methods such as `getWaveform()`.
class _NoopInitProVideoEditor extends MethodChannelProVideoEditor {
  @override
  Stream<dynamic> initializeStream() => const Stream.empty();
}

class _PendingEditorVideo extends Fake implements EditorVideo {
  _PendingEditorVideo(this.path);

  final Future<String> path;

  @override
  Future<String> safeFilePath() => path;
}

DivineVideoClip _createTestClip({
  String id = 'test-clip',
  models.AspectRatio aspectRatio = models.AspectRatio.square,
  EditorVideo? video,
}) {
  return DivineVideoClip(
    id: id,
    video: video ?? EditorVideo.file('test.mp4'),
    duration: const Duration(seconds: 10),
    recordedAt: DateTime.now(),
    targetAspectRatio: aspectRatio,
    originalAspectRatio: 9 / 16,
  );
}

void _setHandler(
  MethodChannel channel,
  Future<Object?> Function(MethodCall call) handler,
) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, handler);
}

void _clearHandler(MethodChannel channel) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProVideoEditor originalProVideoEditor;

  setUp(() {
    DivineVideoPlayerController.resetIdCounterForTesting();
    originalProVideoEditor = ProVideoEditor.instance;
    ProVideoEditor.instance = _NoopInitProVideoEditor();

    _setHandler(const MethodChannel('divine_video_player'), (call) async {
      if (call.method == 'create') return <String, Object?>{'textureId': 1};
      return null;
    });

    _setHandler(const MethodChannel('pro_video_editor'), (call) async {
      if (call.method == 'getThumbnails') return <Object?>[];
      if (call.method == 'getMetadata') {
        return <String, Object?>{
          'duration': 3000000,
          'extension': 'mp4',
          'fileSize': 1024000,
          'width': 1920,
          'height': 1080,
          'rotation': 0,
          'bitrate': 3000000,
        };
      }
      return null;
    });
  });

  tearDown(() {
    ProVideoEditor.instance = originalProVideoEditor;
    _clearHandler(const MethodChannel('divine_video_player'));
    _clearHandler(const MethodChannel('pro_video_editor'));
  });

  group(VideoMetadataCoverScreen, () {
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockGoRouter = MockGoRouter();
      when(mockGoRouter.canPop).thenReturn(true);
      when(() => mockGoRouter.pop<Object?>(any())).thenAnswer((_) async {});
    });

    Widget buildWidget({DivineVideoClip? clip}) {
      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(
            () => _MockVideoEditorNotifier(VideoEditorProviderState()),
          ),
        ],
        child: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: VideoMetadataCoverScreen(clip: clip ?? _createTestClip()),
          ),
        ),
      );
    }

    /// Wraps the screen behind a push so the route transition — and with it
    /// the hero flight — actually runs. Pumped directly as `home:` the route
    /// animation is already completed and never animates.
    Widget buildPushableApp(DivineVideoClip clip) {
      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(
            () => _MockVideoEditorNotifier(VideoEditorProviderState()),
          ),
        ],
        child: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Center(
                // A matching hero on the source side, so the push runs a real
                // flight through the navigator overlay rather than a bare
                // route transition.
                child: Hero(
                  tag: VideoEditorConstants.heroMetaPreviewId,
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: TextButton(
                      // Mirrors the production push in
                      // video_metadata_capture_clip_preview.dart.
                      onPressed: () => Navigator.of(context).push(
                        PageRouteBuilder<void>(
                          pageBuilder: (_, _, _) =>
                              VideoMetadataCoverScreen(clip: clip),
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
      );
    }

    void setUpPlayerChannel() {
      _setHandler(
        const MethodChannel('divine_video_player/player_0'),
        (call) async => null,
      );
      _setHandler(
        const MethodChannel('divine_video_player/player_0/events'),
        (call) async => null,
      );
    }

    void tearDownPlayerChannel() {
      _clearHandler(const MethodChannel('divine_video_player/player_0'));
      _clearHandler(const MethodChannel('divine_video_player/player_0/events'));
    }

    Future<void> triggerConfirm(WidgetTester tester) async {
      final buttonFinder = find.byWidgetPredicate(
        (w) => w is DivineIconButton && w.icon == DivineIconName.check,
      );
      final button = tester.widget<DivineIconButton>(buttonFinder);
      button.onPressed?.call();
      await tester.pump();
    }

    test('can be instantiated', () {
      expect(
        VideoMetadataCoverScreen(clip: _createTestClip()),
        isA<VideoMetadataCoverScreen>(),
      );
    });

    testWidgets('renders $VideoMetadataCoverScreen with scaffold', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(VideoMetadataCoverScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows edit-cover title', (tester) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoMetadataEditCoverTitle), findsOneWidget);
    });

    testWidgets('morphs the hero flight corners on the way back', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      // The metadata thumbnail rounds itself from outside its Hero, so the
      // shuttle arrives carrying no rounding of its own. Without a builder on
      // this screen's Hero the whole flight back is square-cornered.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(VideoEditorProviderState()),
            ),
          ],
          child: MockGoRouterProvider(
            goRouter: mockGoRouter,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: SizedBox(
                      height: 200,
                      // Clip outside the Hero, the way both real thumbnails do.
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
                                    VideoMetadataCoverScreen(
                                      clip: _createTestClip(
                                        aspectRatio:
                                            models.AspectRatio.vertical,
                                      ),
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
        ),
      );

      // Caught mid-lerp the shuttle is strictly inside both endpoints on both
      // corners: the thumbnail's 16 all round and this screen's bottom-only 32.
      // Neither resting shape satisfies that, so only the shuttle matches.
      final shuttleClip = find.byWidgetPredicate((widget) {
        if (widget is! ClipRRect) return false;
        final radius = widget.borderRadius;
        return radius is BorderRadius &&
            radius.topLeft.x > 0 &&
            radius.topLeft.x < VideoEditorConstants.clipPreviewCornerRadius &&
            radius.bottomLeft.x >
                VideoEditorConstants.clipPreviewCornerRadius &&
            radius.bottomLeft.x < 32;
      });
      BorderRadius shuttleRadius() =>
          tester.widget<ClipRRect>(shuttleClip).borderRadius as BorderRadius;

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      expect(shuttleClip, findsOneWidget);
      final early = shuttleRadius();

      await tester.pump(const Duration(milliseconds: 120));
      final later = shuttleRadius();

      // Travelling towards the thumbnail: the top tightens back to 16 as the
      // bottom relaxes off 32. A single sample cannot tell that from a lerp
      // running backwards or one pinned to a constant.
      expect(later.topLeft.x, greaterThan(early.topLeft.x));
      expect(later.bottomLeft.x, lessThan(early.bottomLeft.x));

      await tester.pumpAndSettle();
    });

    testWidgets('shows DivineVideoPlayer', (tester) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DivineVideoPlayer), findsOneWidget);
    });

    testWidgets('shows close button with correct semantics label', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = lookupAppLocalizations(const Locale('en'));
      final closeFinder = find.bySemanticsLabel(
        l10n.videoMetadataEditCoverCloseSemanticLabel,
      );
      expect(closeFinder, findsOneWidget);
      expect(
        tester
            .getSemantics(closeFinder)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
    });

    testWidgets('shows confirm button with correct semantics label', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = lookupAppLocalizations(const Locale('en'));
      final confirmFinder = find.bySemanticsLabel(
        l10n.videoMetadataEditCoverConfirmSemanticLabel,
      );
      expect(confirmFinder, findsOneWidget);
      expect(
        tester
            .getSemantics(confirmFinder)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
    });

    // Disabled alone reads as "unavailable"; the indicator's own label merges
    // in so the button announces that it is busy, not broken.
    testWidgets('confirm button announces disabled and busy while confirming', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);
      final semanticsHandle = tester.ensureSemantics();
      final pendingPath = Completer<String>();
      final clip = _createTestClip(
        video: _PendingEditorVideo(pendingPath.future),
      );

      await tester.pumpWidget(buildWidget(clip: clip));
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = lookupAppLocalizations(const Locale('en'));
      await triggerConfirm(tester);
      await tester.pump();

      final busyLabel =
          '${l10n.videoMetadataEditCoverConfirmSemanticLabel}\n'
          '${l10n.commonLoading}';
      final confirmFinder = find.bySemanticsLabel(busyLabel);
      expect(confirmFinder, findsOneWidget);
      expect(find.byType(BrandedLoadingIndicator), findsWidgets);
      expect(
        tester.getSemantics(confirmFinder),
        isSemantics(
          label: busyLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );

      semanticsHandle.dispose();
    });

    testWidgets('shows thumbnail strip with correct semantics label', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(l10n.videoMetadataEditCoverStripSemanticLabel),
        findsOneWidget,
      );
    });

    testWidgets('thumbnail strip exposes semantic increase/decrease actions', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = lookupAppLocalizations(const Locale('en'));
      final stripFinder = find.bySemanticsLabel(
        l10n.videoMetadataEditCoverStripSemanticLabel,
      );
      final stripSemantics = tester.getSemantics(stripFinder);
      final stripData = stripSemantics.getSemanticsData();

      expect(stripData.flagsCollection.isSlider, isTrue);
      expect(stripData.hasAction(SemanticsAction.increase), isTrue);
      expect(stripData.hasAction(SemanticsAction.decrease), isTrue);

      semanticsHandle.dispose();
    });

    testWidgets('tapping close button calls context.pop()', (tester) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(
        find.bySemanticsLabel(l10n.videoMetadataEditCoverCloseSemanticLabel),
        warnIfMissed: false,
      );
      await tester.pump();

      verify(() => mockGoRouter.pop<Object?>(any())).called(1);
    });

    testWidgets(
      'tapping confirm with no extracted thumbnail surfaces failure snackbar '
      'and stays on screen',
      (tester) async {
        setUpPlayerChannel();
        addTearDown(tearDownPlayerChannel);

        await tester.pumpWidget(
          buildWidget(
            clip: _createTestClip(
              id: 'missing-thumbnail-source',
              video: EditorVideo.file('__missing_cover_thumbnail_source__.mp4'),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        final l10n = lookupAppLocalizations(const Locale('en'));
        await triggerConfirm(tester);

        for (var i = 0; i < 5; i++) {
          await tester.pump();
        }

        verifyNever(() => mockGoRouter.pop<Object?>(any()));
        expect(
          find.text(l10n.videoMetadataEditCoverFailedSnackbar),
          findsOneWidget,
        );
        expect(find.byType(BrandedLoadingIndicator), findsNothing);
      },
    );

    testWidgets('confirm button shows the check icon in its idle state', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(BrandedLoadingIndicator), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIconButton && w.icon == DivineIconName.check,
        ),
        findsOneWidget,
      );
    });

    testWidgets('dims the strip either side of the selection cursor', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      final dimFinder = find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == VineTheme.scrim35,
      );
      expect(dimFinder, findsNWidgets(2));

      Rect leftDim() => tester.getRect(dimFinder.first);
      Rect rightDim() => tester.getRect(dimFinder.last);

      // The dims span the strip between them, flanking the cursor.
      final stripLeft = leftDim().left;
      final stripRight = rightDim().right;
      expect(rightDim().left - leftDim().right, equals(36.0));

      // The default cover sits inside the cursor's own width, so the clamp
      // collapses the leading dim rather than giving it a negative width.
      expect(leftDim().width, equals(0.0));

      final midY = leftDim().center.dy;
      await tester.tapAt(
        Offset(stripLeft + (stripRight - stripLeft) * 0.6, midY),
      );
      await tester.pump();

      // Moving the selection later widens the dim behind it. The strip's own
      // bounds do not move, and the cursor-sized gap is preserved.
      expect(leftDim().width, greaterThan(0));
      expect(leftDim().left, equals(stripLeft));
      expect(rightDim().right, equals(stripRight));
      expect(rightDim().left - leftDim().right, equals(36.0));

      // Clamped at the far end too: the trailing dim collapses rather than
      // running past the strip.
      await tester.tapAt(Offset(stripRight - 1, midY));
      await tester.pump();
      expect(rightDim().width, equals(0.0));
      expect(stripRight - leftDim().right, equals(36.0));

      // And back to the start.
      await tester.tapAt(Offset(stripLeft + 1, midY));
      await tester.pump();
      expect(leftDim().width, equals(0.0));
      expect(rightDim().left - stripLeft, equals(36.0));
    });

    testWidgets('keeps the top bar hidden until the route transition lands', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildPushableApp(_createTestClip()));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final l10n = lookupAppLocalizations(const Locale('en'));
      final topBar = find.ancestor(
        of: find.text(l10n.videoMetadataEditCoverTitle),
        matching: find.byType(AnimatedOpacity),
      );

      // Mid-flight the hero is painted by the navigator overlay, on top of
      // anything the route draws — the bar must stay out of the way.
      expect(tester.widget<AnimatedOpacity>(topBar).opacity, equals(0.0));

      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.widget<AnimatedOpacity>(topBar).opacity, equals(1.0));
    });

    testWidgets(
      'loads the preview at the cover position instead of seeking after '
      'load',
      (tester) async {
        addTearDown(tearDownPlayerChannel);
        final calls = <MethodCall>[];
        _setHandler(const MethodChannel('divine_video_player/player_0'), (
          call,
        ) async {
          calls.add(call);
          return null;
        });
        _setHandler(
          const MethodChannel('divine_video_player/player_0/events'),
          (call) async => null,
        );

        await tester.pumpWidget(
          buildWidget(
            clip: _createTestClip().copyWith(
              thumbnailTimestamp: const Duration(milliseconds: 1500),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        final setClipsCalls = calls.where((c) => c.method == 'setClips');
        expect(setClipsCalls, hasLength(1));
        final setClips = setClipsCalls.first;
        expect(
          (setClips.arguments as Map)['startPositionMs'],
          equals(1500),
          reason: 'the first decoded frame must already be the cover frame',
        );
        expect(calls.where((c) => c.method == 'seekTo'), isEmpty);
      },
    );

    testWidgets(
      'a permanently failed preview still generates the cover strip, hides '
      'the loading indicator, and keeps the picker scrubbable',
      (tester) async {
        addTearDown(tearDownPlayerChannel);
        _setHandler(const MethodChannel('divine_video_player/player_0'), (
          call,
        ) async {
          if (call.method == 'setClips') {
            throw PlatformException(
              code: 'PLAYER_ERROR',
              message: 'decoder init failed',
            );
          }
          return null;
        });
        _setHandler(
          const MethodChannel('divine_video_player/player_0/events'),
          (call) async => null,
        );

        var stripRequested = false;
        _setHandler(const MethodChannel('pro_video_editor'), (call) async {
          if (call.method == 'getThumbnails') {
            stripRequested = true;
            return <Object?>[];
          }
          if (call.method == 'getMetadata') {
            return <String, Object?>{
              'duration': 3000000,
              'extension': 'mp4',
              'fileSize': 1024000,
              'width': 1920,
              'height': 1080,
              'rotation': 0,
              'bitrate': 3000000,
            };
          }
          return null;
        });
        final semanticsHandle = tester.ensureSemantics();

        // A previous test tearing down mid-generation strands the static
        // strip queue on a future from its dead FakeAsync zone; reset it
        // here — inside this test's zone, so the replacement future's
        // completion is flushed by pumps — or the batch loop never runs.
        VideoThumbnailService.resetStripBatchQueueForTesting();

        await tester.pumpWidget(buildWidget());
        await tester.pump(const Duration(milliseconds: 400));
        for (var i = 0; i < 10; i++) {
          await tester.pump();
        }

        expect(stripRequested, isTrue);
        expect(find.byType(BrandedLoadingIndicator), findsNothing);

        // Scrubbing must still move the selection cursor without a player.
        final l10n = lookupAppLocalizations(const Locale('en'));
        final stripFinder = find.bySemanticsLabel(
          l10n.videoMetadataEditCoverStripSemanticLabel,
        );
        final before = tester.getSemantics(stripFinder).getSemanticsData();
        final stripSemantics = find.semantics.byAction(
          SemanticsAction.increase,
        );
        // Two steps with a rebuild in between: a single 500 ms step from the
        // 210 ms default lands at 710 ms, which formats to the same "0:00".
        tester.semantics.increase(stripSemantics);
        await tester.pump();
        tester.semantics.increase(stripSemantics);
        await tester.pump();
        final after = tester.getSemantics(stripFinder).getSemanticsData();
        expect(after.value, isNot(equals(before.value)));

        semanticsHandle.dispose();
      },
    );
  });
}
