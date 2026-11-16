// ABOUTME: Tests for VideoMetadataClassicPreviewThumbnail widget
// ABOUTME: Verifies warning icon, player initialization, and resource disposal

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/video_editor_processing_overlay.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_preview_thumbnail.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/divine_video_player_channel.dart';

void main() {
  group(VideoMetadataClassicPreviewThumbnail, () {
    late DivineVideoClip testClip;
    late SharedPreferences prefs;

    setUp(() async {
      DivineVideoPlayerController.resetIdCounterForTesting();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      testClip = DivineVideoClip(
        id: 'test-clip',
        video: EditorVideo.file('test.mp4'),
        duration: const Duration(seconds: 10),
        recordedAt: DateTime.now(),
        thumbnailPath: 'test_thumbnail.jpg',
        targetAspectRatio: models.AspectRatio.square,
        originalAspectRatio: 9 / 16,
      );
    });

    group('renders', () {
      testWidgets('renders warning icon when thumbnailPath is null', (
        tester,
      ) async {
        final clipNoThumbnail = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('test.mp4'),
          duration: const Duration(seconds: 10),
          recordedAt: DateTime.now(),
          targetAspectRatio: models.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([clipNoThumbnail]),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VideoMetadataClassicPreviewThumbnail()),
            ),
          ),
        );

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon && widget.icon == DivineIconName.warning,
          ),
          findsOneWidget,
        );
      });

      testWidgets('renders thumbnail image when thumbnailPath is set', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VideoMetadataClassicPreviewThumbnail()),
            ),
          ),
        );

        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets(
        'shows processing overlay when isProcessing and no final clip',
        (tester) async {
          final state = VideoEditorProviderState(isProcessing: true);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                clipManagerProvider.overrideWith(
                  () => _MockClipManagerNotifier([testClip]),
                ),
                videoEditorProvider.overrideWith(
                  () => _MockVideoEditorNotifier(state),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: VideoMetadataClassicPreviewThumbnail()),
              ),
            ),
          );

          expect(find.byType(VideoEditorProcessingOverlay), findsOneWidget);
        },
      );

      testWidgets('returns empty widget when clips list is empty', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([]),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VideoMetadataClassicPreviewThumbnail()),
            ),
          ),
        );

        expect(find.byType(SizedBox), findsOneWidget);
      });
    });

    group('player initialization', () {
      testWidgets(
        'initializes player when finalRenderedClip becomes non-null',
        (tester) async {
          final methodCalls = <String>[];
          final setClipsArguments = <Map<Object?, Object?>>[];
          _registerMockPlayerChannel(
            methodCalls,
            setClipsArguments: setClipsArguments,
          );

          final tmpDir = Directory.systemTemp.createTempSync('test_clip_');
          final tmpFile = File('${tmpDir.path}/rendered.mp4')
            ..writeAsBytesSync([0]);
          addTearDown(() => tmpDir.deleteSync(recursive: true));

          final finalClip = DivineVideoClip(
            id: 'final-clip',
            video: EditorVideo.file(tmpFile.path),
            duration: const Duration(seconds: 15),
            recordedAt: DateTime.now(),
            targetAspectRatio: models.AspectRatio.square,
            originalAspectRatio: 9 / 16,
          );

          final state = VideoEditorProviderState(finalRenderedClip: finalClip);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                clipManagerProvider.overrideWith(
                  () => _MockClipManagerNotifier([testClip]),
                ),
                videoEditorProvider.overrideWith(
                  () => _MockVideoEditorNotifier(state),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: VideoMetadataClassicPreviewThumbnail()),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            methodCalls,
            containsAllInOrder(['create', 'setClips', 'play']),
          );
          final clips = setClipsArguments.single['clips']! as List<Object?>;
          final clip = clips.single! as Map<Object?, Object?>;
          expect(clip['trimToCommonTrackEnd'], isTrue);
        },
      );
    });

    group('when the finished video is rendered again', () {
      late Directory tmpDir;
      late DivineVideoClip firstRender;
      late DivineVideoClip secondRender;

      setUp(() {
        tmpDir = Directory.systemTemp.createTempSync('test_clip_');
        addTearDown(() => tmpDir.deleteSync(recursive: true));
        DivineVideoClip renderedClip(String id) => DivineVideoClip(
          id: id,
          video: EditorVideo.file(
            (File('${tmpDir.path}/$id.mp4')..writeAsBytesSync([0])).path,
          ),
          duration: const Duration(seconds: 6),
          recordedAt: DateTime.now(),
          targetAspectRatio: models.AspectRatio.square,
          originalAspectRatio: 1,
        );
        firstRender = renderedClip('first-render');
        secondRender = renderedClip('second-render');
      });

      Future<_MutableVideoEditorNotifier> pumpPlayingFirstRender(
        WidgetTester tester,
        List<String> methodCalls, {
        List<Map<Object?, Object?>>? setClipsArguments,
      }) async {
        _registerMockPlayerChannel(
          methodCalls,
          setClipsArguments: setClipsArguments,
          playerIds: const [0, 1],
        );
        final notifier = _MutableVideoEditorNotifier(
          VideoEditorProviderState(finalRenderedClip: firstRender),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(() => notifier),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VideoMetadataClassicPreviewThumbnail()),
            ),
          ),
        );
        await _waitForMethodCall(
          tester: tester,
          methodCalls: methodCalls,
          method: 'play',
        );
        await _waitForFinder(
          tester: tester,
          finder: find.byType(DivineVideoPlayer),
        );
        // Let the thumbnail finish fading out under the player.
        await _finishCrossFade(tester);
        expect(DivineVideoPlayerController.liveControllerCount, equals(1));
        return notifier;
      }

      testWidgets(
        'releases the player once the video it plays is discarded, so the '
        'next render can claim the hardware codec',
        (tester) async {
          final methodCalls = <String>[];
          final notifier = await pumpPlayingFirstRender(tester, methodCalls);

          // A take's proof landing after the export discards the finished
          // video and starts the next render.
          notifier.emit(VideoEditorProviderState(isProcessing: true));
          await _settleRelease(tester);
          await _finishCrossFade(tester);

          expect(methodCalls, contains('dispose'));
          expect(DivineVideoPlayerController.liveControllerCount, equals(0));
          expect(find.byType(DivineVideoPlayer), findsNothing);
          final overlay = tester.widget<VideoEditorProcessingOverlay>(
            find.byType(VideoEditorProcessingOverlay),
          );
          expect(overlay.isProcessing, isTrue);
        },
      );

      testWidgets('plays the video the next render finished', (tester) async {
        final methodCalls = <String>[];
        final setClipsArguments = <Map<Object?, Object?>>[];
        final notifier = await pumpPlayingFirstRender(
          tester,
          methodCalls,
          setClipsArguments: setClipsArguments,
        );

        notifier.emit(VideoEditorProviderState(isProcessing: true));
        await _settleRelease(tester);
        await _finishCrossFade(tester);
        expect(find.byType(DivineVideoPlayer), findsNothing);
        notifier.emit(
          VideoEditorProviderState(finalRenderedClip: secondRender),
        );
        await _waitForFinder(
          tester: tester,
          finder: find.byType(DivineVideoPlayer),
        );

        expect(DivineVideoPlayerController.liveControllerCount, equals(1));
        expect(setClipsArguments, hasLength(2));
        final clips = setClipsArguments.last['clips']! as List<Object?>;
        final clip = clips.single! as Map<Object?, Object?>;
        expect(clip['uri'], contains('second-render.mp4'));
      });
    });

    group('dispose', () {
      testWidgets('unmounts cleanly after player initialization', (
        tester,
      ) async {
        final methodCalls = <String>[];
        _registerMockPlayerChannel(methodCalls);

        final tmpDir = Directory.systemTemp.createTempSync('test_clip_');
        final tmpFile = File('${tmpDir.path}/rendered.mp4')
          ..writeAsBytesSync([0]);
        addTearDown(() => tmpDir.deleteSync(recursive: true));

        final finalClip = DivineVideoClip(
          id: 'final-clip',
          video: EditorVideo.file(tmpFile.path),
          duration: const Duration(seconds: 15),
          recordedAt: DateTime.now(),
          targetAspectRatio: models.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        final state = VideoEditorProviderState(finalRenderedClip: finalClip);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(state),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VideoMetadataClassicPreviewThumbnail()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _waitForMethodCall(
          tester: tester,
          methodCalls: methodCalls,
          method: 'play',
        );
        await _waitForFinder(
          tester: tester,
          finder: find.byType(DivineVideoPlayer),
        );

        // Unmount the widget — triggers dispose
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(state),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SizedBox()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VideoMetadataClassicPreviewThumbnail), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('disposes a player that finishes starting after unmount', (
        tester,
      ) async {
        final methodCalls = <String>[];
        final releasePlay = Completer<void>();
        _registerMockPlayerChannel(methodCalls, holdPlay: releasePlay.future);

        final tmpDir = Directory.systemTemp.createTempSync('test_clip_');
        final tmpFile = File('${tmpDir.path}/rendered.mp4')
          ..writeAsBytesSync([0]);
        addTearDown(() => tmpDir.deleteSync(recursive: true));

        final finalClip = DivineVideoClip(
          id: 'final-clip',
          video: EditorVideo.file(tmpFile.path),
          duration: const Duration(seconds: 15),
          recordedAt: DateTime.now(),
          targetAspectRatio: models.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );
        final state = VideoEditorProviderState(finalRenderedClip: finalClip);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(state),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VideoMetadataClassicPreviewThumbnail()),
            ),
          ),
        );
        await _waitForMethodCall(
          tester: tester,
          methodCalls: methodCalls,
          method: 'play',
        );
        expect(DivineVideoPlayerController.liveControllerCount, equals(1));

        // Leave while the native play() call is still outstanding.
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(state),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SizedBox()),
            ),
          ),
        );
        releasePlay.complete();
        await tester.pumpAndSettle();

        expect(DivineVideoPlayerController.liveControllerCount, equals(0));
      });
    });
  });
}

/// Runs the preview's 400 ms cross-fade between the thumbnail and the player
/// past its end, where the child that faded out is dropped.
Future<void> _finishCrossFade(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 450));

/// Lets a player release finish: the event subscription it cancels first
/// answers outside the test's fake async zone.
Future<void> _settleRelease(WidgetTester tester) async {
  for (var round = 0; round < 5; round++) {
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
  }
}

Future<void> _waitForFinder({
  required WidgetTester tester,
  required Finder finder,
  int attempts = 100,
}) async {
  for (var i = 0; i < attempts; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 10));
  }

  fail('Finder not found within timeout: $finder');
}

Future<void> _waitForMethodCall({
  required WidgetTester tester,
  required List<String> methodCalls,
  required String method,
  int attempts = 100,
}) async {
  for (var i = 0; i < attempts; i++) {
    if (methodCalls.contains(method)) return;
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 10));
  }
}

/// Registers mock platform channel handlers for divine_video_player.
///
/// The global channel handles `create` / `dispose`; the per-player channel
/// handles `setClips`, `play`, `setLooping`, etc. Both record into
/// [methodCalls]. When [holdPlay] is given, `play` answers only once it
/// completes. [playerIds] lists the players a test creates, in order.
void _registerMockPlayerChannel(
  List<String> methodCalls, {
  List<Map<Object?, Object?>>? setClipsArguments,
  Future<void>? holdPlay,
  List<int> playerIds = const [0],
}) {
  const globalChannel = MethodChannel('divine_video_player');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // Player ID resets via resetIdCounterForTesting in setUp, so first is 0.
  for (final playerId in playerIds) {
    installMockDivineVideoPlayer(
      playerId: playerId,
      onMethodCall: (call) async {
        methodCalls.add(call.method);
        if (call.method == 'setClips') {
          setClipsArguments?.add(
            call.arguments! as Map<Object?, Object?>,
          );
        }
        if (call.method == 'play' && holdPlay != null) await holdPlay;
        return null;
      },
    );
  }

  messenger.setMockMethodCallHandler(globalChannel, (call) async {
    methodCalls.add(call.method);
    if (call.method == 'create') {
      return <String, dynamic>{'textureId': 1};
    }
    return null;
  });

  addTearDown(() {
    messenger.setMockMethodCallHandler(globalChannel, null);
  });
}

class _MockClipManagerNotifier extends ClipManagerNotifier {
  _MockClipManagerNotifier(this._clips);

  final List<DivineVideoClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}

class _MutableVideoEditorNotifier extends VideoEditorNotifier {
  _MutableVideoEditorNotifier(this._initialState);

  final VideoEditorProviderState _initialState;

  @override
  VideoEditorProviderState build() => _initialState;

  void emit(VideoEditorProviderState next) => state = next;
}
