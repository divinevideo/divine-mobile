// ABOUTME: Tests for DmVideoPlayPage: decrypt-to-clip progress, playback, and
// ABOUTME: temp-file cleanup on dispose and on decrypt failure.

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
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
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

import '../../../helpers/divine_video_player_channel.dart';
import '../../../mocks/mock_path_provider_platform.dart';

class _MockDmVideoDecryptor extends Mock implements DmVideoDecryptor {}

class _MockGallerySaveService extends Mock implements GallerySaveService {}

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

  late _MockDmVideoDecryptor decryptor;
  late _MockGallerySaveService gallerySaveService;
  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(_videoMessage());
    registerFallbackValue(EditorVideo.file(''));
  });

  setUp(() {
    decryptor = _MockDmVideoDecryptor();
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
      '${tempDir.path}/${DmVideoDecryptor.playbackDirName}/'
      '${DmVideoDecryptor.clipFileNameFor(_videoMessage())}';

  void stubDecrypt(Future<String> Function() answer) {
    when(() => decryptor.decryptToFile(any())).thenAnswer((_) => answer());
  }

  void stubDelete() {
    when(() => decryptor.deleteClip(any())).thenAnswer((invocation) {
      final path = invocation.positionalArguments.first as String;
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    });
  }

  Widget host({bool canAddToClips = false}) => ProviderScope(
    overrides: [
      dmVideoDecryptorProvider.overrideWithValue(decryptor),
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
      stubDecrypt(() => completer.future);
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

    testWidgets('removes the decrypted temp file on dispose', (tester) async {
      stubDelete();
      stubDecrypt(() async {
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

      expect(File(expectedClipPath()).existsSync(), isFalse);
      verify(() => decryptor.deleteClip(expectedClipPath())).called(1);
    });

    testWidgets('shows an error state when decrypt fails', (tester) async {
      stubDecrypt(() async => throw Exception('decrypt failed'));
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

    group('save', () {
      final l10n = AppLocalizationsEn();

      Future<void> pumpReady(
        WidgetTester tester, {
        required bool canAddToClips,
      }) async {
        stubDelete();
        stubDecrypt(() async {
          File(expectedClipPath())
            ..createSync(recursive: true)
            ..writeAsBytesSync(const [1, 2, 3]);
          return expectedClipPath();
        });
        when(
          () => gallerySaveService.saveVideoToGallery(any()),
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

        verify(() => gallerySaveService.saveVideoToGallery(any())).called(1);
      });

      testWidgets('saves straight to the gallery when clips are not offered', (
        tester,
      ) async {
        await pumpReady(tester, canAddToClips: false);

        await tester.tap(find.bySemanticsLabel(l10n.shareSheetSaveVideo));
        await tester.pumpAndSettle();

        expect(find.text(l10n.shareSheetAddToClips), findsNothing);
        verify(() => gallerySaveService.saveVideoToGallery(any())).called(1);
      });
    });
  });
}
