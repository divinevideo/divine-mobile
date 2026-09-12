// ABOUTME: Widget tests for ProfileAvatarSection in the profile-setup form.
// ABOUTME: Covers avatar rendering, the upload progress indicator, and the
// ABOUTME: pick → crop → dispatch path via the imageCropLauncherProvider seam.

import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/camera_pick_error_l10n.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/camera_pick_error.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/image_crop_launcher_provider.dart';
import 'package:openvine/screens/image_crop_editor/image_crop_editor.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_avatar_section.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../../helpers/image_picker_stub.dart';
import '../../helpers/shared_channel_override.dart';
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

  group(ProfileAvatarSection, () {
    const testPubkeyHex =
        'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';

    late MockAuthService mockAuthService;
    late _MockProfileEditorBloc bloc;
    late TextEditingController nameController;

    setUp(() {
      mockAuthService = createMockAuthService();
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkeyHex);
      bloc = _MockProfileEditorBloc();
      when(() => bloc.state).thenReturn(const ProfileEditorState());
      nameController = TextEditingController();
    });

    tearDown(() => nameController.dispose());

    Future<void> pump(
      WidgetTester tester, {
      TextEditingController? controller,
      ImageCropLauncher? cropLauncher,
    }) {
      return tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            if (cropLauncher != null)
              imageCropLauncherProvider.overrideWithValue(cropLauncher),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: Scaffold(
              body: BlocProvider<ProfileEditorBloc>.value(
                value: bloc,
                child: ProfileAvatarSection(
                  nameController: controller ?? nameController,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the avatar preview', (tester) async {
      await pump(tester);
      expect(find.byType(UserAvatar), findsOneWidget);
    });

    testWidgets('shows a progress indicator while an avatar is uploading', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.uploading,
        ),
      );
      await pump(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('uses pendingPictureUrl for the staged avatar preview', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.staged,
          pendingPictureUrl: 'https://media.divine.video/staged-avatar-hash',
          persistedPictureUrl: 'https://media.divine.video/persisted-avatar',
        ),
      );

      await pump(tester);

      final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
      final imageProvider = avatar.imageProvider;
      expect(imageProvider, isA<NetworkImage>());
      expect(
        (imageProvider! as NetworkImage).url,
        'https://media.divine.video/staged-avatar-hash',
      );
    });

    testWidgets('skips dead pending avatar URLs in the preview', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.staged,
          pendingPictureUrl: 'https://v.cdn.vine.co/v/avatars/staged.jpg',
        ),
      );

      await pump(tester);

      expect(
        tester.widget<UserAvatar>(find.byType(UserAvatar)).imageProvider,
        isNull,
      );
    });

    testWidgets('skips insecure pending avatar URLs in the preview', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.staged,
          pendingPictureUrl: 'http://images.example/staged.jpg',
        ),
      );

      await pump(tester);

      expect(
        tester.widget<UserAvatar>(find.byType(UserAvatar)).imageProvider,
        isNull,
      );
    });

    testWidgets('skips dead persisted avatar URLs in the preview', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const ProfileEditorState(
          persistedPictureUrl: 'https://v.cdn.vine.co/v/avatars/persisted.jpg',
        ),
      );

      await pump(tester);

      expect(
        tester.widget<UserAvatar>(find.byType(UserAvatar)).imageProvider,
        isNull,
      );
    });

    testWidgets(
      're-subscribes the avatar name when nameController is swapped',
      (tester) async {
        await pump(tester);

        final swapped = TextEditingController(text: 'Bob');
        addTearDown(swapped.dispose);
        await pump(tester, controller: swapped);
        expect(tester.widget<UserAvatar>(find.byType(UserAvatar)).name, 'Bob');

        // Mutating the new controller updates the avatar only if the listener
        // was re-bound in didUpdateWidget.
        swapped.text = 'Carol';
        await tester.pump();
        expect(
          tester.widget<UserAvatar>(find.byType(UserAvatar)).name,
          'Carol',
        );
      },
    );

    group('removing the picture', () {
      Future<void> openSheet(WidgetTester tester) async {
        await tester.tap(find.byType(DivineIconButton));
        await tester.pumpAndSettle();
      }

      testWidgets('offers no remove row when there is no picture', (
        tester,
      ) async {
        await pump(tester);
        await openSheet(tester);

        expect(find.text(l10n.profileSetupAvatarClearButton), findsNothing);
      });

      testWidgets('removing a persisted picture dispatches '
          '$ProfilePictureCleared', (tester) async {
        when(() => bloc.state).thenReturn(
          const ProfileEditorState(
            persistedPictureUrl: 'https://cdn.example.com/old.jpg',
          ),
        );
        await pump(tester);
        await openSheet(tester);

        await tester.tap(find.text(l10n.profileSetupAvatarClearButton));
        await tester.pumpAndSettle();

        final captured = verify(() => bloc.add(captureAny())).captured;
        expect(captured.whereType<ProfilePictureCleared>(), hasLength(1));
      });

      testWidgets('a cleared picture leaves the preview empty', (tester) async {
        when(() => bloc.state).thenReturn(
          const ProfileEditorState(
            persistedPictureUrl: 'https://cdn.example.com/old.jpg',
            pictureCleared: true,
          ),
        );
        await pump(tester);

        // Null provider is the placeholder path — the persisted URL must not
        // come back after the user asked for it to go.
        expect(
          tester.widget<UserAvatar>(find.byType(UserAvatar)).imageProvider,
          isNull,
        );
      });
    });

    group('pick → crop → dispatch', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('avatar_section_test');
      });

      tearDown(() async {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });

      File stubPickedFile(List<int> bytes) =>
          stubPickedImageFile(tempDir, bytes);

      // Gallery picks route through file_selector on desktop and image_picker
      // on mobile; force a mobile platform so the mocked image_picker channel
      // is exercised. The sources moved behind the pencil, so each pick is now
      // two taps: open the sheet, then choose the row.
      Future<void> pickFromGallery(WidgetTester tester) async {
        await tester.tap(find.byType(DivineIconButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.profileSetupImageUploadFromCameraRoll));
        await tester.pumpAndSettle();
      }

      testWidgets(
        'dispatches ProfilePictureUploadRequested with the cropped bytes',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          try {
            stubPickedFile([9, 9, 9]);
            final croppedBytes = Uint8List.fromList([1, 2, 3, 4]);
            final launcher = _FakeCropLauncher(croppedBytes);
            await pump(tester, cropLauncher: launcher.launch);

            await pickFromGallery(tester);

            expect(launcher.callCount, 1);
            expect(launcher.lastKind, ImageCropKind.avatar);

            final captured = verify(() => bloc.add(captureAny())).captured;
            expect(captured, hasLength(1));
            final event = captured.single;
            expect(event, isA<ProfilePictureUploadRequested>());
            final upload = event as ProfilePictureUploadRequested;
            expect(upload.pubkey, testPubkeyHex);
            expect(upload.bytes, equals(croppedBytes));
            expect(upload.filename, ImageCropKind.avatar.filename);
            expect(upload.mimeType, ImageCropKind.avatar.mimeType);
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );

      testWidgets('does not dispatch when the crop is cancelled', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          stubPickedFile([9, 9, 9]);
          final launcher = _FakeCropLauncher(null);
          await pump(tester, cropLauncher: launcher.launch);

          await pickFromGallery(tester);

          expect(launcher.callCount, 1);
          verifyNever(() => bloc.add(any()));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('rejects a zero-byte pick before opening the crop editor', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          // iOS occasionally hands back an empty temporary JPEG; decoding it
          // inside the crop editor is what crashed (#6276).
          stubPickedFile([]);
          final launcher = _FakeCropLauncher(Uint8List.fromList([1, 2, 3]));
          await pump(tester, cropLauncher: launcher.launch);

          await pickFromGallery(tester);

          expect(launcher.callCount, 0);
          verifyNever(() => bloc.add(any()));
          expect(
            find.text(l10n.profileSetupImageSelectionFailed),
            findsOneWidget,
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('rejects a pick whose file is gone', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          stubPickedFile([9, 9, 9]).deleteSync();
          final launcher = _FakeCropLauncher(Uint8List.fromList([1, 2, 3]));
          await pump(tester, cropLauncher: launcher.launch);

          await pickFromGallery(tester);

          expect(launcher.callCount, 0);
          verifyNever(() => bloc.add(any()));
          expect(
            find.text(l10n.profileSetupImageSelectionFailed),
            findsOneWidget,
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets(
        'camera permission denial shows localized copy, not the exception',
        (tester) async {
          // #3589: this branch used to render
          // `PlatformException(camera_access_denied, The user did not allow
          // camera access., null, null)` verbatim. It had no test at all —
          // both existing failure tests go through the gallery branch, which
          // uses a different key.
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          try {
            overrideSharedChannel(imagePickerChannel, (call) async {
              throw PlatformException(
                code: 'camera_access_denied',
                message: 'The user did not allow camera access.',
              );
            });
            await pump(tester);

            await tester.tap(find.byType(DivineIconButton));
            await tester.pumpAndSettle();
            await tester.tap(find.text(l10n.profileSetupImageTakePhoto));
            await tester.pumpAndSettle();

            expect(
              find.text(
                l10n.cameraPickErrorMessage(CameraPickError.permissionDenied),
              ),
              findsOneWidget,
            );
            expect(find.textContaining('PlatformException'), findsNothing);
            expect(find.textContaining('camera_access_denied'), findsNothing);
            verifyNever(() => bloc.add(any()));
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );

      Future<void> openUrlSheet(WidgetTester tester) async {
        await tester.tap(find.byType(DivineIconButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.profileSetupImagePasteLink));
        await tester.pumpAndSettle();
      }

      testWidgets('Save stages the typed image URL', (tester) async {
        await pump(tester);
        await openUrlSheet(tester);

        await tester.enterText(
          find.byType(TextField),
          'https://cdn.example.com/a.jpg',
        );
        await tester.tap(find.text(l10n.profileSetupSaveButton));
        await tester.pumpAndSettle();

        final captured = verify(() => bloc.add(captureAny())).captured;
        final staged = captured.whereType<ProfilePictureUrlSet>();
        expect(staged, hasLength(1));
        expect(staged.single.url, 'https://cdn.example.com/a.jpg');
      });

      testWidgets('Cancel leaves the staged picture untouched', (tester) async {
        await pump(tester);
        await openUrlSheet(tester);

        await tester.enterText(
          find.byType(TextField),
          'https://cdn.example.com/a.jpg',
        );
        await tester.tap(find.text(l10n.commonCancel));
        await tester.pumpAndSettle();

        verifyNever(() => bloc.add(any(that: isA<ProfilePictureUrlSet>())));
      });

      testWidgets('skips crop and dispatch when no public key is available', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);
          final launcher = _FakeCropLauncher(Uint8List.fromList([1, 2, 3]));
          await pump(tester, cropLauncher: launcher.launch);

          await pickFromGallery(tester);

          expect(launcher.callCount, 0);
          verifyNever(() => bloc.add(any()));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    });
  });
}
