// ABOUTME: Widget tests for the banner half of ProfileHeaderPreview.
// ABOUTME: Covers the pick → crop → dispatch path via the
// ABOUTME: imageCropLauncherProvider seam, including rejected empty picks.

import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/image_crop_launcher_provider.dart';
import 'package:openvine/screens/image_crop_editor/image_crop_editor.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_header_preview.dart';

import '../../helpers/image_picker_stub.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockProfileEditorBloc
    extends MockBloc<ProfileEditorEvent, ProfileEditorState>
    implements ProfileEditorBloc {}

/// Fake crop launcher that records its invocation and returns a canned result
/// without pumping the real editor (which needs a decodable image).
class _FakeCropLauncher {
  _FakeCropLauncher(this.result);

  final Uint8List? result;
  int callCount = 0;
  ImageCropKind? lastKind;

  Future<Uint8List?> launch(
    BuildContext context, {
    required ImageCropKind kind,
    File? file,
    Uint8List? bytes,
  }) async {
    callCount++;
    lastKind = kind;
    return result;
  }
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(ProfileHeaderPreview, () {
    const testPubkeyHex =
        'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';

    late MockAuthService mockAuthService;
    late _MockProfileEditorBloc bloc;
    late TextEditingController nameController;
    late Directory tempDir;

    setUp(() async {
      mockAuthService = createMockAuthService();
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkeyHex);
      bloc = _MockProfileEditorBloc();
      when(() => bloc.state).thenReturn(const ProfileEditorState());
      when(() => bloc.isClosed).thenReturn(false);
      nameController = TextEditingController();
      tempDir = await Directory.systemTemp.createTemp('header_preview_test');
    });

    tearDown(() async {
      nameController.dispose();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    File stubPickedFile(List<int> bytes) => stubPickedImageFile(tempDir, bytes);

    Future<void> pump(WidgetTester tester, ImageCropLauncher cropLauncher) {
      return tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            imageCropLauncherProvider.overrideWithValue(cropLauncher),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: Scaffold(
              body: BlocProvider<ProfileEditorBloc>.value(
                value: bloc,
                child: ProfileHeaderPreview(nameController: nameController),
              ),
            ),
          ),
        ),
      );
    }

    /// Opens the banner sheet from its own pencil — the avatar has one too —
    /// and picks the gallery row.
    Future<void> pickBannerFromGallery(WidgetTester tester) async {
      await tester.tap(find.byTooltip(l10n.profileSetupEditBannerLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.profileSetupImageUploadFromCameraRoll));
      await tester.pumpAndSettle();
    }

    testWidgets('dispatches $ProfileBannerUploadRequested with the cropped '
        'bytes', (tester) async {
      stubPickedFile([9, 9, 9]);
      final croppedBytes = Uint8List.fromList([1, 2, 3, 4]);
      final launcher = _FakeCropLauncher(croppedBytes);
      await pump(tester, launcher.launch);

      await pickBannerFromGallery(tester);

      expect(launcher.callCount, 1);
      expect(launcher.lastKind, ImageCropKind.banner);

      final captured = verify(() => bloc.add(captureAny())).captured;
      final uploads = captured.whereType<ProfileBannerUploadRequested>();
      expect(uploads, hasLength(1));
      expect(uploads.single.pubkey, testPubkeyHex);
      expect(uploads.single.bytes, equals(croppedBytes));
    });

    testWidgets('rejects a zero-byte pick before opening the crop editor', (
      tester,
    ) async {
      // iOS occasionally hands back an empty temporary JPEG; decoding it
      // inside the crop editor is what crashed (#6276).
      stubPickedFile([]);
      final launcher = _FakeCropLauncher(Uint8List.fromList([1, 2, 3]));
      await pump(tester, launcher.launch);

      await pickBannerFromGallery(tester);

      expect(launcher.callCount, 0);
      verifyNever(() => bloc.add(any()));
      expect(find.text(l10n.profileSetupImageSelectionFailed), findsOneWidget);
    });

    testWidgets('rejects a pick whose file is gone', (tester) async {
      stubPickedFile([9, 9, 9]).deleteSync();
      final launcher = _FakeCropLauncher(Uint8List.fromList([1, 2, 3]));
      await pump(tester, launcher.launch);

      await pickBannerFromGallery(tester);

      expect(launcher.callCount, 0);
      verifyNever(() => bloc.add(any()));
      expect(find.text(l10n.profileSetupImageSelectionFailed), findsOneWidget);
    });

    testWidgets('drops the upload when the editor closed during the crop', (
      tester,
    ) async {
      // Picking and cropping are full screens; leaving the profile editor
      // while they are open closes the bloc before the crop returns.
      stubPickedFile([9, 9, 9]);
      final launcher = _FakeCropLauncher(Uint8List.fromList([1, 2, 3, 4]));
      await pump(tester, launcher.launch);
      when(() => bloc.isClosed).thenReturn(true);

      await pickBannerFromGallery(tester);

      expect(launcher.callCount, 1);
      verifyNever(() => bloc.add(any()));
    });
  });
}
