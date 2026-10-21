// ABOUTME: Tests for DmVideoPlayPage: decrypt-to-clip progress, playback, and
// ABOUTME: temp-file cleanup on dispose and on decrypt failure.

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/screens/inbox/conversation/dm_video_play_page.dart';
import 'package:openvine/services/dm_video_store.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

import '../../../helpers/divine_video_player_channel.dart';
import '../../../mocks/mock_path_provider_platform.dart';

class _MockDmVideoStore extends Mock implements DmVideoStore {}

class _MockGallerySaveService extends Mock implements GallerySaveService {}

/// Records the errors blocs created while it is the observer add.
class _ErrorRecorder extends BlocObserver {
  final List<Object> errors = [];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

/// Native player events the test sends once the controller is listening.
class _PlayerEvents extends MockStreamHandler {
  MockStreamHandlerEventSink? _sink;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    _sink = events;
  }

  @override
  void onCancel(Object? arguments) {
    _sink = null;
  }

  void emit(Map<Object?, Object?> state) => _sink!.success(state);
}

DmFileMetadata _videoMetadata() => DmFileMetadata(
  fileType: 'video/mp4',
  encryptionAlgorithm: 'aes-gcm',
  decryptionKey: '00' * 32,
  decryptionNonce: '00' * 12,
  fileHash: 'ab' * 32,
);

DmMessage _videoMessage() => DmMessage(
  id: 'a' * 64,
  conversationId: 'conversation',
  senderPubkey: 'b' * 64,
  content: 'https://blossom.example/encrypted',
  createdAt: 1757385263,
  giftWrapId: 'c' * 64,
  messageKind: 15,
  fileMetadata: _videoMetadata(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockDmVideoStore store;
  late _MockGallerySaveService gallerySaveService;
  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(_videoMessage());
    registerFallbackValue(EditorVideo.file(''));
  });

  setUp(() {
    store = _MockDmVideoStore();
    gallerySaveService = _MockGallerySaveService();
    tempDir = Directory.systemTemp.createTempSync('dm_video_play_page_');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = MockPathProviderPlatform()
      ..setTemporaryPath(tempDir.path);
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
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          null,
        );
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String expectedClipPath() =>
      '${tempDir.path}/${DmVideoStore.dirName}/owner/'
      '${DmVideoStore.videoFileNameFor(_videoMessage())}';

  void stubKeptVideo(Future<String> Function() answer) {
    when(
      () => store.videoFor(any()),
    ).thenAnswer((_) async => File(await answer()));
  }

  Widget host({bool canAddToClips = false}) => ProviderScope(
    overrides: [
      dmVideoStoreProvider.overrideWithValue(store),
      gallerySaveServiceProvider.overrideWithValue(gallerySaveService),
    ],
    child: MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DmVideoPlayPage(
        message: _videoMessage(),
        canAddToClips: canAddToClips,
      ),
    ),
  );

  group(DmVideoPlayPage, () {
    testWidgets('shows a progress state while decrypting, then the player', (
      tester,
    ) async {
      final completer = Completer<String>();
      stubKeptVideo(() => completer.future);
      installMockDivineVideoPlayer();

      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
      expect(find.byType(DivineVideoPlayer), findsNothing);

      File(expectedClipPath())
        ..createSync(recursive: true)
        ..writeAsBytesSync(const [1, 2, 3]);
      completer.complete(expectedClipPath());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DivineCircularProgressIndicator), findsNothing);
      expect(find.byType(DivineVideoPlayer), findsOneWidget);
    });

    testWidgets('keeps the video when the page closes', (tester) async {
      stubKeptVideo(() async {
        File(expectedClipPath())
          ..createSync(recursive: true)
          ..writeAsBytesSync(const [1, 2, 3]);
        return expectedClipPath();
      });
      installMockDivineVideoPlayer();

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(File(expectedClipPath()).existsSync(), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(File(expectedClipPath()).existsSync(), isTrue);
    });

    testWidgets('shows an error state when decrypt fails', (tester) async {
      stubKeptVideo(() async => throw Exception('decrypt failed'));
      installMockDivineVideoPlayer();

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DivineVideoPlayer), findsNothing);
      expect(find.byType(DivineCircularProgressIndicator), findsNothing);
      expect(
        find.text(AppLocalizationsEn().dmVideoUnavailable),
        findsOneWidget,
      );
    });

    group('playback', () {
      late _PlayerEvents events;
      late List<MethodCall> playerCalls;

      /// Opens the page on a decrypted clip and waits for the player.
      Future<void> openPlayer(WidgetTester tester) async {
        stubKeptVideo(() async {
          File(expectedClipPath())
            ..createSync(recursive: true)
            ..writeAsBytesSync(const [1, 2, 3]);
          return expectedClipPath();
        });
        events = _PlayerEvents();
        playerCalls = [];
        installMockDivineVideoPlayer(
          onMethodCall: (call) async {
            playerCalls.add(call);
            return null;
          },
          streamHandler: events,
        );

        await tester.pumpWidget(host());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(DivineVideoPlayer), findsOneWidget);
      }

      testWidgets('loops the clip, as every Divine video does', (tester) async {
        await openPlayer(tester);

        final looping = playerCalls.where((c) => c.method == 'setLooping');
        expect(looping, hasLength(1));
        expect(looping.single.arguments, equals({'looping': true}));
      });

      testWidgets('keeps the clip in its own shape instead of stretching it', (
        tester,
      ) async {
        await openPlayer(tester);

        events.emit(const {
          'status': 'playing',
          'isFirstFrameRendered': true,
          'videoWidth': 1080,
          'videoHeight': 1920,
        });
        await tester.pump();

        final size = tester.getSize(find.byType(DivineVideoPlayer));
        expect(size.width / size.height, closeTo(9 / 16, 0.01));
      });

      testWidgets(
        'keeps a portrait clip stored sideways in portrait, as Android reports '
        'it',
        (tester) async {
          await openPlayer(tester);

          // Android reports the displayed size alongside the rotation it
          // still applies to the texture itself.
          events.emit(const {
            'status': 'playing',
            'isFirstFrameRendered': true,
            'videoWidth': 1080,
            'videoHeight': 1920,
            'rotationDegrees': 90,
          });
          await tester.pump();

          final size = tester.getSize(find.byType(DivineVideoPlayer));
          expect(size.width / size.height, closeTo(9 / 16, 0.01));
        },
      );

      testWidgets('allows for non-square pixels', (tester) async {
        await openPlayer(tester);

        events.emit(const {
          'status': 'playing',
          'isFirstFrameRendered': true,
          'videoWidth': 1440,
          'videoHeight': 1920,
          'pixelWidthHeightRatio': 0.75,
        });
        await tester.pump();

        final size = tester.getSize(find.byType(DivineVideoPlayer));
        expect(size.width / size.height, closeTo(9 / 16, 0.01));
      });

      group(
        "keeps the kept file's path and name out of the error it records",
        () {
          late _ErrorRecorder recorder;

          setUp(() {
            final previous = Bloc.observer;
            recorder = _ErrorRecorder();
            // Before the page builds its cubit, which takes the observer then.
            Bloc.observer = recorder;
            addTearDown(() => Bloc.observer = previous);
          });

          void expectNoFileIn(Iterable<Object> errors) {
            final recorded = errors.map((error) => '$error').join('\n');
            expect(recorded, isNotEmpty);
            expect(recorded, isNot(contains(expectedClipPath())));
            expect(recorded, isNot(contains(_videoMessage().id)));
          }

          testWidgets('when the player fails after starting', (tester) async {
            await openPlayer(tester);
            final quoting = {
              'status': 'error',
              'errorMessage': 'Cannot open ${expectedClipPath()}',
            };

            events
              ..emit(quoting)
              ..emit(quoting);
            await tester.pump(const Duration(seconds: 3));
            await tester.pump();

            expectNoFileIn(recorder.errors);
          });

          testWidgets('when the player cannot take the file', (tester) async {
            stubKeptVideo(() async {
              File(expectedClipPath())
                ..createSync(recursive: true)
                ..writeAsBytesSync(const [1, 2, 3]);
              return expectedClipPath();
            });
            installMockDivineVideoPlayer(
              onMethodCall: (call) async {
                if (call.method == 'setClips') {
                  throw PlatformException(
                    code: 'source',
                    message: 'No file named ${_videoMessage().id}.mp4',
                  );
                }
                return null;
              },
              streamHandler: _PlayerEvents(),
            );

            await tester.pumpWidget(host());
            await tester.pump();
            // The failed player's teardown answers on real platform channels.
            await tester.runAsync(pumpEventQueue);
            await tester.pump();

            expectNoFileIn(recorder.errors);
          });
        },
      );

      testWidgets(
        'tells the viewer the video could not be opened when the player fails '
        'after starting, instead of leaving a black screen',
        (tester) async {
          await openPlayer(tester);

          events
            ..emit(const {'status': 'error', 'errorMessage': 'decode'})
            ..emit(const {'status': 'error', 'errorMessage': 'decode'});
          await tester.pump(const Duration(seconds: 3));
          await tester.pump();

          expect(find.byType(DivineVideoPlayer), findsNothing);
          expect(
            find.text(AppLocalizationsEn().dmVideoUnavailable),
            findsOneWidget,
          );
        },
      );
    });

    group('player recovery', () {
      testWidgets(
        'keeps playing when the player recovers from a decoder error, as '
        'Android retries one',
        (tester) async {
          stubKeptVideo(() async {
            File(expectedClipPath())
              ..createSync(recursive: true)
              ..writeAsBytesSync(const [1, 2, 3]);
            return expectedClipPath();
          });
          final events = _PlayerEvents();
          installMockDivineVideoPlayer(streamHandler: events);
          await tester.pumpWidget(host());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          events.emit(const {'status': 'error', 'errorMessage': 'decoder'});
          await tester.pump(const Duration(milliseconds: 700));
          events.emit(const {
            'status': 'playing',
            'isFirstFrameRendered': true,
          });
          await tester.pump(const Duration(seconds: 5));

          expect(find.byType(DivineVideoPlayer), findsOneWidget);
          expect(
            find.text(AppLocalizationsEn().dmVideoUnavailable),
            findsNothing,
          );
        },
      );
    });

    group('save', () {
      final l10n = AppLocalizationsEn();

      Future<void> pumpReady(
        WidgetTester tester, {
        required bool canAddToClips,
      }) async {
        stubKeptVideo(() async {
          File(expectedClipPath())
            ..createSync(recursive: true)
            ..writeAsBytesSync(const [1, 2, 3]);
          return expectedClipPath();
        });
        when(
          () => gallerySaveService.saveVideoToGallery(
            any(),
            copyUnderNeutralName: true,
          ),
        ).thenAnswer((_) async => const GallerySaveSuccess());
        installMockDivineVideoPlayer();

        await tester.pumpWidget(host(canAddToClips: canAddToClips));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }

      testWidgets('asks between clips and gallery for a received video', (
        tester,
      ) async {
        await pumpReady(tester, canAddToClips: true);

        await tester.tap(find.bySemanticsLabel(l10n.shareSheetSaveVideo));
        await tester.pumpAndSettle();

        expect(find.text(l10n.shareSheetAddToClips), findsOneWidget);
        await tester.tap(find.text(l10n.shareSheetSaveToGallery));
        await tester.pumpAndSettle();

        verify(
          () => gallerySaveService.saveVideoToGallery(
            any(),
            copyUnderNeutralName: true,
          ),
        ).called(1);
      });

      testWidgets('saves straight to the gallery when clips are not offered', (
        tester,
      ) async {
        await pumpReady(tester, canAddToClips: false);

        await tester.tap(find.bySemanticsLabel(l10n.shareSheetSaveVideo));
        await tester.pumpAndSettle();

        expect(find.text(l10n.shareSheetAddToClips), findsNothing);
        verify(
          () => gallerySaveService.saveVideoToGallery(
            any(),
            copyUnderNeutralName: true,
          ),
        ).called(1);
      });
    });
  });
}
