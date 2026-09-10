// ABOUTME: Tests for VideoMetadataClassicPreviewThumbnail widget
// ABOUTME: Verifies warning icon, player initialization, and resource disposal

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
          finder: find.byKey(const ValueKey('player')),
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
            child: const MaterialApp(home: Scaffold(body: SizedBox())),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VideoMetadataClassicPreviewThumbnail), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  });
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
/// [methodCalls].
void _registerMockPlayerChannel(
  List<String> methodCalls, {
  List<Map<Object?, Object?>>? setClipsArguments,
}) {
  const globalChannel = MethodChannel('divine_video_player');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // Player ID resets via resetIdCounterForTesting in setUp, so first is 0.
  installMockDivineVideoPlayer(
    onMethodCall: (call) async {
      methodCalls.add(call.method);
      if (call.method == 'setClips') {
        setClipsArguments?.add(
          call.arguments! as Map<Object?, Object?>,
        );
      }
      return null;
    },
  );

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
